import 'dart:async';

import 'package:crasy/features/auth/domain/entities/app_user.dart';
import 'package:crasy/features/auth/domain/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  /// `userChanges` e non `authStateChanges`.
  ///
  /// Il secondo batte solo quando si entra e quando si esce; a noi serve
  /// sapere anche **quando l'email viene confermata**, che e' un cambiamento
  /// dell'utente e non della sessione. Con `authStateChanges` la schermata di
  /// verifica sarebbe rimasta li' per sempre anche dopo aver aperto il link.
  @override
  Stream<AppUser?> authStateChanges() {
    return _firebaseAuth.userChanges().map(_mapUser);
  }

  @override
  AppUser? get currentUser => _mapUser(_firebaseAuth.currentUser);

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return _mapFirebaseUser(credential.user);
  }

  @override
  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Il messaggio parte subito, senza che nessuno debba chiederlo: chi si e'
    // appena registrato ha l'app in mano e la casella aperta, ed e' l'unico
    // momento in cui confermare costa zero.
    await credential.user?.sendEmailVerification(_backToCrasy);

    return _mapFirebaseUser(credential.user);
  }

  @override
  Future<void> sendEmailVerification() async {
    await _firebaseAuth.currentUser?.sendEmailVerification(_backToCrasy);
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: _backToCrasy,
      );
    } on FirebaseAuthException catch (error) {
      // **Un indirizzo sconosciuto non e' un errore da mostrare.** Firebase lo
      // dice — `user-not-found` — e ripeterlo a schermo trasformerebbe questa
      // schermata in uno strumento per sapere chi e' iscritto a CRASY: si
      // provano indirizzi finche' uno non risponde "esiste". Qui il caso si
      // ingoia, e chi ha sbagliato a scrivere se ne accorge dal messaggio che
      // non arriva.
      if (error.code != 'user-not-found' && error.code != 'invalid-email') {
        rethrow;
      }
    }
  }

  /// Dove si finisce dopo aver confermato l'indirizzo.
  ///
  /// Senza, l'ultima cosa che vede chi si registra e' una pagina bianca di
  /// Firebase con scritto "indirizzo verificato" e nessuna via d'uscita: ha
  /// appena fatto tutto giusto e si ritrova fuori dall'app, su un indirizzo che
  /// non ha mai sentito nominare. Con questo, sulla stessa pagina compare un
  /// collegamento che riporta dentro CRASY.
  ///
  /// **Non cambia il dominio del link** — quello e' l'indirizzo del gestore di
  /// Firebase e si sposta solo dalla Console. Cambia dove si atterra dopo, che
  /// e' la meta' del problema che si puo' risolvere da qui.
  static final ActionCodeSettings _backToCrasy = ActionCodeSettings(
    url: 'https://crasy.web.app/',
    handleCodeInApp: false,
  );

  @override
  Future<AppUser?> reload() async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      return null;
    }

    await user.reload();

    // Si rilegge da `currentUser` e non dalla variabile qui sopra: `reload`
    // aggiorna l'istanza tenuta da Firebase, non quella che avevamo in mano.
    return _mapUser(_firebaseAuth.currentUser);
  }

  AppUser _mapFirebaseUser(User? user) {
    final mappedUser = _mapUser(user);

    if (mappedUser == null) {
      throw StateError('Utente Firebase non disponibile.');
    }

    return mappedUser;
  }

  AppUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }

    return AppUser(
      id: user.uid,
      email: user.email,
      emailVerified: user.emailVerified,
      createdAt: user.metadata.creationTime,
    );
  }

  @override
  Future<void> discardUnverifiedAccount() async {
    final user = _firebaseAuth.currentUser;

    if (user == null || user.emailVerified) {
      return;
    }

    try {
      await user.delete();
    } on Object {
      // Se Firebase pretende un accesso piu' recente non si insiste: si esce e
      // basta. L'account resta li' e verra' buttato al prossimo tentativo — e
      // nel frattempo la persona non e' bloccata su una schermata che non le
      // fa fare niente.
      await _firebaseAuth.signOut();
    }
  }

  @override
  Future<String> sendPhoneCode({required String phoneNumber}) async {
    // **Sul web e sui telefoni si parte da due strade diverse.** Nel browser
    // Firebase apre da se' il proprio controllo anti-robot e il codice torna
    // per un'altra via; su iPhone e Android il controllo lo fa il sistema
    // operativo, in silenzio.
    //
    // Il `Completer` mette d'accordo le due: qualunque strada prenda Firebase,
    // di qui esce **un identificativo o un errore**, una volta sola.
    final atteso = Completer<String>();

    if (kIsWeb) {
      final conferma = await _firebaseAuth.signInWithPhoneNumber(phoneNumber);

      return conferma.verificationId;
    }

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      // Su Android il codice a volte arriva e si applica da solo. Non lo
      // usiamo per chiudere l'operazione: la schermata sta aspettando un
      // identificativo, e riceverne uno e' l'unico modo di andare avanti in
      // tutti i casi allo stesso modo.
      verificationCompleted: (_) {},
      verificationFailed: (errore) {
        if (!atteso.isCompleted) {
          atteso.completeError(errore);
        }
      },
      codeSent: (verificationId, _) {
        if (!atteso.isCompleted) {
          atteso.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        // Scaduta l'attesa del riempimento automatico l'identificativo resta
        // buono: se nessuno ha ancora risposto, e' questo il momento di
        // consegnarlo.
        if (!atteso.isCompleted) {
          atteso.complete(verificationId);
        }
      },
      timeout: const Duration(seconds: 60),
    );

    return atteso.future;
  }

  @override
  Future<String> confirmPhoneCode({
    required String verificationId,
    required String code,
  }) async {
    final utente = _firebaseAuth.currentUser;

    if (utente == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Sessione non valida.',
      );
    }

    final credenziale = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );

    // **Si attacca al proprio account, non si entra con il numero.**
    //
    // Se il numero e' gia' attaccato a un altro account Firebase rifiuta, ed e'
    // esattamente quello che vogliamo: e' la riga che impedisce a una persona
    // sola di verificare cinque profili con lo stesso telefono, cioe' tutto il
    // motivo per cui questa schermata esiste.
    await utente.linkWithCredential(credenziale);
    await utente.reload();

    return _firebaseAuth.currentUser?.phoneNumber ?? '';
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    final user = _firebaseAuth.currentUser;
    final email = user?.email;

    if (user == null || email == null) {
      return;
    }

    // Prima si dimostra di essere chi si dice, poi si cancella. L'ordine non e'
    // negoziabile: al contrario, un accesso scaduto lascerebbe i dati
    // cancellati e l'account in piedi.
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );

    await user.delete();
  }
}
