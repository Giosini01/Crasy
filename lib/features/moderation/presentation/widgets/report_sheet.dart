import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/modal_sheet.dart';
import 'package:crasy/features/moderation/domain/report_reason.dart';
import 'package:crasy/features/moderation/presentation/providers/moderation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Il foglio con cui si segnala qualcosa o si blocca qualcuno.
///
/// **Le due cose stanno insieme perche' arrivano insieme.** Chi ha appena letto
/// un insulto vuole due cose nello stesso momento: che qualcuno se ne occupi, e
/// non vedere piu' quella persona. Dargliene una sola lo lascia con la
/// sensazione di non aver risolto niente, e la seconda volta non segnala piu'.
///
/// Si apre da ogni foto, da ogni commento e da ogni profilo. E' sempre lo stesso
/// foglio: chi impara a segnalare una foto sa gia' segnalare un commento.
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required ReportTargetKind kind,
  required String reportedUserId,
  required String reportedUsername,
  String challengeId = '',
  String entryId = '',
  String commentId = '',
}) async {
  final scelta = await ModalSheet.show<_Choice>(
    context: context,
    builder: (sheetContext) => ModalSheet(
      title: 'SEGNALA',
      confirmLabel: 'Chiudi',
      onConfirm: () => Navigator.of(sheetContext).pop(),
      child: _ReportBody(
        kind: kind,
        username: reportedUsername,
        onPick: (voce) => Navigator.of(sheetContext).pop(voce),
      ),
    ),
  );

  if (scelta == null || !context.mounted) {
    return;
  }

  final azioni = ref.read(moderationActionsProvider);
  final messenger = ScaffoldMessenger.of(context);

  if (scelta.block) {
    final fatto = await azioni.block(reportedUserId);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          fatto
              ? 'Hai bloccato @$reportedUsername. Non lo vedi più.'
              : 'Non siamo riusciti a bloccarlo. Riprova.',
        ),
      ),
    );

    return;
  }

  final motivo = scelta.reason;

  if (motivo == null) {
    return;
  }

  final fatto = await azioni.report(
    kind: kind,
    reportedUserId: reportedUserId,
    reason: motivo,
    challengeId: challengeId,
    entryId: entryId,
    commentId: commentId,
  );

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        fatto
            // **Si dice cosa succede adesso, non "grazie".** Chi segnala vuole
            // sapere se e' servito a qualcosa: le due frasi qui sotto sono
            // tutte e due vere, ed e' il motivo per cui segnalera' di nuovo.
            ? 'Segnalata. Tu non la vedi più, e la guardiamo entro 24 ore.'
            : 'Segnalazione non riuscita. Riprova.',
      ),
    ),
  );
}

/// Cosa e' stato scelto nel foglio: un motivo, oppure il blocco.
class _Choice {
  const _Choice.report(this.reason) : block = false;
  const _Choice.block() : reason = null, block = true;

  final ReportReason? reason;
  final bool block;
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.kind,
    required this.username,
    required this.onPick,
  });

  final ReportTargetKind kind;
  final String username;
  final ValueChanged<_Choice> onPick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    final cosa = switch (kind) {
      ReportTargetKind.entry => 'questa foto',
      ReportTargetKind.comment => 'questo commento',
      ReportTargetKind.challenge => 'questa missione',
      ReportTargetKind.user => 'questa persona',
    };

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Cosa non va in $cosa?', style: texts.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'La guardiamo entro 24 ore. Nel frattempo tu non la vedi più.',
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
              // altre cinque.
              accent: reason == ReportReason.danger,
              onTap: () => onPick(_Choice.report(reason)),
            ),
          Divider(color: palette.line, height: AppSpacing.xl),
          _Row(
            label: 'Blocca @$username',
            detail:
                'Non vedi più le sue foto e i suoi commenti, e lui non vede '
                'i tuoi. Si toglie dalle impostazioni.',
            accent: true,
            onTap: () => onPick(const _Choice.block()),
          ),
        ],
      ),
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
