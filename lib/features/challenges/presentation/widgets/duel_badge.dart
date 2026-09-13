import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/duel_status.dart';
import 'package:flutter/material.dart';

/// **Chi ha sfidato chi, e a che punto e' la sfida.**
///
/// Una riga sola: i due nomi con una freccia in mezzo, e accanto il distintivo
/// dello stato. E' l'unica cosa che distingue una sfida mirata da una missione
/// qualunque — senza, chi la apre vede una gara con premio zero e un posto
/// solo, e non capisce cosa sta guardando.
///
/// Lo stesso widget sta nel dettaglio della missione e nelle due schede del
/// party, ed e' voluto: la stessa cosa deve avere la stessa faccia nei due
/// posti in cui la si incontra, o si impara due volte.
class DuelBadge extends StatelessWidget {
  const DuelBadge({required this.challenge, this.compact = false, super.key});

  final Challenge challenge;

  /// Dentro un elenco: piu' piccolo, e senza i nomi per esteso.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final state = challenge.duelStateAt(DateTime.now());

    return Row(
      children: [
        DuelStateChip(state: state),
        if (!compact) ...[
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              '@${challenge.createdByUsername} → '
              '@${challenge.targetUsername}',
              style: texts.labelMedium?.copyWith(color: palette.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

/// Il distintivo dello stato, da solo.
///
/// **Il colore dice cosa c'e' da fare, non che umore avere.** Rosso dove la
/// palla e' ancora in gioco — in attesa, accettata — e grigio dove non c'e'
/// piu' niente da decidere: rifiutata, scaduta. La completata e' l'eccezione e
/// se lo merita: e' l'unica cosa che questa funzione esiste per produrre.
class DuelStateChip extends StatelessWidget {
  const DuelStateChip({required this.state, super.key});

  final DuelState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final (colore, sfondo, icona) = switch (state) {
      DuelState.pending => (
        palette.accent,
        palette.accentTint,
        Icons.hourglass_top_rounded,
      ),
      DuelState.accepted => (
        palette.accent,
        palette.accentTint,
        Icons.handshake_rounded,
      ),
      DuelState.completed => (
        palette.accent,
        palette.accentTint,
        Icons.military_tech_rounded,
      ),
      DuelState.declined => (
        palette.textFaint,
        palette.surfaceMuted,
        Icons.do_not_disturb_alt_rounded,
      ),
      DuelState.expired => (
        palette.textFaint,
        palette.surfaceMuted,
        Icons.schedule_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: sfondo,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icona, size: 12, color: colore),
          const SizedBox(width: 4),
          Text(
            state.label,
            style: context.texts.labelSmall?.copyWith(
              color: colore,
              fontSize: 9,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
