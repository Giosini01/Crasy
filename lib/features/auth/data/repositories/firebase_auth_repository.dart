import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crasy/features/auth/domain/entities/app_user.dart';
import 'package:crasy/features/auth/domain/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._firebaseAuth, this._functions);

  final FirebaseAuth _firebaseAuth;

  /// Serve per una cosa sola: chiedere al server di mandare la conferma.
  final FirebaseFunctions _functions;

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
    //
    // **Se non parte, la registrazione vale lo stesso.** L'invio adesso passa
    // dal nostro server, quindi puo' fallire per cose che non riguardano chi si
    // sta iscrivendo: la casella di posta che non risponde, una funzione ancora
    // da pubblicare. Lasciando salire l'errore, l'account verrebbe creato e la
    // schermata direbbe che la registrazione non e' riuscita — e chi riprova si
    // sentirebbe dire che l'indirizzo e' gia' in uso. Un vicolo cieco creato da
    // noi, per un messaggio che si puo' rimandare con un tocco.
    try {
      await sendEmailVerification();
    } on Object catch (_) {
      // Vedi sopra: c'e' il tasto "rimandamela" nella schermata dopo.
    }

    return _mapFirebaseUser(credential.user);
  }

  /// **La conferma la manda il server, non Firebase.**
  ///
  /// Non e' un capriccio: l'indirizzo a cui portano i link di Firebase su
  /// questo progetto **non si puo' cambiare** — l'API risponde
  /// `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED` a qualunque valore, e la console
  /// fallisce allo stesso modo. L'email arrivava dal nostro dominio e portava
  /// a una pagina bianca ospitata sul vecchio nome del progetto.
  ///
  /// La funzione `mandaLaConferma` chiede a Firebase il codice, se lo prende e
  /// lo mette dentro un messaggio nostro con un link nostro. Vedi
  /// `functions/posta.js`.
  ///
  /// Non lancia se il server dice di no: l'unico caso in cui succede e' un
  /// invio troppo ravvicinato, e a chi ha appena premuto "rimandamela" va detto
  /// che e' partita — perche' e' partita, un minuto fa.
  @override
  Future<void> sendEmailVerification() async {
    await _functions.httpsCallable('mandaLaConferma').call<Object?>();
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

  @override
  Future<void> applyActionCode(String code) =>
      _firebaseAuth.applyActionCode(code);

  @override
  Future<String> checkPasswordResetCode(String code) =>
      _firebaseAuth.verifyPasswordResetCode(code);

  @override
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) {
    return _firebaseAuth.confirmPasswordReset(
      code: code,
      newPassword: newPassword,
    );
  }

  /// Dove si finisce dopo aver confermato l'indirizzo.
  ///
  /// **Adesso il link non porta piu' a una pagina di Firebase.** Il gestore dei
  /// messaggi e' stato spostato su `crasy.web.app/#/conferma`, che e' una
  /// schermata nostra — vedi `EmailActionPage` e `tool/pagina_dei_messaggi.py`.
  /// Chi conferma l'indirizzo resta dentro CRASY dall'inizio alla fine, invece
  /// di finire su una pagina bianca con sopra il vecchio nome del progetto.
  ///
  /// Questo indirizzo resta comunque, e viaggia nel link come `continueUrl`:
  /// e' dove si torna dopo, ed e' l'unica via d'uscita per chi ha aperto il
  /// messaggio da un telefono diverso da quello dove ha l'app.
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
  String? get currentPhoneNumber => _firebaseAuth.currentUser?.phoneNumber;

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
      // **Nel browser si aggancia il numero, non si entra con il numero.**
      //
      // C'era `signInWithPhoneNumber`, ed era sbagliato in un modo che si
      // vedeva solo provandolo: quel metodo apre una sessione **nuova**
      // intestata al telefono, buttando fuori l'account con cui si e' entrati.
      // Chi verificava il proprio numero si ritrovava scollegato dal proprio
      // account — e senza un `currentUser` a cui attaccarlo, l'operazione
      // moriva li'.
      //
      // `linkWithPhoneNumber` fa la cosa giusta: attacca il numero all'account
      // che c'e' gia', come su iPhone e su Android.
      final utente = _firebaseAuth.currentUser;

      if (utente == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'Sessione non valida.',
        );
      }

      final conferma = await utente.linkWithPhoneNumber(phoneNumber);
      _confermaWeb = conferma;

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

  /// La verifica in corso nel browser.
  ///
  /// **Sul web il codice non si controlla ricostruendo una credenziale**: si
  /// consegna all'oggetto che ha mandato l'SMS, e quello vive solo in memoria.
  /// Per questo va tenuto da parte fra il momento in cui si manda il codice e
  /// quello in cui si scrive.
  ConfirmationResult? _confermaWeb;

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

    if (kIsWeb) {
      final conferma = _confermaWeb;

      if (conferma == null) {
        throw FirebaseAuthException(
          code: 'session-expired',
          message: 'Il codice e\' scaduto. Chiedine un altro.',
        );
      }

      await conferma.confirm(code);
      await utente.reload();
      _confermaWeb = null;

      return _firebaseAuth.currentUser?.phoneNumber ?? '';
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
    try {
      await utente.linkWithCredential(credenziale);
    } on FirebaseAuthException catch (errore) {
      // **Gia' agganciato non e' un fallimento.**
      //
      // Capita a chi si e' fermato fra i due passaggi: il numero era stato
      // legato all'account, ma il profilo non era stato aggiornato. Tornando
      // qui, Firebase rifiuta di legarlo una seconda volta — giustamente — e
      // trattare quel rifiuto come un errore lascerebbe la persona chiusa
      // fuori per sempre, con la schermata che chiede un numero che ha gia'
      // dato.
      //
      // Vale solo se il numero agganciato c'e' davvero: allora il lavoro era
      // gia' fatto, e qui non resta che dirlo.
      final gia = _firebaseAuth.currentUser?.phoneNumber;

      if (errore.code != 'provider-already-linked' ||
          gia == null ||
          gia.isEmpty) {
        rethrow;
      }
    }

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
