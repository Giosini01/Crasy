import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/entry_tile.dart';
import 'package:crasy/features/friends/presentation/widgets/friend_avatar.dart';
import 'package:crasy/features/friends/presentation/widgets/verified_tick.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// La foto con cui qualcuno che segui e' in gara, come un post.
///
/// **Prima chi, poi dove, poi la foto.** In cima la faccia e il nome, grandi
/// abbastanza da riconoscere la persona senza leggere: e' lei che si segue, non
/// la gara. Sotto il nome, piccola, la gara in cui sta — premio e titolo — che
/// si tocca per entrarci. Poi la foto: doppio tocco per la fiamma, tocco
/// singolo per aprirla grande, gli stessi gesti della home.
class FollowedEntry extends ConsumerWidget {
  const FollowedEntry({required this.entry, super.key});

  final ChallengeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final challenge = ref.watch(knownChallengeProvider(entry.challengeId));
    final quando = entry.createdAt;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push(AppRoutes.userProfileOf(entry.userId)),
                child: FriendAvatar(
                  userId: entry.userId,
                  username: entry.authorName,
                  size: 42,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () =>
                          context.push(AppRoutes.userProfileOf(entry.userId)),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              '@${entry.authorName}',
                              style: texts.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          VerifiedTick(userId: entry.userId, size: 14),
                          if (quando != null) ...[
                            Text(
                              '  ·  ${AppDateUtils.shortTimeAgo(quando)}',
                              style: texts.labelSmall?.copyWith(
                                color: palette.textFaint,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    // **Dove e' in gara**, piccolo e toccabile: si entra nella
                    // gara da qui.
                    GestureDetector(
                      onTap: () => context.push(
                        AppRoutes.challengeDetailOf(entry.challengeId),
                      ),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Text(
                            'IN GARA',
                            style: texts.labelSmall?.copyWith(
                              color: palette.textFaint,
                            ),
                          ),
                          if (challenge != null) ...[
                            Text(
                              '  ·  ',
                              style: texts.labelSmall?.copyWith(
                                color: palette.textFaint,
                              ),
                            ),
                            Text(
                              challenge.prizeLabel,
                              style: texts.labelSmall?.copyWith(
                                color: palette.accent,
                              ),
                            ),
                            Text(
                              '  ·  ',
                              style: texts.labelSmall?.copyWith(
                                color: palette.textFaint,
                              ),
                            ),
                          ],
                          Flexible(
                            child: Text(
                              (challenge?.title ?? entry.challengeTitle)
                                  .toUpperCase(),
                              style: texts.labelSmall?.copyWith(
                                color: palette.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: palette.textFaint,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // La gara e il nome stanno gia' qui sopra.
          EntryTile(entry: entry, showChallenge: false),
        ],
      ),
    );
  }
}
