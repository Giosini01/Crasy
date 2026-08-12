import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/countdown_text.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Il feed: **le tue foto in gara, e nient'altro**.
///
/// Non e' la bacheca di tutti. Le foto degli altri stanno dentro la loro
/// challenge, che e' il posto in cui hanno un senso — li' si confrontano fra
/// loro e li' si vota. Qui c'e' solo quello che hai mandato tu.
///
/// E' la schermata che risponde all'unica domanda che ti fai riaprendo l'app:
/// *come sta andando la mia?* Con qualche challenge aperta in contemporanea
/// diventa un cruscotto — quante fiamme ha presa ognuna, quanto tempo resta — e
/// toccandone una si va sulla sua gara a vedere contro chi si sta correndo.
class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inPlay = ref.watch(myEntriesInPlayProvider);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.xxl,
            ),
            children: [
              Text('LE TUE', style: context.texts.displaySmall),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                inPlay.isEmpty
                    ? 'Le foto che mandi alle challenge aperte finiscono qui.'
                    : '${inPlay.length} ${inPlay.length == 1 ? 'foto' : 'foto'} '
                          'in gara. Tocca per vedere come sta andando.',
                style: context.texts.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (inPlay.isEmpty)
                const EmptyState(
                  title: 'Non sei in gara',
                  message:
                      'Partecipa a una challenge e la tua foto compare qui, '
                      'con le fiamme che prende e il tempo che resta.',
                )
              else
                for (final item in inPlay) ...[
                  _EntryInPlayTile(item: item),
                  const SizedBox(height: AppSpacing.xl),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Una foto in gara: l'immagine, la challenge, le fiamme, il tempo.
///
/// Tutto il blocco e' toccabile e porta alla challenge. Non c'e' un bottone
/// "apri": la foto **e'** il bottone, ed e' l'unica cosa che uno ha voglia di
/// toccare in questa schermata.
class _EntryInPlayTile extends StatelessWidget {
  const _EntryInPlayTile({required this.item});

  final EntryInPlay item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final entry = item.entry;
    final challenge = item.challenge;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.challengeDetailOf(challenge.id)),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  challenge.title.toUpperCase(),
                  style: texts.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                challenge.prizeLabel,
                style: texts.headlineSmall?.copyWith(color: palette.accent),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          MediaFrame(url: entry.mediaUrl, caption: entry.authorName),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.local_fire_department,
                size: 18,
                color: palette.accent,
              ),
              const SizedBox(width: 3),
              Text(
                '${entry.votes}',
                style: texts.titleMedium?.copyWith(color: palette.accent),
              ),
              Text('  ·  ', style: texts.labelMedium),
              CountdownText(
                target: challenge.endsAt,
                style: texts.labelMedium,
                urgentColor: palette.accent,
              ),
              const Spacer(),
              Text(
                'VEDI LA GARA',
                style: texts.labelSmall?.copyWith(color: palette.textPrimary),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: palette.textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
