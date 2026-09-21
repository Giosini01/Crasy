import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';

/// Il ponte verso i soldi.
///
/// **Nessun importo parte da qui, e nessuno torna qui per essere creduto.** Le
/// cifre le decide il server, e a incassarle e' Stripe: o la sua pagina, sul
/// sito, o il suo foglio nativo dentro l'app.
///
/// La conseguenza pratica e' che **i numeri di carta non passano mai da CRASY**.
/// Non e' comodita': e' la differenza fra dover rispettare lo standard PCI e non
/// doverlo fare, e vale anche per la conferma con la banca che le carte europee
/// richiedono — quella pagina la sa gia' gestire, noi no.
class PaymentsService {
  PaymentsService(this._functions);

  final FirebaseFunctions _functions;

  /// Fa pagare il premio di una challenge appena creata.
  ///
  /// **Due strade, e la differenza non e' un dettaglio tecnico.** Sul telefono
  /// si alza un foglio dentro CRASY: Apple Pay in cima, la carta sotto, due
  /// tocchi e si e' di nuovo dove si era. Sul sito non esiste niente del
  /// genere, quindi resta la pagina di Stripe.
  ///
  /// Uscire dall'app costa gente: si apre il browser, si perde la schermata, si
  /// torna indietro a mano. Chi stava lanciando una missione per gioco, a meta'
  /// strada, si ferma — e quello e' il momento esatto in cui CRASY guadagna o
  /// non guadagna.
  ///
  /// Torna `false` se il pagamento non e' stato fatto. Non lancia: chi chiama
  /// e' una schermata, e ha gia' un modo di dirlo alla persona.
  Future<bool> payChallenge(String challengeId) async {
    if (kIsWeb) {
      final result = await _functions
          .httpsCallable('startChallengePayment')
          .call<Map<Object?, Object?>>({'challengeId': challengeId});

      return _open(result.data['url']);
    }

    final result = await _functions
        .httpsCallable('createChallengePaymentIntent')
        .call<Map<Object?, Object?>>({'challengeId': challengeId});

    final dati = result.data;
    final clientSecret = dati['clientSecret'] as String?;
    final publishableKey = dati['publishableKey'] as String?;

    if (clientSecret == null || publishableKey == null) {
      return false;
    }

    // **La chiave arriva dal server a ogni pagamento**, non sta scritta
    // dentro l'app. Cosi' il giorno in cui si passa dalle chiavi di prova a
    // quelle vere nessuno deve scaricare una versione nuova: i telefoni gia'
    // installati cominciano a pagare sul serio da soli.
    Stripe.publishableKey = publishableKey;
    await Stripe.instance.applySettings();

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        customerId: dati['customerId'] as String?,
        customerEphemeralKeySecret: dati['ephemeralKey'] as String?,
        merchantDisplayName: 'CRASY',
        // Chiaro come il resto di CRASY: il foglio segue il tema del telefono
        // se non gli si dice niente, e un pannello nero che si alza dentro
        // un'app bianca sembra di un'altra applicazione.
        style: ThemeMode.light,
        applePay: const PaymentSheetApplePay(merchantCountryCode: 'IT'),
        googlePay: const PaymentSheetGooglePay(
          merchantCountryCode: 'IT',
          testEnv: kDebugMode,
        ),
      ),
    );

    try {
      await Stripe.instance.presentPaymentSheet();
    } on StripeException {
      // **Chi annulla non ha sbagliato niente.** Il foglio si chiude col dito,
      // ed e' un gesto normale: trattarlo come un errore vorrebbe dire un
      // messaggio rosso per aver cambiato idea.
      return false;
    }

    return true;
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
      // **Dal browser si cambia pagina, non se ne apre una nuova.** Una
      // finestra nuova aperta dopo una chiamata al server non e' piu' figlia
      // del tocco sul bottone, e Chrome e Safari la bloccano come un popup:
      // Stripe non compariva e `launchUrl` diceva lo stesso che era andata.
      // Stripe poi rimanda sul sito, quindi non si perde niente.
      webOnlyWindowName: kIsWeb ? '_self' : null,
    );
  }
}
