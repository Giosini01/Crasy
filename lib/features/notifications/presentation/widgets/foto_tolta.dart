import 'package:cloud_functions/cloud_functions.dart';
import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// **Perche' la tua foto e' stata tolta, e cosa ci puoi fare.**
///
/// Si apre toccando l'avviso in campanella. Prima quell'avviso portava alla
/// gara, dove la foto non c'era piu' e nessuno spiegava niente: chi l'aveva
/// mandata non sapeva ne' il motivo ne' a chi chiedere.
///
/// Qui ci sono le tre cose che il Digital Services Act chiede a chi toglie un
/// contenuto: **il motivo**, **se l'ha deciso una macchina** e **il modo di
/// contestarlo** — un tasto, non un indirizzo da cercare. La revisione la fa
/// una persona del team, dalla pagina di amministrazione (vedi
/// `functions/revisioni.js`).
Future<void> mostraFotoTolta(BuildContext context, AppNotification avviso) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.palette.background,
    builder: (_) => _FotoTolta(avviso: avviso),
  );
}

class _FotoTolta extends ConsumerStatefulWidget {
  const _FotoTolta({required this.avviso});

  final AppNotification avviso;

  @override
  ConsumerState<_FotoTolta> createState() => _FotoToltaState();
}

class _FotoToltaState extends ConsumerState<_FotoTolta> {
  bool _working = false;
  String? _errore;

  /// Lo stato visto da qui: parte da quello dell'avviso, e diventa `chiesta`
  /// appena il server risponde — senza aspettare che l'avviso si aggiorni.
  late String _revisione = widget.avviso.revisione;

  Future<void> _chiedi() async {
    setState(() {
      _working = true;
      _errore = null;
    });

    try {
      await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable('chiediRevisione')
          .call<Object?>({'challengeId': widget.avviso.challengeId});

      if (mounted) {
        setState(() {
          _working = false;
          _revisione = 'chiesta';
        });
      }
    } on FirebaseFunctionsException catch (errore) {
      if (mounted) {
        setState(() {
          _working = false;
          _errore = errore.code == 'failed-precondition'
              ? 'Questa foto non risulta più tolta: forse è già tornata in '
                    'gara.'
              : 'Non ci siamo riusciti. Riprova fra poco.';
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _working = false;
          _errore = 'Non ci siamo riusciti. Riprova fra poco.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final avviso = widget.avviso;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Perché è stata tolta',
              style: texts.headlineMedium?.copyWith(
                fontWeight: FontWeight.w400,
              ),
            ),
            if (avviso.challengeTitle.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                avviso.challengeTitle.toUpperCase(),
                style: texts.labelSmall?.copyWith(color: palette.textFaint),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(avviso.perche, style: texts.bodyLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              // Tolta per il conto, non per quello che mostrava: la regola da
              // ricordare e' un'altra.
              avviso.oltreIlLimite
                  ? 'Si partecipa al massimo a ${Challenge.livesPerDay} gare '
                        'al giorno; la sfida del giorno e le sfide mirate non '
                        'contano. A mezzanotte si ricomincia.'
                  : 'Le regole delle missioni non ammettono contenuti '
                        'sessuali, violenti, offensivi o che mettono in '
                        'pericolo qualcuno: è il punto 3 dei termini.',
              style: texts.bodySmall?.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            _Riga(
              icona: avviso.automatico
                  ? Icons.smart_toy_outlined
                  : Icons.person_outline_rounded,
              testo: avviso.automatico
                  ? 'Decisione automatica: nessuna persona l\'ha ancora '
                        'guardata.'
                  : 'L\'ha decisa una persona del team.',
            ),
            const SizedBox(height: AppSpacing.lg),
            ..._cosaPuoiFare(context),
            if (_errore != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _errore!,
                style: texts.bodySmall?.copyWith(color: palette.accent),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Center(
              child: TextButton(
                onPressed: () {
                  // Il router si prende prima di chiudere il foglio: dopo, il
                  // suo contesto non c'e' piu'.
                  final router = GoRouter.of(context);

                  Navigator.of(context).pop();
                  router.push(AppRoutes.challengeDetailOf(avviso.challengeId));
                },
                child: const Text('Vai alla missione'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _cosaPuoiFare(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return switch (_revisione) {
      'chiesta' => [
        _Stato(
          testo:
              'Revisione chiesta. La guarda una persona del team: se ci siamo '
              'sbagliati la rimettiamo in gara e te lo diciamo con una '
              'notifica.',
          colore: palette.accent,
        ),
      ],
      'respinta' => [
        _Stato(
          testo:
              'Una persona del team l\'ha riguardata: resta fuori dalla '
              'gara.',
          colore: palette.textSecondary,
        ),
      ],
      _ => [
        Text(
          'Pensi che sia un errore? Chiedi una revisione: la guarda una '
          'persona del team e, se ci siamo sbagliati, la rimettiamo in gara.',
          style: texts.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        CrasyButton(
          label: 'Chiedi una revisione',
          loading: _working,
          onPressed: _chiedi,
        ),
      ],
    };
  }
}

/// Un segno e una frase: chi ha deciso.
class _Riga extends StatelessWidget {
  const _Riga({required this.icona, required this.testo});

  final IconData icona;
  final String testo;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Icon(icona, size: 18, color: palette.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            testo,
            style: context.texts.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// A che punto e' la revisione, in un riquadro: e' una risposta, non un tasto.
class _Stato extends StatelessWidget {
  const _Stato({required this.testo, required this.colore});

  final String testo;
  final Color colore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colore.withValues(alpha: 0.4)),
      ),
      child: Text(testo, style: context.texts.bodyMedium),
    );
  }
}
