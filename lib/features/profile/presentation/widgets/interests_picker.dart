import 'package:app_incontri/core/theme/app_palette.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/features/profile/domain/entities/profile_interests.dart';
import 'package:flutter/material.dart';

/// Scelta degli interessi, su cui si calcola l'affinita'.
///
/// Vive qui e non dentro l'onboarding perche' serve in due posti: alla
/// registrazione e a ogni modifica del profilo.
class InterestsPicker extends StatelessWidget {
  const InterestsPicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  bool get _isFull => selected.length >= ProfileInterests.maxChoices;

  void _toggle(String id) {
    if (selected.contains(id)) {
      onChanged([...selected]..remove(id));
      return;
    }

    if (_isFull) {
      return;
    }

    onChanged([...selected, id]);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final missing = ProfileInterests.minChoices - selected.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          missing > 0
              ? 'Scegline almeno altri $missing.'
              : _isFull
              ? 'Hai raggiunto il massimo di ${ProfileInterests.maxChoices}.'
              : 'Ne hai scelti ${selected.length}. Puoi fermarti qui.',
          style: context.texts.bodySmall?.copyWith(
            color: missing > 0 ? palette.brand : palette.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final id in ProfileInterests.allIds)
              _InterestChip(
                label: ProfileInterests.labelOf(id),
                selected: selected.contains(id),
                // Al massimo si possono solo togliere, non aggiungere: il
                // limite si fa sentire senza far sparire le altre voci.
                enabled: selected.contains(id) || !_isFull,
                onTap: () => _toggle(id),
              ),
          ],
        ),
      ],
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: selected ? palette.brand : palette.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            label,
            style: context.texts.bodyMedium?.copyWith(
              color: selected ? palette.onBrand : palette.textPrimary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// Gli interessi in sola lettura, con quelli in comune messi in evidenza.
class InterestChips extends StatelessWidget {
  const InterestChips({
    required this.ids,
    this.highlighted = const [],
    super.key,
  });

  final List<String> ids;

  /// Quelli condivisi con chi guarda: sono il motivo per cui si scrive.
  final List<String> highlighted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final id in ids)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs + 2,
              vertical: AppSpacing.xxs + 2,
            ),
            decoration: BoxDecoration(
              color: highlighted.contains(id)
                  ? palette.brand
                  : palette.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              ProfileInterests.labelOf(id),
              style: context.texts.bodySmall?.copyWith(
                color: highlighted.contains(id)
                    ? palette.onBrand
                    : palette.textPrimary,
              ),
            ),
          ),
      ],
    );
  }
}
