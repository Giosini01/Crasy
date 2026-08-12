import 'package:crasy/features/challenges/data/repositories/firestore_challenge_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract final class ErrorMessageMapper {
  static String map(Object error) {
    if (error is ChallengeClosedException) {
      return 'La challenge si e chiusa. Il tempo era scaduto.';
    }

    if (error is ChallengeNotFoundException) {
      return 'Questa challenge non esiste piu.';
    }

    if (error is AlreadyParticipatingException) {
      return 'Hai gia mandato la tua foto per questa challenge.';
    }

    if (error is FirebaseAuthException) {
      return _mapAuthError(error);
    }

    if (error is FirebaseException) {
      return _mapFirebaseError(error);
    }

    return 'Si e verificato un problema. Riprova tra poco.';
  }

  static String _mapAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Inserisci un indirizzo email valido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email o password non corrette.';
      case 'email-already-in-use':
        return 'Esiste gia un account con questa email.';
      case 'weak-password':
        return 'La password deve avere almeno 8 caratteri.';
      case 'network-request-failed':
        return 'Connessione assente o instabile. Controlla la rete.';
      case 'too-many-requests':
        return 'Troppi tentativi. Riprova tra qualche minuto.';
      default:
        return 'Autenticazione non riuscita. Riprova.';
    }
  }

  static String _mapFirebaseError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Non hai accesso a questa operazione.';
      case 'unavailable':
        return 'Servizio temporaneamente non disponibile.';
      case 'network-request-failed':
        return 'Connessione assente o instabile. Controlla la rete.';
      default:
        return 'Salvataggio non riuscito. Riprova.';
    }
  }
}
