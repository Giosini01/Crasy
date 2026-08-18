import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

/// Il ponte verso i soldi.
///
/// Tutte e tre le chiamate hanno la stessa forma: si manda un identificativo,
/// torna **un indirizzo da aprire**. Nessun importo parte da qui e nessun
/// importo torna qui per essere creduto: le cifre le decide il server, e la
/// pagina su cui si paga e' di Stripe.
///
/// La conseguenza pratica e' che **i numeri di carta non passano mai da CRASY**.
/// Non e' comodita': e' la differenza fra dover rispettare lo standard PCI e non
/// doverlo fare, e vale anche per la conferma con la banca che le carte europee
/// richiedono — quella pagina la sa gia' gestire, noi no.
class PaymentsService {
  PaymentsService(this._functions);

  final FirebaseFunctions _functions;

  /// Apre la pagina per pagare il premio di una challenge appena creata.
  ///
  /// Torna `false` se la pagina non si e' potuta aprire. Non lancia: chi chiama
  /// e' una schermata, e ha gia' un modo di dirlo alla persona.
  Future<bool> payChallenge(String challengeId) async {
    final result = await _functions
        .httpsCallable('startChallengePayment')
        .call<Map<Object?, Object?>>({'challengeId': challengeId});

    return _open(result.data['url']);
  }

  /// Apre la registrazione di chi deve incassare: nome, documento, IBAN.
  ///
  /// Si fa una volta sola, alla prima vittoria. Non e' un modulo che abbiamo
  /// deciso noi: pagare qualcuno senza sapere chi e' e' vietato, e nessuna app
  /// puo' saltarlo.
  Future<bool> startPayoutOnboarding() async {
    final result = await _functions
        .httpsCallable('createPayoutOnboarding')
        .call<Map<Object?, Object?>>();

    return _open(result.data['url']);
  }

  /// Preleva tutto quello che c'e' nel portafoglio.
  ///
  /// Torna il motivo per cui **non** e' partito, oppure `null` se e' partito.
  /// Non lancia per il caso piu' comune — l'account che non c'e' ancora — che
  /// non e' un errore ma il primo passo: chi chiama apre la registrazione.
  Future<String?> withdraw() async {
    final result = await _functions
        .httpsCallable('withdrawWallet')
        .call<Map<Object?, Object?>>();

    if (result.data['paid'] == true) {
      return null;
    }

    return result.data['reason'] as String? ?? 'sconosciuto';
  }

  Future<bool> _open(Object? url) async {
    if (url is! String || url.isEmpty) {
      return false;
    }

    return launchUrl(
      Uri.parse(url),
      // Sul telefono il pagamento apre il browser vero e non una finestra
      // dentro l'app: e' li' che stanno le carte salvate e le app della banca
      // per la conferma, e senza di quelle un pagamento europeo si blocca a
      // meta'.
      mode: LaunchMode.externalApplication,
    );
  }
}
