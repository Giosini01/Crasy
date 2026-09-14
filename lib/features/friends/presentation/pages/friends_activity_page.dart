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
import 'package:crasy/features/challenges/domain/entities/duel_status.dart';
import 'package:crasy/features/challenges/presentation/controllers/duel_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/challenge_card.dart';
import 'package:crasy/features/challenges/presentation/widgets/duel_badge.dart';
import 'package:crasy/features/challenges/presentation/widgets/entry_tile.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/friends/presentation/widgets/friend_avatar.dart';
import 'package:crasy/features/profile/presentation/widgets/trophy_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Cosa scelgo di guardare qui dentro.
///
/// **Cinque, e ognuna risponde a una domanda diversa.** Prima erano tre, e due
/// di quelle tre raccontavano la stessa cosa da due lati — le missioni del
/// gruppo e quelle degli amici. Le sfide mirate hanno reso la divisione
/// evidente: quello che si viene a sapere qui dentro e' *chi sta aspettando
/// me* e *chi sto aspettando io*, e sono due file separate.
enum FriendActivityView {
  /// Le sfide che mi hanno lanciato: la palla e' mia.
  received('RICEVUTE'),

  /// Le sfide che ho lanciato io: la palla e' loro.
  sent('LANCIATE'),

  /// Le missioni private aperte a tutto il gruppo.
  party('PARTY'),

  /// Le gare pubbliche che hanno lanciato loro.
  missions('DI AMICI'),

  /// Quelle finite oggi, con la figurina di chi ha vinto.
  closed('CHIUSE'),

  /// Le foto con cui sono in gara adesso.
  ///
  /// **I nomi sono corti apposta.** Erano tre e uno si chiamava "DOVE SONO IN
  /// GARA": su un telefono stretto la fila usciva dallo schermo e il numero
  /// dell'ultima finiva tagliato sul bordo. Parole corte ci stanno tutte, e una
  /// fila che si legge intera e' una fila che si usa.
  entries('IN GARA');

  const FriendActivityView(this.label);

  final String label;
}

/// Quale delle cinque si sta guardando.
///
/// Si apre sulle **ricevute**: e' l'unica scheda in cui c'e' qualcuno che
/// aspetta una risposta, e le cose da fare stanno prima di quelle da guardare.
final friendActivityViewProvider = StateProvider<FriendActivityView>(
  (ref) => FriendActivityView.received,
);

/// **Party**: le sfide fra amici, le missioni del gruppo, le loro foto in gara.
///
/// Sta in una pagina sua e non in fondo all'elenco degli amici, per una ragione
/// di lunghezza: sotto trenta nomi nessuno arriva, e quello che c'e' qui non e'
/// una coda dell'elenco — e' la parte che si guarda, mentre l'elenco e' quella
/// che si consulta.
///
/// **Le cose non stanno insieme.** Una sfida che ti ha lanciato Mario, una gara
/// aperta da un amico e una foto che ha mandato sono tre inviti diversi: il
/// primo chiede una parola, il secondo chiede di mettersi in gioco, il terzo
/// chiede una fiamma. Mescolati in una lista sola diventano un flusso da
/// scorrere; separati da una scelta restano tre cose che si fanno.
class FriendsActivityPage extends ConsumerStatefulWidget {
  const FriendsActivityPage({super.key});

  @override
  ConsumerState<FriendsActivityPage> createState() =>
      _FriendsActivityPageState();
}

/// Le missioni del party: quelle degli amici e le mie, in un elenco solo.
///
/// Nel party sono la stessa cosa — missioni che vedete soltanto voi — e
/// separarle vorrebbe dire due mezzi elenchi quasi sempre vuoti. Si uniscono
/// **qui e non in due posti**: il numero accanto alla scheda e la lista che ci
/// sta sotto devono uscire dalla stessa riga, o dicono due cose diverse.
List<Challenge> _party(List<Challenge> degliAmici, List<Challenge> mie) {
  return <Challenge>[
    ...degliAmici,
    for (final challenge in mie)
      if (!degliAmici.any((altra) => altra.id == challenge.id)) challenge,
  ]..sort((a, b) => a.endsAt.compareTo(b.endsAt));
}

class _FriendsActivityPageState extends ConsumerState<FriendsActivityPage> {
  @override
  Widget build(BuildContext context) {
    final view = ref.watch(friendActivityViewProvider);
    final missions = ref.watch(friendChallengesProvider);
    final chiuse = ref.watch(closedPartyProvider);
    final entries = ref.watch(friendEntriesProvider);
    // **Le missioni che ho lanciato io, prese dal provider che le sa.**
    //
    // Qui c'era una lista vuota scritta a mano, ed e' il motivo per cui una
    // missione appena lanciata non compariva da nessuna parte: il numero
    // accanto a LANCIATE era zero per costruzione, non per mancanza di dati.
    // Il dato c'era gia' — `myFriendChallengesProvider` — e nessuno lo
    // guardava.
    // **Le mie e quelle degli amici, unite una volta sola.** Il numero accanto
    // alla scheda e la lista che ci sta sotto devono venire dalla stessa
    // riga: sommare le due lunghezze dava un conto piu' alto della lista,
    // perche' una missione mia che e' ancora aperta sta in tutt'e due.
    final party = _party(
      ref.watch(partyChallengesProvider),
      ref.watch(myFriendChallengesProvider),
    );
    final received = ref.watch(receivedDuelsProvider);
    final sent = ref.watch(sentDuelsProvider);
    final problema = ref.watch(friendActivityProblemProvider);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // **In cima solo il marchio, come sulle altre schede.** Questa
              // e' una delle cinque, non una pagina in cui si e' entrati.
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
                      'Sfida i tuoi amici, uno per uno. Chi accetta, ci mette '
                      'la parola.',
                      highlight: 'ci mette la parola',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // **Il comando per sfidare sta in cima, su tutte le
                    // schede.** E' la cosa che questa sezione esiste per far
                    // fare, e un comando che si trova solo dopo aver scelto la
                    // scheda giusta e' un comando che meta' delle persone non
                    // vede mai.
                    const _LaunchDuel(),
                    const SizedBox(height: AppSpacing.md),
                    _Switch(
                      received: received.length,
                      sent: sent.length,
                      party: party.length,
                      missions: missions.length,
                      closed: chiuse.length,
                      entries: entries.length,
                      daFare: ref.watch(pendingDuelsCountProvider),
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
                    ..._sezione(
                      view: view,
                      received: received,
                      sent: sent,
                      party: party,
                      missions: missions,
                      closed: chiuse,
                      entries: entries,
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

  /// Cosa c'e' sotto la fila delle schede.
  ///
  /// Sta in un metodo suo e non dentro il `build` perche' erano cinque rami di
  /// un `if` lungo quanto la schermata, e in mezzo a quelli si era gia'
  /// nascosto un ramo irraggiungibile — la seconda condizione `party` che non
  /// veniva mai valutata, e con lei l'elenco delle missioni lanciate.
  List<Widget> _sezione({
    required FriendActivityView view,
    required List<Challenge> received,
    required List<Challenge> sent,
    required List<Challenge> party,
    required List<Challenge> missions,
    required List<Challenge> closed,
    required List<ChallengeEntry> entries,
  }) {
    switch (view) {
      case FriendActivityView.received:
        if (received.isEmpty) {
          return const [
            EmptyState(
              title: 'Nessuno ti ha ancora sfidato',
              message:
                  'Quando un amico ti lancia una sfida la trovi qui, e puoi '
                  'accettarla o rifiutarla. Accettare è una parola data.',
            ),
          ];
        }

        return [
          for (final challenge in received)
            _DuelRow(challenge: challenge, received: true),
        ];

      case FriendActivityView.sent:
        if (sent.isEmpty) {
          return const [
            EmptyState(
              title: 'Non hai sfidato nessuno',
              message:
                  'Scegli un amico e lanciagli una missione: la vedete solo '
                  'voi due, e non toglie niente alla vostra giornata.',
            ),
          ];
        }

        return [
          for (final challenge in sent)
            _DuelRow(challenge: challenge, received: false),
        ];

      case FriendActivityView.party:
        if (party.isEmpty) {
          return const [
            _PartyIntro(),
            SizedBox(height: AppSpacing.lg),
            EmptyState(
              title: 'Il party è pronto',
              message:
                  'Lancia la prima missione per gli amici: la vedete solo voi, '
                  'e può anche essere gratis.',
            ),
          ];
        }

        return [
          const _PartyIntro(),
          const SizedBox(height: AppSpacing.md),
          for (final challenge in party) _MissionRow(challenge: challenge),
        ];

      case FriendActivityView.missions:
        if (missions.isEmpty) {
          return const [
            EmptyState(
              title: 'Nessuno ha lanciato niente',
              message:
                  'Quando un amico lancia una missione la trovi qui, e puoi '
                  'partecipare prima di tutti gli altri.',
            ),
          ];
        }

        return [
          for (final challenge in missions) _MissionRow(challenge: challenge),
        ];

      case FriendActivityView.closed:
        if (closed.isEmpty) {
          return const [
            EmptyState(
              title: 'Niente di finito oggi',
              message:
                  'Quando una missione del party o una sfida arriva alla fine, '
                  'qui trovi la figurina di chi l\'ha vinta. Resta un giorno, '
                  'poi vive sul profilo di chi se l\'è presa.',
            ),
          ];
        }

        return [
          // **Le stesse figurine del profilo, e non una scheda nuova.** Una
          // gara vinta ha gia' una faccia in questa app — la figurina con la
          // foto e la cifra — e inventarne una seconda per dire la stessa cosa
          // vorrebbe dire due modi di guardare una vittoria, da tenere
          // d'accordo per sempre.
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Finite nelle ultime 24 ore. Poi restano sul profilo di chi ha '
              'vinto.',
              style: context.texts.bodySmall?.copyWith(
                color: context.palette.textFaint,
              ),
            ),
          ),
          TrophyGrid(challenges: closed, kind: TrophyKind.won),
        ];

      case FriendActivityView.entries:
        if (entries.isEmpty) {
          return const [
            EmptyState(
              title: 'Nessuno è in gara adesso',
              message:
                  'Appena un amico manda uno scatto lo vedi qui, e una tua '
                  'fiamma può essere quella che lo fa vincere.',
            ),
          ];
        }

        return [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              // Doppio tocco per la fiamma, tocco singolo per aprirla grande:
              // gli stessi due gesti della home. Qui non si impara niente di
              // nuovo, cambia solo di chi sono le foto.
              child: _InGara(entry: entry),
            ),
        ];
    }
  }
}

/// La fila delle schede: una parola e il suo numero.
///
/// **Il numero delle ricevute si fa rosso quando qualcuno aspetta.** E' l'unico
/// pallino di questa schermata, ed e' il segno che distingue "ci sono tre
/// sfide" da "ci sono tre sfide **a cui non hai risposto**": la seconda e' una
/// cosa da fare, la prima e' un archivio.
class _Switch extends ConsumerWidget {
  const _Switch({
    required this.received,
    required this.sent,
    required this.party,
    required this.missions,
    required this.closed,
    required this.entries,
    required this.daFare,
  });

  final int received;
  final int sent;
  final int party;
  final int missions;
  final int closed;
  final int entries;

  /// Quante sfide ricevute aspettano ancora una risposta.
  final int daFare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final selected = ref.watch(friendActivityViewProvider);

    int quante(FriendActivityView view) => switch (view) {
      FriendActivityView.received => received,
      FriendActivityView.sent => sent,
      FriendActivityView.party => party,
      FriendActivityView.missions => missions,
      FriendActivityView.closed => closed,
      FriendActivityView.entries => entries,
    };

    // Scorre di lato: bastano un telefono piccolo e un carattere ingrandito
    // dalle impostazioni perche' cinque parole non ci stiano piu'.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final view in FriendActivityView.values)
            GestureDetector(
              onTap: () =>
                  ref.read(friendActivityViewProvider.notifier).state = view,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                margin: const EdgeInsets.only(right: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  // **La scheda scelta ha un fondo, le altre no.** Prima si
                  // distinguevano solo per il colore del testo, e su cinque
                  // parole vicine quella differenza si perde: si finiva per
                  // non sapere piu' cosa si stava guardando.
                  color: view == selected
                      ? palette.accentTint
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
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
                    if (view == FriendActivityView.received && daFare > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: palette.accent,
                          shape: BoxShape.circle,
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

/// Il comando per sfidare un amico, e quello per il party.
///
/// **Il secondo e' quello di sempre e non si tocca**: stesse parole, stesso
/// posto, stesso riquadro con il bordo rosso. Sopra ce n'e' uno nuovo per la
/// sfida a una persona sola, che e' una cosa diversa — un nome, non un gruppo.
class _LaunchDuel extends StatelessWidget {
  const _LaunchDuel();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => context.push(AppRoutes.launchDuel),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sports_kabaddi_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SFIDA UN AMICO',
                        style: texts.labelSmall?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Scegli una persona e lanciale una missione. '
                        'Non toglie niente alla vostra giornata.',
                        style: texts.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const _LaunchForFriends(),
      ],
    );
  }
}

/// Il bottone per lanciare una missione riservata a tutti gli amici.
///
/// **Sta com'era.** Testo, posizione nel blocco, riquadro e bordo rosso sono
/// quelli di prima: e' il comando che la gente ha gia' imparato a riconoscere,
/// e il restyling di questa schermata riguarda tutto il resto.
class _LaunchForFriends extends StatelessWidget {
  const _LaunchForFriends();

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
                    'LANCIA UNA MISSIONE PER I TUOI AMICI',
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

/// Una sfida mirata in elenco.
///
/// **E' una scheda e non una riga, ed e' l'unica di questa schermata.** Le
/// missioni sono voci di un elenco che si scorre; una sfida e' una cosa fra
/// due persone, con una faccia, uno stato e — quando tocca a te — due tasti.
/// Un riquadro con dentro tutto questo si guarda una alla volta, che e'
/// esattamente il modo in cui si risponde a una sfida.
class _DuelRow extends ConsumerWidget {
  const _DuelRow({required this.challenge, required this.received});

  final Challenge challenge;

  /// Se l'ho ricevuta io. Cambia di chi si mostra la faccia e cosa si puo'
  /// fare: sulle lanciate non c'e' niente da rispondere, si aspetta.
  final bool received;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final state = challenge.duelStateAt(DateTime.now());
    final controller = ref.watch(duelControllerProvider.notifier);
    final busy = ref.watch(duelControllerProvider).isLoading;

    final chiId = received
        ? challenge.createdByUserId
        : challenge.targetUserId;
    final chiNome = received
        ? challenge.createdByUsername
        : challenge.targetUsername;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.challengeDetailOf(challenge.id)),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: palette.surfaceMuted,
            // Un filo rosso attorno alle sole sfide che aspettano te: senza,
            // una cosa da fare e un archivio hanno lo stesso identico aspetto.
            border: received && state == DuelState.pending
                ? Border.all(color: palette.accent, width: 1.5)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FriendAvatar(userId: chiId, username: chiNome, size: 32),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      received
                          ? '@$chiNome ti ha sfidato'
                          : 'Hai sfidato @$chiNome',
                      style: texts.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  DuelStateChip(state: state),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // **Il premio, anche quando non c'e'.**
              //
              // Su ogni altra scheda dell'app la prima cosa che si legge e'
              // quanto c'e' in palio; qui mancava, e una sfida mirata restava
              // l'unica cosa dell'app di cui non si capiva se ci fossero dei
              // soldi in mezzo prima di accettarla. `GRATIS` e' una risposta
              // quanto una cifra: si accetta sapendo cosa si accetta.
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    challenge.prizeLabel,
                    style: texts.titleSmall?.copyWith(color: palette.accent),
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
                ],
              ),
              if (challenge.brief.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  challenge.brief,
                  style: texts.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              ChallengeMetaRow(challenge: challenge),
              // **Il fischio.** Su una sfida rifiutata — o lasciata scadere —
              // il distintivo dice cos'e' successo, questa riga dice che non e'
              // stata una bella figura. E' tutto quello che costa dire di no, e
              // deve costare qualcosa o la parola data non vale niente.
              if ((state.fischio(mine: received, username: chiNome) ??
                      state.nota(mine: received, username: chiNome))
                  case final fischio?) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      switch (state) {
                        DuelState.judging => Icons.gavel_rounded,
                        DuelState.noVerdict => Icons.help_outline_rounded,
                        _ => Icons.thumb_down_rounded,
                      },
                      size: 13,
                      color: palette.accent,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        fischio,
                        style: texts.labelSmall?.copyWith(
                          color: palette.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              // I due tasti compaiono solo dove servono: sulla sfida che ho
              // ricevuto e a cui non ho ancora risposto. Altrove sarebbero due
              // comandi che non fanno niente.
              if (received && state == DuelState.pending) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: busy
                            ? null
                            : () => controller.accept(challenge),
                        child: const Text('ACCETTO'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => controller.decline(challenge),
                      child: Text(
                        'RIFIUTA',
                        style: texts.labelSmall?.copyWith(
                          color: palette.textFaint,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              // **La via di ritorno.** Un no non e' una porta murata: si puo'
              // tornare indietro, ma passando da qui — si riapre la sfida,
              // l'altro lo viene a sapere, e solo dopo si puo' scattare. Senza
              // questo passaggio dire di no e mandare la foto lo stesso
              // sarebbe la stessa cosa, e il rifiuto non varrebbe niente.
              //
              // Il tempo riparte insieme alla sfida: un rifiuto ferma la sfida
              // ma non l'orologio, e quasi sempre quando uno ci ripensa la
              // scadenza e' gia' passata. Riaprirla scaduta vorrebbe dire un
              // tasto che sembra rotto.
              //
              // **Ma non per sempre: cinque ore.** Un no che si puo' disfare a
              // distanza di giorni non e' un no, e' una risposta rimandata — e
              // chi ha lanciato la sfida resta appeso a tempo indeterminato a
              // una cosa a cui gli hanno gia' detto di no.
              if (received && challenge.canReconsiderAt(DateTime.now())) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: busy ? null : () => controller.accept(challenge),
                  child: const Text('CI HO RIPENSATO'),
                ),
              ],
              // **Il giudizio non si da' da qui.**
              //
              // Il tasto porta alla missione, dove la foto si vede grande: due
              // comandi "vale / non vale" su una riga di elenco, senza la foto
              // sotto gli occhi, sarebbero un giudizio dato a scatola chiusa —
              // ed e' esattamente la cosa che questo passaggio esiste per
              // impedire.
              if (!received && state == DuelState.judging) ...[
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () =>
                      context.push(AppRoutes.challengeDetailOf(challenge.id)),
                  child: const Text('GUARDA E GIUDICA'),
                ),
              ],
              // Accettata e non ancora fatta: il passo successivo e' scattare,
              // e va detto dove si fa.
              if (received && state == DuelState.accepted) ...[
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () =>
                      context.push(AppRoutes.participateOf(challenge.id)),
                  child: const Text('FALLA ADESSO'),
                ),
              ],
            ],
          ),
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
            // foto.
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
class _MissionRow extends ConsumerWidget {
  const _MissionRow({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final isMine =
        challenge.createdByUserId == ref.watch(currentUserIdProvider);

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
          Row(
            children: [
              // **"L'HAI LANCIATA TU", dove e' vero.** Nel party le proprie
              // missioni e quelle degli amici stanno nello stesso elenco: senza
              // questa parola non si distingue la cosa che si e' chiesta da
              // quella a cui si puo' rispondere.
              if (isMine) ...[
                Text(
                  'L\'HAI LANCIATA TU',
                  style: texts.labelSmall?.copyWith(color: palette.accent),
                ),
                Text(
                  '  ·  ',
                  style: texts.labelSmall?.copyWith(color: palette.textFaint),
                ),
              ] else if (challenge.hasCreator) ...[
                Text(
                  '@${challenge.createdByUsername}'.toUpperCase(),
                  style: texts.labelSmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                Text(
                  '  ·  ',
                  style: texts.labelSmall?.copyWith(color: palette.textFaint),
                ),
              ],
              // Quanto manca e quanti sono dentro: le due cose che dicono se
              // vale ancora la pena entrare.
              Flexible(child: ChallengeMetaRow(challenge: challenge)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: palette.line, height: 0.5, thickness: 0.5),
        ],
      ),
    );
  }
}
