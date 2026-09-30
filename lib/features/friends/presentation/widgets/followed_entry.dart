import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/entry_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// La foto con cui qualcuno che segui e' in gara: una riga piccola con premio e
/// gara, e la foto grande sotto.
///
/// Doppio tocco per la fiamma, tocco singolo per aprirla grande: gli stessi due
/// gesti della home. Cambia solo di chi sono le foto.
class FollowedEntry extends ConsumerWidget {
  const FollowedEntry({required this.entry, super.key});

  final ChallengeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final challenge = ref.watch(knownChallengeProvider(entry.challengeId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (challenge != null) ...[
          GestureDetector(
            onTap: () =>
                context.push(AppRoutes.challengeDetailOf(challenge.id)),
            behavior: HitTestBehavior.opaque,
            // **Una riga piccola, e la foto grande sotto.** Qui si guarda cosa
            // ha combinato qualcuno, e la cosa da guardare e' la foto.
            child: Row(
              children: [
                Text(
                  challenge.prizeLabel,
                  style: texts.labelSmall?.copyWith(color: palette.accent),
                ),
                Text(
                  '  ·  ',
                  style: texts.labelSmall?.copyWith(color: palette.textFaint),
                ),
                Flexible(
                  child: Text(
                    challenge.title.toUpperCase(),
                    style: texts.labelSmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: palette.textFaint,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        // Il titolo della gara sta gia' nella riga qui sopra.
        EntryTile(entry: entry, showChallenge: challenge == null),
        const SizedBox(height: AppSpacing.lg),
        Divider(color: palette.line, height: 0.5, thickness: 0.5),
      ],
    );
  }
}
