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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Cosa scelgo di guardare qui dentro.
///
/// **Tre, e sono tre momenti e non tre categorie.** Erano sei — ricevute,
/// lanciate, party, di amici, chiuse, in gara — e ognuna aveva la sua ragione
/// d'essere presa una per una. Tutte insieme erano una fila che usciva dallo
/// schermo e che costringeva, ogni volta, a ricordarsi in quale delle sei
/// stava la cosa che si cercava. Sei nomi da imparare per usare una schermata
/// sola.
///
/// La domanda vera non e' mai stata "di che tipo e' questa cosa": e' **devo
/// farci qualcosa?**. Una sfida che mi hanno lanciato e una missione del party
/// a cui non ho ancora mandato niente sono la stessa cosa per chi guarda — due
/// cose che aspettano me — anche se dentro il programma sono due oggetti
/// diversi. E una volta mandata la foto, tutte e due diventano la stessa altra
/// cosa: roba che sta andando avanti senza di me.
enum FriendActivityView {
  /// Quello che aspetta me: le sfide ricevute e le missioni a cui non ho
  /// ancora mandato niente.
  todo('DA FARE'),

  /// Quello che e' gia' partito: le sfide che ho lanciato io, le missioni in
  /// cui sono gia' dentro, e le foto con cui gli amici sono in gara adesso.
  running('IN CORSO'),

  /// Com'e' finita.
  done('FINITE');

  const FriendActivityView(this.label);

  final String label;
}

/// Quale delle tre si sta guardando.
///
/// Si apre su **da fare**: e' l'unica scheda in cui c'e' qualcuno che aspetta,
/// e le cose da fare stanno prima di quelle da guardare.
final friendActivityViewProvider = StateProvider<FriendActivityView>(
  (ref) => FriendActivityView.todo,
);

/// **Party**: le sfide fra amici, le missioni del gruppo, le loro foto in gara.
///
/// Sta in una pagina sua e non in fondo all'elenco degli amici, per una ragione
/// di lunghezza: sotto trenta nomi nessuno arriva, e quello che c'e' qui non e'
/// una coda dell'elenco — e' la parte che si guarda, mentre l'elenco e' quella
/// che si consulta.
///
/// **Si divide per momento, non per tipo.** Una sfida che ti ha lanciato Mario
/// e una missione del party a cui non hai ancora mandato niente sono due
/// oggetti diversi nel programma e la stessa identica cosa per chi guarda: due
/// cose che aspettano te. Dividerle per specie voleva dire sei schede e sei
/// nomi da ricordare; dividerle per *devo farci qualcosa* ne vuole tre, e a
/// quelle tre non c'e' niente da imparare.
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
    final bocciate = ref.watch(closedDuelsProvider);
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

    // **Quello che ho gia' fatto**, per nome di missione. E' l'unica cosa che
    // serve a dividere "aspetta me" da "sta andando avanti": una sfida a cui
    // ho gia' risposto e una missione in cui ho gia' mandato uno scatto non
    // sono piu' cose da fare, sono cose in corso.
    final fatte = {
      for (final entry
          in ref.watch(myEntriesProvider).valueOrNull ?? const <ChallengeEntry>[])
        entry.challengeId,
    };

    bool daFare(Challenge challenge) => !fatte.contains(challenge.id);

    final aperte = [...party, ...missions];

    final todo = <Challenge>[
      for (final challenge in received)
        if (daFare(challenge)) challenge,
      for (final challenge in aperte)
        if (daFare(challenge)) challenge,
    ];

    final running = <Challenge>[
      // Le sfide che ho lanciato io stanno sempre qui: non c'e' niente che
      // aspetti me, aspettano l'altro.
      ...sent,
      for (final challenge in received)
        if (!daFare(challenge)) challenge,
      for (final challenge in aperte)
        if (!daFare(challenge)) challenge,
    ];

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
                      todo: todo.length,
                      running: running.length + entries.length,
                      done: chiuse.length + bocciate.length,
                      daRispondere: ref.watch(pendingDuelsCountProvider),
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
                      todo: todo,
                      running: running,
                      sent: sent,
                      closed: chiuse,
                      rejected: bocciate,
                      meId: ref.watch(currentUserIdProvider),
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
  /// **Le righe sono le stesse di prima.** Una sfida si vede come si e' sempre
  /// vista, una missione pure: quello che e' cambiato e' in che mucchio
  /// finiscono, non come si leggono. Cosi' chi usava le sei schede non deve
  /// imparare niente di nuovo — deve solo cercare in tre posti invece che in
  /// sei.
  List<Widget> _sezione({
    required FriendActivityView view,
    required List<Challenge> todo,
    required List<Challenge> running,
    required List<Challenge> sent,
    required List<Challenge> closed,
    required List<Challenge> rejected,
    required String? meId,
    required List<ChallengeEntry> entries,
  }) {
    // Una sfida mirata e una missione aperta a tutti sono due righe diverse, e
    // qui stanno nello stesso elenco: si sceglie guardando la missione, non la
    // scheda in cui ci si trova.
    Widget riga(Challenge challenge) {
      if (!challenge.isDuel) {
        return _MissionRow(challenge: challenge);
      }

      return _DuelRow(
        challenge: challenge,
        received: !sent.any((mia) => mia.id == challenge.id),
      );
    }

    switch (view) {
      case FriendActivityView.todo:
        if (todo.isEmpty) {
          return const [
            EmptyState(
              title: 'Non aspetta niente',
              message:
                  'Quando un amico ti sfida o lancia una missione, la trovi '
                  'qui. Accettare una sfida è una parola data.',
            ),
          ];
        }

        return [for (final challenge in todo) riga(challenge)];

      case FriendActivityView.running:
        if (running.isEmpty && entries.isEmpty) {
          return const [
            EmptyState(
              title: 'Niente in corso',
              message:
                  'Qui finisce quello che è già partito: le sfide che hai '
                  'lanciato, le missioni in cui sei dentro e le foto con cui i '
                  'tuoi amici sono in gara adesso.',
            ),
          ];
        }

        return [
          for (final challenge in running) riga(challenge),
          // **Le foto in fondo, non in cima.** Le missioni sono cose in cui si
          // e' dentro; le foto degli amici sono cose da guardare, e le cose da
          // guardare non passano davanti a quelle in cui si gioca.
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              // Doppio tocco per la fiamma, tocco singolo per aprirla grande:
              // gli stessi due gesti della home. Qui non si impara niente di
              // nuovo, cambia solo di chi sono le foto.
              child: _InGara(entry: entry),
            ),
        ];

      case FriendActivityView.done:
        if (closed.isEmpty && rejected.isEmpty) {
          return const [
            EmptyState(
              title: 'Niente di finito oggi',
              message:
                  'Quando una missione del party o una sfida arriva alla fine, '
                  'qui vedi com\'è andata. Resta un giorno: la figurina di chi '
                  'ha vinto vive sul suo profilo, e quella non scade.',
            ),
          ];
        }

        return [
          // **Righe, non figurine.** Le figurine stanno sul profilo e solo li':
          // sono la bacheca di una persona, quello che ha vinto da quando
          // esiste. Ripeterle qui vorrebbe dire due posti in cui si colleziona
          // la stessa cosa, con questa scheda che per un giorno mostra una
          // figurina e il giorno dopo no. Qui si guarda com'e' finita, e
          // com'e' finita e' una riga — le stesse righe delle altre schede,
          // cosi' non si impara niente di nuovo.
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Finite nelle ultime 24 ore. La figurina di chi ha vinto resta '
              'sul suo profilo.',
              style: context.texts.bodySmall?.copyWith(
                color: context.palette.textFaint,
              ),
            ),
          ),
          for (final challenge in rejected)
            _ClosedRow(challenge: challenge, meId: meId),
          for (final challenge in closed)
            _ClosedRow(challenge: challenge, meId: meId),
        ];
    }
  }
}

/// La fila delle schede: una parola e il suo numero.
///
/// **Il numero di DA FARE si fa rosso quando qualcuno aspetta una parola.** E'
/// l'unico pallino di questa schermata, ed e' il segno che distingue "ci sono
/// tre cose" da "ci sono tre sfide **a cui non hai ancora risposto**": la
/// seconda e' una promessa in sospeso, la prima e' un elenco.
class _Switch extends ConsumerWidget {
  const _Switch({
    required this.todo,
    required this.running,
    required this.done,
    required this.daRispondere,
  });

  final int todo;
  final int running;
  final int done;

  /// Quante sfide ricevute aspettano ancora una risposta.
  final int daRispondere;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final selected = ref.watch(friendActivityViewProvider);

    int quante(FriendActivityView view) => switch (view) {
      FriendActivityView.todo => todo,
      FriendActivityView.running => running,
      FriendActivityView.done => done,
    };

    // Scorre di lato lo stesso: tre parole ci stanno su qualunque telefono, ma
    // con il carattere ingrandito dalle impostazioni nessuna misura e' sicura.
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
                    if (view == FriendActivityView.todo && daRispondere > 0) ...[
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

/// **Una gara finita, in una riga sola: chi, con chi, e com'e' andata.**
///
/// Sta a parte da [_DuelRow] e da [_MissionRow] perche' racconta un'altra cosa.
/// Quelle due servono a **fare** qualcosa — accettare, rifiutare, andare a
/// scattare, giudicare — e per quello hanno il titolo grande e i comandi
/// sotto. Qui non c'e' niente da fare: la gara e' finita, e l'unica domanda e'
/// com'e' finita. Tutto piccolo, tre righe, e si scorre.
///
/// **I due nomi ci sono sempre.** Su una sfida chiusa "hai sfidato @mario" non
/// basta piu': il giorno dopo, in un elenco di roba finita, serve leggere in un
/// colpo chi l'aveva lanciata e a chi era rivolta — senza doverci entrare.
class _ClosedRow extends StatelessWidget {
  const _ClosedRow({required this.challenge, required this.meId});

  final Challenge challenge;
  final String? meId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    final (segno, esito, colore) = _comEFinita(palette);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.challengeDetailOf(challenge.id)),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: palette.surfaceMuted,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chi contro chi. Su una missione di party il destinatario non
              // c'e': c'e' il gruppo, e si scrive cosi'.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      challenge.isDuel
                          ? '@${challenge.createdByUsername} → '
                                '@${challenge.targetUsername}'
                          : 'Party · @${challenge.createdByUsername}',
                      style: texts.labelSmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    challenge.prizeLabel,
                    style: texts.labelSmall?.copyWith(color: palette.accent),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                challenge.title.toUpperCase(),
                // `labelMedium` e non un titolo: in un elenco di cose finite il
                // titolo grande ruba lo spazio alla sola riga che si legge
                // davvero, cioe' quella sotto.
                style: texts.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Text(segno, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      esito,
                      style: texts.labelSmall?.copyWith(color: colore),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// La riga che dice com'e' andata, con il suo segno davanti.
  ///
  /// **La merda e' voluta, e sta solo dove ci va.** Su chi si e' tirato
  /// indietro o non ce l'ha fatta in tempo: e' il fischio del pubblico, ed e'
  /// esattamente quanto deve costare un no — una figuraccia fra amici, niente
  /// di piu'. Su una sfida giudicata non valida no: li' la sfida l'ha fatta, e
  /// il no e' arrivato da chi l'aveva chiesta.
  (String, String, Color) _comEFinita(AppPalette palette) {
    if (challenge.isDuel) {
      final state = challenge.duelStateAt(DateTime.now());
      final chi = challenge.targetUsername;
      final io = meId != null && meId == challenge.targetUserId;

      return switch (state) {
        DuelState.completed => (
          '🏆',
          io ? 'Ce l\'hai fatta: sfida vinta.' : '@$chi ha vinto la sfida.',
          palette.accent,
        ),
        DuelState.notValid => (
          '👎',
          io
              ? 'Non è stata giudicata valida.'
              : 'Hai giudicato la prova non valida.',
          palette.textSecondary,
        ),
        DuelState.declined => (
          '💩',
          io ? 'Hai rifiutato la sfida.' : '@$chi ha rifiutato la sfida.',
          palette.textSecondary,
        ),
        DuelState.expired => (
          '💩',
          io
              ? 'Non ce l\'hai fatta in tempo.'
              : '@$chi non l\'ha fatta in tempo.',
          palette.textSecondary,
        ),
        DuelState.noVerdict => (
          '⏳',
          'Nessun giudizio in tempo: chiusa senza vincitore.',
          palette.textSecondary,
        ),
        _ => ('⏳', 'Chiusa.', palette.textSecondary),
      };
    }

    if (challenge.winnerUsername.isNotEmpty) {
      final io = meId != null && meId == challenge.winnerUserId;

      return (
        '🏆',
        io ? 'L\'hai vinta tu.' : 'Ha vinto @${challenge.winnerUsername}.',
        palette.accent,
      );
    }

    return ('—', 'Finita senza vincitore.', palette.textSecondary);
  }
}
