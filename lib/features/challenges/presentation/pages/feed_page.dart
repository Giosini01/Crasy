import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/entry_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Il feed: prima le tue foto in gara, poi quelle di tutti gli altri.
///
/// L'ordine e' quello giusto per la domanda che uno si fa riaprendo l'app —
/// *come sta andando la mia?* — e non e' un vezzo da profilo: le proprie foto
/// ancora in gara sono l'unica cosa il cui numero **cambia da solo** mentre non
/// stai guardando.
///
/// Le partecipazioni a challenge gia' chiuse qui non compaiono: il loro esito
/// sta fra i vincitori, e tenerle qui trasformerebbe la striscia in un archivio.
class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(feedEntriesProvider);
    final mine = ref.watch(myOpenEntriesProvider);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: context.palette.accent,
            onRefresh: () async => ref.invalidate(feedEntriesProvider),
            child: entries.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                children: const [
                  _Title(),
                  EmptyState(
                    title: 'Feed non disponibile',
                    message:
                        'Non riusciamo a caricare le partecipazioni. '
                        'Controlla la connessione.',
                  ),
                ],
              ),
              data: (items) => ListView.separated(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                itemCount: items.length + 1,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.xl),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.page,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Title(),
                          if (mine.isNotEmpty) _InPlay(entries: mine),
                          if (items.isEmpty)
                            const EmptyState(
                              title: 'Ancora niente',
                              message:
                                  'Quando qualcuno manda una foto a una '
                                  'challenge la trovi qui.',
                            ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                    ),
                    child: EntryTile(entry: items[index - 1]),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le mie foto ancora in gara, in fila orizzontale.
///
/// In fila e non a tutta larghezza: sono un **cruscotto**, non contenuto da
/// guardare. Quello che conta e' il numero di fiamme accanto a ognuna, e
/// toccandone una si apre la sua challenge per vedere come si sta messi rispetto
/// agli altri.
class _InPlay extends StatelessWidget {
  const _InPlay({required this.entries});

  final List<ChallengeEntry> entries;

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Text(
              'LE TUE IN GARA',
              style: texts.labelSmall?.copyWith(color: palette.textFaint),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '${entries.length}',
              style: texts.labelSmall?.copyWith(color: palette.accent),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: _size + 26,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: entries.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, index) => _InPlayTile(entry: entries[index]),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Divider(color: palette.line),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'DAGLI ALTRI',
          style: texts.labelSmall?.copyWith(color: palette.textFaint),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _InPlayTile extends StatelessWidget {
  const _InPlayTile({required this.entry});

  final ChallengeEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.challengeDetailOf(entry.challengeId)),
      child: SizedBox(
        width: _InPlay._size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _InPlay._size,
              child: MediaFrame(
                url: entry.mediaUrl,
                aspectRatio: 1,
                radius: AppRadius.sm,
                caption: entry.authorName,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 14,
                  color: palette.accent,
                ),
                const SizedBox(width: 2),
                Text(
                  '${entry.votes}',
                  style: context.texts.labelMedium?.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Text('FEED', style: context.texts.displaySmall),
    );
  }
}
