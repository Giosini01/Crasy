import 'package:cloud_functions/cloud_functions.dart';
import 'package:crasy/core/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Lo stesso filo verso Swift che usa il pallino delle notifiche.
  static const _filo = MethodChannel('crasy/pallino');

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
    String? returnRoute,
  }) async {
    if (kIsWeb) {
      // **Stripe riporta dove si era, non su un indirizzo fisso.** L'app puo'
      // stare su `crasyapp.com/app` o su `crasy.web.app/app`: si manda il suo
      // indirizzo vero — senza la schermata dopo il `#` — e la schermata da
      // cui si era aperto il modulo. Il server accetta solo domini di CRASY.
      final base = Uri.base;
      final appUrl = '${base.origin}${base.path}';

      final result = await _functions
          .httpsCallable('startChallengePayment')
          .call<Map<Object?, Object?>>({
            'challengeId': challengeId,
            'appUrl': appUrl,
            'returnRoute': ?returnRoute,
          });

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
    final customerId = dati['customerId'] as String?;
    final ephemeralKeySecret = dati['ephemeralKeySecret'] as String?;

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

      // **La carta della volta scorsa.** Se il server ha mandato cliente e
      // chiave temporanea, il foglio si apre con la carta gia' salvata da
      // Stripe. Se con quei due il foglio non si prepara — una volta era
      // successo — si riprova senza: meglio rimettere la carta che non pagare.
      final conCarta = customerId != null && ephemeralKeySecret != null;

      try {
        await _preparaIlFoglio(
          clientSecret,
          customerId: conCarta ? customerId : null,
          ephemeralKeySecret: conCarta ? ephemeralKeySecret : null,
        );
      } on Object {
        if (!conCarta) {
          rethrow;
        }

        await _preparaIlFoglio(clientSecret);
      }

      passo?.call('apro il foglio');

      // **Su iPhone il foglio ha bisogno di una finestra in prestito.** Stripe
      // la cerca nell'AppDelegate, che con le scene non ne ha: senza, il foglio
      // si apre nel vuoto e l'attesa non finisce mai. Si presta solo adesso e
      // si riprende subito dopo — vedi `prestaLaFinestra` in AppDelegate.swift.
      final iPhone = defaultTargetPlatform == TargetPlatform.iOS;

      if (iPhone) {
        await _filo.invokeMethod<void>('prestaLaFinestra');
      }

      try {
        await Stripe.instance.presentPaymentSheet();
      } finally {
        if (iPhone) {
          await _filo.invokeMethod<void>('restituisciLaFinestra');
        }
      }
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

  /// Prepara il foglio di Stripe. Con cliente e chiave temporanea mostra le
  /// carte salvate; senza, chiede la carta da capo.
  Future<void> _preparaIlFoglio(
    String clientSecret, {
    String? customerId,
    String? ephemeralKeySecret,
  }) async {
    await Stripe.instance
        .initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            customerId: customerId,
            customerEphemeralKeySecret: ephemeralKeySecret,
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
            // Chiaro come il resto di CRASY: il foglio segue il tema del telefono
            // se non gli si dice niente, e un pannello nero che si alza dentro
            // un'app bianca sembra di un'altra applicazione.
            style: ThemeMode.light,
            // **Il tasto dice PAGA, in italiano.**
            //
            // Il foglio segue la lingua del telefono, e su un telefono in
            // inglese diceva "Pay" in mezzo a una schermata scritta in
            // italiano. La parola sul tasto che tira fuori i soldi e' l'ultima
            // che uno legge prima di premere: deve essere nella sua lingua.
            primaryButtonLabel: 'Paga',
            // **E ha la faccia di CRASY.**
            //
            // Il foglio di Stripe nasce blu, e blu e' il colore di Stripe.
            // Chi lo vede alzarsi si trova davanti un pezzo di un'altra
            // applicazione proprio nel momento in cui deve fidarsi — che e'
            // il momento peggiore per sembrare un'altra cosa. Il rosso, il
            // bianco e gli angoli sono gli stessi del resto dell'app: non
            // sta cambiando posto, sta pagando dentro CRASY.
            appearance: const PaymentSheetAppearance(
              colors: PaymentSheetAppearanceColors(
                primary: AppColors.crasyRed,
                background: AppColors.paper,
                componentBackground: AppColors.paperMuted,
                componentBorder: AppColors.line,
                componentDivider: AppColors.line,
                componentText: AppColors.ink,
                primaryText: AppColors.ink,
                secondaryText: AppColors.inkSoft,
                placeholderText: AppColors.inkFaint,
                icon: AppColors.inkSoft,
                error: AppColors.crasyRed,
              ),
              shapes: PaymentSheetShape(
                borderRadius: 12,
                borderWidth: 1,
              ),
              primaryButton: PaymentSheetPrimaryButtonAppearance(
                colors: PaymentSheetPrimaryButtonTheme(
                  light: PaymentSheetPrimaryButtonThemeColors(
                    background: AppColors.crasyRed,
                    text: AppColors.paper,
                    border: AppColors.crasyRed,
                  ),
                  dark: PaymentSheetPrimaryButtonThemeColors(
                    background: AppColors.crasyRed,
                    text: AppColors.paper,
                    border: AppColors.crasyRed,
                  ),
                ),
              ),
            ),
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
  }

  /// Apre la registrazione di chi deve incassare: nome, documento, IBAN.
  ///
  /// Si fa una volta sola, alla prima vittoria. Non e' un modulo che abbiamo
  /// deciso noi: pagare qualcuno senza sapere chi e' e' vietato, e nessuna app
  /// puo' saltarlo.
  Future<bool> startPayoutOnboarding() async {
    final result = await _functions
        .httpsCallable('createPayoutOnboarding')
        .call<Map<Object?, Object?>>({
          // Come per il pagamento: finita la registrazione, Stripe riporta
          // dove si era. Dal telefono non c'e' un indirizzo da mandare e il
          // server ripiega sul sito.
          if (kIsWeb) 'appUrl': '${Uri.base.origin}${Uri.base.path}',
        });

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
