import 'package:crasy/features/auth/domain/entities/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<AppUser> signUp({required String email, required String password});

  Future<AppUser> signIn({required String email, required String password});

  Future<void> signOut();

  /// Manda (o rimanda) il messaggio con il link di conferma.
  Future<void> sendEmailVerification();

  /// Richiede al server lo stato aggiornato dell'utente.
  ///
  /// Serve perche' la conferma dell'email avviene **fuori dall'app** — in una
  /// pagina del browser — e nessuno viene ad avvisarci. Senza questa richiesta
  /// l'app resterebbe convinta che l'indirizzo non sia confermato anche dopo
  /// che lo e'.
  Future<AppUser?> reload();
}
