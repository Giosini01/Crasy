import 'package:app_incontri/core/theme/app_palette.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/features/stats/domain/entities/vibe_stats.dart';
import 'package:flutter/material.dart';

/// I tre numeri di una giornata, uno accanto all'altro.
class VibeDayRow extends StatelessWidget {
  const VibeDayRow({required this.day, super.key});

  final VibeDay day;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _VibeTile(
            icon: Icons.visibility_outlined,
            value: day.views,
            label: day.views == 1 ? 'persona ti ha visto' : 'ti hanno visto',
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _VibeTile(
            icon: Icons.favorite_rounded,
            value: day.likes,
            label: day.likes == 1 ? 'cuore' : 'cuori',
            highlight: true,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _VibeTile(
            icon: Icons.bolt_rounded,
            value: day.matches,
            label: day.matches == 1 ? 'match' : 'match',
            highlight: true,
          ),
        ),
      ],
    );
  }
}

class _VibeTile extends StatelessWidget {
  const _VibeTile({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final int value;
  final String label;

  /// Cuori e match prendono il viola, gli sguardi no: il viola resta
  /// l'indicazione di una cosa successa, non di un numero qualunque.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = highlight && value > 0 ? palette.brand : palette.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '$value',
            style: context.texts.headlineSmall?.copyWith(
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          // Le tre etichette hanno lunghezze molto diverse e le colonne sono
          // strette: rimpicciolire e' meglio che troncare una parola a meta'.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: context.texts.bodySmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La striscia di giorni consecutivi.
class StreakBadge extends StatelessWidget {
  const StreakBadge({required this.days, super.key});

  final int days;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final alive = days > 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: alive ? palette.brandTint : palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: alive ? palette.brand : palette.border,
          width: alive ? 1 : 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 17,
            color: alive ? palette.brand : palette.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            alive
                ? '$days ${days == 1 ? 'giorno' : 'giorni'} di autenticita'
                : 'Nessuna striscia',
            style: context.texts.bodySmall?.copyWith(
              color: alive ? palette.brand : palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
