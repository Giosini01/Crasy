import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
import 'package:crasy/core/widgets/modal_sheet.dart';
import 'package:crasy/features/moderation/domain/report_reason.dart';
import 'package:crasy/features/moderation/presentation/providers/moderation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Il menu con cui si segnala qualcosa o si blocca qualcuno.
///
/// **Le due cose stanno insieme perche' arrivano insieme.** Chi ha appena letto
/// un insulto vuole due cose nello stesso momento: che qualcuno se ne occupi, e
/// non vedere piu' quella persona. Dargliene una sola lo lascia con la
/// sensazione di non aver risolto niente, e la seconda volta non segnala piu'.
///
/// Si apre da ogni foto, da ogni commento, da ogni missione e da ogni profilo. E'
/// sempre lo stesso menu: chi impara a segnalare una foto sa gia' segnalare un
/// commento.
///
/// **Ma restano due gesti diversi.** Bloccare non e' segnalare: non chiede a
/// nessuno di giudicare niente, e un blocco non diventa mai da solo una
/// segnalazione. Al team arriva un avviso, e non una cosa da decidere.
///
/// Torna cosa e' successo, o `null` se ci si e' ripensato: chi guarda la foto a
/// tutto schermo deve sapere che adesso non la deve piu' mostrare.
Future<ContentAction?> showContentMenu(
  BuildContext context,
  WidgetRef ref,
  ReportTarget target,
) async {
  final giaBloccato = ref
      .read(blockedNowProvider)
      .contains(target.reportedUserId);

  final scelta = await ModalSheet.show<_MenuChoice>(
    context: context,
    builder: (sheetContext) => ModalSheet(
      title: 'OPZIONI',
      confirmLabel: 'Chiudi',
      onConfirm: () => Navigator.of(sheetContext).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Row(
            label: 'Segnala',
            detail:
                'Segnala ${target.cosa}: la guarda una persona del team entro '
                '24 ore.',
            accent: false,
            onTap: () => Navigator.of(sheetContext).pop(_MenuChoice.report),
          ),
          if (target.bloccabile)
            giaBloccato
                ? _Row(
                    label: 'Sblocca @${target.reportedUsername}',
                    detail: 'Torni a vedere i suoi contenuti.',
                    accent: false,
                    onTap: () =>
                        Navigator.of(sheetContext).pop(_MenuChoice.unblock),
                  )
                : _Row(
                    label: 'Blocca @${target.reportedUsername}',
                    detail:
                        'Non vedi più i suoi contenuti e non potete più '
                        'interagire.',
                    accent: true,
                    onTap: () =>
                        Navigator.of(sheetContext).pop(_MenuChoice.block),
                  ),
        ],
      ),
    ),
  );

  if (scelta == null || !context.mounted) {
    return null;
  }

  switch (scelta) {
    case _MenuChoice.report:
      return await showReportSheet(context, target)
          ? ContentAction.reported
          : null;
    case _MenuChoice.block:
      return await confirmAndBlock(context, ref, target)
          ? ContentAction.blocked
          : null;
    case _MenuChoice.unblock:
      await _sblocca(context, ref, target);

      return null;
  }
}

/// Cosa e' successo dal menu.
enum ContentAction { reported, blocked }

enum _MenuChoice { report, block, unblock }

/// **Il tasto del menu**: tre puntini, che vogliono dire la stessa cosa dovunque.
class ContentMenuButton extends ConsumerWidget {
  const ContentMenuButton({
    required this.target,
    this.color,
    this.size = 20,
    this.onAction,
    super.key,
  });

  final ReportTarget target;
  final Color? color;
  final double size;
  final ValueChanged<ContentAction>? onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // **CRASY non si segnala**: la riceverebbe la stessa persona che dovrebbe
    // deciderla, e le regole la rifiutano. Un tasto che promette una cosa che non
    // puo' succedere vale meno di un tasto che non c'e'.
    if (target.reportedUserId == 'crasy') {
      return const SizedBox.shrink();
    }

    return IconButton(
      onPressed: () async {
        final fatto = await showContentMenu(context, ref, target);

        if (fatto != null) {
          onAction?.call(fatto);
        }
      },
      icon: Icon(Icons.more_horiz_rounded, size: size, color: color),
      tooltip: 'Segnala o blocca',
    );
  }
}

/// La segnalazione: il motivo, una descrizione se si vuole, e la conferma.
///
/// Torna `true` se e' arrivata, anche se era gia' arrivata prima.
Future<bool> showReportSheet(BuildContext context, ReportTarget target) async {
  final messenger = ScaffoldMessenger.of(context);

  final frase = await ModalSheet.show<String>(
    context: context,
    builder: (sheetContext) => ModalSheet(
      title: 'SEGNALA',
      confirmLabel: 'Chiudi',
      onConfirm: () => Navigator.of(sheetContext).pop(),
      child: _ReportFlow(target: target),
    ),
  );

  if (frase == null) {
    return false;
  }

  messenger.showSnackBar(SnackBar(content: Text(frase)));

  return true;
}

/// **Chiede conferma, e poi blocca.**
///
/// Il blocco si disfa, ma fra i due toglie tutto — amicizia compresa — e a farlo
/// partire basta un dito storto su una riga di un menu. Si chiede una volta,
/// dicendo cosa succede davvero.
///
/// Torna `true` se il blocco e' stato registrato.
Future<bool> confirmAndBlock(
  BuildContext context,
  WidgetRef ref,
  ReportTarget target,
) async {
  final palette = context.palette;
  final nome = target.reportedUsername;
  final messenger = ScaffoldMessenger.of(context);

  final si = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Bloccare @$nome?'),
      content: const Text(
        'Le sue foto, le sue missioni e i suoi commenti spariscono subito dalla '
        'tua vista, e fra voi non sono più possibili commenti, fiamme, amicizia '
        'e sfide.\n\n'
        'Non glielo diciamo noi. Il blocco viene comunicato al team di CRASY, e '
        'puoi toglierlo quando vuoi dalle impostazioni del profilo.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text('Blocca', style: TextStyle(color: palette.accent)),
        ),
      ],
    ),
  );

  if (si != true) {
    return false;
  }

  final fatto = await ref.read(moderationActionsProvider).block(target);

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        fatto
            ? 'Hai bloccato @$nome. Non vedi più i suoi contenuti.'
            : 'Non siamo riusciti a bloccarlo. Riprova.',
      ),
    ),
  );

  return fatto;
}

Future<void> _sblocca(
  BuildContext context,
  WidgetRef ref,
  ReportTarget target,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final fatto = await ref
      .read(moderationActionsProvider)
      .unblock(target.reportedUserId);

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        fatto
            ? 'Hai sbloccato @${target.reportedUsername}.'
            : 'Non ci siamo riusciti. Riprova.',
      ),
    ),
  );
}

/// **Si dice cosa succede adesso, non "grazie".** Chi segnala vuole sapere se e'
/// servito a qualcosa: queste frasi sono vere, ed e' il motivo per cui segnalera'
/// di nuovo.
///
/// Solo una foto segnalata sparisce davvero dalla vista di chi la segnala, e solo
/// quella lo promette: una persona o una missione restano dove sono finche' non
/// ha deciso il team.
String fraseDopoLaSegnalazione(ReportTargetKind kind, ReportOutcome esito) {
  if (esito == ReportOutcome.alreadySent) {
    return 'L\'avevi già segnalata: una persona del team la guarda entro 24 ore.';
  }

  return switch (kind) {
    ReportTargetKind.entry =>
      'Segnalata. Una persona del team la guarda entro 24 ore. Tu intanto non '
          'la vedi più.',
    ReportTargetKind.comment =>
      'Segnalato. Una persona del team lo guarda entro 24 ore.',
    ReportTargetKind.challenge || ReportTargetKind.user =>
      'Segnalata. Una persona del team la guarda entro 24 ore.',
  };
}

/// I due passi: prima il motivo, poi la conferma.
///
/// **La conferma e' un passo vero**, e non solo per prudenza: e' li' che si
/// scrive cosa e' successo, e una segnalazione con due righe di spiegazione si
/// giudica in un quarto del tempo.
class _ReportFlow extends ConsumerStatefulWidget {
  const _ReportFlow({required this.target});

  final ReportTarget target;

  @override
  ConsumerState<_ReportFlow> createState() => _ReportFlowState();
}

class _ReportFlowState extends ConsumerState<_ReportFlow> {
  final _nota = TextEditingController();

  ReportReason? _motivo;

  /// **Mentre parte, il tasto non si ripreme.** Due tocchi sarebbero una
  /// segnalazione sola lo stesso, ma il secondo tornerebbe "gia' segnalata" a chi
  /// ha appena segnalato per la prima volta.
  bool _inviando = false;
  bool _nonRiuscita = false;

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  Future<void> _invia() async {
    final motivo = _motivo;

    if (motivo == null || _inviando) {
      return;
    }

    final navigator = Navigator.of(context);

    setState(() {
      _inviando = true;
      _nonRiuscita = false;
    });

    final esito = await ref
        .read(moderationActionsProvider)
        .report(widget.target, reason: motivo, note: _nota.text);

    if (!mounted) {
      return;
    }

    if (esito == ReportOutcome.failed) {
      setState(() {
        _inviando = false;
        _nonRiuscita = true;
      });

      return;
    }

    navigator.pop(fraseDopoLaSegnalazione(widget.target.kind, esito));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final motivo = _motivo;

    if (motivo == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Cosa non va in ${widget.target.cosa}?',
            style: texts.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'La guarda una persona del team entro 24 ore. Chi hai segnalato non '
            'saprà che sei stato tu.',
            style: texts.bodySmall?.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final reason in ReportReason.values)
            _Row(
              label: reason.label,
              detail: reason.detail,
              // Il primo motivo e' il piu' grave e si vede: e' l'unico in
              // rosso. Non per gerarchia estetica — perche' chi ha davanti una
              // cosa pericolosa deve trovare quella voce senza leggere le
              // altre.
              accent: reason == ReportReason.danger,
              onTap: () => setState(() => _motivo = reason),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'MOTIVO',
          style: texts.labelSmall?.copyWith(color: palette.textFaint),
        ),
        Row(
          children: [
            Expanded(child: Text(motivo.label, style: texts.titleMedium)),
            TextButton(
              onPressed: _inviando
                  ? null
                  : () => setState(() => _motivo = null),
              child: Text(
                'CAMBIA',
                style: texts.labelSmall?.copyWith(color: palette.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _nota,
          enabled: !_inviando,
          maxLength: 500,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'VUOI AGGIUNGERE QUALCOSA? (FACOLTATIVO)',
            hintText: 'Cosa è successo',
          ),
        ),
        if (_nonRiuscita) ...[
          const SizedBox(height: AppSpacing.sm),
          const InlineBanner(
            message:
                'Segnalazione non riuscita. Controlla la connessione e riprova.',
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        CrasyButton(
          label: 'Invia la segnalazione',
          loading: _inviando,
          onPressed: _invia,
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.detail,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: texts.titleSmall?.copyWith(
                      color: accent ? palette.accent : palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: texts.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.textFaint),
          ],
        ),
      ),
    );
  }
}
