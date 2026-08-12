import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/entry_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Il feed: cosa hanno mandato gli altri, alle challenge di tutti.
///
/// E' la parte folle del prodotto, ed e' l'unica schermata in cui CRASY non ha
/// niente da dire: nessun premio, nessun countdown, nessun comando rosso. Solo
/// foto grandi, un nome sotto, un voto. L'interfaccia si toglie di mezzo.
class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(feedEntriesProvider);

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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  0,
                  AppSpacing.page,
                  AppSpacing.xxl,
                ),
                itemCount: items.length + 1,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.xl),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return items.isEmpty
                        ? const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Title(),
                              EmptyState(
                                title: 'Ancora niente',
                                message:
                                    'Quando qualcuno manda una foto a una '
                                    'challenge la trovi qui.',
                              ),
                            ],
                          )
                        : const _Title();
                  }

                  return EntryTile(entry: items[index - 1]);
                },
              ),
            ),
          ),
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
