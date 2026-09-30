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

/// **Una persona che segui, con tutte le gare in cui e' dentro adesso.**
///
/// Prima una riga per foto: chi era in tre gare compariva tre volte di fila,
/// tre facce uguali una sotto l'altra. Adesso la persona compare una volta, e
/// le sue foto stanno affiancate come carte accavallate — la prossima sporge
/// dal bordo, e si scorre di lato per vederle tutte. Ogni carta dice in che
/// gara sta, e si tocca per entrarci.
class FollowedPerson extends StatefulWidget {
  const FollowedPerson({required this.entries, super.key});

  /// Le sue foto in gara, dalla piu' recente. Tutte della stessa persona.
  final List<ChallengeEntry> entries;

  @override
  State<FollowedPerson> createState() => _FollowedPersonState();
}

class _FollowedPersonState extends State<FollowedPerson> {
  /// Quanto di una carta si vede: il resto e' la prossima che sporge.
  static const double _larghezzaCarta = 0.86;

  final _pagine = PageController(viewportFraction: _larghezzaCarta);
  int _qui = 0;

  @override
  void dispose() {
    _pagine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final entries = widget.entries;
    final prima = entries.first;
    final quando = prima.createdAt;
    final tante = entries.length > 1;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      context.push(AppRoutes.userProfileOf(prima.userId)),
                  child: FriendAvatar(
                    userId: prima.userId,
                    username: prima.authorName,
                    size: 42,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        context.push(AppRoutes.userProfileOf(prima.userId)),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TickedName(
                          userId: prima.userId,
                          text: '@${prima.authorName}',
                          style: texts.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            tante
                                ? 'IN GARA IN ${entries.length} MISSIONI'
                                : 'IN GARA',
                            if (quando != null)
                              AppDateUtils.shortTimeAgo(quando),
                          ].join('  ·  '),
                          style: texts.labelSmall?.copyWith(
                            color: palette.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Dove si e' nel mazzo: 2/3.
                if (tante)
                  Text(
                    '${_qui + 1}/${entries.length}',
                    style: texts.labelSmall?.copyWith(color: palette.accent),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!tante)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: _Carta(entry: prima),
            )
          else
            LayoutBuilder(
              builder: (context, vincoli) {
                // La carta e' larga una parte dello schermo; la foto e' 4:5,
                // sopra c'e' la riga della gara e sotto quella dei comandi.
                final carta = vincoli.maxWidth * _larghezzaCarta;
                final altezza = carta * 5 / 4 + 120;

                return SizedBox(
                  height: altezza,
                  child: PageView.builder(
                    controller: _pagine,
                    padEnds: false,
                    itemCount: entries.length,
                    onPageChanged: (pagina) => setState(() => _qui = pagina),
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      // Dentro uno scorrimento fermo: se la carta viene piu'
                      // alta del previsto si taglia in fondo, invece di
                      // rompere l'impaginazione.
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: _Carta(entry: entries[index]),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Una foto con sopra la gara in cui sta.
class _Carta extends ConsumerWidget {
  const _Carta({required this.entry});

  final ChallengeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final challenge = ref.watch(knownChallengeProvider(entry.challengeId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () =>
              context.push(AppRoutes.challengeDetailOf(entry.challengeId)),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                if (challenge != null) ...[
                  Text(
                    challenge.prizeLabel,
                    style: texts.labelSmall?.copyWith(color: palette.accent),
                  ),
                  Text(
                    '  ·  ',
                    style: texts.labelSmall?.copyWith(color: palette.textFaint),
                  ),
                ],
                Flexible(
                  child: Text(
                    (challenge?.title ?? entry.challengeTitle).toUpperCase(),
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
        ),
        // Il nome sta gia' in cima al riquadro.
        EntryTile(entry: entry, showChallenge: false),
      ],
    );
  }
}
