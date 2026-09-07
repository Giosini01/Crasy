import 'dart:async';

import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/countdown_text.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/features/challenges/data/reveal_seen_store.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/controllers/challenge_closer.dart';
import 'package:crasy/features/challenges/presentation/controllers/vote_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/challenge_card.dart';
import 'package:crasy/features/challenges/presentation/widgets/entry_tile.dart';
import 'package:crasy/features/challenges/presentation/widgets/fire_tap.dart';
import 'package:crasy/features/challenges/presentation/widgets/fullscreen_media.dart';
import 'package:crasy/features/challenges/presentation/widgets/winner_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// La pagina di una challenge: cosa c'e' in palio, cosa bisogna fare, chi ha
/// gia' mandato qualcosa.
///
/// Il comando per partecipare sta **incollato in fondo allo schermo** e non in
/// coda alla pagina. Le regole e le partecipazioni sono lunghe da scorrere, e
/// un bottone che si raggiunge solo arrivando in fondo e' un bottone che meta'
/// delle persone non vede mai.
class ChallengeDetailPage extends ConsumerWidget {
  const ChallengeDetailPage({required this.challengeId, super.key});

  final String challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeState = ref.watch(challengeProvider(challengeId));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => _leave(context)),
        title: const Text('Challenge'),
      ),
      body: AppBackground(
        child: challengeState.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const EmptyState(
            title: 'Challenge non disponibile',
            message: 'Non riusciamo a caricarla. Riprova tra poco.',
          ),
          data: (challenge) {
            if (challenge == null) {
              return const EmptyState(
                title: 'Challenge non trovata',
                message: 'Questa challenge non esiste più.',
              );
            }

            return _Body(challenge: challenge);
          },
        ),
      ),
      bottomNavigationBar: challengeState.valueOrNull == null
          ? null
          : _BottomAction(challenge: challengeState.value!),
    );
  }

  /// Chi arriva qui da una notifica o da un link non ha una pagina precedente:
  /// senza questo controllo il tasto indietro non farebbe niente e lascerebbe
  /// la persona bloccata sul dettaglio.
  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.challenges);
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final entries = ref.watch(challengeEntriesProvider(challenge.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                challenge.prizeLabel,
                style: texts.displayLarge?.copyWith(color: palette.accent),
              ),
            ),
            Text(
              challenge.scopeLabel,
              style: texts.labelSmall?.copyWith(color: palette.textFaint),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(challenge.title.toUpperCase(), style: texts.displaySmall),
        // Qui dentro **non** c'e' la foto in testa, e fuori si': nella home
        // serve a far capire di che gara si tratta, ma dopo aver aperto la
        // challenge sarebbe la stessa immagine due volte di fila, e per giunta
        // sopra la griglia dove quella foto compare di nuovo. Chi entra qui
        // vuole scorrere e vederle tutte.
        const SizedBox(height: AppSpacing.lg),
        Text(challenge.brief, style: texts.bodyLarge),
        if (challenge.hasCreator) ...[
          const SizedBox(height: AppSpacing.md),
          ChallengeAuthor(challenge: challenge),
        ],
        const SizedBox(height: AppSpacing.lg),
        _TimeBlock(challenge: challenge),
        // **Le regole del gioco, scritte.**
        //
        // Sono tre cose che non si indovinano guardando la schermata — i numeri
        // coperti sembrano un difetto, l'ordine mescolato sembra un capriccio,
        // il tetto sembra una porta chiusa in faccia — e non dette diventano
        // esattamente questo: tre difetti. Dette, sono il gioco.
        if (!challenge.hasEndedAt(DateTime.now())) ...[
          const SizedBox(height: AppSpacing.lg),
          _GameRules(challenge: challenge),
        ],
        if (challenge.rules.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            'REGOLE',
            style: texts.labelSmall?.copyWith(color: palette.textFaint),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final rule in challenge.rules)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('—  ', style: texts.bodyMedium),
                  Expanded(child: Text(rule, style: texts.bodyMedium)),
                ],
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(
          challenge.hasEndedAt(DateTime.now())
              ? 'IL VINCITORE'
              : 'PARTECIPAZIONI',
          style: texts.labelSmall?.copyWith(color: palette.textFaint),
        ),
        const SizedBox(height: AppSpacing.md),
        entries.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => Text(
            'Non riusciamo a caricare le partecipazioni.',
            style: texts.bodyMedium,
          ),
          data: (items) => _Entries(challenge: challenge, entries: items),
        ),
      ],
    );
  }
}

/// Il tempo e i partecipanti, grandi.
///
/// Nella home la stessa informazione sta su una riga di servizio; qui e' una
/// delle cose per cui uno ha aperto la pagina, e prende il corpo che merita.
class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final ended = challenge.hasEndedAt(DateTime.now());

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ended ? 'CONCLUSA' : 'TEMPO RIMASTO',
                style: texts.labelSmall?.copyWith(color: palette.textFaint),
              ),
              const SizedBox(height: AppSpacing.xxs),
              if (ended)
                Text('—', style: texts.headlineSmall)
              else
                CountdownText(
                  target: challenge.endsAt,
                  style: texts.headlineSmall,
                  urgentColor: palette.accent,
                ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PARTECIPANTI',
                style: texts.labelSmall?.copyWith(color: palette.textFaint),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${challenge.participantsCount}',
                style: texts.headlineSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Le partecipazioni, e la foto che qualcuno e' venuto a vedere.
///
/// Se l'indirizzo porta con se' `?foto=`, quella foto si apre grande da sola,
/// una volta sola. E' il link che gira fuori da CRASY: chi lo riceve deve
/// trovarsi davanti **la cosa di cui gli hanno parlato**, non una pagina in cui
/// cercarla. La gara resta sotto, a un tocco di distanza.
class _Entries extends ConsumerStatefulWidget {
  const _Entries({required this.challenge, required this.entries});

  final Challenge challenge;
  final List<ChallengeEntry> entries;

  @override
  ConsumerState<_Entries> createState() => _EntriesState();
}

class _EntriesState extends ConsumerState<_Entries> {
  bool _opened = false;

  /// Se abbiamo gia' guardato se c'era una proclamazione da mostrare.
  ///
  /// Una volta sola per visita, e non una per ricostruzione: qui si ricostruisce
  /// a ogni fiamma che qualcuno accende da qualunque parte del mondo.
  bool _revealChiesto = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _openSharedEntry();
    _closeIfOver();
    _proclamaSeServe();
  }

  @override
  void didUpdateWidget(_Entries oldWidget) {
    super.didUpdateWidget(oldWidget);

    // **Anche qui, e non solo all'apertura.** La gara arriva spesso ancora
    // aperta e viene chiusa un istante dopo — dal server o da noi stessi in
    // `_closeIfOver`. Il vincitore compare in quel momento, con un widget
    // nuovo: guardando soltanto all'ingresso, il rullo non partirebbe mai
    // proprio nel caso piu' comune, cioe' chi arriva appena scaduto il tempo.
    _proclamaSeServe();
  }

  /// Apre il rullo di tamburi, se c'e' qualcosa da proclamare a questa persona.
  ///
  /// **Le condizioni sono tutte necessarie, e ognuna toglie un modo di fare una
  /// figuraccia.** Una gara senza vincitore non ha niente da dire; chi non era
  /// in gara non ha nessun motivo di prendersi cinque secondi di animazione
  /// addosso; e chi l'ha gia' vista non deve rivederla ogni volta che riapre la
  /// missione per guardarsi la classifica.
  void _proclamaSeServe() {
    if (_revealChiesto) {
      return;
    }

    final challenge = widget.challenge;
    final vincitrice = challenge.winnerEntryId ?? '';

    if (vincitrice.isEmpty || !challenge.isOver) {
      return;
    }

    final io = ref.read(currentUserIdProvider);
    final store = ref.read(revealSeenStoreProvider);

    if (io == null || io.isEmpty || store == null) {
      return;
    }

    // **Chi ha partecipato, piu' chi ha messo i soldi.** Sono le due persone
    // per cui quel risultato e' una notizia; per tutti gli altri e' una
    // classifica.
    final dentro =
        widget.entries.any((entry) => entry.userId == io) ||
        challenge.createdByUserId == io;

    if (!dentro) {
      return;
    }

    final winner = widget.entries
        .where((entry) => entry.id == vincitrice)
        .firstOrNull;

    if (winner == null) {
      return;
    }

    _revealChiesto = true;

    unawaited(_proclama(store: store, io: io, winner: winner));
  }

  Future<void> _proclama({
    required RevealSeenStore store,
    required String io,
    required ChallengeEntry winner,
  }) async {
    final challenge = widget.challenge;

    if (await store.seen(userId: io, challengeId: challenge.id)) {
      return;
    }

    if (!mounted) {
      return;
    }

    // **Si segna prima, non dopo.** Chi chiude l'app a meta' l'ha visto
    // abbastanza da sapere com'e' andata; segnandolo alla fine, un'uscita a
    // meta' lo farebbe ripartire da capo alla riapertura, e cosi' ogni volta.
    unawaited(store.markSeen(userId: io, challengeId: challenge.id));

    await WinnerReveal.show(
      context,
      challenge: challenge,
      entries: widget.entries,
      winner: winner,
      mine: winner.userId == io,
    );
  }

  /// Chiude la gara se e' scaduta e nessuno l'ha ancora proclamata.
  ///
  /// Lo dovrebbe fare il server ogni cinque minuti, e il codice c'e' gia': gli
  /// manca il piano a pagamento. Finche' non c'e', a chiudere e' il primo che
  /// apre la gara dopo la scadenza — vedi `ChallengeCloser`, che spiega perche'
  /// questa strada si spegne da sola il giorno in cui girano dei soldi veri.
  void _closeIfOver() {
    final challenge = widget.challenge;
    final entries = widget.entries;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Qui l'elenco arriva dal ramo `data` dello stream, quindi e' per
        // definizione caricato.
        ref
            .read(challengeCloserProvider)
            .closeIfNeeded(challenge, entries, entriesLoaded: true);
      }
    });
  }

  /// Apre la foto indicata dall'indirizzo.
  ///
  /// Una volta sola, e il segno di averlo fatto e' un campo di stato: le
  /// partecipazioni arrivano da uno stream e questo widget si ricostruisce a
  /// ogni fiamma che qualcuno accende. Senza il segno, la foto si riaprirebbe
  /// da sola sopra a quella che si sta guardando.
  void _openSharedEntry() {
    if (_opened) {
      return;
    }

    final wanted = GoRouterState.of(context).uri.queryParameters['foto'];

    if (wanted == null || wanted.isEmpty || widget.entries.isEmpty) {
      return;
    }

    final entry = widget.entries.where((item) => item.id == wanted).firstOrNull;

    if (entry == null) {
      return;
    }

    _opened = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FullscreenMedia.open(context, entries: widget.entries, entry: entry);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final entries = widget.entries;

    if (entries.isEmpty) {
      return Text(
        'Ancora nessuno. Puoi essere il primo.',
        style: context.texts.bodyMedium,
      );
    }

    // A challenge chiusa vince una foto sola, e va vista grande: mostrarla
    // nella stessa griglia da due colonne delle altre significherebbe non
    // proclamare nessuno.
    final winnerId = challenge.winnerEntryId;

    if (winnerId != null) {
      final winner = entries.where((entry) => entry.id == winnerId).firstOrNull;

      if (winner != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // **Perche' e' finita cosi'.**
            //
            // Un vincitore che compare senza spiegazioni lascia chi ha lanciato
            // la gara a chiedersi perche' non gli sia stato chiesto niente. La
            // risposta e' una sola riga, e cambia tutto: o ha scelto lui, o ha
            // lasciato scadere le ventiquattro ore e ha deciso il conteggio
            // delle fiamme.
            _Verdict(challenge: challenge),
            EntryTile(entry: winner, showChallenge: false),
          ],
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Le fiamme rimaste stanno **sopra le foto**, non sotto: si guardano
        // prima di cominciare a spenderle, non dopo averle finite.
        if (!challenge.hasEndedAt(DateTime.now())) ...[
          _FireBudget(challengeId: challenge.id),
          const SizedBox(height: AppSpacing.md),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.xs,
            mainAxisSpacing: AppSpacing.lg,
            // Il quadrato della foto piu' la riga sotto. Fissato invece che
            // calcolato da un rapporto, cosi' la riga non si schiaccia quando la
            // colonna si stringe.
            mainAxisExtent: 210,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) =>
              _EntryGridTile(entry: entries[index], entries: entries),
        ),
      ],
    );
  }
}

class _EntryGridTile extends ConsumerWidget {
  const _EntryGridTile({required this.entry, required this.entries});

  final ChallengeEntry entry;

  /// Tutte le partecipazioni della gara, per poter scorrere da questa alle
  /// altre una volta aperta a schermo intero.
  final List<ChallengeEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FireTap(
          entry: entry,
          // Un tocco solo apre la foto grande; il doppio tocco resta la
          // fiamma. Nel quadrato di due dita della griglia non si vede niente:
          // e' un indice, non il contenuto.
          onTap: () =>
              FullscreenMedia.open(context, entries: entries, entry: entry),
          child: MediaFrame(
            // **Qui la miniatura ci sta**: e' una griglia a due colonne, ogni
            // quadrato vale mezzo schermo, e settecentoventi punti lo coprono
            // con margine. L'originale si scarica toccandola.
            url: entry.previewUrl,
            video: entry.isVideo,
            // **Ferma sul primo fotogramma.** Questa griglia costruisce tutti
            // i riquadri insieme, anche quelli sotto lo schermo: con i video
            // accesi erano venti file scaricati in ciclo per venti
            // francobolli, e il video che uno stava davvero guardando aspettava
            // il suo turno dietro gli altri diciannove. Si tocca e si apre
            // grande.
            autoplay: false,
            aspectRatio: 1,
            caption: entry.authorName,
            mine: entry.userId == ref.watch(currentUserIdProvider),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Row(
          children: [
            Expanded(
              // Anche qui il nome apre il profilo: chi vede una foto che gli
              // piace deve poter arrivare a chi l'ha fatta da dove si trova,
              // senza tornare indietro a cercarla altrove.
              child: GestureDetector(
                onTap: () =>
                    context.push(AppRoutes.userProfileOf(entry.userId)),
                child: Text(
                  '@${entry.authorName}',
                  style: context.texts.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            VoteButton(entry: entry),
          ],
        ),
      ],
    );
  }
}

/// Il comando in fondo, sempre visibile.
class _BottomAction extends ConsumerWidget {
  const _BottomAction({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final ended = challenge.hasEndedAt(DateTime.now());
    final myEntry = ref.watch(myEntryForChallengeProvider(challenge.id));
    final isMine = ref.watch(isMyChallengeProvider(challenge.id));

    return Container(
      color: palette.background,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.sm + MediaQuery.paddingOf(context).bottom,
      ),
      child: switch ((ended, isMine, myEntry)) {
        (true, _, _) => ChallengeMetaRow(challenge: challenge),
        (false, true, _) => Row(
          children: [
            const Expanded(child: OwnChallengeNote()),
            // **Si cancella solo finche' e' vuota.** Dalla prima foto in poi la
            // gara non e' piu' solo di chi l'ha lanciata: chi ha partecipato ha
            // speso una delle sue cinque del giorno, e toglierla da sotto
            // vorrebbe dire prendergliela senza dargli niente in cambio.
            if (challenge.participantsCount == 0)
              _DeleteChallenge(challenge: challenge),
          ],
        ),
        (false, false, final entry?) => Row(
          children: [
            const AlreadyJoinedNote(),
            const Spacer(),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 18,
                  color: palette.accent,
                ),
                const SizedBox(width: 4),
                Text('${entry.votes}', style: context.texts.titleMedium),
              ],
            ),
          ],
        ),
        (false, false, null) => CrasyButton(
          label: 'Partecipa',
          onPressed: () => context.push(AppRoutes.participateOf(challenge.id)),
        ),
      },
    );
  }
}

/// Chi ha lanciato la gara sceglie, e questa e' la riga che glielo dice.
///
/// **Il verdetto non e' del conteggio, e' suo.** Le fiamme restano sotto ogni
/// foto — servono a capire il polso di chi guarda, e a decidere in automatico
/// se lui non decide — ma chi ha messo i soldi sta comprando un'opera, e la
/// piu' votata non e' sempre quella che aveva chiesto.
///
/// Agli altri la stessa riga dice due cose: che si sta aspettando una persona
/// precisa, e **entro quando**. Una gara finita che non dice chi ha vinto ne'
/// perche' e' il modo piu' rapido di far pensare che i soldi non arriveranno.
class _FireBudget extends ConsumerWidget {
  const _FireBudget({required this.challengeId});

  final String challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final left = ref.watch(firesLeftProvider(challengeId));
    final finite = left == 0;

    return Row(
      children: [
        for (var i = 0; i < Challenge.firesPerChallenge; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Icon(
              i < left
                  ? Icons.local_fire_department
                  : Icons.local_fire_department_outlined,
              size: 16,
              color: i < left ? palette.accent : palette.textFaint,
            ),
          ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          finite ? 'FINITE QUI' : 'TE NE RESTANO $left',
          style: texts.labelSmall?.copyWith(
            color: finite ? palette.textFaint : palette.accent,
          ),
        ),
      ],
    );
  }
}

/// Come e' stato deciso il premio, in una riga.
///
/// E' sempre lo stesso modo — piu' fiamme — ma scriverlo serve lo stesso: chi
/// arriva su una gara chiusa vede una foto sola, e nessuna spiegazione di
/// perche' proprio quella.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 16,
            color: palette.textFaint,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Ha vinto la foto con più fiamme alla chiusura.',
              style: context.texts.bodySmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cancella la gara, finche' non ci ha partecipato nessuno.
///
/// **Serve a un caso solo, ed e' quello che capita davvero**: il premio
/// sbagliato, il titolo con l'errore di battitura, la consegna che rileggendola
/// non si capisce. Senza, quella gara resta in home fino alla scadenza e chi
/// l'ha scritta la guarda senza poterci fare niente — e la seconda, quella
/// giusta, si somma alla prima invece di sostituirla.
class _DeleteChallenge extends ConsumerStatefulWidget {
  const _DeleteChallenge({required this.challenge});

  final Challenge challenge;

  @override
  ConsumerState<_DeleteChallenge> createState() => _DeleteChallengeState();
}

class _DeleteChallengeState extends ConsumerState<_DeleteChallenge> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _working ? null : _ask,
      child: Text(
        'Cancella',
        style: context.texts.bodySmall?.copyWith(color: context.palette.accent),
      ),
    );
  }

  Future<void> _ask() async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancellare la missione?'),
        content: const Text(
          'Non ha ancora partecipato nessuno, quindi si può. Sparisce dalla '
          'home e non si recupera.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'CANCELLA',
              style: TextStyle(color: context.palette.accent),
            ),
          ),
        ],
      ),
    );

    if (conferma != true || !mounted) {
      return;
    }

    setState(() => _working = true);

    try {
      await ref
          .read(challengeRepositoryProvider)
          .deleteChallenge(widget.challenge.id);
    } on Object {
      // **Quasi sempre vuol dire che qualcuno ha appena partecipato.** Fra il
      // momento in cui il comando e' comparso e quello in cui e' stato toccato
      // puo' essere arrivata una foto, e da li' in poi le regole non lasciano
      // piu' cancellare — giustamente.
      if (mounted) {
        setState(() => _working = false);
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Non si può più: qualcuno ha appena partecipato.'),
          ),
        );
      }

      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

/// Le tre regole che rendono la gara una gara.
class _GameRules extends StatelessWidget {
  const _GameRules({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final posti = challenge.spotsLeft;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COME SI VINCE',
            style: texts.labelSmall?.copyWith(color: palette.accent),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Rule(
            icon: Icons.visibility_off_outlined,
            text: 'Le fiamme sono nascoste.',
            detail:
                'Nessuno sa come sta andando, nemmeno tu. Si scopre tutto alla '
                'fine, insieme.',
          ),
          _Rule(
            icon: Icons.shuffle_rounded,
            text: 'Le foto sono in ordine sparso.',
            detail:
                'Ognuno le vede in un ordine diverso: chi manda per primo non '
                'ha nessun vantaggio.',
          ),
          if (posti != null)
            _Rule(
              icon: Icons.people_outline_rounded,
              text: posti == 0
                  ? 'Posti esauriti.'
                  : 'Restano $posti posti su ${challenge.maxParticipants}.',
              detail: posti == 0
                  ? 'Nessuno può più entrare in questa gara.'
                  : 'Quando finiscono non si entra più. Una possibilità su '
                        '${challenge.maxParticipants}.',
              accent: true,
            )
          else
            _Rule(
              icon: Icons.people_outline_rounded,
              text: 'Aperta a chiunque.',
              detail: 'Nessun tetto ai partecipanti.',
            ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({
    required this.icon,
    required this.text,
    required this.detail,
    this.accent = false,
  });

  final IconData icon;
  final String text;
  final String detail;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 16,
              color: accent ? palette.accent : palette.textFaint,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: texts.titleSmall?.copyWith(
                    color: accent ? palette.accent : palette.textPrimary,
                  ),
                ),
                Text(
                  detail,
                  style: texts.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
