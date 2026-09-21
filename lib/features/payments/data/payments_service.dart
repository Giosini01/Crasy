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
  /// si alza un foglio dentro CRASY: si mette la carta, due tocchi, e si e' di
  /// nuovo dove si era. Sul sito non esiste niente del genere, quindi resta la
  /// pagina di Stripe.
  ///
  /// Uscire dall'app costa gente: si apre il browser, si perde la schermata, si
  /// torna indietro a mano. Chi stava lanciando una missione per gioco, a meta'
  /// strada, si ferma — e quello e' il momento esatto in cui CRASY guadagna o
  /// non guadagna.
  ///
  /// Torna `false` se il pagamento non e' stato fatto. Non lancia: chi chiama
  /// e' una schermata, e ha gia' un modo di dirlo alla persona.
  /// **Nessun passo puo' durare per sempre.**
  ///
  /// Un pagamento che si blocca e' peggio di uno che fallisce: il bottone
  /// torna com'era, non compare niente, e chi guarda pensa che l'app sia rotta
  /// senza avere niente da riferire. Dieci secondi sono tanti per qualunque
  /// passo di questi e pochi per la pazienza di chi aspetta.
  static const _pazienza = Duration(seconds: 10);

  Future<bool> payChallenge(
    String challengeId, {
    void Function(String passo)? passo,
  }) async {
    if (kIsWeb) {
      final result = await _functions
          .httpsCallable('startChallengePayment')
          .call<Map<Object?, Object?>>({'challengeId': challengeId});

      return _open(result.data['url']);
    }

    passo?.call('chiedo il pagamento');

    final result = await _functions
        .httpsCallable('createChallengePaymentIntent')
        .call<Map<Object?, Object?>>({'challengeId': challengeId})
        .timeout(_pazienza, onTimeout: () => throw Exception('server lento'));

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

    // **Da qui in poi e' tutto dentro un solo `try`.**
    //
    // Prima ne era coperto solo l'ultimo pezzo, quello che mostra il foglio. E
    // i due passi prima — la configurazione e la preparazione — possono
    // fallire eccome: una chiave che non combacia col pagamento, un permesso
    // che manca, il modulo di Stripe non ancora pronto. Quando succedeva li',
    // l'errore usciva da una porta che nessuno sorvegliava: il bottone tornava
    // com'era, nessun foglio, nessun messaggio. **Non funziona e non dice
    // niente** e' il modo peggiore in cui un pagamento puo' rompersi, perche'
    // non lascia nemmeno da dove ricominciare a guardare.
    try {
      passo?.call('configuro Stripe');
      await Stripe.instance.applySettings().timeout(
        _pazienza,
        onTimeout: () =>
            throw Exception('Stripe non risponde (configurazione)'),
      );

      passo?.call('preparo il foglio');
      await Stripe.instance
          .initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
              paymentIntentClientSecret: clientSecret,
              merchantDisplayName: 'CRASY',
              // **Dove tornare, se qualcosa esce dall'app.**
              //
              // Con i soli pagamenti a carta non ci va nessuno, e infatti il
              // server chiede a Stripe di non proporne altri. Ma il foglio
              // vuole saperlo lo stesso prima di aprirsi, e senza resta chiuso
              // senza dire perche'. `crasy://` e' lo schema con cui l'app si fa
              // gia' riaprire dal browser dopo il recupero della password: era
              // gia' registrato, non ce n'e' voluto uno nuovo.
              returnURL: 'crasy://pagamento',
              // **Niente carte salvate, per ora.**
              //
              // Qui passavano l'identificativo del cliente e una chiave
              // temporanea, che sono le due cose che fanno ritrovare la carta
              // la volta dopo. Quella chiave pero' nasce legata a una versione
              // precisa delle interfacce di Stripe, e quando non combacia con
              // quella che il telefono si aspetta il foglio non si apre — di
              // nuovo senza dire niente.
              //
              // Un tocco risparmiato la seconda volta non vale un pagamento
              // che non parte la prima. Si rimettono quando il giro base e'
              // provato: il cliente su Stripe viene creato lo stesso, quindi
              // non si perde niente per strada.
              // Chiaro come il resto di CRASY: il foglio segue il tema del telefono
              // se non gli si dice niente, e un pannello nero che si alza dentro
              // un'app bianca sembra di un'altra applicazione.
              style: ThemeMode.light,
              // **Niente Apple Pay, per adesso.**
              //
              // Chiederlo qui non lo fa comparire: serve un identificativo mercante
              // di Apple, il permesso corrispondente dentro l'app e la stessa cosa
              // registrata su Stripe. Senza quelle tre, il foglio non si apre e
              // basta — e fallisce prima ancora di mostrarsi, quindi si vede solo
              // "non siamo riusciti ad aprire il pagamento" e nessuno capisce
              // perche'.
              //
              // La carta funziona da sola. Apple Pay si aggiunge dopo, quando ci
              // sara' l'account vero: e' un tocco in meno, non un pagamento in piu'.
            ),
          )
          .timeout(
            _pazienza,
            onTimeout: () =>
                throw Exception('Stripe non risponde (preparazione)'),
          );

      passo?.call('apro il foglio');
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (errore) {
      // **Chi annulla non ha sbagliato niente.** Il foglio si chiude col dito,
      // ed e' un gesto normale: trattarlo come un errore vorrebbe dire un
      // messaggio rosso per aver cambiato idea.
      if (errore.error.code == FailureCode.Canceled) {
        return false;
      }

      // **Tutto il resto invece si racconta.** Prima finiva qui dentro
      // insieme all'annullamento, e una carta rifiutata, una configurazione
      // sbagliata e un dito sul tasto chiudi davano tutti la stessa riga:
      // "non siamo riusciti ad aprire il pagamento". Che e' il modo piu'
      // sicuro di non sapere mai cos'e' successo.
      throw Exception(
        errore.error.localizedMessage ?? errore.error.message ?? 'Stripe',
      );
    } on Object catch (errore) {
      // **Anche quello che non e' un errore di Stripe.** Un guasto del modulo
      // nativo non arriva come `StripeException`: arriva come un errore di
      // piattaforma qualunque, e fino a un minuto fa passava dritto e spariva.
      throw Exception('$errore');
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
