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

      // **I casi del numero di telefono, uno per uno.**
      //
      // Prima finivano tutti nel ripiego — "autenticazione non riuscita" — che
      // e' la frase piu' inutile che si possa scrivere sotto un campo: non dice
      // se hai sbagliato tu, se il codice e' scaduto o se manca qualcosa dalla
      // nostra parte. Chi la legge non sa nemmeno se vale la pena riprovare.
      case 'invalid-phone-number':
        return 'Questo numero non sembra giusto. Controllalo.';
      case 'invalid-verification-code':
        return 'Codice sbagliato. Ricontrolla le sei cifre.';
      case 'session-expired':
      case 'code-expired':
        return 'Il codice è scaduto. Chiedine un altro.';
      case 'credential-already-in-use':
      case 'account-exists-with-different-credential':
        // **E' la regola che rende utile tutta la verifica**, quindi si dice
        // esattamente cosa e' successo invece di un errore vago: un numero, un
        // account. Chi ci finisce sopra sta provando a verificare un secondo
        // profilo con lo stesso telefono.
        return 'Questo numero è già su un altro account CRASY. '
            'Un numero vale per un account solo.';
      case 'provider-already-linked':
        return 'Hai già verificato un numero su questo account.';
      case 'quota-exceeded':
        return 'Abbiamo finito i messaggi per oggi. Riprova domani.';
      case 'operation-not-allowed':
        // Non e' colpa di chi sta guardando lo schermo: e' un interruttore
        // spento nella console. Dirlo apertamente e' l'unico modo perche' chi
        // tiene l'app lo scopra invece di cercare il difetto nel codice.
        return 'La verifica via SMS non è attiva. '
            'Non dipende da te: ci stiamo lavorando.';
      case 'captcha-check-failed':
      case 'missing-client-identifier':
        return 'Verifica di sicurezza non riuscita. Riprova fra un minuto.';

      default:
        return 'Autenticazione non riuscita. Riprova.';
    }
  }

  static String _mapFirebaseError(FirebaseException error) {
    switch (error.code) {
      // **Mai piu' "operazione non consentita, chiudi e riapri l'app".**
      //
      // Era la frase di prima, e diceva tre cose sbagliate insieme: dava la
      // colpa a chi legge, gli chiedeva di fare il tecnico, e non spiegava
      // niente. Chi la trovava dopo aver scattato una foto concludeva di aver
      // rotto qualcosa — o che fosse rotta l'app.
      //
      // Un rifiuto di permessi, visto da questo lato dello schermo, vuol dire
      // quasi sempre **una cosa sola**: si sta provando a fare una cosa che
      // adesso non si puo' piu' fare, perche' il tempo e' scaduto mentre la
      // schermata era aperta. Non e' un guasto, e non deve suonare come tale.
      //
      // I casi in cui invece la colpa e' nostra si prendono **prima di
      // arrivare qui**, dove si sa ancora cosa si stava facendo: vedi la
      // fiamma, che un rifiuto lo traduce in "il tempo e' finito" senza
      // mostrare niente di rosso.
      case 'permission-denied':
        return 'Questa cosa adesso non si può più fare: il tempo è scaduto.';
      case 'unavailable':
        return 'Servizio temporaneamente non disponibile.';
      case 'network-request-failed':
        return 'Connessione assente o instabile. Controlla la rete.';
      default:
        return 'Salvataggio non riuscito. Riprova.';
    }
  }
}
