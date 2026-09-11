import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/services/share/share_entry.dart';
import 'package:crasy/core/theme/app_colors.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/video_frame.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/controllers/vote_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/entry_comments.dart';
import 'package:crasy/features/moderation/domain/report_reason.dart';
import 'package:crasy/features/moderation/presentation/widgets/report_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Una partecipazione a schermo intero.
///
/// **La foto e' il contenuto, e dentro la griglia della gara se ne vede un
/// quadrato di due dita.** Qui prende tutto lo schermo su fondo nero, che e'
/// l'unico posto di CRASY in cui il nero fa da fondo: e' la sala buia in cui si
/// guarda una cosa sola.
///
/// Si scorre da una partecipazione all'altra con il dito, senza tornare
/// indietro: guardare le foto di una gara e' un gesto continuo, e chiudere e
/// riaprire venti volte lo spezzerebbe. Il doppio tocco accende la fiamma come
/// ovunque nell'app — chi sta guardando una foto a schermo intero e'
/// esattamente chi ha piu' voglia di votarla.
class FullscreenMedia extends ConsumerStatefulWidget {
  const FullscreenMedia({
    required this.challengeId,
    required this.entryId,
    required this.initialEntries,
    super.key,
  });

  final String challengeId;
  final String entryId;

  /// Le partecipazioni cosi' com'erano al momento dell'apertura.
  ///
  /// Servono a mostrare qualcosa subito e a fissare **l'ordine**. I numeri
  /// aggiornati arrivano dallo stream; l'ordine no, e il perche' e' spiegato
  /// sotto.
  final List<ChallengeEntry> initialEntries;

  /// Apre la vista. E' un `Navigator.push` e non una rotta del router: e' una
  /// finestra sopra la schermata, non un posto in cui si atterra da un
  /// indirizzo — e da qui il tasto indietro del telefono la chiude, che e'
  /// quello che tutti si aspettano.
  static Future<void> open(
    BuildContext context, {
    required List<ChallengeEntry> entries,
    required ChallengeEntry entry,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: AppColors.ink,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: FullscreenMedia(
            challengeId: entry.challengeId,
            entryId: entry.id,
            initialEntries: entries.isEmpty ? [entry] : entries,
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<FullscreenMedia> createState() => _FullscreenMediaState();
}

class _FullscreenMediaState extends ConsumerState<FullscreenMedia> {
  /// L'ordine in cui si scorre, deciso all'apertura e **mai piu' toccato**.
  ///
  /// La gara e' ordinata per fiamme, quindi accendendone una la classifica si
  /// riordina sotto le dita: la foto che si sta guardando scivolerebbe avanti e
  /// lo schermo salterebbe su un'altra, come punizione per aver votato. Qui
  /// l'ordine resta quello di quando si e' aperto; i numeri, quelli si', si
  /// aggiornano.
  late final List<String> _order = [
    for (final entry in widget.initialEntries) entry.id,
  ];

  late final PageController _pages = PageController(
    initialPage: _order.indexOf(widget.entryId).clamp(0, _order.length - 1),
  );

  late int _index = _pages.initialPage;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Le partecipazioni con i numeri di adesso, nell'ordine di prima.
  ///
  /// **Senza questo, il conto delle fiamme si fermava.** La vista riceveva la
  /// lista com'era all'apertura e non la rileggeva mai: accendendo una fiamma
  /// il numero saliva finche' la scrittura era in volo e poi tornava giu', al
  /// valore vecchio, con la fiamma rimasta rossa. Sembrava un voto che non
  /// veniva contato, e invece era la lista a non essere piu' quella vera.
  List<ChallengeEntry> _entries() {
    final live = ref.watch(challengeEntriesProvider(widget.challengeId));
    final byId = {
      for (final entry in widget.initialEntries) entry.id: entry,
      for (final entry in live.valueOrNull ?? const <ChallengeEntry>[])
        entry.id: entry,
    };

    return [
      for (final id in _order)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries();

    // **Niente da mostrare non vuol dire niente da disegnare.**
    //
    // Qui c'era un riquadro vuoto, e sotto sta un fondo nero: il risultato era
    // uno schermo nero e basta — nessuna scritta, nessuna freccia, e il gesto
    // per tornare indietro che non chiude niente perche' questa e' una
    // finestra aperta sopra, non una pagina. L'unica via d'uscita era chiudere
    // l'app.
    //
    // Non importa quanto sia raro il caso: **quando capita, uno resta chiuso
    // dentro**. E un riquadro vuoto e' la cosa piu' facile da scrivere e la
    // piu' difficile da diagnosticare, perche' non lascia niente da leggere.
    if (entries.isEmpty) {
      return const _NienteDaVedere(messaggio: "Questa foto non c'e' piu'.");
    }

    final current = entries[_index.clamp(0, entries.length - 1)];

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: entries.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => _Slide(entry: entries[index]),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  position: '${_index + 1} / ${entries.length}',
                  onClose: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                _BottomBar(entry: current),
              ],
            ),
          ),
          // Foto e video espongono gli stessi comandi sotto il pollice.
          Positioned(
            right: AppSpacing.sm,
            bottom: current.isVideo ? 164 : 132,
            child: SafeArea(child: _Actions(entry: current, vertical: true)),
          ),
        ],
      ),
    );
  }
}

/// Una singola partecipazione dentro la vista.
///
/// La foto si puo' ingrandire con due dita. Non e' un vezzo: le challenge si
/// vincono con i dettagli — cosa c'e' scritto sul cartello, che faccia ha fatto
/// lo sconosciuto — e su un telefono quei dettagli si vedono solo
/// avvicinandosi.
class _Slide extends ConsumerWidget {
  const _Slide({required this.entry});

  final ChallengeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = entry.mediaUrl;

    // Vedi `_NienteDaVedere`: un riquadro vuoto su fondo nero e' uno schermo
    // nero, e chi ci finisce non ha modo di sapere che non e' un guasto suo.
    if (url.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.page),
          child: Text(
            'Questa foto non si carica.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.paper),
          ),
        ),
      );
    }

    // **Niente didascalia qui.** Sulla miniatura la scritta attorno dice cosa
    // sta succedendo dentro la foto prima di aprirla, ed e' la sua ragione di
    // esistere. Aperta a tutto schermo la foto si guarda e basta: la stessa
    // scritta diventerebbe una cornice messa fra l'occhio e l'immagine, nel
    // momento esatto in cui l'immagine e' l'unica cosa che si voleva vedere.
    final media = entry.isVideo
        ? VideoFrame(url: url, immersive: true)
        : _Photo(url: url);

    return GestureDetector(
      // Il doppio tocco vale anche qui, e a fiamma gia' accesa non fa niente:
      // nessuno ripete lo stesso gesto per disfare quello che ha appena fatto.
      // A fermarlo e' `giveFire`, che ignora la richiesta di accendere una
      // fiamma gia' accesa — la regola sta in un posto solo.
      onDoubleTap: () => giveFire(context, ref, entry, voted: true),
      // `giveFire` sa gia' che a gara finita non si vota, e sa anche che una
      // fiamma gia' accesa non si riaccende: la regola sta in un posto solo.
      child: Center(child: media),
    );
  }
}

/// Cosa si vede quando non c'e' niente da vedere.
///
/// **Una scritta e una via d'uscita.** Sono le due cose che mancavano: senza la
/// prima non si capisce se sia un guasto o una cosa normale, senza la seconda
/// non si esce — questa e' una finestra aperta sopra la schermata, e il gesto
/// per tornare indietro non la chiude da solo.
class _NienteDaVedere extends StatelessWidget {
  const _NienteDaVedere({required this.messaggio});

  final String messaggio;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: AppColors.paper),
                tooltip: 'Chiudi',
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Text(
                  messaggio,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.paper),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La foto a tutto schermo, e nient'altro.
///
/// **Si ingrandisce con due dita.** Una foto mandata a una gara si guarda per
/// il dettaglio — cos'ha in mano, cosa c'e' scritto dietro — e senza
/// l'ingranditore quel dettaglio non c'e' modo di vederlo.
class _Photo extends StatelessWidget {
  const _Photo({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(child: Image.network(url, fit: BoxFit.contain)),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.position, required this.onClose});

  final String position;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: AppColors.paper),
            tooltip: 'Chiudi',
          ),
          const Spacer(),
          Text(
            position,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.paper),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// Chi l'ha mandata, il tasto per condividerla, e le fiamme.
///
/// Sono le sole cose che servono qui: il resto della gara sta nella schermata
/// sotto, e riproporlo su fondo nero vorrebbe dire coprire la foto con quello
/// che si e' appena chiuso per vederla.
class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.entry});

  final ChallengeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.lg,
      ),
      color: AppColors.ink.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // **Da qui si torna alla gara.** Alla foto grande adesso ci si arriva
          // anche dalla griglia di un profilo, dove prima il tocco portava
          // dritto alla challenge: senza questa riga, quella strada sparirebbe
          // e una foto resterebbe una foto senza sapere per cosa era in gara.
          if (entry.challengeTitle.isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.challengeDetailOf(entry.challengeId));
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  entry.challengeTitle.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.paper.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          // **La didascalia sta qui, in riga.** E' l'unico posto in cui si
          // vede: sulla foto piccola la scritta curva attorno al bordo e' in
          // pausa, e comunque sull'immagine aperta si metterebbe fra l'occhio e
          // la cosa che si e' venuti a guardare.
          if (entry.caption.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                entry.caption.trim(),
                // Tre righe: piu' in la' non e' piu' una didascalia, e in
                // fondo a una foto a schermo intero coprirebbe la foto.
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.paper),
              ),
            ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              context.push(AppRoutes.userProfileOf(entry.userId));
            },
            behavior: HitTestBehavior.opaque,
            child: Text(
              '@${entry.authorName}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.paper),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // **I comandi su una riga sola, in fondo — per le foto.**
          //
          // Sono passati per due posti sbagliati prima di arrivare qui. Erano
          // righe impilate — titolo, didascalia, nome, e sotto tutto il resto i
          // commenti: l'ultima cosa dell'ultima riga, cioe' il posto peggiore
          // per quello che si tocca di piu' dopo la fiamma. Poi una colonna a
          // destra, che risolveva la distanza ma tagliava l'immagine in due.
          //
          // Su una riga sola stanno tutti alla stessa altezza, il pollice ci
          // arriva senza spostarsi, e **i lati della foto restano liberi**:
          // guardando un'immagine a tutto schermo non deve esserci niente
          // appoggiato sopra. Condividi sta staccato, all'altro capo: gli altri
          // due parlano alla gara, quello parla a chi sta fuori.
        ],
      ),
    );
  }
}

/// La riga dei comandi: fiamma, commenti, e in fondo condividi.
class _Actions extends ConsumerWidget {
  const _Actions({required this.entry, this.vertical = false});

  final ChallengeEntry entry;
  final bool vertical;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voted = ref.watch(entryVotedProvider(entry.voteKey));
    final votes = visibleVotes(ref, entry);
    final live = ref.watch(challengeIsLiveProvider(entry.challengeId));
    final comments = ref
        .watch(
          entryCommentsProvider((
            challengeId: entry.challengeId,
            entryId: entry.id,
          )),
        )
        .valueOrNull;

    final actions = <Widget>[
      _Action(
        // A gara finita il numero resta, ma non e' piu' un comando: quelle
        // fiamme hanno gia' deciso chi si prende i soldi.
        onTap: live ? () => giveFire(context, ref, entry, voted: !voted) : null,
        icon: voted
            ? Icons.local_fire_department
            : Icons.local_fire_department_outlined,
        color: voted ? AppColors.crasyRed : AppColors.paper,
        label: votesLabel(votes),
        tooltip: voted ? 'Togli la fiamma' : 'Dai la fiamma',
        vertical: vertical,
      ),
      // **I commenti spariscono alla sirena.** Non e' un permesso tolto: un
      // commento e' tifo, e il tifo si fa durante.
      if (live) ...[
        if (!vertical) const SizedBox(width: AppSpacing.lg),
        _Action(
          onTap: () => showEntryComments(context, entry: entry),
          icon: Icons.mode_comment_outlined,
          color: AppColors.paper,
          label: comments == null || comments.isEmpty
              ? ''
              : '${comments.length}',
          tooltip: 'Commenti',
          vertical: vertical,
        ),
      ],
      if (!vertical) const Spacer(),
      // **Segnalare sta qui, non dentro un menu di secondo livello.**
      //
      // Chi ha davanti una cosa che non dovrebbe esserci la sta guardando a
      // tutto schermo, in questo momento: e' l'unico istante in cui
      // segnalera'. Nascosto dietro due tocchi, il comando esiste per le
      // linee guida e non per le persone.
      //
      // Non compare sulle proprie foto: segnalare se stessi non vuol dire
      // niente.
      if (entry.userId != ref.watch(currentUserIdProvider))
        _Action(
          onTap: () => showReportSheet(
            context,
            ref,
            kind: ReportTargetKind.entry,
            reportedUserId: entry.userId,
            reportedUsername: entry.authorName,
            challengeId: entry.challengeId,
            entryId: entry.id,
          ),
          icon: Icons.flag_outlined,
          color: AppColors.paper,
          label: '',
          tooltip: 'Segnala o blocca',
          vertical: vertical,
        ),
      if (!vertical) const SizedBox(width: AppSpacing.lg),
      // Condividere non sta nascosto in un menu: e' il gesto con cui chi e'
      // in gara si porta dentro i voti, ed e' anche il modo in cui CRASY
      // incontra gente che non la conosce.
      _Action(
        onTap: () => ShareEntry.send(
          context,
          challengeId: entry.challengeId,
          entryId: entry.id,
          challengeTitle: entry.challengeTitle,
          // Solo il nome: il link non porta il file, perche' la foto si
          // guarda dentro l'app e da nessun'altra parte. Vedi
          // `ShareEntry.linkTo`.
          authorName: entry.authorName,
          ended: !live,
        ),
        icon: Icons.ios_share_rounded,
        color: AppColors.paper,
        label: '',
        tooltip: 'Condividi',
        vertical: vertical,
      ),
    ];

    if (!vertical) {
      return Row(children: actions);
    }

    // Nel flusso video il numero va sotto la sua icona, non di lato: la
    // colonna resta stretta e ogni gesto ha una zona di tocco separata.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          actions[index],
          if (index < actions.length - 1) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

/// Un comando della riga: l'icona e, accanto, il suo numero.
class _Action extends StatefulWidget {
  const _Action({
    required this.onTap,
    required this.icon,
    required this.color,
    required this.label,
    required this.tooltip,
    this.vertical = false,
  });

  final VoidCallback? onTap;
  final IconData icon;
  final Color color;
  final String label;
  final String tooltip;
  final bool vertical;

  @override
  State<_Action> createState() => _ActionState();
}

class _ActionState extends State<_Action> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: GestureDetector(
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: widget.onTap == null
            ? null
            : (_) {
                setState(() => _pressed = false);
                widget.onTap?.call();
              },
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? .9 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: _pressed ? .25 : .18),
                  Colors.black.withValues(alpha: .30),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: .24)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Flex(
              direction: widget.vertical ? Axis.vertical : Axis.horizontal,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    widget.icon,
                    key: ValueKey(widget.icon),
                    size: 27,
                    color: widget.color,
                  ),
                ),
                if (widget.label.isNotEmpty) ...[
                  SizedBox(
                    width: widget.vertical ? 0 : 6,
                    height: widget.vertical ? 3 : 0,
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Text(
                      widget.label,
                      key: ValueKey(widget.label),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: widget.color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
