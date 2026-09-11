import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/challenge_card.dart';
import 'package:crasy/features/challenges/presentation/widgets/entry_tile.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Cosa scelgo di guardare qui dentro.
enum FriendActivityView {
  /// Le missioni private che vivono nel gruppo di amici.
  party('PARTY'),

  /// Le gare riservate che ho lanciato io.
  /// Le gare che hanno lanciato loro.
  missions('LANCIATE'),

  /// Le foto con cui sono in gara adesso.
  ///
  /// **I nomi sono corti apposta.** Erano tre e uno si chiamava "DOVE SONO IN
  /// GARA": su un telefono stretto la fila usciva dallo schermo e il numero
  /// dell'ultima finiva tagliato sul bordo. Tre parole corte ci stanno tutte,
  /// e una fila che si legge intera e' una fila che si usa.
  entries('IN GARA');

  const FriendActivityView(this.label);

  final String label;
}

/// Quale delle due si sta guardando.
///
/// Si apre sulle **loro missioni**: e' la cosa in cui uno puo' entrare, e
/// entrare in una gara con un amico e' il motivo per cui questa schermata
/// esiste. Le foto vengono dopo, che si guardano e basta.
final friendActivityViewProvider = StateProvider<FriendActivityView>(
  (ref) => FriendActivityView.party,
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
  @override
  Widget build(BuildContext context) {
    final view = ref.watch(friendActivityViewProvider);
    final missions = ref.watch(friendChallengesProvider);
    final entries = ref.watch(friendEntriesProvider);
    final mine = const <Challenge>[];
    final party = ref.watch(partyChallengesProvider);
    final problema = ref.watch(friendActivityProblemProvider);

    // **Si apre sempre su LE TUE, anche quando e' vuota.**
    //
    // C'era un salto automatico sulla sezione che aveva qualcosa dentro, e
    // sembrava premuroso: in realta' spostava la schermata sotto le dita di chi
    // l'aveva appena aperta, e due aperture di fila non davano mai la stessa
    // schermata. Una scheda che si apre sempre uguale si impara; una che
    // indovina non si impara mai.
    //
    // E vuota qui non vuol dire niente da fare: e' dove sta il comando per
    // lanciare una missione, cioe' la cosa da fare.

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // **In cima solo il marchio, come sulle altre schede.** Questa
              // e' una delle cinque, non una pagina in cui si e' entrati.
              //
              // L'elenco degli amici si apre dal numero sul profilo, e li' c'e'
              // anche il pallino rosso delle richieste che aspettano: qui in
              // cima c'era una seconda porta per lo stesso posto, e due porte
              // per una stanza sola sono una porta di troppo.
              const CrasyHeaderBar(),
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
                      mine: mine.length,
                      party: party.length,
                      missions: missions.length,
                      entries: entries.length,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (problema != null) ...[
                      const InlineBanner(
                        message:
                            'Non riusciamo a leggere cosa stanno facendo i tuoi '
                            'amici. Riprova fra poco: se resta così, non è '
                            'colpa tua.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (view == FriendActivityView.party) ...[
                      const _PartyIntro(),
                      const SizedBox(height: AppSpacing.md),
                      const _LaunchForFriends(quante: 0),
                      const SizedBox(height: AppSpacing.lg),
                      if (party.isEmpty)
                        const EmptyState(
                          title: 'Il party e pronto',
                          message:
                              'Lancia la prima missione per gli amici: la vedete '
                              'solo voi, e puo anche essere gratis.',
                        )
                      else
                        for (final challenge in party)
                          _MissionRow(challenge: challenge),
                    ] else if (view == FriendActivityView.party && mine.isNotEmpty) ...[
                      // **Da qui si lancia una missione per i soli amici.**
                      //
                      // Sta in cima e non in fondo perche' quando questa sezione e'
                      // vuota — cioe' la prima volta di chiunque — il bottone e' tutto
                      // quello che c'e' da fare qui dentro.
                      _LaunchForFriends(quante: mine.length),
                      const SizedBox(height: AppSpacing.lg),
                      if (mine.isEmpty)
                        const EmptyState(
                          title: 'Non ne hai lanciata nessuna',
                          message:
                              'Una missione per i soli amici non compare nella home di '
                              'nessun altro: la vedono loro e basta. E può anche non '
                              'avere un premio.',
                        )
                      else
                        for (final challenge in mine)
                          _MissionRow(challenge: challenge),
                    ] else if (view == FriendActivityView.missions)
                      if (missions.isEmpty)
                        const EmptyState(
                          title: 'Nessuno ha lanciato niente',
                          message:
                              'Quando un amico lancia una missione la trovi qui, e '
                              'puoi partecipare prima di tutti gli altri.',
                        )
                      else
                        for (final challenge in missions)
                          _MissionRow(challenge: challenge)
                    else if (entries.isEmpty)
                      const EmptyState(
                        title: 'Nessuno è in gara adesso',
                        message:
                            'Appena un amico manda uno scatto lo vedi qui, e una tua '
                            'fiamma può essere quella che lo fa vincere.',
                      )
                    else
                      for (final entry in entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                          // Doppio tocco per la fiamma, tocco singolo per aprirla
                          // grande: gli stessi due gesti della home. Qui non si impara
                          // niente di nuovo, cambia solo di chi sono le foto.
                          child: _InGara(entry: entry),
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

/// La scelta fra le due: due parole e il loro numero.
class _Switch extends ConsumerWidget {
  const _Switch({
    required this.mine,
    required this.party,
    required this.missions,
    required this.entries,
  });

  final int mine;
  final int party;
  final int missions;
  final int entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final selected = ref.watch(friendActivityViewProvider);

    int quante(FriendActivityView view) => switch (view) {
      FriendActivityView.party => party,
      FriendActivityView.missions => missions,
      FriendActivityView.entries => entries,
    };

    // Scorre di lato lo stesso, per sicurezza: bastano un telefono piccolo e
    // un carattere ingrandito dalle impostazioni perche' tre parole non ci
    // stiano piu'.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
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
      ),
    );
  }
}

/// Una sola frase: chiarisce che il party e' privato, non un altro feed.
class _PartyIntro extends StatelessWidget {
  const _PartyIntro();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Text(
      'Le vostre missioni private. Qui entrano solo i tuoi amici.',
      style: texts.bodyMedium?.copyWith(color: palette.textSecondary),
    );
  }
}

/// Il bottone per lanciare una missione riservata agli amici.
class _LaunchForFriends extends StatelessWidget {
  const _LaunchForFriends({required this.quante});

  /// Quante ne hai gia' in giro: cambia solo le parole, non il comando.
  final int quante;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.createForFriends),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: palette.accent, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Icon(Icons.add_rounded, color: palette.accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quante == 0
                        ? 'LANCIA UNA MISSIONE PER I TUOI AMICI'
                        : 'LANCIANE UN\'ALTRA',
                    style: texts.labelSmall?.copyWith(color: palette.accent),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  // Le due cose che rendono diversa questa missione, dette
                  // prima di aprire il modulo: chi la vede, e che puo' non
                  // costare niente. Nel modulo si sceglie SOLO AMICI.
                  Text(
                    'La vedono soltanto loro, e il premio può anche essere '
                    'zero. Nel modulo scegli SOLO AMICI.',
                    style: texts.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
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

/// Una foto di un amico, con sopra la gara in cui sta.
///
/// **La foto da sola non basta.** Vedere che un amico e' in gara senza sapere
/// per cosa e per quanto e' un pettegolezzo, non un invito: la domanda che uno
/// si fa guardandola e' "quanto c'e' in palio, e posso entrarci anch'io". Il
/// premio in rosso e il titolo sono le stesse due cose che si leggono per prime
/// su ogni scheda della home — qui in piccolo, perche' la foto resta la cosa
/// grande.
///
/// La riga si tocca e apre la gara. La gara si prende fra quelle gia' caricate:
/// una lettura in piu' per ogni foto, solo per scrivere una riga sopra, sarebbe
/// il modo piu' silenzioso di rimettere in piedi il conto delle letture appena
/// smontato.
class _InGara extends ConsumerWidget {
  const _InGara({required this.entry});

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
            // **Una riga piccola, e la foto grande sotto.**
            //
            // Il premio era grande come sulla scheda della home, e li' e'
            // giusto — la' si decide se entrare in una gara. Qui no: qui si
            // guarda cosa ha combinato un amico, e la cosa da guardare e' la
            // foto. Premio e titolo servono solo a dire *dentro cosa* sta, in
            // una riga sola che si legge in un secondo e non ruba spazio
            // all'immagine.
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
        // Il titolo della gara sta gia' nella riga qui sopra: ripeterlo sotto
        // la foto sarebbe la stessa cosa scritta due volte a due dita di
        // distanza.
        EntryTile(entry: entry, showChallenge: challenge == null),
        // **La riga che separa una missione dall'altra.**
        //
        // Due foto di fila, senza niente in mezzo, si leggono come due foto
        // della stessa gara: la riga del premio della seconda sembra la
        // didascalia della prima. Mezzo pixel di grigio dice "qui finisce" e
        // non dice nient'altro — e' lo stesso segno che divide le gare in home.
        const SizedBox(height: AppSpacing.lg),
        Divider(color: palette.line, height: 0.5, thickness: 0.5),
      ],
    );
  }
}

/// Una missione in elenco: **solo il premio e il titolo**.
///
/// **Senza la foto in testa, ed e' voluto.** Nella home quella foto serve — li'
/// si decide se entrare in una gara, e vedere cosa stanno mandando gli altri e'
/// meta' della decisione. Qui no: qui si scorre l'elenco delle missioni di un
/// gruppo di amici, e una foto grande per ognuna trasforma un elenco di dieci
/// righe in dieci schermate da scorrere. Chi vuole vedere le foto tocca e
/// entra.
///
/// La riga grigia sotto separa una missione dall'altra. Senza, due missioni di
/// fila diventano un blocco solo di testo e il premio della seconda sembra
/// appartenere al titolo della prima.
class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.challengeDetailOf(challenge.id)),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                challenge.prizeLabel,
                style: texts.titleLarge?.copyWith(color: palette.accent),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  challenge.title.toUpperCase(),
                  style: texts.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: palette.textFaint,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          // Quanto manca e quanti sono dentro: le due cose che dicono se vale
          // ancora la pena entrare. Stanno qui e non nel titolo perche' si
          // leggono dopo, non prima.
          ChallengeMetaRow(challenge: challenge),
          const SizedBox(height: AppSpacing.md),
          Divider(color: palette.line, height: 0.5, thickness: 0.5),
        ],
      ),
    );
  }
}
