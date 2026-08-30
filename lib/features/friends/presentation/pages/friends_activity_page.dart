import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
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
class FriendsActivityPage extends ConsumerStatefulWidget {
  const FriendsActivityPage({super.key});

  @override
  ConsumerState<FriendsActivityPage> createState() =>
      _FriendsActivityPageState();
}

class _FriendsActivityPageState extends ConsumerState<FriendsActivityPage> {
  /// Se la scelta l'ha fatta chi guarda.
  ///
  /// Finche' e' falso la pagina si sposta da sola sulla parte che ha qualcosa
  /// dentro. Dopo il primo tocco non lo fa piu': una schermata che cambia da
  /// sola sotto le dita di chi l'ha appena scelta e' una schermata rotta.
  var _scelto = false;

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(friendActivityViewProvider);
    final missions = ref.watch(friendChallengesProvider);
    final entries = ref.watch(friendEntriesProvider);
    final problema = ref.watch(friendActivityProblemProvider);

    // **Si apre su quella che ha qualcosa da mostrare.**
    //
    // Aprire sempre sulle missioni e' giusto quando ce ne sono: e' la cosa in
    // cui uno puo' entrare. Ma se nessun amico ne ha lanciata una, quella
    // scelta mostra una schermata vuota mentre l'altra e' piena di foto — e chi
    // guarda conclude che non funziona, non che ha guardato dalla parte
    // sbagliata. E' successo davvero.
    if (!_scelto &&
        view == FriendActivityView.missions &&
        missions.isEmpty &&
        entries.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _scelto) {
          return;
        }

        ref.read(friendActivityViewProvider.notifier).state =
            FriendActivityView.entries;
      });
    }

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // **In cima il marchio, come sulle altre schede.** Questa e' una
              // delle cinque, non una pagina in cui si e' entrati: una freccia
              // per tornare indietro qui non porterebbe da nessuna parte.
              //
              // A destra la porta per l'elenco vero — chi ti ha chiesto
              // l'amicizia, chi hai gia' — con sopra il numero delle richieste
              // che aspettano. Sono l'unica cosa dell'app che aspetta una
              // risposta da te, e da qualche parte si devono vedere.
              const CrasyHeaderBar(action: _ListButton()),
              Expanded(
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
                    _Switch(
                      missions: missions.length,
                      entries: entries.length,
                      onPicked: () => _scelto = true,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (problema != null) ...[
                      const InlineBanner(
                        message:
                            'Non riusciamo a leggere cosa stanno facendo i tuoi '
                            'amici. Riprova fra poco: se resta cosi\', non e\' '
                            'colpa tua.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
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
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xl,
                            ),
                            child: ChallengeCard(
                              challenge: challenge,
                              onOpen: () => context.push(
                                AppRoutes.challengeDetailOf(challenge.id),
                              ),
                              onParticipate: () => context.push(
                                AppRoutes.participateOf(challenge.id),
                              ),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// La porta per l'elenco degli amici, con le richieste che aspettano.
class _ListButton extends ConsumerWidget {
  const _ListButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final aspettano =
        ref.watch(incomingRequestsProvider).valueOrNull?.length ?? 0;

    return Semantics(
      button: true,
      label: aspettano > 0
          ? 'I tuoi amici, $aspettano richieste'
          : 'I tuoi amici',
      child: IconButton(
        onPressed: () => context.push(AppRoutes.friends),
        tooltip: 'I tuoi amici',
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.format_list_bulleted_rounded,
              size: 20,
              color: palette.textFaint,
            ),
            if (aspettano > 0)
              Positioned(
                top: -5,
                right: -7,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '$aspettano',
                    style: context.texts.labelSmall?.copyWith(
                      color: palette.onAccent,
                      fontSize: 9,
                      height: 1.3,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// La scelta fra le due: due parole e il loro numero.
class _Switch extends ConsumerWidget {
  const _Switch({
    required this.missions,
    required this.entries,
    required this.onPicked,
  });

  final int missions;
  final int entries;

  /// Da qui in poi la pagina non si sposta piu' da sola.
  final VoidCallback onPicked;

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
            onTap: () {
              onPicked();
              ref.read(friendActivityViewProvider.notifier).state = view;
            },
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
