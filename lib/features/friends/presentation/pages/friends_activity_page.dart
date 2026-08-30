import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/features/challenges/presentation/widgets/challenge_card.dart';
import 'package:crasy/features/challenges/presentation/widgets/entry_tile.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Cosa scelgo di guardare qui dentro.
enum FriendActivityView {
  /// Le gare che hanno lanciato loro.
  missions('LE LORO MISSIONI'),

  /// Le foto con cui sono in gara adesso.
  entries('DOVE SONO IN GARA');

  const FriendActivityView(this.label);

  final String label;
}

/// Quale delle due si sta guardando.
///
/// Si apre sulle **loro missioni**: e' la cosa in cui uno puo' entrare, e
/// entrare in una gara con un amico e' il motivo per cui questa schermata
/// esiste. Le foto vengono dopo, che si guardano e basta.
final friendActivityViewProvider = StateProvider<FriendActivityView>(
  (ref) => FriendActivityView.missions,
);

/// **Attivita' amici**: le gare che hanno lanciato, le foto con cui sono in
/// gara.
///
/// Sta in una pagina sua e non in fondo all'elenco degli amici, per una ragione
/// di lunghezza: sotto trenta nomi nessuno arriva, e quello che c'e' qui non e'
/// una coda dell'elenco — e' la parte che si guarda, mentre l'elenco e' quella
/// che si consulta.
///
/// **Le due cose non stanno insieme.** Una gara aperta da un amico e una foto
/// che ha mandato sono due inviti diversi: la prima chiede di mettersi in gioco,
/// la seconda chiede una fiamma. Mescolate in una lista sola diventano un flusso
/// da scorrere; separate da una scelta restano due cose che si fanno.
class FriendsActivityPage extends ConsumerWidget {
  const FriendsActivityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(friendActivityViewProvider);
    final missions = ref.watch(friendChallengesProvider);
    final entries = ref.watch(friendEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Attivita\' amici'),
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          children: [
            const HighlightedText(
              'Quello che stanno combinando. Entra nelle loro missioni, o '
              'accendi una fiamma per farli vincere.',
              highlight: 'per farli vincere',
            ),
            const SizedBox(height: AppSpacing.lg),
            _Switch(missions: missions.length, entries: entries.length),
            const SizedBox(height: AppSpacing.lg),
            if (view == FriendActivityView.missions)
              if (missions.isEmpty)
                const EmptyState(
                  title: 'Nessuno ha lanciato niente',
                  message:
                      'Quando un amico lancia una missione la trovi qui, e '
                      'puoi partecipare prima di tutti gli altri.',
                )
              else
                for (final challenge in missions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    child: ChallengeCard(
                      challenge: challenge,
                      onOpen: () => context.push(
                        AppRoutes.challengeDetailOf(challenge.id),
                      ),
                      onParticipate: () =>
                          context.push(AppRoutes.participateOf(challenge.id)),
                    ),
                  )
            else if (entries.isEmpty)
              const EmptyState(
                title: 'Nessuno e\' in gara adesso',
                message:
                    'Appena un amico manda uno scatto lo vedi qui, e una tua '
                    'fiamma puo\' essere quella che lo fa vincere.',
              )
            else
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  // Doppio tocco per la fiamma, tocco singolo per aprirla
                  // grande: gli stessi due gesti della home. Qui non si impara
                  // niente di nuovo, cambia solo di chi sono le foto.
                  child: EntryTile(entry: entry),
                ),
          ],
        ),
      ),
    );
  }
}

/// La scelta fra le due: due parole e il loro numero.
class _Switch extends ConsumerWidget {
  const _Switch({required this.missions, required this.entries});

  final int missions;
  final int entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final selected = ref.watch(friendActivityViewProvider);

    int quante(FriendActivityView view) =>
        view == FriendActivityView.missions ? missions : entries;

    return Row(
      children: [
        for (final view in FriendActivityView.values)
          GestureDetector(
            onTap: () =>
                ref.read(friendActivityViewProvider.notifier).state = view,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: Row(
                children: [
                  Text(
                    view.label,
                    style: texts.labelSmall?.copyWith(
                      color: view == selected
                          ? palette.accent
                          : palette.textFaint,
                    ),
                  ),
                  if (quante(view) > 0) ...[
                    const SizedBox(width: 5),
                    Text(
                      '${quante(view)}',
                      style: texts.labelSmall?.copyWith(
                        color: view == selected
                            ? palette.accent
                            : palette.textFaint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
