import 'package:crasy/features/auth/domain/entities/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<AppUser> signUp({required String email, required String password});

  Future<AppUser> signIn({required String email, required String password});

  Future<void> signOut();

  /// Manda (o rimanda) il messaggio con il link di conferma.
  Future<void> sendEmailVerification();

  /// Manda il messaggio per rifarsi la password.
  ///
  /// **Non dice mai se quell'indirizzo esiste**, e non e' pigrizia: rispondere
  /// "questa email non e' registrata" regala a chiunque un modo di scoprire chi
  /// sta su CRASY, provando indirizzi finche' uno non risponde. Chi ha
  /// sbagliato a scrivere se ne accorge dal messaggio che non arriva.
  Future<void> sendPasswordReset({required String email});

  /// Richiede al server lo stato aggiornato dell'utente.
  ///
  /// Serve perche' la conferma dell'email avviene **fuori dall'app** — in una
  /// pagina del browser — e nessuno viene ad avvisarci. Senza questa richiesta
  /// l'app resterebbe convinta che l'indirizzo non sia confermato anche dopo
  /// che lo e'.
  Future<AppUser?> reload();
}
