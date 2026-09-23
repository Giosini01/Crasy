import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';
import 'package:crasy/features/payments/domain/entities/wallet.dart';
import 'package:crasy/features/payments/presentation/pages/payout_details_page.dart';
import 'package:crasy/features/payments/presentation/providers/payments_providers.dart';
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

  Future<void> _withdraw() async {
    // **Prima i dati, poi i soldi.**
    //
    // Chi non li ha ancora messi non si prende un errore: si prende il modulo.
    // E' l'unico momento in cui ha senso chiederli — ha appena chiesto di
    // essere pagato — e chiederli prima sarebbe stato un modulo davanti alla
    // porta a chi voleva solo fare una foto.
    final dati = ref.read(payoutDetailsProvider).valueOrNull;

    if (dati == null || !dati.isComplete) {
      final fatto = await Navigator.of(
        context,
      ).push<bool>(
        MaterialPageRoute(builder: (_) => const PayoutDetailsPage()),
      );

      if (fatto != true || !mounted) {
        return;
      }
    }

    setState(() {
      _working = true;
      _message = null;
    });

    final payments = ref.read(paymentsServiceProvider);

    try {
      final reason = await payments.withdraw();

      if (!mounted) {
        return;
      }

      if (reason == null) {
        setState(() {
          _working = false;
          _message = 'Fatto. Arrivano sul tuo conto in pochi giorni.';
        });

        return;
      }

      if (reason == 'gia-in-corso') {
        setState(() {
          _working = false;
          _message = 'Ne hai già chiesto uno: è in viaggio.';
        });

        return;
      }

      if (reason == 'dati-mancanti') {
        setState(() {
          _working = false;
          _message = 'Mancano i dati per il bonifico: compilali e riprova.';
        });

        return;
      }

      if (reason == 'account-mancante') {
        // **La prima volta non e' un errore: e' il momento in cui bisogna dire
        // chi si e'.** Pagare qualcuno senza sapere chi e' e' vietato, e non e'
        // una regola di CRASY: vale per chiunque mandi del denaro. Si fa una
        // volta sola, e la pagina che si apre e' di Stripe.
        //
        // **Se pero' non parte, si dice cosa non va.**
        //
        // Puo' non partire per una ragione che non riguarda chi sta premendo:
        // il conto per incassare va configurato una volta sola, e finche' non
        // lo e' nessuno puo' prelevare. Dirgli "riprova" sarebbe mandarlo a
        // sbattere contro lo stesso muro.
        try {
          await payments.startPayoutOnboarding();
        } on Object catch (errore) {
          if (mounted) {
            setState(() {
              _working = false;
              _message = '$errore'.contains('incasso-non-configurato')
                  ? 'I prelievi non sono ancora aperti. I soldi restano tuoi '
                        'e non si perdono: riprova fra qualche giorno.'
                  : '$errore'.contains('dati-mancanti')
                  ? 'Mancano i dati per il bonifico: compilali e riprova.'
                  : 'Non siamo riusciti ad aprire la registrazione. Riprova '
                        'fra poco.';
            });
          }

          return;
        }

        if (mounted) {
          setState(() {
            _working = false;
            _message =
                'Finisci la registrazione nella pagina che si è aperta, poi '
                'torna qui e premi di nuovo.';
          });
        }

        return;
      }

      setState(() {
        _working = false;
        _message = reason == 'saldo-basso'
            ? 'Servono almeno '
                  '${AppMoney.format(Wallet.minimumWithdrawalCents)} per '
                  'prelevare.'
            : 'Non ci siamo riusciti. Riprova fra poco.';
      });
    } on Exception catch (_) {
      if (mounted) {
        setState(() {
          _working = false;
          _message = 'Non ci siamo riusciti. Riprova fra poco.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final wallet = ref.watch(walletProvider).valueOrNull ?? const Wallet();
    final dati = ref.watch(payoutDetailsProvider).valueOrNull;
    final inViaggio = wallet.withdrawingCents;
    final balance = ref.watch(walletBalanceProvider);
    final quanto = Wallet.minimumWithdrawalCents - balance;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Portafoglio'),
      ),
      body: AppBackground(
        child: SafeArea(
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
                      style: texts.displayLarge?.copyWith(color: palette.accent),
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
                  dati != null && dati.isComplete
                      ? 'Vanno sul conto ${dati.ibanTail}, intestato a '
                            '${dati.firstName} ${dati.lastName}. Arrivano in '
                            'pochi giorni.'
                      : 'La prima volta che prelevi servono nome, data di '
                            'nascita, codice fiscale e IBAN: è la legge per '
                            'chiunque riceva denaro, e si fa una volta sola.',
                  style: texts.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                // **Il conto si puo' cambiare, e si trova.** Un IBAN si sbaglia
                // o si chiude, e se l'unico modo di correggerlo fosse scrivere
                // a qualcuno, quei soldi resterebbero fermi per sempre.
                if (dati != null && dati.isComplete)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => context.push(AppRoutes.payoutDetails),
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
      return 'Qui finiscono i premi che vinci. Restano su CRASY finché non li '
          'prelevi.';
    }

    return 'Sono tuoi e stanno su CRASY. Da '
        '${AppMoney.format(Wallet.minimumWithdrawalCents)} in su li puoi '
        'mandare sul tuo conto: sotto, il prelievo costerebbe più di quanto '
        'vale.';
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
                    AppDateUtils.shortTimeAgo(quando),
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
