import 'dart:async';
import 'dart:math' as math;

import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/services/firebase/firebase_providers.dart';
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
import 'package:crasy/features/moderation/domain/report_reason.dart';
import 'package:crasy/features/moderation/presentation/widgets/report_sheet.dart';
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
          // **Si segnala anche la missione, non solo le foto.**
          //
          // Una consegna puo' essere il problema: chiedere di fare una cosa
          // pericolosa, o molestare qualcuno, o peggio. Finora si poteva
          // segnalare solo chi aveva obbedito — cioe' la vittima della
          // richiesta — e non chi l'aveva scritta.
          //
          // Non compare sulla propria: segnalare se stessi non vuol dire
          // niente. E nemmeno sulle sfide del giorno, che le scrive CRASY.
          if (challengeState.valueOrNull case final gara?
              when gara.createdByUserId.isNotEmpty &&
                  gara.createdByUserId != ref.watch(currentUserIdProvider) &&
                  !gara.isDaily)
            IconButton(
              onPressed: () => showReportSheet(
                context,
                ref,
                kind: ReportTargetKind.challenge,
                reportedUserId: gara.createdByUserId,
                reportedUsername: gara.createdByUsername,
                challengeId: gara.id,
                challengeTitle: gara.title,
              ),
              icon: const Icon(Icons.flag_outlined, size: 20),
              tooltip: 'Segnala la missione',
            ),
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
                if (rifiutata)
                  _SplatStorm(
                    key: ValueKey(challenge.id),
                    userId: challenge.targetUserId,
                    username: challenge.targetUsername,
                  ),
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
        // **La riga che ti ha scritto chi ti sfida.**
        //
        // Sta sotto la consegna e non sopra: prima cosa devi fare, poi cosa ti
        // ha detto. Invertirli farebbe leggere la battuta senza sapere a cosa
        // si riferisce.
        if (challenge.duelMessage.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _DuelMessage(challenge: challenge),
        ],
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
    _proclamaSeServe();
  }

  @override
  void didUpdateWidget(_Entries oldWidget) {
    super.didUpdateWidget(oldWidget);

    // **Anche qui, e non solo all'apertura.** La gara arriva spesso ancora
    // aperta e il server la chiude un istante dopo: il vincitore compare in
    // quel momento, con un widget nuovo. Guardando soltanto all'ingresso, il
    // rullo non partirebbe mai proprio nel caso piu' comune — chi arriva
    // appena scaduto il tempo.
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
    final vincitrice = challenge.winnerEntryId;

    // **Finita ma non ancora proclamata: si chiede di chiuderla adesso.**
    //
    // A decidere e' il server, e il server ci passa da solo ogni pochi minuti.
    // Ma quei minuti cadono esattamente dove non devono: la sirena e' suonata,
    // uno apre la missione per sapere com'e' andata, e non c'e' niente —
    // nessun vincitore, nessun tamburo. Sembra rotta proprio nel momento in
    // cui dovrebbe dire che si sono vinti dei soldi.
    //
    // Chiederlo costa una chiamata e solo quando c'e' davvero qualcuno che
    // guarda. Non si decide niente da qui: il server rifa' gli stessi controlli
    // e gli stessi conti che avrebbe fatto fra poco. Quando ha finito, la gara
    // cambia sotto gli occhi e il rullo parte da se'.
    if (vincitrice == null && challenge.isOver) {
      _chiediLaChiusura(challenge.id);

      return;
    }

    if (vincitrice == null || vincitrice.isEmpty || !challenge.isOver) {
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

  /// Una volta sola per schermata: la gara arriva da uno stream e questo
  /// widget si ricostruisce a ogni fiamma che qualcuno accende.
  var _chiusuraChiesta = false;

  void _chiediLaChiusura(String challengeId) {
    if (_chiusuraChiesta) {
      return;
    }

    _chiusuraChiesta = true;

    unawaited(() async {
      try {
        await ref
            .read(firebaseFunctionsProvider)
            .httpsCallable('closeChallengeNow')
            .call<Object?>({'challengeId': challengeId});
      } catch (_) {
        // **Se non riesce, non si dice niente.** Non e' una cosa che
        // qualcuno ha chiesto di fare: e' un anticipo di un lavoro che il
        // server fa comunque da solo fra pochi minuti. Un messaggio d'errore
        // qui sarebbe un allarme per un ritardo.
      }
    }());
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

    // **Se il premio e' gia' in cassa, si dice che torna indietro.**
    //
    // E' la sola cosa che uno vuole sapere prima di toccare quel tasto, e
    // tacerla era il modo piu' sicuro di far restare una missione sbagliata in
    // home per paura di perderci dei soldi.
    final pagata = widget.challenge.prizeStatus.isEscrowed;

    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancellare la missione?'),
        content: Text(
          // **Si dice cosa torna, e in quanto tempo.**
          //
          // Le due cose che uno vuole sapere prima di toccare quel tasto, e
          // tacere la seconda era il modo piu' sicuro di farsi scrivere fra
          // due giorni "dove sono i miei soldi". Una carta non restituisce
          // niente in tempo reale: l'ordine parte subito, la banca ci mette
          // giorni, e chi non lo sa pensa che i soldi siano spariti.
          pagata
              ? 'Non ha ancora partecipato nessuno, quindi si può. Ti '
                    'torna il premio di ${widget.challenge.prizeLabel}: '
                    'restano fuori le spese di pagamento, che sono già state '
                    'pagate e non si recuperano. Arrivano sulla tua carta in '
                    '5-10 giorni lavorativi, e li mette la tua banca, non '
                    'noi. La missione sparisce e non si recupera.'
              : 'Non ha ancora partecipato nessuno, quindi si può. Sparisce '
                    'dalla home e non si recupera.',
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
      if (pagata) {
        // **Una gara pagata la cancella il server, non il telefono.**
        //
        // Le regole del database non lasciano cancellare un documento con dei
        // soldi in cassa, ed e' giusto: sparirebbe la gara e resterebbero i
        // soldi su Stripe senza piu' niente che dica a chi tornano. Il server
        // fa le due cose nell'ordine che le rende sicure — prima il rimborso,
        // poi la cancellazione.
        await ref
            .read(firebaseFunctionsProvider)
            .httpsCallable('cancelChallenge')
            .call<Object?>({'challengeId': widget.challenge.id});
      } else {
        await ref
            .read(challengeRepositoryProvider)
            .deleteChallenge(widget.challenge.id);
      }
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

    if (!mounted) {
      return;
    }

    // **Cancellata, si torna in home — non "indietro".**
    //
    // Indietro presuppone che ci sia un dietro, e spesso non c'e': chi arriva
    // qui da una notifica, da un link condiviso o dal ritorno di un pagamento
    // apre il dettaglio come prima schermata. Chiudere l'unica pagina aperta
    // lasciava uno schermo bianco, subito dopo aver toccato un tasto che dice
    // "cancella" — nel momento peggiore per far sembrare che sia andato storto
    // qualcosa.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.challenges);
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
            ? (challenge.canReconsiderAt(DateTime.now())
                  ? 'Hai cinque ore per rimetterti in gioco. Se lo fai, il '
                        'tempo della sfida riparte da adesso.'
                  : 'Le cinque ore per ripensarci sono passate.')
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
          if (sfidato && challenge.canReconsiderAt(DateTime.now())) ...[
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

/// Uno schizzo della sassaiola: da dove arriva, dove colpisce, quanto e'
/// grosso.
///
/// Sono scritti a mano e non tirati a caso: **a caso viene male.** Quattordici
/// direzioni casuali si accavallano, tre arrivano dallo stesso lato e mezza
/// faccia resta pulita — e la volta dopo e' un'altra cosa, quindi non si puo'
/// nemmeno sistemare guardandola. Scritti, arrivano da tutto il giro e coprono
/// la faccia in modo uguale ogni volta.
class _Schizzo {
  const _Schizzo({
    required this.parte,
    required this.angolo,
    required this.dove,
    required this.grande,
  });

  /// Quando parte, sulla durata intera. Sfalsati: partissero insieme sarebbe
  /// un anello che si stringe, non una sassaiola.
  final double parte;

  /// Da che parte del giro arriva, in radianti. Zero e' destra, e si gira in
  /// senso orario da li'.
  final double angolo;

  /// Dove colpisce, in frazione del raggio della faccia: `0` il naso, `1` il
  /// bordo. Sopra `1` schizza intorno, che serve a non far sembrare la faccia
  /// un bersaglio con il cerchio disegnato.
  final double dove;

  /// Quanto e' grosso lo schizzo che lascia, in punti.
  final double grande;
}

/// **Gli schizzi che convergono sulla faccia di chi ha detto di no.**
///
/// E' la stessa cosa che dice la riga di testo sotto — *ha rifiutato la sfida*
/// — detta nel modo in cui la direbbe un amico: non un'etichetta grigia, ma il
/// lancio dagli spalti. Rifiutare una sfida d'onore e' l'unica mossa che non
/// costa niente a chi la fa, e questo e' esattamente quanto deve costare —
/// niente di piu' di una figuraccia fra amici, ma non zero.
///
/// **Tutto converge al centro, e al centro c'e' una persona con un nome.** Le
/// versioni prima tiravano roba sparsa su tutto lo schermo: si vedeva una
/// pioggia, non un bersaglio, e soprattutto non si capiva di chi si stesse
/// parlando. Qui la faccia e il nome stanno fermi in mezzo e tutto il resto
/// punta li'.
///
/// **Sta sopra tutta la pagina, e non dentro l'elenco.** Era attaccata alla
/// foto in fondo alla pagina, ed e' il motivo per cui non la vedeva nessuno: la
/// pagina costruisce tutti i suoi pezzi subito, quindi l'animazione partiva e
/// finiva mentre quel pezzo era ancora sotto il bordo dello schermo.
///
/// **Sporca e poi si pulisce.** Gli schizzi restano un secondo, poi svaniscono
/// tutti insieme allo sfondo: quello che resta e' la riga di testo. Una
/// macchia incollata per sempre trasforma una battuta in una condanna — ogni
/// volta che uno riapre quella missione se la ritrova addosso.
class _SplatStorm extends StatelessWidget {
  const _SplatStorm({
    required this.userId,
    required this.username,
    super.key,
  });

  final String userId;
  final String username;

  /// Quanto e' grande la faccia in mezzo.
  static const double _faccia = 116;

  @override
  Widget build(BuildContext context) {
    // **Non ruba nessun tocco.** Sta sopra tutta la pagina, e senza questo per
    // quasi tre secondi nessun tasto sotto risponderebbe — compreso "CI HO
    // RIPENSATO", che e' proprio quello che uno cerca subito dopo.
    return IgnorePointer(
      child: _SplatStormBody(
        userId: userId,
        username: username,
        faccia: _faccia,
      ),
    );
  }
}

class _SplatStormBody extends StatefulWidget {
  const _SplatStormBody({
    required this.userId,
    required this.username,
    required this.faccia,
  });

  final String userId;
  final String username;
  final double faccia;

  @override
  State<_SplatStormBody> createState() => _SplatStormBodyState();
}

class _SplatStormBodyState extends State<_SplatStormBody>
    with SingleTickerProviderStateMixin {
  /// Quanto dura il volo di uno schizzo, sulla durata intera.
  static const double _volo = 0.13;

  /// Quanto ci mette la macchia ad aprirsi, appena colpisce.
  static const double _apertura = 0.05;

  /// Quando comincia a ripulirsi tutto.
  static const double _pulizia = 0.70;

  /// La sassaiola. Quattordici, sparsi su tutto il giro: sotto sembra un
  /// errore di caricamento, sopra diventa una macchia sola in cui non si legge
  /// piu' nessun singolo colpo — e la faccia non si vede piu' affatto, che e'
  /// il contrario di quello che serve.
  static const List<_Schizzo> _schizzi = [
    _Schizzo(parte: 0.00, angolo: -2.60, dove: 0.34, grande: 40),
    _Schizzo(parte: 0.04, angolo: 0.45, dove: 0.58, grande: 34),
    _Schizzo(parte: 0.08, angolo: -1.15, dove: 0.20, grande: 46),
    _Schizzo(parte: 0.12, angolo: 2.05, dove: 0.66, grande: 30),
    _Schizzo(parte: 0.16, angolo: -0.30, dove: 0.78, grande: 38),
    _Schizzo(parte: 0.20, angolo: 1.35, dove: 0.28, grande: 44),
    _Schizzo(parte: 0.24, angolo: 3.00, dove: 0.50, grande: 32),
    _Schizzo(parte: 0.27, angolo: -1.95, dove: 0.72, grande: 36),
    _Schizzo(parte: 0.30, angolo: 0.95, dove: 0.06, grande: 50),
    _Schizzo(parte: 0.33, angolo: -0.75, dove: 1.08, grande: 26),
    _Schizzo(parte: 0.36, angolo: 2.55, dove: 1.02, grande: 24),
    _Schizzo(parte: 0.39, angolo: -2.25, dove: 0.94, grande: 28),
    _Schizzo(parte: 0.42, angolo: 1.75, dove: 1.12, grande: 22),
    _Schizzo(parte: 0.45, angolo: 0.10, dove: 0.42, grande: 34),
  ];

  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 2800),
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
    final texts = context.texts;

    return LayoutBuilder(
      builder: (context, vincoli) {
        final schermo = Size(vincoli.maxWidth, vincoli.maxHeight);

        // Un filo sopra la meta': sotto la faccia ci va il nome, e un blocco
        // centrato davvero finisce per sembrare basso.
        final centro = Offset(schermo.width / 2, schermo.height * 0.42);
        final raggio = widget.faccia / 2;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final tempo = _controller.value;
            final via = tempo <= _pulizia
                ? 0.0
                : ((tempo - _pulizia) / (1 - _pulizia)).clamp(0.0, 1.0);
            final visibile = (1 - via).clamp(0.0, 1.0);

            // Lo sfondo si scurisce appena: serve a staccare la faccia dalla
            // pagina sotto, non a nasconderla. Piu' scuro di cosi' e la
            // schermata sembrerebbe bloccata da un pannello.
            final buio = (tempo < 0.08 ? tempo / 0.08 : 1.0) * visibile;

            return Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.55 * buio),
                  ),
                ),
                Positioned(
                  left: centro.dx - raggio,
                  top: centro.dy - raggio,
                  child: Opacity(
                    opacity: visibile,
                    child: FriendAvatar(
                      userId: widget.userId,
                      username: widget.username,
                      size: widget.faccia,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: centro.dy + raggio + AppSpacing.sm,
                  child: Opacity(
                    opacity: visibile,
                    child: Text(
                      '@${widget.username}',
                      textAlign: TextAlign.center,
                      style: texts.titleMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
                // Le macchie stanno **sopra** la faccia: sotto sarebbero una
                // decorazione attorno a un ritratto, non roba tirata addosso a
                // qualcuno.
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SchizziPainter(
                      schizzi: _schizzi,
                      tempo: tempo,
                      centro: centro,
                      raggio: raggio,
                      lontano: schermo.longestSide,
                      visibile: visibile,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Disegna la sassaiola: quelli che stanno ancora volando e le macchie di
/// quelli gia' arrivati.
///
/// **Un disegno solo per tutti e quattordici**, invece di quattordici pezzi di
/// interfaccia sovrapposti: sono forme piene senza testo dentro, e farle
/// disegnare tutte insieme su una tela sola costa un passaggio al posto di
/// quattordici — su un'animazione che gira a sessanta fotogrammi al secondo la
/// differenza si vede.
class _SchizziPainter extends CustomPainter {
  const _SchizziPainter({
    required this.schizzi,
    required this.tempo,
    required this.centro,
    required this.raggio,
    required this.lontano,
    required this.visibile,
  });

  final List<_Schizzo> schizzi;
  final double tempo;
  final Offset centro;
  final double raggio;

  /// Da quanto lontano partono: la misura piu' lunga dello schermo, cosi'
  /// nascono fuori da qualunque bordo su qualunque telefono.
  final double lontano;

  final double visibile;

  /// I marroni. Tre e non uno: una macchia sola di un colore solo sembra una
  /// forma incollata sopra, tre sfumature sembrano roba.
  static const List<Color> _marroni = [
    Color(0xFF6B3F1D),
    Color(0xFF80501F),
    Color(0xFF53300F),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < schizzi.length; i++) {
      final schizzo = schizzi[i];
      final volo = ((tempo - schizzo.parte) / _SplatStormBodyState._volo).clamp(
        0.0,
        1.0,
      );

      // Non ancora partito: non c'e' niente da disegnare.
      if (volo <= 0) {
        continue;
      }

      final direzione = Offset(
        math.cos(schizzo.angolo),
        math.sin(schizzo.angolo),
      );
      final arrivo = centro + direzione * (raggio * schizzo.dove);
      final colore = _marroni[i % _marroni.length];

      if (volo < 1) {
        _volante(canvas, schizzo, direzione, arrivo, colore, volo);

        continue;
      }

      _macchia(canvas, schizzo, arrivo, colore, i);
    }
  }

  /// Lo schizzo mentre viaggia, con la sua scia.
  ///
  /// La scia sono tre copie sempre piu' deboli dietro di lui, lungo la
  /// direzione da cui arriva: e' il modo in cui l'occhio legge la velocita'.
  /// Una sfocatura uguale su tutti i lati direbbe "fuori fuoco", non "veloce".
  void _volante(
    Canvas canvas,
    _Schizzo schizzo,
    Offset direzione,
    Offset arrivo,
    Color colore,
    double volo,
  ) {
    // Accelera mentre arriva: una cosa tirata addosso a qualcuno non viaggia a
    // velocita' costante, e l'occhio se ne accorge subito quando lo fa.
    final avanti = Curves.easeIn.transform(volo);
    final partenza = arrivo + direzione * lontano;
    final dove = Offset.lerp(partenza, arrivo, avanti)!;
    final misura = schizzo.grande * 0.32;

    for (var scia = 2; scia >= 0; scia--) {
      final dietro = dove + direzione * (misura * 1.5 * scia);
      final forza = (1 - scia * 0.3) * visibile;

      canvas.drawCircle(
        dietro,
        misura * (1 - scia * 0.18),
        Paint()..color = colore.withValues(alpha: 0.9 * forza),
      );
    }
  }

  /// La macchia, una volta arrivato.
  ///
  /// Si apre di scatto e poi resta: **non e' un cerchio**, o sembrerebbe un
  /// bollo appiccicato sopra. E' una forma storta con qualche goccia intorno,
  /// e le storture sono le stesse ogni volta perche' escono da un conto e non
  /// dal caso — una macchia che cambia forma a ogni fotogramma tremola.
  void _macchia(
    Canvas canvas,
    _Schizzo schizzo,
    Offset dove,
    Color colore,
    int seme,
  ) {
    final aperta = ((tempo - schizzo.parte - _SplatStormBodyState._volo) /
            _SplatStormBodyState._apertura)
        .clamp(0.0, 1.0);

    // Un filo oltre e poi indietro: e' lo scatto che fa sembrare che sia
    // arrivata di forza invece di comparire.
    final scatto = Curves.easeOutBack.transform(aperta);
    final misura = schizzo.grande / 2 * scatto;

    if (misura <= 0) {
      return;
    }

    final pennello = Paint()
      ..color = colore.withValues(alpha: 0.92 * visibile);

    canvas.drawPath(_forma(dove, misura, seme), pennello);

    // Le gocce: quattro, sparse intorno e sempre piu' lontane man mano che la
    // macchia si apre. Sono loro a far sembrare che qualcosa sia **esploso**
    // li' sopra, invece di essere stato appoggiato.
    for (var g = 0; g < 4; g++) {
      final angolo = _caso(seme, g) * math.pi * 2;
      final distanza = misura * (1.2 + _caso(seme, g + 10) * 1.1);
      final piccola = misura * (0.14 + _caso(seme, g + 20) * 0.16);

      canvas.drawCircle(
        dove + Offset(math.cos(angolo), math.sin(angolo)) * distanza,
        piccola,
        pennello,
      );
    }
  }

  /// Una forma storta: un giro di punti con il raggio che balla, uniti da
  /// curve.
  Path _forma(Offset centro, double misura, int seme) {
    const lati = 9;
    final punti = <Offset>[];

    for (var i = 0; i < lati; i++) {
      final angolo = i / lati * math.pi * 2;
      final quanto = misura * (0.72 + _caso(seme, i) * 0.55);

      punti.add(
        centro + Offset(math.cos(angolo), math.sin(angolo)) * quanto,
      );
    }

    final path = Path()
      ..moveTo(
        (punti[0].dx + punti[lati - 1].dx) / 2,
        (punti[0].dy + punti[lati - 1].dy) / 2,
      );

    for (var i = 0; i < lati; i++) {
      final ora = punti[i];
      final poi = punti[(i + 1) % lati];

      // Il punto e' il vertice della curva, il mezzo fra due e' dove la curva
      // passa: cosi' il giro si chiude tondo invece che a spigoli.
      path.quadraticBezierTo(
        ora.dx,
        ora.dy,
        (ora.dx + poi.dx) / 2,
        (ora.dy + poi.dy) / 2,
      );
    }

    return path..close();
  }

  /// Un numero fra zero e uno che dipende solo da dove lo si chiede.
  ///
  /// Serve a dare a ogni macchia la sua forma storta **senza il caso**: chiamato
  /// con gli stessi due numeri risponde sempre lo stesso, quindi la macchia sta
  /// ferma da un fotogramma all'altro invece di tremolare.
  double _caso(int seme, int i) {
    final x = math.sin(seme * 12.9898 + i * 78.233) * 43758.5453;

    return x - x.floorToDouble();
  }

  @override
  bool shouldRepaint(_SchizziPainter vecchio) =>
      vecchio.tempo != tempo ||
      vecchio.centro != centro ||
      vecchio.visibile != visibile;
}

/// La riga scritta a mano da chi ha lanciato la sfida.
///
/// **Si vede che e' di una persona, non dell'app.** Il filetto rosso a
/// sinistra e il nome sotto fanno la differenza fra "vediamo se ce la fai"
/// detto da un amico e la stessa frase che sembrerebbe una consegna scritta da
/// CRASY — e quella differenza e' tutto il senso di questa riga.
class _DuelMessage extends StatelessWidget {
  const _DuelMessage({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            challenge.duelMessage,
            style: context.texts.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '@${challenge.createdByUsername}',
            style: context.texts.labelSmall?.copyWith(
              color: palette.textFaint,
            ),
          ),
        ],
      ),
    );
  }
}
