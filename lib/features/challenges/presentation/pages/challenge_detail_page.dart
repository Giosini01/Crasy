import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/services/share/share_challenge.dart';
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
import 'package:crasy/features/challenges/domain/entities/duel_status.dart';
import 'package:crasy/features/challenges/presentation/controllers/challenge_closer.dart';
import 'package:crasy/features/challenges/presentation/controllers/duel_controller.dart';
import 'package:crasy/features/challenges/presentation/controllers/vote_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/archive_badge.dart';
import 'package:crasy/features/challenges/presentation/widgets/challenge_card.dart';
import 'package:crasy/features/challenges/presentation/widgets/duel_badge.dart';
import 'package:crasy/features/challenges/presentation/widgets/entry_tile.dart';
import 'package:crasy/features/challenges/presentation/widgets/fire_tap.dart';
import 'package:crasy/features/challenges/presentation/widgets/fullscreen_media.dart';
import 'package:crasy/features/challenges/presentation/widgets/winner_reveal.dart';
import 'package:crasy/features/friends/presentation/widgets/friend_avatar.dart';
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
        actions: [
          // **Condividere una missione non e' partecipare.**
          //
          // Sta in cima accanto al titolo e non fra i comandi in fondo, dove
          // c'e' "Partecipa": quello e' il posto delle cose che cambiano lo
          // stato della gara, e questa non ne cambia nessuno — non la
          // completa, non consuma la foto del giorno, non muove contatori.
          // Vedi `ShareChallenge`, che di proposito non ha in mano nessun
          // repository.
          if (challengeState.valueOrNull != null)
            _ShareButton(challenge: challengeState.value!),
        ],
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

            // **La sassaiola sta qui, sopra tutta la pagina.**
            //
            // Stava attaccata alla foto profilo, in fondo alla lista, ed e' il
            // motivo per cui non la vedeva nessuno: la pagina costruisce tutti
            // i suoi pezzi subito, quindi l'animazione partiva e finiva mentre
            // quel pezzo era ancora sotto il bordo dello schermo. Chi scorreva
            // fin laggiu' arrivava sempre a cose fatte.
            //
            // La chiave porta dentro l'identificativo della missione: cosi'
            // passando da una sfida rifiutata a un'altra la sassaiola
            // ricomincia, invece di restare quella di prima gia' finita.
            final rifiutata = challenge.isDuel && _fischiata(challenge);

            return Stack(
              children: [
                _Body(challenge: challenge),
                if (rifiutata) _PoopStorm(key: ValueKey(challenge.id)),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: challengeState.valueOrNull == null
          ? null
          : _BottomAction(challenge: challengeState.value!),
    );
  }

  /// Se questa sfida merita la sassaiola: ha detto di no, o ha lasciato finire
  /// il tempo senza fare niente.
  ///
  /// Le sfide bocciate non entrano qui dentro, e non e' una dimenticanza: li' la
  /// sfida l'ha fatta, e il no e' arrivato da chi l'aveva chiesta. Tirargli la
  /// cacca sarebbe fischiare la persona sbagliata.
  static bool _fischiata(Challenge challenge) {
    final state = challenge.duelStateAt(DateTime.now());

    return state == DuelState.declined || state == DuelState.expired;
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

/// Il tasto che manda la missione fuori da CRASY.
///
/// Un `Builder` attorno: il pannello di condivisione di iPad ha bisogno della
/// posizione sullo schermo dell'oggetto che lo apre, e quella si legge solo dal
/// contesto del tasto — non da quello della pagina.
class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Condividi la missione',
      icon: const Icon(Icons.ios_share_rounded),
      onPressed: () => ShareChallenge.send(
        context,
        challengeId: challenge.id,
        challengeTitle: challenge.title,
        prizeCents: challenge.prizeCents,
        brief: challenge.brief,
        ended: challenge.hasEndedAt(DateTime.now()),
      ),
    );
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
            // Come sulla scheda: al posto di GLOBAL, che c'era sempre e non
            // diceva niente, resta solo il marchio dell'archivio — e sulle
            // istantanee non c'e' niente.
            if (challenge.source.isArchive)
              ArchiveBadge(challenge: challenge, compact: true),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(challenge.title.toUpperCase(), style: texts.displaySmall),
        // **Chi ha sfidato chi, e a che punto siamo.** Su una sfida mirata e'
        // la prima cosa da sapere: senza, questa e' una missione con un premio
        // a zero e un partecipante solo, cioe' una gara che non si capisce.
        if (challenge.isDuel) ...[
          const SizedBox(height: AppSpacing.md),
          DuelBadge(challenge: challenge),
        ],
        // Qui dentro **non** c'e' la foto in testa, e fuori si': nella home
        // serve a far capire di che gara si tratta, ma dopo aver aperto la
        // challenge sarebbe la stessa immagine due volte di fila, e per giunta
        // sopra la griglia dove quella foto compare di nuovo. Chi entra qui
        // vuole scorrere e vederle tutte.
        // **Sotto il titolo, sopra la consegna.** E' la prima cosa che
        // cambia il senso di tutto quello che viene dopo: chi legge la consegna
        // sapendo gia' che si pesca dall'archivio la legge in un altro modo.
        if (challenge.source.isArchive) ...[
          const SizedBox(height: AppSpacing.md),
          // **Il marchio sta gia' in cima**, accanto al premio: qui resta
          // solo la riga che spiega cosa vuol dire, perche' "ARCHIVIO" da solo
          // non dice a nessuno che la fotocamera non si aprira'.
          Text(challenge.source.spiegazione, style: texts.bodySmall),
        ],
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
        //
        // **Su una sfida mirata sono regole diverse**, e quelle normali sono
        // perfino false: "restano 1 posti su 1" su una sfida a una persona
        // sola non dice niente a nessuno, e "vince chi ha piu' fiamme" e'
        // proprio il contrario di come funziona qui.
        if (challenge.isDuel) ...[
          const SizedBox(height: AppSpacing.lg),
          _DuelRules(gratis: challenge.prizeCents == 0),
        ] else if (!challenge.hasEndedAt(DateTime.now())) ...[
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
          // Su una sfida mirata non ci sono "partecipazioni": c'e' una persona
          // sola, e quello che si viene a vedere qui e' com'e' andata fra due.
          challenge.isDuel
              ? 'LA SFIDA'
              : challenge.hasEndedAt(DateTime.now())
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
      // **Su una sfida mirata "ancora nessuno" e' una bugia.**
      //
      // Quella riga vuol dire "puoi essere il primo", e su una sfida lanciata a
      // una persona sola non e' vero per nessuno: chi guarda o e' quello che ha
      // sfidato — e non puo' partecipare — o e' quello sfidato, che ha gia'
      // detto di no. Il risultato era una schermata vuota che non diceva la
      // sola cosa che c'era da dire, cioe' com'e' finita.
      if (challenge.isDuel) {
        return _DuelOutcome(challenge: challenge);
      }

      return Text(
        'Ancora nessuno. Puoi essere il primo.',
        style: context.texts.bodyMedium,
      );
    }

    // **La foto c'e', e aspetta un giudizio.** Su una sfida uno contro uno la
    // foto da sola non chiude niente: la mostra grande, e sotto ci mette i due
    // comandi — ma solo a chi la sfida l'ha lanciata.
    if (challenge.isDuel && !challenge.duelVerdict.isApproved) {
      return _DuelJudgement(challenge: challenge, entry: entries.first);
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
    final meId = ref.watch(currentUserIdProvider);

    // **Chi e' stato sfidato ha un comando diverso da tutti gli altri.**
    //
    // Prima di rispondere non c'e' niente da fotografare: davanti a una sfida
    // si dice si' o no, e "Partecipa" al posto di quei due tasti farebbe
    // saltare esattamente il passaggio che rende la sfida una parola data.
    if (challenge.isDuel &&
        meId != null &&
        meId == challenge.targetUserId &&
        !ended &&
        myEntry == null &&
        challenge.duelStatus.isPending) {
      return Container(
        color: palette.background,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.sm + MediaQuery.paddingOf(context).bottom,
        ),
        child: _DuelAnswer(challenge: challenge),
      );
    }

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

/// I due tasti con cui si risponde a una sfida: **accetta** o **rifiuta**.
///
/// L'accetta e' pieno e rosso, il rifiuta e' una parola grigia accanto. Non e'
/// una gerarchia grafica a caso: qui si sta chiedendo a qualcuno di prendere
/// un impegno, e il tasto grosso deve essere quello che lo fa prendere. Dire
/// di no resta a un tocco di distanza — nasconderlo o renderlo scomodo
/// significherebbe raccogliere dei si' che non valgono niente.
class _DuelAnswer extends ConsumerWidget {
  const _DuelAnswer({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final controller = ref.watch(duelControllerProvider.notifier);
    final busy = ref.watch(duelControllerProvider).isLoading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '@${challenge.createdByUsername} ti ha sfidato. '
          'Se accetti, la porti a termine.',
          style: texts.bodySmall?.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: CrasyButton(
                label: 'Accetto',
                onPressed: busy ? null : () => controller.accept(challenge),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            TextButton(
              onPressed: busy ? null : () => controller.decline(challenge),
              child: Text(
                'RIFIUTA',
                style: texts.labelSmall?.copyWith(color: palette.textFaint),
              ),
            ),
          ],
        ),
      ],
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
            challenge.isDuel
                ? Icons.emoji_events_rounded
                : Icons.local_fire_department_rounded,
            size: 16,
            color: palette.textFaint,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              // Su una sfida mirata non ha vinto nessun conteggio: ha vinto
              // perche' chi l'ha lanciata ha detto che ce l'aveva fatta.
              challenge.isDuel
                  ? '@${challenge.createdByUsername} ha detto che ce l\'ha '
                        'fatta: sfida vinta.'
                  : 'Ha vinto la foto con più fiamme alla chiusura.',
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

/// **Com'e' finita una sfida mirata a cui non ha partecipato nessuno.**
///
/// Prende il posto di "Ancora nessuno. Puoi essere il primo.", che su una sfida
/// uno contro uno non e' vera per nessuno dei due: chi l'ha lanciata non puo'
/// partecipare, e chi l'ha ricevuta o deve ancora rispondere o ha gia' detto di
/// no. Quella riga lasciava una schermata vuota proprio dove c'era l'unica cosa
/// da sapere.
///
/// **La cacca e' voluta.** Un rifiuto scritto in grigio istituzionale non e' il
/// tono di una sfida fra amici, e soprattutto non costa niente: qui costa una
/// figuraccia, che e' esattamente il prezzo giusto — niente di piu', ma non
/// zero.
class _DuelOutcome extends ConsumerWidget {
  const _DuelOutcome({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final meId = ref.watch(currentUserIdProvider);
    final sfidato = meId != null && meId == challenge.targetUserId;
    final state = challenge.duelStateAt(DateTime.now());

    final (emoji, titolo, dettaglio) = switch (state) {
      DuelState.declined => (
        '💩',
        sfidato
            ? 'Hai rifiutato la sfida.'
            : '@${challenge.targetUsername} ha rifiutato la sfida.',
        sfidato
            ? 'Se ci hai ripensato puoi ancora rimetterti in gioco: il tempo '
                  'riparte da adesso.'
            : 'Non se l\'è sentita. Capita.',
      ),
      DuelState.expired => (
        '💩',
        sfidato
            ? 'Non ce l\'hai fatta in tempo.'
            : '@${challenge.targetUsername} non l\'ha fatta in tempo.',
        'Le ventiquattro ore sono finite e non è arrivata nessuna foto.',
      ),
      DuelState.accepted => (
        '🤝',
        sfidato
            ? 'Hai accettato: adesso tocca a te.'
            : '@${challenge.targetUsername} ha accettato.',
        sfidato
            ? 'Hai dato la tua parola. Manda la foto prima che scada.'
            : 'Ha dato la sua parola: aspetta la foto.',
      ),
      _ => (
        '⏳',
        sfidato
            ? '@${challenge.createdByUsername} ti ha sfidato.'
            : 'Aspetti una risposta da @${challenge.targetUsername}.',
        sfidato
            ? 'Rispondi dal party: accetti o rifiuti.'
            : 'Non ha ancora detto né sì né no.',
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // **Dove c'e' una figuraccia, la figuraccia ha una faccia.**
          //
          // L'emoji da sola diceva la cosa giusta senza farla sentire: e' il
          // fischio del pubblico, e un fischio senza nessuno a cui e' rivolto
          // e' solo un disegno. La faccia resta pulita — a sporcare ci pensa
          // la sassaiola sopra tutta la pagina, che poi se ne va: una cacca
          // incollata qui sopra per sempre sarebbe una condanna, non uno
          // sfottio.
          if (state == DuelState.declined || state == DuelState.expired)
            FriendAvatar(
              userId: challenge.targetUserId,
              username: challenge.targetUsername,
              size: 64,
            )
          else
            Text(emoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(height: AppSpacing.sm),
          Text(titolo, style: texts.titleSmall),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            dettaglio,
            style: texts.bodySmall?.copyWith(color: palette.textSecondary),
          ),
          // **La via di ritorno sta qui dentro, non solo nel party.**
          //
          // Questa e' la schermata che si apre toccando la notifica, ed e'
          // dove uno arriva quando ci ripensa: mandarlo a cercare il tasto in
          // un'altra scheda vuol dire perderlo per strada.
          if (sfidato && state == DuelState.declined) ...[
            const SizedBox(height: AppSpacing.md),
            _Reconsider(challenge: challenge),
          ],
        ],
      ),
    );
  }
}

/// Il tasto di chi aveva detto di no e ci ha ripensato.
///
/// Rimette la sfida fra le accettate **e fa ripartire l'orologio**: un rifiuto
/// ferma la sfida ma non il tempo, quindi quando uno torna indietro la scadenza
/// originale e' quasi sempre gia' passata. Riaprirla senza toccarla vorrebbe
/// dire riaprirla morta, e il tasto sembrerebbe rotto.
class _Reconsider extends ConsumerWidget {
  const _Reconsider({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(duelControllerProvider).isLoading;

    return OutlinedButton(
      onPressed: busy
          ? null
          : () => ref.read(duelControllerProvider.notifier).accept(challenge),
      child: const Text('CI HO RIPENSATO'),
    );
  }
}

/// **La foto di una sfida mirata, e il giudizio di chi l'ha lanciata.**
///
/// Su ogni altra gara a decidere sono le fiamme. Qui non possono: c'e' un
/// partecipante solo, e "vince chi ne ha di piu'" vuol dire che vince chiunque
/// abbia mandato qualcosa — anche un video nero su una sfida che diceva "balla
/// in mezzo alla piazza". Allora la guarda chi l'ha chiesta.
///
/// **E' un giudizio in buona fede, e non puo' essere altro.** Niente qui dentro
/// puo' obbligare una persona a essere onesta: quello che si puo' fare e' che
/// il giudizio abbia un nome sopra, e ce l'ha. E' la stessa scommessa su cui
/// sta in piedi il resto — chi accetta si impegna sulla parola, chi giudica
/// risponde della sua, e tutti e due sanno chi e' l'altro.
class _DuelJudgement extends ConsumerWidget {
  const _DuelJudgement({required this.challenge, required this.entry});

  final Challenge challenge;
  final ChallengeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final meId = ref.watch(currentUserIdProvider);
    final mio = meId != null && meId == challenge.createdByUserId;
    final state = challenge.duelStateAt(DateTime.now());
    final busy = ref.watch(duelControllerProvider).isLoading;
    final controller = ref.read(duelControllerProvider.notifier);
    final altro = mio ? challenge.targetUsername : challenge.createdByUsername;

    final riga =
        state.nota(mine: !mio, username: altro) ??
        state.fischio(mine: !mio, username: altro);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (riga != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                state == DuelState.judging
                    ? Icons.gavel_rounded
                    : Icons.info_outline_rounded,
                size: 16,
                color: palette.accent,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  riga,
                  style: texts.bodySmall?.copyWith(color: palette.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        EntryTile(entry: entry, showChallenge: false),
        // I due comandi compaiono **solo a chi ha lanciato la sfida, e solo
        // finche' non ha deciso**. A chi l'ha fatta non servono: guarderebbe
        // due tasti che non puo' toccare.
        if (mio && state == DuelState.judging) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'TOCCA A TE',
            style: texts.labelSmall?.copyWith(color: palette.textFaint),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Guarda la foto e dì com\'è andata. Conta sulla tua onestà: sei tu '
            'che hai chiesto questa cosa, e lo sa anche lei.',
            style: texts.bodySmall?.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: busy
                      ? null
                      : () => controller.judge(
                          challenge,
                          approved: true,
                          entry: entry,
                        ),
                  child: const Text('CE L\'HA FATTA'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: busy
                    ? null
                    : () => controller.judge(
                        challenge,
                        approved: false,
                        entry: entry,
                      ),
                child: Text(
                  'NON VALE',
                  style: texts.labelSmall?.copyWith(color: palette.textFaint),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// **Come funziona una sfida mirata**, scritto dove si guarda.
///
/// Prende il posto di "COME SI VINCE", che qui diceva tre cose e due erano
/// false: "vince chi ha piu' fiamme" — con un partecipante solo non vince
/// niente nessuno — e "restano 1 posti su 1", che su una sfida lanciata a una
/// persona per nome e' un modo complicato di non dire niente.
///
/// La terza riga e' quella che conta, ed e' la ragione per cui questo blocco
/// esiste: **chi ha lanciato la sfida decide se vale**. Va detto prima, a tutti
/// e due, o il giorno in cui arriva un "non vale" sembra un sopruso inventato
/// sul momento.
class _DuelRules extends StatelessWidget {
  const _DuelRules({required this.gratis});

  /// Cambia una riga sola, ed e' quella che dice cosa c'e' in palio.
  final bool gratis;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

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
            'COME FUNZIONA',
            style: texts.labelSmall?.copyWith(color: palette.accent),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Rule(
            icon: Icons.sports_kabaddi_rounded,
            text: 'Siete in due, e basta.',
            detail:
                'Nessun altro la vede e nessun altro può parteciparci. Non '
                'toglie niente alle vostre partecipazioni del giorno.',
          ),
          if (gratis)
            _Rule(
              icon: Icons.handshake_rounded,
              text: 'In palio c\'è la parola data.',
              detail:
                  'Non ci sono soldi: chi accetta si impegna a farla, e chi '
                  'rifiuta si becca il buuu.',
            )
          else
            _Rule(
              icon: Icons.savings_outlined,
              text: 'C\'è un premio in denaro.',
              detail:
                  'Lo paga chi ha lanciato la sfida, direttamente a chi vince: '
                  'CRASY non lo trattiene e non fa da garante. Vale come una '
                  'promessa fra voi due, come tutto il resto qui dentro.',
            ),
          _Rule(
            icon: Icons.gavel_rounded,
            text: 'Decide chi ha lanciato la sfida.',
            detail:
                'Quando la foto arriva, è lui a dire se vale — in buona fede, '
                'perché è lui che l\'ha chiesta. Poi la sfida si chiude '
                'subito, senza aspettare la scadenza.',
            accent: true,
          ),
        ],
      ),
    );
  }
}

/// Una cacca sola della sassaiola, con la sua traiettoria.
///
/// Sono scritte a mano e non tirate a caso: **a caso viene male.** Venti
/// traiettorie casuali si accavallano, ne arrivano tre dallo stesso punto e
/// mezzo schermo resta pulito — e la volta dopo e' un'altra cosa, quindi non si
/// puo' nemmeno sistemare guardandola. Scritte, la sassaiola arriva da tutti i
/// lati e copre lo schermo in modo uguale ogni volta.
class _Tiro {
  const _Tiro({
    required this.parte,
    required this.dove,
    required this.da,
    required this.grande,
    required this.storta,
  });

  /// Quando parte, sulla durata intera. Sfalsate: partissero insieme sarebbe
  /// un blocco solo che si sposta, non una sassaiola.
  final double parte;

  /// Dove si spiaccica, in frazione di schermo: `(0,0)` in alto a sinistra,
  /// `(1,1)` in basso a destra.
  final Offset dove;

  /// Da che parte arriva. E' una direzione, non un punto: si moltiplica per la
  /// misura dello schermo, cosi' parte sempre da fuori su qualunque telefono.
  final Offset da;

  final double grande;

  /// Di quanto gira mentre vola.
  final double storta;
}

/// **La sassaiola di cacca, su tutto lo schermo.**
///
/// E' la stessa cosa che dice la riga di testo sotto — *ha rifiutato la sfida*
/// — detta nel modo in cui la direbbe un amico: non un'etichetta grigia, ma il
/// lancio dagli spalti. Rifiutare una sfida d'onore e' l'unica mossa che non
/// costa niente a chi la fa, e questo e' esattamente quanto deve costare —
/// niente di piu' di una figuraccia fra amici, ma non zero.
///
/// **Sta sopra tutta la pagina, e non dentro l'elenco.** Era attaccata alla
/// foto profilo, in fondo alla pagina, ed e' il motivo per cui non la vedeva
/// nessuno: la pagina e' una lista che costruisce tutti i suoi pezzi subito,
/// quindi l'animazione partiva e finiva mentre quel pezzo era ancora sotto il
/// bordo dello schermo. Chi scorreva fin laggiu' arrivava sempre a cose fatte e
/// trovava una cacca ferma incollata su una faccia — che e' il contrario di
/// quello che doveva succedere.
///
/// **Sporca e poi si pulisce.** Le cacche restano appiccicate un secondo, poi
/// colano via e spariscono: quello che resta e' la riga di testo. Una cacca
/// incollata per sempre trasforma una battuta in una condanna — ogni volta che
/// uno riapre quella missione se la ritrova addosso, e li' non e' piu' uno
/// sfottio fra amici.
class _PoopStorm extends StatefulWidget {
  const _PoopStorm({super.key});

  @override
  State<_PoopStorm> createState() => _PoopStormState();
}

class _PoopStormState extends State<_PoopStorm>
    with SingleTickerProviderStateMixin {
  /// Quanto dura il volo di una cacca, sulla durata intera.
  static const double _volo = 0.16;

  /// E quanto ci mette a fermarsi, subito dopo: il tempo in cui la scia si
  /// spegne. Non si deforma — si ferma e basta.
  static const double _spiaccico = 0.05;

  /// Quando lo schermo comincia a ripulirsi.
  static const double _pulizia = 0.62;

  /// La sassaiola. Diciotto, sparse su tutto lo schermo: sotto sembra un
  /// errore di caricamento, sopra diventa una macchia marrone in cui non si
  /// legge piu' nessun singolo colpo.
  static const List<_Tiro> _tiri = [
    _Tiro(parte: 0.00, dove: Offset(0.22, 0.18), da: Offset(-1.2, -0.4), grande: 44, storta: -2.2),
    _Tiro(parte: 0.03, dove: Offset(0.74, 0.12), da: Offset(1.2, -0.5), grande: 36, storta: 2.6),
    _Tiro(parte: 0.06, dove: Offset(0.48, 0.30), da: Offset(0.2, -1.2), grande: 52, storta: -1.6),
    _Tiro(parte: 0.09, dove: Offset(0.12, 0.44), da: Offset(-1.3, 0.2), grande: 32, storta: 2.0),
    _Tiro(parte: 0.12, dove: Offset(0.88, 0.38), da: Offset(1.3, 0.1), grande: 40, storta: -2.4),
    _Tiro(parte: 0.15, dove: Offset(0.34, 0.52), da: Offset(-1.1, 0.6), grande: 48, storta: 1.8),
    _Tiro(parte: 0.18, dove: Offset(0.64, 0.48), da: Offset(1.1, -0.6), grande: 34, storta: -2.8),
    _Tiro(parte: 0.21, dove: Offset(0.20, 0.68), da: Offset(-1.2, 0.8), grande: 38, storta: 2.2),
    _Tiro(parte: 0.24, dove: Offset(0.80, 0.64), da: Offset(1.2, 0.7), grande: 46, storta: -1.9),
    _Tiro(parte: 0.27, dove: Offset(0.50, 0.74), da: Offset(0.1, 1.3), grande: 30, storta: 2.7),
    _Tiro(parte: 0.30, dove: Offset(0.30, 0.86), da: Offset(-1.0, 1.1), grande: 42, storta: -2.1),
    _Tiro(parte: 0.33, dove: Offset(0.70, 0.88), da: Offset(1.0, 1.2), grande: 36, storta: 1.7),
    _Tiro(parte: 0.36, dove: Offset(0.08, 0.24), da: Offset(-1.4, -0.7), grande: 28, storta: -2.5),
    _Tiro(parte: 0.39, dove: Offset(0.92, 0.78), da: Offset(1.4, 0.9), grande: 30, storta: 2.3),
    _Tiro(parte: 0.42, dove: Offset(0.44, 0.08), da: Offset(-0.3, -1.4), grande: 34, storta: -1.5),
    _Tiro(parte: 0.45, dove: Offset(0.58, 0.94), da: Offset(0.4, 1.4), grande: 32, storta: 2.9),
    _Tiro(parte: 0.48, dove: Offset(0.16, 0.58), da: Offset(-1.3, -0.2), grande: 26, storta: -2.0),
    _Tiro(parte: 0.51, dove: Offset(0.84, 0.22), da: Offset(1.3, -0.8), grande: 28, storta: 1.4),
  ];

  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 2600),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // **Non ruba nessun tocco.** Sta sopra tutta la pagina, e senza questo per
    // due secondi e mezzo nessun tasto sotto risponderebbe — compreso "CI HO
    // RIPENSATO", che e' proprio quello che uno cerca subito dopo.
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, vincoli) {
          final schermo = Size(vincoli.maxWidth, vincoli.maxHeight);

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final tempo = _controller.value;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final tiro in _tiri)
                    _volante(tiro, tempo: tempo, schermo: schermo),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Una cacca a mezz'aria, o gia' ferma addosso, o che sta colando via:
  /// dipende da che ora e'.
  Widget _volante(_Tiro tiro, {required double tempo, required Size schermo}) {
    final volo = ((tempo - tiro.parte) / _volo).clamp(0.0, 1.0);

    // Non ancora partita: non c'e' niente da disegnare. Disegnarla ferma al
    // punto di partenza vorrebbe dire diciotto cacche appese ai bordi dello
    // schermo prima che cominci qualcosa.
    if (volo <= 0) {
      return const SizedBox.shrink();
    }

    // Accelera mentre arriva: una cosa tirata addosso a qualcuno non viaggia a
    // velocita' costante, e l'occhio se ne accorge subito quando lo fa.
    final avvicinarsi = Curves.easeIn.transform(volo);

    final arrivo = Offset(
      tiro.dove.dx * schermo.width,
      tiro.dove.dy * schermo.height,
    );
    final partenza =
        arrivo +
        Offset(tiro.da.dx * schermo.width, tiro.da.dy * schermo.height);
    final dove = Offset.lerp(partenza, arrivo, avvicinarsi)!;

    final colpo = ((tempo - tiro.parte - _volo) / _spiaccico).clamp(0.0, 1.0);

    // **La scia, invece della deformazione.**
    //
    // Prima si allargavano e si schiacciavano nell'istante dell'impatto, e il
    // risultato era una cacca stirata — un disegno tirato per i lati, che si
    // legge come un difetto e non come un colpo. Al suo posto c'e' quello che
    // succede davvero a una cosa che viaggia veloce: si sfoca **nella
    // direzione in cui va**, e la sfocatura si spegne quando si ferma.
    //
    // Cresce con la velocita' — che con una curva in accelerazione vuol dire
    // con il quadrato di quanto manca all'arrivo — e sulla misura della cacca:
    // una grande che passa lascia piu' scia di una piccola.
    final velocita = colpo <= 0 ? volo * volo : 1 - colpo;
    final scia = velocita * 9 * (tiro.grande / 40);

    // **La pulizia.** Scivolano verso il basso e svaniscono, ognuna con il suo
    // ritardo: sparissero tutte nello stesso fotogramma sembrerebbe che
    // qualcuno abbia spento l'interruttore. Nient'altro — non si restringono e
    // non si allungano, restano quelle che sono fino all'ultimo fotogramma.
    final quandoVia = _pulizia + (tiro.parte * 0.35);
    final via = tempo <= quandoVia
        ? 0.0
        : ((tempo - quandoVia) / (1 - quandoVia)).clamp(0.0, 1.0);
    final scivola = Curves.easeIn.transform(via);

    return Positioned(
      left: dove.dx - tiro.grande / 2,
      top: dove.dy - tiro.grande / 2 + scivola * 44,
      child: Opacity(
        opacity: (1 - via).clamp(0.0, 1.0),
        child: Transform.rotate(
          // Gira mentre vola e si ferma quando arriva: una cacca che continua a
          // roteare da ferma non sta piu' su niente.
          angle: tiro.storta * (1 - avvicinarsi),
          child: _sfocata(scia: scia, verso: tiro.da, grande: tiro.grande),
        ),
      ),
    );
  }

  /// La cacca con la sua scia, **nella direzione in cui viaggia**.
  ///
  /// La sfocatura non e' uguale sui due assi: e' forte lungo la traiettoria e
  /// quasi nulla di traverso, che e' quello che fa sembrare una scia invece di
  /// una cosa fuori fuoco. Le due misure escono dalla direzione di arrivo,
  /// normalizzata — se arriva da sinistra si sfoca in orizzontale, se piove
  /// dall'alto in verticale.
  ///
  /// Ferma non si sfoca affatto, e il filtro non si applica proprio: sfocare di
  /// zero costa comunque un passaggio di disegno in piu' per ognuna delle
  /// diciotto, e per niente.
  Widget _sfocata({
    required double scia,
    required Offset verso,
    required double grande,
  }) {
    final cacca = Text('💩', style: TextStyle(fontSize: grande));

    if (scia < 0.4) {
      return cacca;
    }

    final lunghezza = verso.distance;

    if (lunghezza == 0) {
      return cacca;
    }

    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: scia * (verso.dx / lunghezza).abs(),
        sigmaY: scia * (verso.dy / lunghezza).abs(),
        // Senza questo la sfocatura si ferma al bordo del riquadro e la scia
        // esce tagliata di netto, come se la cacca stesse dietro una finestra.
        tileMode: TileMode.decal,
      ),
      child: cacca,
    );
  }
}
