import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/services/share/share_entry.dart';
import 'package:crasy/core/theme/app_colors.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/video_frame.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/controllers/vote_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/entry_comments.dart';
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

    if (entries.isEmpty) {
      return const SizedBox.shrink();
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
                // **I comandi stanno di lato, all'altezza del pollice.**
                //
                // Erano una fila di righe impilate in fondo — titolo,
                // didascalia, nome, e sotto tutto il resto i commenti: l'ultima
                // cosa dell'ultima riga, cioe' il posto peggiore in cui mettere
                // la cosa che si tocca di piu' dopo la fiamma.
                //
                // In colonna a destra ognuno e' un bersaglio grande, sono tutti
                // alla stessa distanza dalla mano, e soprattutto **non stanno
                // sotto la foto**: guardando un'immagine a tutto schermo non si
                // legge nulla in fondo, si guarda l'immagine.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _ActionRail(entry: current),
                  ),
                ),
                _BottomBar(entry: current),
              ],
            ),
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

    if (url.isEmpty) {
      return const SizedBox.shrink();
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
          // **La didascalia qui sotto, dritta.** Sulla miniatura corre curva sul
          // bordo della foto perche' li' e' un'anteprima: dice cosa c'e'
          // dentro senza rubare l'immagine. Aperta a tutto schermo la foto e'
          // la cosa che si sta guardando, e una scritta che le gira attorno si
          // mette in mezzo — quindi scende qui, in riga, dove si legge e basta.
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
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push(AppRoutes.userProfileOf(entry.userId));
                  },
                  child: Text(
                    '@${entry.authorName}',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: AppColors.paper),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          // **La didascalia non si ripete qui.** Corre sul bordo della foto,
          // sopra, ed e' li' che va letta: e' parte dell'immagine, non una riga
          // di servizio. Scritta anche qui sarebbe la stessa cosa detta due
          // volte, e la seconda toglierebbe forza alla prima.
          //
          // **I commenti spariscono alla sirena.**
          //
          // Non e' un permesso tolto: e' che un commento e' tifo, e il tifo si
          // fa durante. Sotto la foto di una gara finita restano il numero
          // delle fiamme e la didascalia, cioe' il risultato e quello che ha
          // detto chi l'ha scattata. Quello che si erano detti gli altri era di
          // quel momento, e li' resta.
        ],
      ),
    );
  }
}

/// I comandi in colonna, sul lato destro.
///
/// **Uno sopra l'altro e non in fila in fondo.** Su una foto a tutto schermo il
/// fondo e' il posto in cui si mettono le cose da leggere, non quelle da
/// toccare: una riga di icone li' sotto e' lontana dal pollice quanto il bordo
/// opposto, e l'ultima della riga — che era proprio "commenti" — e' la piu'
/// lontana di tutte.
///
/// In colonna hanno tutti la stessa distanza dalla mano, il bersaglio e' grande
/// quanto un dito, e il numero sta sotto l'icona invece che accanto: si legge
/// con un'occhiata sola senza allargare la fila.
class _ActionRail extends ConsumerWidget {
  const _ActionRail({required this.entry});

  final ChallengeEntry entry;

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

    return Padding(
      padding: const EdgeInsets.only(
        right: AppSpacing.sm,
        bottom: AppSpacing.md,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          _RailButton(
            // A gara finita il numero resta, ma non e' piu' un comando: quelle
            // fiamme hanno gia' deciso chi si prende i soldi.
            onTap: live
                ? () => giveFire(context, ref, entry, voted: !voted)
                : null,
            icon: voted
                ? Icons.local_fire_department
                : Icons.local_fire_department_outlined,
            color: voted ? AppColors.crasyRed : AppColors.paper,
            label: '$votes',
            tooltip: voted ? 'Togli la fiamma' : 'Dai la fiamma',
          ),
          // **I commenti spariscono alla sirena.** Non e' un permesso tolto:
          // un commento e' tifo, e il tifo si fa durante.
          if (live)
            _RailButton(
              onTap: () => showEntryComments(context, entry: entry),
              icon: Icons.mode_comment_outlined,
              color: AppColors.paper,
              label: comments == null || comments.isEmpty
                  ? ''
                  : '${comments.length}',
              tooltip: 'Commenti',
            ),
          // Condividere non sta nascosto in un menu: e' il gesto con cui chi e'
          // in gara si porta dentro i voti, ed e' anche il modo in cui CRASY
          // incontra gente che non la conosce.
          _RailButton(
            onTap: () => ShareEntry.send(
              context,
              challengeId: entry.challengeId,
              entryId: entry.id,
              challengeTitle: entry.challengeTitle,
              ended: !live,
            ),
            icon: Icons.ios_share_rounded,
            color: AppColors.paper,
            label: '',
            tooltip: 'Condividi',
          ),
        ],
      ),
    );
  }
}

/// Un comando della colonna: l'icona, e sotto il suo numero.
class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.onTap,
    required this.icon,
    required this.color,
    required this.label,
    required this.tooltip,
  });

  final VoidCallback? onTap;
  final IconData icon;
  final Color color;
  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // L'ombra sotto le icone: cadono su una foto qualunque, e su uno
              // scatto chiaro il bianco sparirebbe. E' la stessa ragione per
              // cui la didascalia ha il suo alone.
              Icon(
                icon,
                size: 30,
                color: color,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
