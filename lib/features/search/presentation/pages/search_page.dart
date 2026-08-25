import 'dart:async';
import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/friends/presentation/widgets/friend_avatar.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:crasy/features/search/presentation/providers/search_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// La lente.
///
/// Si cercano **due cose sole**, e stanno nella stessa scatola: una challenge e
/// una persona. Due campi separati, o due schede da scegliere prima di
/// scrivere, chiederebbero a chi cerca di sapere in che categoria sta la cosa
/// che ha in testa — e chi cerca sa solo la parola.
///
/// Le challenge stanno sopra le persone perche' e' quello il motivo per cui
/// questa schermata esiste: le gare aperte diventano tante, e ritrovare *quella
/// del cartello* scorrendo la home e' il momento in cui uno smette di cercarla.
///
/// ## Cosa cambia rispetto a prima
///
/// Per molto tempo qui **non c'e' stata nessuna ricerca di persone**, ed era una
/// scelta: su CRASY si incontra la gente guardando cosa combina — dal nome sotto
/// una foto, dalla riga di chi ha lanciato una gara — non cercandola per nome.
///
/// Adesso c'e', e vale la pena dire cosa comporta: **si trova per nome esatto,
/// dall'inizio**. Non ci sono suggerimenti, non c'e' "forse cercavi", e non si
/// cerca dentro le biografie. Chi sa come si chiama una persona la trova; chi
/// vuole sfogliare gli iscritti no, e quella parte resta chiusa apposta.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  /// Quanto si aspetta prima di cercare davvero.
  ///
  /// Un quarto di secondo e' sotto la soglia in cui si percepisce un'attesa, e
  /// sopra la velocita' con cui si scrive: "marco" diventa **una** ricerca
  /// invece di cinque.
  static const _debounce = Duration(milliseconds: 250);

  final _controller = TextEditingController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (mounted) {
        ref.read(searchQueryProvider.notifier).state = value;
      }
    });

    // Il pulsante per cancellare compare e sparisce con il testo, e quello
    // deve seguire il dito senza aspettare nessuna pausa.
    setState(() {});
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider).trim();
    final filter = ref.watch(searchFilterProvider);
    final live = ref.watch(liveChallengeResultsProvider);
    final ended = ref.watch(endedChallengeResultsProvider);
    final people = ref.watch(peopleResultsProvider);
    final peopleFound = people.valueOrNull ?? const <UserProfile>[];
    final waiting =
        filter.wantsPeople &&
        query.length >= searchMinimumLength &&
        people.isLoading;
    final nothing =
        query.isNotEmpty &&
        !waiting &&
        live.isEmpty &&
        ended.isEmpty &&
        peopleFound.isEmpty;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // **Il marchio alla stessa quota di tutte le altre schede.**
              //
              // Prima qui c'era una `AppBar`, ed era sbagliata due volte: il
              // logotipo non c'era affatto, e la casella partiva piu' in alto
              // di dove sta il marchio nelle altre quattro. Passando da una
              // scheda all'altra si vedeva tutto saltare — una di quelle cose
              // che non si sanno dire ma si notano subito.
              //
              // Adesso l'impalcatura e' identica a quella degli amici e dei
              // vincitori: `CrasyHeader` decide l'altezza, e la casella sta
              // sotto, dove le altre schede mettono la loro prima riga.
              const CrasyHeaderBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _controller,
                      // **Non si prende il fuoco da sola.** Da quando la lente
                      // e' una scheda ci si passa sopra scorrendo, e una
                      // tastiera che salta su a ogni passaggio e' la cosa piu'
                      // fastidiosa che un'app possa fare.
                      autofocus: false,
                      textInputAction: TextInputAction.search,
                      style: context.texts.bodyLarge,
                      onChanged: _onChanged,
                      onSubmitted: (value) {
                        _timer?.cancel();
                        ref.read(searchQueryProvider.notifier).state = value;
                      },
                      // Il filetto sotto e nient'altro: i campi di CRASY sono
                      // tutti cosi', e una casella con il fondo grigio e gli
                      // angoli tondi qui dentro sarebbe l'unica.
                      decoration: InputDecoration(
                        hintText: 'Una challenge, o una persona',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 32,
                        ),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : GestureDetector(
                                onTap: _clear,
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                ),
                              ),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const _Filters(),
              Expanded(
                child: _Results(
                  query: query,
                  live: live,
                  ended: ended,
                  people: peopleFound,
                  waiting: waiting,
                  nothing: nothing,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// I quattro filtri sotto la casella.
///
/// Parole, non pillole colorate: e' la stessa scelta del resto dell'app —
/// niente fondi, niente bordi, niente badge. **Quello scelto e' rosso**, ed e'
/// esattamente il significato che il rosso ha qui dentro: cio' che e' attivo.
///
/// Restano sempre tutti e quattro visibili invece di nascondersi in un menu a
/// tendina: sono quattro parole corte, ci stanno in una riga, e un filtro che
/// bisogna aprire per sapere che esiste non lo usa nessuno.
class _Filters extends ConsumerWidget {
  const _Filters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(searchFilterProvider);
    final palette = context.palette;

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        children: [
          for (final filter in SearchFilter.values) ...[
            GestureDetector(
              onTap: () =>
                  ref.read(searchFilterProvider.notifier).state = filter,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Center(
                  child: Text(
                    filter.label,
                    style: context.texts.labelSmall?.copyWith(
                      color: filter == selected
                          ? palette.accent
                          : palette.textFaint,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Cosa mostrare sotto la casella.
class _Results extends StatelessWidget {
  const _Results({
    required this.query,
    required this.live,
    required this.ended,
    required this.people,
    required this.waiting,
    required this.nothing,
  });

  final String query;
  final List<Challenge> live;
  final List<Challenge> ended;
  final List<UserProfile> people;
  final bool waiting;
  final bool nothing;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
        child: EmptyState(
          title: 'Cosa cerchi',
          message:
              'Il titolo di una challenge, il posto in cui si svolge, o il '
              'nome di chi l\'ha lanciata. Le persone si trovano scrivendo il '
              'loro nome dall\'inizio.',
        ),
      );
    }

    if (nothing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        child: EmptyState(
          title: 'Niente',
          message:
              'Nessuna challenge e nessuno che si chiami "$query". I nomi si '
              'cercano dall\'inizio, non a pezzi.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: [
        if (live.isNotEmpty) ...[
          _SectionLabel(label: 'CHALLENGE APERTE', count: live.length),
          for (final challenge in live) _ChallengeResult(challenge: challenge),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (ended.isNotEmpty) ...[
          _SectionLabel(label: 'CHALLENGE FINITE', count: ended.length),
          for (final challenge in ended) _ChallengeResult(challenge: challenge),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (people.isNotEmpty) ...[
          _SectionLabel(label: 'PERSONE', count: people.length),
          for (final profile in people) _PersonResult(profile: profile),
        ],
        if (waiting && people.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Cerco le persone...',
              style: context.texts.labelSmall?.copyWith(
                color: context.palette.textFaint,
              ),
            ),
          ),
      ],
    );
  }
}

/// L'occhiello di una sezione, con quante cose ci sono sotto.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        '$label · $count',
        style: context.texts.labelSmall?.copyWith(
          color: context.palette.textFaint,
        ),
      ),
    );
  }
}

/// Una challenge fra i risultati.
///
/// Il premio in rosso e per primo: e' la ragione per cui si guarda una gara, e
/// in un elenco e' anche il modo piu' veloce di riconoscere quella giusta.
class _ChallengeResult extends StatelessWidget {
  const _ChallengeResult({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final left = challenge.endsAt.difference(DateTime.now());
    final closed = left.isNegative;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.challengeDetailOf(challenge.id)),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    challenge.title,
                    style: texts.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: challenge.prizeLabel,
                          style: texts.labelMedium?.copyWith(
                            color: palette.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: '  ·  ${challenge.scopeLabel}  ·  ',
                          style: texts.labelMedium?.copyWith(
                            color: palette.textFaint,
                          ),
                        ),
                        TextSpan(
                          // Una gara chiusa si trova lo stesso — e' li' che si
                          // va a rivedere chi ha vinto — ma lo dice subito,
                          // invece di far leggere un tempo che non scorre piu'.
                          text: closed
                              ? 'chiusa'
                              : AppDateUtils.formatTimeLeft(left),
                          style: texts.labelMedium?.copyWith(
                            color: palette.textFaint,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una persona fra i risultati.
class _PersonResult extends StatelessWidget {
  const _PersonResult({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final under = profile.city.isNotEmpty ? profile.city : profile.bio.trim();

    return GestureDetector(
      onTap: () => context.push(AppRoutes.userProfileOf(profile.id)),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            FriendAvatar(
              userId: profile.id,
              username: profile.username,
              size: 44,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('@${profile.username}', style: texts.titleMedium),
                  if (under.isNotEmpty)
                    Text(
                      under,
                      style: texts.labelMedium?.copyWith(
                        color: palette.textFaint,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
