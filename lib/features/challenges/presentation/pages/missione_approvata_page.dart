import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/errors/error_message_mapper.dart';
import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/flame_waiting.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
import 'package:crasy/features/challenges/domain/entities/proposta_missione.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/esito_missione.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';
import 'package:crasy/features/payments/domain/prize_ledger.dart';
import 'package:crasy/features/payments/presentation/providers/payments_providers.dart';
import 'package:crasy/features/payments/presentation/widgets/pay_choice.dart';
import 'package:crasy/features/payments/presentation/widgets/riepilogo_premio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// La proposta come la racconta il server a chi l'ha scritta.
///
/// `autoDispose`: si legge quando si apre la pagina, cosi' chi ci torna dopo aver
/// pagato non si ritrova una risposta di prima.
final propostaMissioneProvider = FutureProvider.autoDispose
    .family<PropostaMissione, String>((ref, propostaId) async {
      final risposta = await ref
          .watch(firebaseFunctionsProvider)
          .httpsCallable('leggiLaMiaProposta')
          .call<Map<Object?, Object?>>({'propostaId': propostaId});

      return PropostaMissione.fromMap(risposta.data);
    });

/// **La missione approvata: si paga, e parte.**
///
/// Ci si arriva dall'avviso in campanella. Una missione che ha dovuto aspettare
/// una persona non e' stata pagata prima, ed e' voluto: se fosse stata rifiutata
/// non ci sarebbe stato niente da rimborsare, e CRASY non avrebbe tenuto soldi per
/// una cosa che magari non sarebbe mai uscita.
///
/// **La gara nasce quando si preme il tasto, non quando e' stata approvata.** Fra
/// le due cose possono passare dei giorni, e una gara scritta prima sarebbe gia'
/// scaduta all'arrivo del pagamento (vedi `lanciaApprovata` sul server).
class MissioneApprovataPage extends ConsumerStatefulWidget {
  const MissioneApprovataPage({required this.propostaId, super.key});

  final String propostaId;

  @override
  ConsumerState<MissioneApprovataPage> createState() =>
      _MissioneApprovataPageState();
}

class _MissioneApprovataPageState extends ConsumerState<MissioneApprovataPage> {
  /// Copre lo schermo mentre si paga: fra il tocco e il foglio di Stripe passano
  /// dei secondi, e un tasto ancora premibile vuol dire due pagamenti aperti per
  /// la stessa gara.
  bool _lavoro = false;
  String? _errore;

  void _fermati(String frase) {
    if (mounted) {
      setState(() {
        _lavoro = false;
        _errore = frase;
      });
    }
  }

  void _apriLaGara(String garaId) {
    context.pushReplacement(AppRoutes.challengeDetailOf(garaId));
  }

  /// **Lo stesso giro di pagamento del modulo**: se il portafoglio basta si chiede
  /// con cosa pagare, altrimenti si va dritti alla carta.
  Future<void> _pagaELancia(PropostaMissione proposta) async {
    setState(() {
      _lavoro = true;
      _errore = null;
    });

    final String garaId;

    try {
      final risposta = await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable('lanciaMissioneApprovata')
          .call<Map<Object?, Object?>>({'propostaId': proposta.id});
      final id = risposta.data['challengeId'];

      if (id is! String || id.isEmpty) {
        _fermati(
          'Non siamo riusciti ad aprire il pagamento. Riprova fra poco.',
        );

        return;
      }

      garaId = id;

      // Il secondo tocco su un tasto deve finire bene come il primo: se e' gia'
      // pagata si va alla gara, senza chiedere un altro pagamento.
      if (risposta.data['giaPagata'] == true ||
          !paymentsEnabled ||
          proposta.prizeCents == 0) {
        if (mounted) {
          _apriLaGara(garaId);
        }

        return;
      }
    } on Object catch (errore) {
      _fermati(ErrorMessageMapper.map(errore));

      return;
    }

    if (!mounted) {
      return;
    }

    final premio = proposta.prizeCents;
    final saldo = ref.read(walletBalanceProvider);

    // Si chiede, non si prende: il portafoglio e' denaro che sta aspettando di
    // uscire sul conto. Vedi `chiediComePagare`.
    if (saldo >= premio) {
      // Il saldo conta anche i premi che Stripe non ha ancora reso spendibili:
      // si chiede prima di promettere.
      final spendibile = await ref
          .read(paymentsServiceProvider)
          .saldoSpendibile();

      if (!mounted) {
        return;
      }

      setState(() => _lavoro = false);

      final scelta = await chiediComePagare(
        context,
        premioCents: premio,
        saldoCents: saldo,
        conLaCartaCents: PrizeLedger.chargeCents(premio),
        spendibile: spendibile,
      );

      // Chiuso il foglio senza scegliere: non e' un errore e non si dice niente.
      // La gara scritta resta spenta, e il tasto la riprende.
      if (!mounted || scelta == null) {
        return;
      }

      setState(() => _lavoro = true);

      if (scelta == PayChoice.portafoglio) {
        final esito = await ref
            .read(paymentsServiceProvider)
            .payChallengeFromWallet(garaId);

        if (!mounted) {
          return;
        }

        if (esito.pagata) {
          _apriLaGara(garaId);

          return;
        }

        _fermati(
          esito.saldoBasso
              // Fra l'apertura del foglio e il tocco puo' essere partito un
              // prelievo: il saldo di un attimo fa non e' una promessa.
              ? 'Il portafoglio non basta più: riprova, o paga con la carta.'
              : esito.inArrivo
              ? 'I tuoi premi più recenti sono ancora in arrivo sul tuo conto: '
                    'potrai usarli fra qualche giorno. Intanto puoi pagare con '
                    'la carta.'
              : esito.consensoMancante
              ? 'Per usare i premi del tuo conto Stripe serve il tuo permesso, '
                    'una volta: lo dai dal portafoglio, con “Usa i premi per le '
                    'missioni”.'
              : 'Non siamo riusciti a pagare dal portafoglio. Riprova fra poco.',
        );

        return;
      }
    }

    try {
      final pagata = await ref
          .read(paymentsServiceProvider)
          .payChallenge(garaId, returnRoute: AppRoutes.challenges);

      if (!mounted) {
        return;
      }

      if (!pagata) {
        _fermati(
          'Il premio non è stato pagato, quindi la missione non è ancora '
          'partita. Puoi riprovare quando vuoi.',
        );

        return;
      }

      _apriLaGara(garaId);
    } on Object catch (errore) {
      _fermati(
        'Non siamo riusciti ad aprire il pagamento: $errore. Riprova fra poco.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final proposta = ref.watch(propostaMissioneProvider(widget.propostaId));

    return VeloDiAttesa(
      acceso: _lavoro,
      child: Scaffold(
        appBar: AppBar(title: const Text('La tua missione')),
        body: AppBackground(
          child: proposta.when(
            loading: () => const Center(child: FiammaCheGira()),
            error: (errore, _) => _Riquadro(
              children: [
                InlineBanner(message: ErrorMessageMapper.map(errore)),
                const SizedBox(height: AppSpacing.md),
                SecondaryButton(
                  label: 'Riprova',
                  onPressed: () => ref.invalidate(
                    propostaMissioneProvider(widget.propostaId),
                  ),
                ),
              ],
            ),
            data: _corpo,
          ),
        ),
      ),
    );
  }

  Widget _corpo(PropostaMissione proposta) {
    if (proposta.rifiutata || proposta.bloccata) {
      return _Riquadro(
        children: [
          AvvisoRifiutata(
            titolo: proposta.title,
            motivo: proposta.motivo,
            daUnaPersona: proposta.rifiutata,
          ),
        ],
      );
    }

    if (proposta.inCoda) {
      return const _Riquadro(children: [AvvisoInControllo()]);
    }

    final gara = proposta.challengeId;

    // **Gia' in gara: non c'e' piu' niente da pagare.** Gratis lo e' da quando e'
    // stata approvata; con un premio, da quando il pagamento e' arrivato. Si
    // guarda la gara e non la proposta, perche' e' Stripe a dirlo, e l'avviso in
    // campanella resta li' anche dopo.
    final partita =
        gara != null &&
        (proposta.prizeCents == 0 ||
            (ref
                    .watch(challengeProvider(gara))
                    .valueOrNull
                    ?.prizeStatus
                    .isVisible ??
                false));

    return _Approvata(
      proposta: proposta,
      partita: partita,
      errore: _errore,
      onPaga: () => _pagaELancia(proposta),
      onApri: () => _apriLaGara(gara ?? ''),
    );
  }
}

class _Riquadro extends StatelessWidget {
  const _Riquadro({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: children,
    );
  }
}

class _Approvata extends StatelessWidget {
  const _Approvata({
    required this.proposta,
    required this.partita,
    required this.errore,
    required this.onPaga,
    required this.onApri,
  });

  final PropostaMissione proposta;

  /// Se e' gia' in gara: resta solo da andarla a vedere.
  final bool partita;
  final String? errore;
  final VoidCallback onPaga;
  final VoidCallback onApri;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final premio = proposta.prizeCents;

    // Senza soldi in palio non c'e' niente da pagare, e il tasto non lo dice.
    final paga = paymentsEnabled && premio > 0;

    return _Riquadro(
      children: [
        Text(
          partita ? 'È IN GARA' : 'APPROVATA',
          style: texts.labelSmall?.copyWith(color: palette.accent),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Il premio e' la cosa piu' grande, come su ogni gara dell'app.
        if (premio > 0) ...[
          Text(
            AppMoney.format(premio),
            style: texts.displayLarge?.copyWith(color: palette.accent),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(proposta.title.toUpperCase(), style: texts.displaySmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          proposta.brief,
          style: texts.bodyLarge?.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (partita)
          CrasyButton(label: 'Vai alla missione', onPressed: onApri)
        else ...[
          Text(
            paga
                ? 'Una persona del team l’ha guardata, e può uscire. Parte appena '
                      'paghi il premio: il tempo comincia da lì.'
                : 'Una persona del team l’ha guardata, e può uscire.',
            style: texts.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (paga) RiepilogoPremio(cents: premio),
          if (errore != null) ...[
            InlineBanner(message: errore!),
            const SizedBox(height: AppSpacing.md),
          ],
          CrasyButton(
            label: paga ? 'Paga e lancia' : 'Lancia la missione',
            onPressed: onPaga,
          ),
          if (paga) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              RiepilogoPremio.avvertenza,
              style: texts.bodySmall?.copyWith(color: palette.textSecondary),
            ),
          ],
        ],
      ],
    );
  }
}
