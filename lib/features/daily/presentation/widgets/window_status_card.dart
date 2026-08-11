import 'package:app_incontri/core/theme/app_palette.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/features/daily/domain/entities/daily_access.dart';
import 'package:app_incontri/features/daily/domain/entities/daily_window.dart';
import 'package:app_incontri/features/daily/presentation/widgets/countdown_text.dart';
import 'package:flutter/material.dart';

/// Il conto alla rovescia verso la prossima Istantanea, con le tre fasce
/// della giornata sotto.
///
/// Il numero grande da solo direbbe solo "quanto manca"; la fila delle fasce
/// dice anche "a che punto sei" — quali hai gia' fatto e quale ti aspetta —
/// che e' l'informazione che fa tornare la sera.
class WindowStatusCard extends StatelessWidget {
  const WindowStatusCard({required this.access, super.key});

  final DailyAccess access;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final open = access.windowOpen && !access.usedCurrentSlot;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _caption(),
            style: context.texts.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xxs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: CountdownText(
              target: access.boundary,
              style: context.texts.displaySmall?.copyWith(
                color: open ? palette.brand : palette.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SlotStrip(access: access),
        ],
      ),
    );
  }

  String _caption() {
    if (access.windowOpen && !access.usedCurrentSlot) {
      return 'Sei in tempo, chiude tra';
    }

    if (access.limitReached) {
      return 'Hai finito le istantanee di oggi. Si ricomincia tra';
    }

    return 'Prossima istantanea tra';
  }
}

/// Le tre fasce della giornata: fatta, aperta adesso, oppure in attesa.
class _SlotStrip extends StatelessWidget {
  const _SlotStrip({required this.access});

  final DailyAccess access;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < DailyWindow.slotHours.length; index++) ...[
          if (index > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _SlotChip(
              label: DailyWindow.labelOf(index),
              done: access.usedSlots.contains(index),
              open: access.openSlot == index,
            ),
          ),
        ],
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.done,
    required this.open,
  });

  final String label;
  final bool done;

  /// Aperta adesso. Se e' anche gia' fatta, vince [done]: cio' che conta e'
  /// che quella foto c'e'.
  final bool open;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final highlighted = done || open;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: done ? palette.brand : palette.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: open && !done ? palette.brand : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_rounded : Icons.photo_camera_outlined,
            size: 16,
            color: done
                ? palette.onBrand
                : highlighted
                ? palette.brand
                : palette.textSecondary,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: context.texts.bodySmall?.copyWith(
              color: done
                  ? palette.onBrand
                  : highlighted
                  ? palette.brand
                  : palette.textSecondary,
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Riga compatta con gli orari delle fasce.
class WindowScheduleLine extends StatelessWidget {
  const WindowScheduleLine({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hours = [
      for (var index = 0; index < DailyWindow.slotHours.length; index++)
        DailyWindow.labelOf(index),
    ].join(', ');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_rounded, size: 15, color: palette.textSecondary),
        const SizedBox(width: AppSpacing.xxs),
        Flexible(
          child: Text(
            'Ogni giorno alle $hours',
            style: context.texts.bodySmall,
          ),
        ),
      ],
    );
  }
}
