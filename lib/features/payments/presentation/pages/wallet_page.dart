import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/flame_waiting.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';
import 'package:crasy/features/payments/domain/entities/wallet.dart';
import 'package:crasy/features/payments/presentation/pages/payout_details_page.dart';
import 'package:crasy/features/payments/presentation/providers/payments_providers.dart';
import 'package:crasy/features/payments/presentation/widgets/collega_conto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// **I soldi vinti, e il modo di portarseli via.**
///
/// Nel profilo il portafoglio c'e' gia', ma e' un riquadro fra gli altri: dice
/// quanto, e lascia il prelievo a un tasto piccolo accanto alla cifra. Va bene
/// per guardare, non per fare. Prelevare e' l'unico momento in cui dei soldi
/// veri escono da CRASY e arrivano su un conto vero — la fine di tutto il giro
/// — e merita una schermata che non parli d'altro.
///
/// Qui ci sta anche quello che nel riquadro non entrava: **tutti i movimenti**,
/// non gli ultimi cinque. Chi ha vinto sei volte ha il diritto di ritrovarle
/// tutte e sei, e chi non ricorda un accredito deve poterlo cercare senza
/// chiedere a nessuno.
class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  bool _working = false;
  String? _message;

  /// Mentre si apre la pagina del conto su Stripe: il server prepara il
  /// collegamento, e ci puo' mettere fino a mezzo minuto.
  bool _aproStripe = false;

  /// Mentre si salva il permesso di usare i premi per le missioni.
  bool _salvoIlPermesso = false;

  Future<void> _withdraw() async {
    // **Prima il conto, poi i soldi.** Chi non l'ha ancora collegato non si
    // prende un errore: si prende la spiegazione e il modulo, una volta sola.
    // Vedi `assicuratiIlConto`.
    //
    // **L'attesa qui dentro si vede gia'.** Mentre chiede al server a che
    // punto e' il conto, `assicuratiIlConto` copre lo schermo con la sua
    // fiamma; il velo di questa pagina si accende dopo, sul prelievo. Acceso
    // prima, starebbe anche sotto la spiegazione e il modulo — una fiamma che
    // gira mentre si aspetta soltanto che uno legga.
    if (!await assicuratiIlConto(context, ref) || !mounted) {
      return;
    }

    setState(() {
      _working = true;
      _message = null;
    });

    final payments = ref.read(paymentsServiceProvider);

    try {
      final esito = await payments.withdraw();

      if (!mounted) {
        return;
      }

      final motivo = esito.motivo;

      if (motivo == null) {
        final partiti = esito.suStripeCents + esito.manualeCents;

        setState(() {
          _working = false;
          _message =
              'Fatto: ${AppMoney.format(partiti)} in viaggio verso la tua '
              'banca. Arrivano in qualche giorno.'
              '${esito.inArrivoCents > 0 ? ' Altri ${AppMoney.format(esito.inArrivoCents)} sono ancora in arrivo sul tuo conto: li potrai prelevare fra qualche giorno.' : ''}';
        });

        return;
      }

      if (motivo == 'account-mancante' || motivo == 'account-incompleto') {
        // Stripe vuole ancora qualcosa: si riapre la sua pagina.
        final pronto = await payments.startPayoutOnboarding();

        if (mounted) {
          setState(() {
            _working = false;
            _message = pronto
                ? 'Il conto è a posto: premi di nuovo per prelevare.'
                : 'Stripe ha bisogno di un dato in più. Finisci nella pagina '
                      'che si è aperta, poi torna qui e premi di nuovo.';
          });
        }

        return;
      }

      setState(() {
        _working = false;
        _message = switch (motivo) {
          'in-arrivo' =>
            'I tuoi premi più recenti sono ancora in arrivo sul tuo conto: '
                'Stripe li rende prelevabili qualche giorno dopo la vittoria. '
                'Riprova fra qualche giorno.',
          'gia-in-corso' => 'Ne hai già chiesto uno: è in viaggio.',
          'saldo-basso' =>
            'Servono almeno '
                '${AppMoney.format(Wallet.minimumWithdrawalCents)} per '
                'prelevare.',
          _ => 'Non ci siamo riusciti. Riprova fra poco.',
        };
      });
    } on Object catch (_) {
      if (mounted) {
        setState(() {
          _working = false;
          _message = 'Non ci siamo riusciti. Riprova fra poco.';
        });
      }
    }
  }

  /// Chiede il permesso di usare il saldo Stripe per pagare le missioni, con
  /// lo stesso testo che si accetta nella pagina del conto.
  Future<void> _chiediIlPermesso() async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usa i premi per le missioni'),
        content: const Text(PayoutDetailsPage.testoAddebito),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Non ora'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Autorizzo'),
          ),
        ],
      ),
    );

    final repository = ref.read(walletRepositoryProvider);
    final userId = ref.read(currentUserIdProvider);

    if (si != true || repository == null || userId == null || !mounted) {
      return;
    }

    // Finche' non e' salvato, al posto del tasto la fiamma: toccato due
    // volte, il permesso si scriverebbe due volte.
    setState(() => _salvoIlPermesso = true);

    try {
      await repository.accettaAddebitoDalSaldo(
        userId,
        PayoutDetailsPage.testoAddebito,
      );
    } on Object {
      if (mounted) {
        setState(
          () => _message = 'Non siamo riusciti a salvarlo. Riprova fra poco.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _salvoIlPermesso = false);
      }
    }
  }

  /// Apre la pagina del proprio conto su Stripe.
  ///
  /// **Coperta, mentre si prepara.** Il collegamento lo chiede il server, e
  /// fino a mezzo minuto senza niente a schermo e' un tasto che sembra non
  /// fare niente: lo si ritocca, e ogni tocco apre un'altra pagina.
  Future<void> _apriContoStripe() async {
    setState(() {
      _aproStripe = true;
      _message = null;
    });

    var aperta = false;

    try {
      aperta = await ref.read(paymentsServiceProvider).apriContoStripe();
    } on Object {
      // Non aperta: lo si dice qui sotto.
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _aproStripe = false;

      // Prima un errore qui spariva e basta: non si apriva niente, e nessuno
      // diceva perche'.
      if (!aperta) {
        _message =
            'Non siamo riusciti ad aprire il tuo conto Stripe. Riprova fra '
            'poco.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final portafoglio = ref.watch(walletProvider);
    final datiInArrivo = ref.watch(payoutDetailsProvider);
    final contoInArrivo = ref.watch(contoProntoProvider);
    final permessoInArrivo = ref.watch(addebitoAccettatoProvider);
    final wallet = portafoglio.valueOrNull ?? const Wallet();
    final dati = datiInArrivo.valueOrNull;
    final contoPronto = contoInArrivo.valueOrNull == true;
    final inViaggio = wallet.withdrawingCents;
    final balance = ref.watch(walletBalanceProvider);
    final quanto = Wallet.minimumWithdrawalCents - balance;

    // **Mentre carica, la fiamma: niente zeri.** Prima la pagina si disegnava
    // subito con quello che non era ancora arrivato — "HAI VINTO € 0,00", un
    // bottone spento con "Ti mancano € 10,00", "Ancora niente" nei movimenti,
    // la riga che chiede i dati a chi li aveva gia' dati — e un attimo dopo
    // cambiava tutto. Chi ha dei soldi qui dentro, per quell'attimo, li vede
    // spariti.
    //
    // Si aspetta cio' che la pagina scrive: saldo e movimenti, i trofei da
    // cui si conta quanto hai vinto quando i pagamenti sono spenti (vedi
    // `walletBalanceProvider`), e con i pagamenti accesi le tre cose che
    // decidono la riga sotto il bottone e i tasti sotto di lei.
    final essenziali = <AsyncValue<Object?>>[
      portafoglio,
      if (!paymentsEnabled) ref.watch(myTrophiesProvider),
    ];
    final tutte = <AsyncValue<Object?>>[
      ...essenziali,
      if (paymentsEnabled) ...[datiInArrivo, contoInArrivo, permessoInArrivo],
    ];
    final caricando = tutte.any((fonte) => !fonte.hasValue && !fonte.hasError);

    // **Un guasto non e' un'attesa.** Se il saldo non si legge lo si dice,
    // invece di far girare la fiamma per sempre o di scrivere uno zero che
    // non e' vero. Gli altri tre, se falliscono, valgono come prima: niente
    // dati, conto non pronto, permesso non dato.
    final guasto = essenziali.any((fonte) => fonte.hasError && !fonte.hasValue);

    // **Mentre i soldi si muovono, lo schermo e' coperto.** Un prelievo e la
    // pagina di Stripe sono chiamate al server che durano anche mezzo minuto,
    // e in quel mezzo minuto la freccia indietro e gli altri tasti restavano
    // li', toccabili, come se non stesse succedendo niente.
    return VeloDiAttesa(
      acceso: _working || _aproStripe,
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Portafoglio'),
          actions: [
            // **La porta per l'estratto conto sta qui**, e non in fondo alla
            // pagina: il portafoglio mostra solo i soldi che passano dentro
            // CRASY, e chi cerca un pagamento fatto con la carta lo cerca da
            // questa schermata — e' l'unico posto dove gli viene in mente.
            TextButton(
              onPressed: () => context.push(AppRoutes.ledger),
              child: Text(
                'TUTTI I MOVIMENTI',
                style: context.texts.labelSmall?.copyWith(
                  color: context.palette.accent,
                ),
              ),
            ),
          ],
        ),
        body: AppBackground(
          child: guasto
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  child: EmptyState(
                    title: 'Portafoglio non disponibile',
                    message: 'Non riusciamo a leggerlo. Riprova tra poco.',
                  ),
                )
              : caricando
              ? const Center(child: FiammaCheGira())
              : SafeArea(
                  top: false,
                  bottom: false,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.lg,
                      AppSpacing.page,
                      AppSpacing.xxl,
                    ),
                    children: [
                      // **La cifra grande, e sotto dove sta.** Un portafoglio che
                      // mostra un numero senza dire dove sono quei soldi e' la cosa
                      // piu' vicina a una truffa che si possa costruire in buona fede.
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: palette.accentTint,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HAI VINTO',
                              style: texts.labelSmall?.copyWith(
                                color: palette.accent,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              AppMoney.format(balance),
                              style: texts.displayLarge?.copyWith(
                                color: palette.accent,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _dove(wallet),
                              style: texts.bodySmall?.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (paymentsEnabled) ...[
                        // **Il bottone c'e' sempre, anche spento.** Nascosto sotto i
                        // dieci euro, chi ne ha tre non saprebbe nemmeno che il
                        // prelievo esiste, ne' quanto gli manca: vedrebbe dei soldi
                        // fermi e nessun modo di prenderli. Spento e con scritto quanto
                        // manca, invece, dice due cose in una riga sola.
                        // **Un prelievo gia' chiesto si vede, e blocca il bottone.**
                        //
                        // Senza, chi ha chiesto i soldi vedrebbe il saldo a zero e un
                        // bottone spento, senza sapere se la richiesta e' arrivata. E'
                        // il momento in cui uno si preoccupa piu' di tutti.
                        if (inViaggio > 0)
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: palette.line),
                            ),
                            child: Text(
                              '${AppMoney.format(inViaggio)} sono in viaggio verso il '
                              'tuo conto. Arrivano in qualche giorno.',
                              style: texts.bodyMedium,
                            ),
                          )
                        else
                          CrasyButton(
                            label: wallet.canWithdraw
                                ? 'Preleva ${AppMoney.format(balance)}'
                                : 'Ti mancano ${AppMoney.format(quanto)}',
                            loading: _working,
                            onPressed: wallet.canWithdraw ? _withdraw : null,
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          contoPronto
                              ? 'Vanno sulla banca che hai indicato a Stripe, in pochi '
                                    'giorni.'
                              : dati != null && dati.isComplete
                              ? 'Vanno sul conto ${dati.ibanTail}, intestato a '
                                    '${dati.firstName} ${dati.lastName}. Arrivano in '
                                    'pochi giorni.'
                              : 'La prima volta servono nome, cognome e IBAN, '
                                    'poi Stripe ti chiede di confermarli: è la legge '
                                    'per chiunque riceva denaro, e si fa una volta '
                                    'sola.',
                          style: texts.bodySmall?.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                        // **Il conto si puo' cambiare, e si trova.** Un IBAN si sbaglia
                        // o si chiude, e se l'unico modo di correggerlo fosse scrivere
                        // a qualcuno, quei soldi resterebbero fermi per sempre.
                        //
                        // Con il conto Stripe collegato la banca vera sta li', e si
                        // cambia dalla sua pagina: e' anche dove si vede tutto quello
                        // che e' arrivato e partito.
                        if (contoPronto) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _apriContoStripe,
                              child: const Text('Il tuo conto Stripe'),
                            ),
                          ),
                          // **Il permesso di rimettere i premi in gioco.** I premi
                          // stanno sul conto Stripe: per pagarci una missione CRASY
                          // deve poterli prendere da li', e lo fa solo con un si'
                          // detto una volta. Finche' non c'e', il tasto lo chiede.
                          if (permessoInArrivo.valueOrNull != true)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _salvoIlPermesso
                                  // Mentre si salva, la fiamma al posto del tasto.
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                        vertical: AppSpacing.xs,
                                      ),
                                      child: FiammaCheGira(misura: 24),
                                    )
                                  : TextButton(
                                      onPressed: _chiediIlPermesso,
                                      child: const Text(
                                        'Usa i premi per le missioni',
                                      ),
                                    ),
                            ),
                        ] else if (dati != null && dati.isComplete)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () =>
                                  context.push(AppRoutes.payoutDetails),
                              child: const Text('Cambia i dati'),
                            ),
                          ),
                        if (_message != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(_message!, style: texts.bodyMedium),
                        ],
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'MOVIMENTI',
                        style: texts.labelSmall?.copyWith(
                          color: palette.textFaint,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (wallet.movements.isEmpty)
                        const EmptyState(
                          title: 'Ancora niente',
                          message:
                              'Qui finiscono i premi che vinci, uno per riga, con la '
                              'missione da cui arrivano.',
                        )
                      else
                        for (final movement in wallet.movements)
                          _Movimento(movement: movement),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  /// Dove sono i soldi, adesso. Tre situazioni, tre frasi diverse.
  String _dove(Wallet wallet) {
    if (!paymentsEnabled) {
      return 'I pagamenti non sono ancora attivi, quindi questi soldi te li '
          'deve chi ha lanciato la challenge: CRASY non li ha in cassa e non fa '
          'da garante.';
    }

    if (wallet.balanceCents <= 0) {
      return 'Qui finiscono i premi che vinci. Vanno su un conto Stripe a nome '
          'tuo: CRASY non tiene i tuoi soldi.';
    }

    final soglia = AppMoney.format(Wallet.minimumWithdrawalCents);

    // **Dove sono, detto per quello che e'.** Se una parte e' ancora su
    // CRASY lo si dice, con il motivo: un portafoglio che non dice dove sono i
    // soldi e' la cosa piu' vicina a una truffa che si possa costruire in
    // buona fede.
    if (wallet.inCustodiaCents > 0) {
      return 'Sono tuoi. ${AppMoney.format(wallet.inCustodiaCents)} sono '
          'ancora su CRASY e ti arrivano appena aggiungi il tuo IBAN. '
          'Da $soglia in su li puoi mandare sulla tua banca.';
    }

    return 'Sono tuoi, su un conto Stripe a nome tuo: CRASY non li tiene. Da '
        '$soglia in su li puoi mandare sulla tua banca: sotto, il prelievo '
        'costerebbe più di quanto vale.';
  }
}

/// Una riga del portafoglio: quanto, da dove, quando.
class _Movimento extends StatelessWidget {
  const _Movimento({required this.movement});

  final WalletMovement movement;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  movement.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: texts.labelMedium,
                ),
                if (movement.createdAt case final quando?) ...[
                  const SizedBox(height: 1),
                  Text(
                    // **Cosa e', accanto a quando.** Una missione pagata col
                    // portafoglio ha il titolo della gara in testa, come un
                    // premio vinto: senza questa riga si leggerebbe come una
                    // vittoria con l'importo negativo, che non vuol dire
                    // niente.
                    movement.note.isEmpty
                        ? AppDateUtils.shortTimeAgo(quando)
                        : '${movement.note} · '
                              '${AppDateUtils.shortTimeAgo(quando)}',
                    style: texts.labelSmall?.copyWith(color: palette.textFaint),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // **Il segno c'e' sempre**, anche davanti a un premio: senza, un
          // accredito e un prelievo della stessa cifra sono due righe uguali.
          Text(
            '${movement.isPrize ? '+' : ''}'
            '${AppMoney.format(movement.amountCents)}',
            style: texts.titleSmall?.copyWith(
              color: movement.isPrize ? palette.accent : palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
