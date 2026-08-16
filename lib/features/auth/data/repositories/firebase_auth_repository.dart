import 'package:crasy/features/auth/domain/entities/app_user.dart';
import 'package:crasy/features/auth/domain/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    await credential.user?.sendEmailVerification();

    return _mapFirebaseUser(credential.user);
  }

  @override
  Future<void> sendEmailVerification() async {
    await _firebaseAuth.currentUser?.sendEmailVerification();
  }

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
    );
  }
}
