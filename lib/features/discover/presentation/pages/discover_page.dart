import 'dart:ui';

import 'package:app_incontri/core/constants/app_routes.dart';
import 'package:app_incontri/core/theme/app_palette.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_shadows.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/core/utils/app_date_utils.dart';
import 'package:app_incontri/core/widgets/app_background.dart';
import 'package:app_incontri/core/widgets/brand_mark.dart';
import 'package:app_incontri/features/daily/domain/entities/daily_access.dart';
import 'package:app_incontri/features/daily/presentation/providers/daily_providers.dart';
import 'package:app_incontri/features/daily/presentation/widgets/window_status_card.dart';
import 'package:app_incontri/features/feed/domain/entities/feed_person.dart';
import 'package:app_incontri/features/feed/presentation/controllers/feed_decision_controller.dart';
import 'package:app_incontri/features/feed/presentation/pages/person_profile_page.dart';
import 'package:app_incontri/features/feed/presentation/providers/feed_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(dailyAccessProvider);

    if (!access.discoverUnlocked) {
      return _TeaserDiscover(access: access);
    }

    return const _FeedView();
  }
}

/// L'impaginazione comune a tutte le versioni del Feed.
///
/// Sopra c'e' il solo logotipo, centrato; sotto, tutto lo spazio va alla
/// persona che si sta guardando. Niente schede e niente filtri: una riga di
/// comandi in cima ruberebbe altezza alla foto, che e' l'unica cosa per cui si
/// apre questa pagina.
class _FeedScaffold extends StatelessWidget {
  const _FeedScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const _FeedHeader(),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Solo il logotipo, in alto a sinistra.
///
/// Niente altro: ogni punto rubato qui e' un punto in meno per la foto, che e'
/// il motivo per cui si e' aperta l'app. La striscia di giorni sta nella
/// pagina dell'Istantanea, dove e' pertinente.
class _FeedHeader extends StatelessWidget {
  const _FeedHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: BrandWordmark(height: 22),
      ),
    );
  }
}

/// Il Feed aperto: una persona alla volta, come un mazzo.
class _FeedView extends ConsumerWidget {
  const _FeedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(feedPeopleProvider);

    // Serve a distinguere due vuoti che si assomigliano ma non sono lo stesso:
    // non e' arrivato ancora nessuno, oppure sono stati valutati tutti.
    final arrived = ref.watch(todayFeedProvider).valueOrNull ?? const [];

    return _FeedScaffold(
      child: people.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _FeedMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Non riusciamo a caricare il Feed.',
          description: 'Riprova fra poco.',
        ),
        data: (list) {
          if (list.isEmpty) {
            final seenEveryone = arrived.isNotEmpty;

            return _FeedMessage(
              icon: seenEveryone
                  ? Icons.check_rounded
                  : Icons.hourglass_empty_rounded,
              title: seenEveryone
                  ? 'Per oggi hai visto tutti.'
                  : 'Ancora nessuno, per oggi.',
              description:
                  'Qui compaiono solo le istantanee di chi ti sta vicino ed e '
                  'compatibile con te. Torna piu tardi.',
            );
          }

          return _Deck(people: list);
        },
      ),
    );
  }
}

/// Il mazzo, con la scheda che si trascina.
///
/// **Destra il cuore, sinistra lo scarto**, come in ogni app di questo tipo:
/// chi ci arriva ha gia' il gesto nelle mani, e con il verso invertito
/// passerebbe persone per sbaglio — cosa che qui non si puo' annullare.
///
/// Il trascinamento e i due tasti finiscono nello stesso posto: la scheda vola
/// via dal lato della scelta. Il gesto e' quindi anche un modo per imparare
/// cosa fanno i tasti, e viceversa.
class _Deck extends ConsumerStatefulWidget {
  const _Deck({required this.people});

  final List<FeedPerson> people;

  @override
  ConsumerState<_Deck> createState() => _DeckState();
}

class _DeckState extends ConsumerState<_Deck>
    with SingleTickerProviderStateMixin {
  /// Quanto la scheda si e' spostata rispetto al centro.
  double _offset = 0;

  /// Vera mentre la scheda sta volando via: da li' non si torna indietro, e
  /// un secondo tocco non deve registrare una seconda decisione.
  bool _leaving = false;

  /// Costruito in `initState` e non con un inizializzatore pigro: se la
  /// scheda sparisce senza che nessuno l'abbia mai trascinata, il primo
  /// accesso sarebbe quello di `dispose`, e creare un ticker mentre il widget
  /// si sta smontando fa esplodere l'albero.
  late final AnimationController _controller;

  Animation<double>? _travel;

  /// Oltre questa frazione della larghezza il gesto vale come scelta.
  static const double _commitFraction = 0.26;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_Deck oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Persona nuova: la scheda torna al centro. Senza questo, quella dopo
    // entrerebbe gia' spostata di lato.
    if (oldWidget.people.first.userId != widget.people.first.userId) {
      _controller.stop();
      setState(() {
        _offset = 0;
        _leaving = false;
        _travel = null;
      });
    }
  }

  void _animateTo(double target, {required VoidCallback? onArrival}) {
    _travel = Tween<double>(begin: _offset, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() => setState(() => _offset = _travel!.value));

    _controller
      ..reset()
      ..forward().whenComplete(() => onArrival?.call());
  }

  Future<void> _decide({required bool liked, String? message}) {
    return ref
        .read(feedDecisionControllerProvider.notifier)
        .decide(
          targetId: widget.people.first.userId,
          liked: liked,
          message: message,
        );
  }

  /// Manda via la scheda e registra la scelta a movimento finito.
  void _fling({required bool liked, String? message}) {
    if (_leaving) {
      return;
    }

    final width = MediaQuery.sizeOf(context).width;

    setState(() => _leaving = true);
    _animateTo(
      liked ? width * 1.3 : -width * 1.3,
      onArrival: () => _decide(liked: liked, message: message),
    );
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_leaving) {
      return;
    }

    setState(() => _offset += details.delta.dx);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_leaving) {
      return;
    }

    final width = MediaQuery.sizeOf(context).width;
    final velocity = details.primaryVelocity ?? 0;
    final farEnough = _offset.abs() > width * _commitFraction;

    // Anche un colpo secco vale, senza dover arrivare a meta' schermo: e' il
    // gesto che fa chi sa gia' cosa vuole.
    final flicked = velocity.abs() > 700;

    if (farEnough || flicked) {
      _fling(liked: flicked ? velocity > 0 : _offset > 0);
      return;
    }

    _animateTo(0, onArrival: null);
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.people.first;
    final isDeciding = ref.watch(feedDecisionControllerProvider).isLoading;
    final width = MediaQuery.sizeOf(context).width;
    final progress = (_offset / (width * _commitFraction)).clamp(-1.0, 1.0);

    Future<void> likeWithMessage() async {
      final written = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _MessageSheet(name: person.name),
      );

      if (written != null && mounted) {
        _fling(liked: true, message: written);
      }
    }

    void openProfile() {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => PersonProfilePage(
            person: person,
            onDecide: ({required bool liked}) => _decide(liked: liked),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: Transform.translate(
                offset: Offset(_offset, 0),
                // La rotazione e' minima e legata allo spostamento: da' peso
                // al gesto senza farlo sembrare un giocattolo.
                child: Transform.rotate(
                  angle: _offset / width * 0.28,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // La chiave lega lo stato della scheda alla persona:
                      // passando alla successiva la sequenza riparte
                      // dall'ultima istantanea invece di ereditare l'indice.
                      _PersonCard(
                        key: ValueKey(person.userId),
                        person: person,
                        onOpenProfile: openProfile,
                      ),
                      // Il verdetto compare **mentre** si trascina, prima di
                      // lasciare: cosi' non si scopre a cose fatte di aver
                      // scartato qualcuno, e si puo' tornare indietro.
                      if (progress != 0)
                        IgnorePointer(
                          child: _SwipeStamp(progress: progress),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _DecisionRow(
            enabled: !isDeciding && !_leaving,
            onPass: () => _fling(liked: false),
            onLike: () => _fling(liked: true),
            onLikeWithMessage: likeWithMessage,
          ),
        ],
      ),
    );
  }
}

/// Il timbro che compare sulla foto mentre la si trascina.
class _SwipeStamp extends StatelessWidget {
  const _SwipeStamp({required this.progress});

  /// Da -1 (scarto pieno) a 1 (cuore pieno).
  final double progress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final liked = progress > 0;
    final strength = progress.abs();
    final color = liked ? palette.brand : palette.danger;

    return Opacity(
      opacity: strength,
      child: Align(
        alignment: liked ? Alignment.topLeft : Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Transform.rotate(
            angle: liked ? -0.22 : 0.22,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: color, width: 3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    liked ? Icons.favorite_rounded : Icons.close_rounded,
                    color: color,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    liked ? 'MI PIACE' : 'PASSA',
                    style: context.texts.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// I due tasti sotto la scheda.
///
/// Sono solo due — passa e mi piace — perche' sono le uniche due decisioni che
/// il resto dell'app sa registrare davvero.
class _DecisionRow extends StatelessWidget {
  const _DecisionRow({
    required this.enabled,
    required this.onPass,
    required this.onLike,
    this.onLikeWithMessage,
  });

  final bool enabled;
  final VoidCallback onPass;
  final VoidCallback onLike;

  /// Il cuore con una riga allegata. Assente nell'assaggio, dove le decisioni
  /// non si registrano.
  final VoidCallback? onLikeWithMessage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _DecisionButton(
          icon: Icons.close_rounded,
          label: 'Passa',
          enabled: enabled,
          onPressed: onPass,
        ),
        const SizedBox(width: AppSpacing.lg),
        // Sta in mezzo e piu' piccolo dei due: e' una variante del cuore, non
        // una terza decisione. Il tocco sul cuore resta immediato — chi vuole
        // scrivere fa un gesto in piu', chi non vuole non ne fa nessuno.
        if (onLikeWithMessage != null)
          _DecisionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Mi piace, con un messaggio',
            enabled: enabled,
            small: true,
            onPressed: onLikeWithMessage!,
          ),
        if (onLikeWithMessage != null) const SizedBox(width: AppSpacing.lg),
        _DecisionButton(
          icon: Icons.favorite_rounded,
          label: 'Mi piace',
          filled: true,
          enabled: enabled,
          onPressed: onLike,
        ),
      ],
    );
  }
}

/// Il foglio per scrivere la riga da allegare al cuore.
class _MessageSheet extends StatefulWidget {
  const _MessageSheet({required this.name});

  final String name;

  @override
  State<_MessageSheet> createState() => _MessageSheetState();
}

class _MessageSheetState extends State<_MessageSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scrivi a ${widget.name}',
                style: context.texts.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xxs),
              // Detto subito: e' l'informazione che decide se scrivere o no.
              Text(
                'Lo legge solo se ricambia. Altrimenti non lo sapra mai.',
                style: context.texts.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _controller,
                maxLength: 200,
                maxLines: 3,
                minLines: 1,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Anche io adoro la montagna.',
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ElevatedButton.icon(
                onPressed: () {
                  final text = _controller.text.trim();

                  Navigator.of(context).pop(text.isEmpty ? null : text);
                },
                icon: const Icon(Icons.favorite_rounded, size: 20),
                label: const Text('Invia con il cuore'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le Daily di una persona sfogliate come una storia: si tocca a sinistra per
/// andare indietro nel tempo, a destra per tornare verso l'ultima.
class _PersonCard extends ConsumerStatefulWidget {
  const _PersonCard({
    required this.person,
    required this.onOpenProfile,
    this.locked = false,
    super.key,
  });

  final FeedPerson person;
  final VoidCallback onOpenProfile;

  /// Scheda velata: la foto si intravede ma non si legge, e al centro compare
  /// l'avviso. E' la versione per chi non ha ancora pubblicato la sua.
  final bool locked;

  @override
  ConsumerState<_PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends ConsumerState<_PersonCard> {
  /// Indice nella lista, che va dalla piu' recente alla piu' vecchia.
  int _index = 0;

  int get _count => widget.person.dailies.length;

  void _older() {
    if (_index >= _count - 1) {
      return;
    }

    setState(() => _index++);
  }

  void _newer() {
    if (_index <= 0) {
      return;
    }

    setState(() => _index--);
  }

  /// Le barrette contano al contrario dell'indice: la prima a sinistra e' la
  /// piu' vecchia, mentre l'indice zero e' l'ultima scattata.
  void _goTo(int segment) {
    setState(() => _index = _count - 1 - segment);
  }


  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final person = widget.person;
    final daily = person.dailies[_index];
    final locked = widget.locked;

    // Lo sguardo si conta quando la foto e' davvero sullo schermo, non quando
    // arriva nel feed: una scheda velata o mai raggiunta non e' stata vista.
    if (!locked) {
      ref.read(feedSeenControllerProvider).mark(daily.dailyId);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.lifted,
      ),
      child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: ColoredBox(
        color: palette.surfaceMuted,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (daily.photoUrl.isEmpty)
              const _PhotoError(
                message: 'Questa istantanea non ha una foto collegata.',
              )
            else
              Image.network(
                daily.photoUrl,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                // Se lo scaricamento dei byte fallisce, Flutter ripiega su un
                // vero elemento <img> del browser, che per mostrare
                // un'immagine non ha bisogno del consenso CORS. Copre i casi
                // in cui la richiesta viene rifiutata pur essendo l'immagine
                // perfettamente leggibile.
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }

                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, _, _) => const _PhotoError(),
              ),
            if (locked)
              // Il velo copre solo la foto, non le scritte: nome, distanza e
              // affinita' restano leggibili, ed e' proprio il contrasto fra
              // quello che si legge e la faccia che non si vede a spingere a
              // scattare.
              IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                  child: ColoredBox(
                    color: palette.background.withValues(alpha: 0.2),
                  ),
                ),
              ),
            // Le due zone di tocco stanno sopra la foto ma sotto le altre
            // sovrapposizioni, cosi' il gesto copre tutta l'immagine.
            //
            // Qui **non** c'e' piu' lo scorrimento col dito: quel gesto ora
            // sposta l'intera scheda per scegliere, e due trascinamenti
            // orizzontali sovrapposti se lo contenderebbero. Per passare fra
            // le Istantanee restano il tocco, le frecce e le barrette.
            if (!locked && _count > 1)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _older,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _newer,
                    ),
                  ),
                ],
              ),
            // Le frecce compaiono solo quando c'e' davvero un'altra istantanea
            // da vedere, e sono **tasti veri**: prima erano disegni sotto un
            // `IgnorePointer`, quindi chi le vedeva e le premeva non otteneva
            // niente. Sono anche l'unico comando che resta raggiungibile se il
            // tocco sull'immagine non arriva.
            if (!locked && _index < _count - 1)
              Positioned(
                left: AppSpacing.xs,
                top: 0,
                bottom: 0,
                child: _StoryArrow(
                  icon: Icons.chevron_left_rounded,
                  label: 'Istantanea precedente',
                  onTap: _older,
                ),
              ),
            if (!locked && _index > 0)
              Positioned(
                right: AppSpacing.xs,
                top: 0,
                bottom: 0,
                child: _StoryArrow(
                  icon: Icons.chevron_right_rounded,
                  label: 'Istantanea successiva',
                  onTap: _newer,
                ),
              ),
            Positioned(
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              top: AppSpacing.sm,
              child: _StorySegments(
                count: _count,
                current: _index,
                onSelect: _goTo,
              ),
            ),
            // L'etichetta del momento in alto accanto all'orario: sono le due
            // cose che dicono "adesso", e stanno insieme.
            if (person.hasVibe)
              Positioned(
                left: AppSpacing.sm,
                top: AppSpacing.md + 4,
                child: IgnorePointer(child: _VibeTag(text: person.vibe)),
              ),
            Positioned(
              right: AppSpacing.sm,
              top: AppSpacing.md + 4,
              child: IgnorePointer(
                // Letto qui e non da un orologio che batte: la targhetta si
                // aggiorna quando la scheda si ridisegna, e nessuno resta a
                // fissare la stessa foto abbastanza da vedere "2h" diventare
                // "3h" sotto i propri occhi.
                child: _TimeChip(
                  label: AppDateUtils.shortTimeAgo(daily.capturedAt),
                ),
              ),
            ),
            if (locked)
              Center(child: _LockedNotice(access: ref.watch(dailyAccessProvider))),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _PersonBanner(
                person: person,
                onOpenProfile: widget.onOpenProfile,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Da quanto e' stata scattata l'Istantanea che si sta guardando.
///
/// E' la sola cosa che distingue una foto di oggi da una di tre ore fa, e su
/// un'app dove conta l'adesso vale piu' di qualunque altra etichetta.
class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Il punto pulsante dice che e' roba di adesso, non una foto
          // profilo qualunque: e' la differenza che l'app deve far sentire.
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF34C759),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const SizedBox(width: 3),
          Text(
            label,
            style: context.texts.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// L'avviso al centro della scheda velata.
class _LockedNotice extends StatelessWidget {
  const _LockedNotice({required this.access});

  final DailyAccess access;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.background.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              access.verifying
                  ? Icons.hourglass_top_rounded
                  : Icons.blur_on_rounded,
              size: 26,
              color: palette.brand,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              // Impersonale di proposito: nel feed puo' esserci chiunque, e
              // una frase al femminile stonerebbe per meta' delle persone che
              // la leggono.
              access.verifying
                  ? 'Ci siamo quasi.'
                  : 'Qualcuno si e gia fatto vedere.',
              textAlign: TextAlign.center,
              style: context.texts.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              access.verifying
                  ? 'Stiamo controllando la tua Istantanea: appena e pronta, '
                        'questa foto si mette a fuoco.'
                  : 'Resta sfocata finche non fai la tua Istantanea. '
                        'Si vede chi si fa vedere.',
              textAlign: TextAlign.center,
              style: context.texts.bodySmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (access.verifying)
              const CircularProgressIndicator()
            else if (access.canCapture)
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.camera),
                child: const Text('Scatta la tua Istantanea'),
              )
            else ...[
              WindowStatusCard(access: access),
              const SizedBox(height: AppSpacing.sm),
              const WindowScheduleLine(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Freccia sul bordo della foto: da quel lato c'e' un'altra istantanea, e
/// premendola ci si va.
class _StoryArrow extends StatelessWidget {
  const _StoryArrow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.black.withValues(alpha: 0.42),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              height: 40,
              width: 40,
              child: Icon(icon, size: 24, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barrette in cima alla scheda, una per Daily.
///
/// Sono disegnate dalla piu' vecchia alla piu' recente, da sinistra a destra,
/// mentre l'indice conta al contrario: la scheda si apre sull'ultima foto.
class _StorySegments extends StatelessWidget {
  const _StorySegments({
    required this.count,
    required this.current,
    required this.onSelect,
  });

  final int count;
  final int current;

  /// Anche le barrette portano alla loro istantanea: e' il gesto che si fa
  /// d'istinto quando si vede una barra divisa in pezzi, e vale come terza
  /// via se il tocco sulla foto non arriva.
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    if (count < 2) {
      return const SizedBox.shrink();
    }

    final activeSegment = count - 1 - current;

    return Row(
      children: [
        for (var index = 0; index < count; index++) ...[
          if (index > 0) const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(index),
              // La zona toccabile e' molto piu' alta della barretta disegnata:
              // tre pixel non si centrano col pollice.
              child: SizedBox(
                height: 22,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 3,
                    decoration: BoxDecoration(
                      color: index == activeSegment
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Nome, eta', distanza e rompighiaccio sul fondo della foto.
class _PersonBanner extends StatelessWidget {
  const _PersonBanner({required this.person, required this.onOpenProfile});

  final FeedPerson person;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xxl,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        // La sfumatura serve a garantire il contrasto del testo su qualunque
        // foto, anche chiarissima.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.78),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  '${person.name}, ${person.age}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              if (person.hasPhoto) ...[
                const SizedBox(width: AppSpacing.xxs),
                // Non e' un vezzo: il server ha guardato la foto profilo di
                // questa persona e ci ha riconosciuto un volto. Dice quello, e
                // niente di piu'.
                const Tooltip(
                  message: 'Foto profilo verificata',
                  child: Icon(
                    Icons.verified_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ],
              const Spacer(),
              _InfoButton(onTap: onOpenProfile),
            ],
          ),
          const SizedBox(height: 2),
          // Distanza e interessi in comune su una riga sola, separati da un
          // punto: sono due dati brevi, e due righe per due dati sono una
          // riga di troppo sopra una foto.
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 14, color: Colors.white70),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(
                child: Text(
                  person.sharedInterests.isEmpty
                      ? person.distanceLabel
                      : '${person.distanceLabel} · '
                            '${person.sharedInterestsLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          if (person.hasIcebreaker) ...[
            const SizedBox(height: AppSpacing.sm),
            // L'"Oggi..." sulla foto: e' l'esca, il resto si legge aprendo il
            // profilo.
            _IcebreakerChip(text: person.icebreaker),
          ],
        ],
      ),
    );
  }
}

/// L'etichetta del momento posata sulla foto.
class _VibeTag extends StatelessWidget {
  const _VibeTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.texts.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// La frase da cui partire, dentro una pillola sua.
///
/// Sta in un riquadro invece che a testo libero perche' non e' una didascalia
/// della foto: e' roba scritta dalla persona, e va letta come tale.
class _IcebreakerChip extends StatelessWidget {
  const _IcebreakerChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.auto_awesome,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Il tasto che apre il profilo intero.
class _InfoButton extends StatelessWidget {
  const _InfoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Apri il profilo',
      child: Material(
        color: Colors.white.withValues(alpha: 0.22),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            height: 34,
            width: 34,
            child: Icon(
              Icons.info_outline_rounded,
              size: 19,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoError extends StatelessWidget {
  const _PhotoError({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 32,
              color: palette.textSecondary,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message ?? 'Foto non disponibile',
              textAlign: TextAlign.center,
              style: context.texts.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionButton extends StatefulWidget {
  const _DecisionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.filled = false,
    this.small = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  /// Il cuore e' pieno di viola, lo scarto no: l'azione che porta avanti la
  /// storia e' l'unica colorata.
  final bool filled;

  /// Le varianti secondarie, piu' piccole dei due tasti principali.
  final bool small;

  @override
  State<_DecisionButton> createState() => _DecisionButtonState();
}

class _DecisionButtonState extends State<_DecisionButton> {
  /// Il tasto si schiaccia sotto il dito e rimbalza al rilascio.
  ///
  /// Su un'azione irreversibile la risposta al tocco non e' un vezzo: e' la
  /// conferma che il dito ha preso, ed e' l'unica cosa che si vede prima che
  /// la scheda cominci a volare via.
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final filled = widget.filled;
    final small = widget.small;
    final enabled = widget.enabled;
    final icon = widget.icon;
    final label = widget.label;
    final onPressed = widget.onPressed;
    final size = filled
        ? 72.0
        : small
        ? 48.0
        : 60.0;

    return Semantics(
      button: true,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: AnimatedScale(
          scale: _pressed ? 0.86 : 1,
          duration: Duration(milliseconds: _pressed ? 90 : 220),
          // Si schiaccia in fretta e rimbalza piano: e' il verso in cui si
          // muovono le cose vere.
          curve: _pressed ? Curves.easeOut : Curves.elasticOut,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: filled
                  ? AppShadows.brand(palette.brand)
                  : AppShadows.soft,
            ),
            child: Material(
              color: filled ? palette.brand : palette.surface,
              shape: CircleBorder(
                side: filled
                    ? BorderSide.none
                    : BorderSide(color: palette.border, width: 1.5),
              ),
              child: InkWell(
                onTap: enabled ? onPressed : null,
                onTapDown: enabled ? (_) => _setPressed(true) : null,
                onTapUp: (_) => _setPressed(false),
                onTapCancel: () => _setPressed(false),
                customBorder: const CircleBorder(),
                child: SizedBox(
                  height: size,
                  width: size,
                  child: Icon(
                    icon,
                    size: filled ? 32 : (small ? 21 : 26),
                    // Rosso solo sulla croce: il messaggio non e' un rifiuto.
                    color: filled
                        ? palette.onBrand
                        : (small ? palette.textSecondary : palette.danger),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedMessage extends StatelessWidget {
  const _FeedMessage({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GlyphTile(icon: icon),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: context.texts.displaySmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                description,
                style: context.texts.bodyLarge?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Il Feed prima della propria Istantanea.
///
/// **La prima persona si vede davvero.** Una schermata interamente sfocata
/// chiede fiducia a chi non ha ancora visto niente; mostrare una faccia vera
/// e poi sfocare la seconda spiega il patto senza doverlo scrivere: qui c'e'
/// gente, e per vederla tutta tocca metterci la propria.
class _TeaserDiscover extends ConsumerStatefulWidget {
  const _TeaserDiscover({required this.access});

  final DailyAccess access;

  @override
  ConsumerState<_TeaserDiscover> createState() => _TeaserDiscoverState();
}

class _TeaserDiscoverState extends ConsumerState<_TeaserDiscover> {
  /// Vero dopo che si e' passata la prima persona: da li' in poi tutto e'
  /// sfocato.
  bool _passed = false;

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(feedPeopleProvider).valueOrNull ?? const [];

    // Senza nessuno da mostrare non c'e' assaggio possibile: si torna al
    // riquadro con la spiegazione.
    if (people.isEmpty) {
      return _LockedDiscover(access: widget.access);
    }

    if (_passed) {
      return _BlurredTeaser(
        person: people.length > 1 ? people[1] : people.first,
      );
    }

    return _FreePeek(
      person: people.first,
      onLike: () => context.go(AppRoutes.camera),
      onPass: () => setState(() => _passed = true),
    );
  }
}

/// La prima persona, in chiaro. I due tasti ci sono ma portano altrove: il
/// cuore alla fotocamera, la croce alla seconda foto sfocata.
class _FreePeek extends StatelessWidget {
  const _FreePeek({
    required this.person,
    required this.onLike,
    required this.onPass,
  });

  final FeedPerson person;
  final VoidCallback onLike;
  final VoidCallback onPass;

  @override
  Widget build(BuildContext context) {
    return _FeedScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _PersonCard(
                key: ValueKey(person.userId),
                person: person,
                onOpenProfile: onLike,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _DecisionRow(enabled: true, onPass: onPass, onLike: onLike),
          ],
        ),
      ),
    );
  }
}

/// La seconda persona, velata, con l'avviso sopra la scheda.
class _BlurredTeaser extends StatelessWidget {
  const _BlurredTeaser({required this.person});

  final FeedPerson person;

  @override
  Widget build(BuildContext context) {
    return _FeedScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _PersonCard(
                key: ValueKey(person.userId),
                person: person,
                locked: true,
                onOpenProfile: () {},
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // I tasti restano visibili ma spenti: si vede che cosa si sta
            // perdendo, non si finge che non ci sia niente.
            _DecisionRow(enabled: false, onPass: () {}, onLike: () {}),
          ],
        ),
      ),
    );
  }
}

/// Ripiego per quando non c'e' nessuno da mostrare in anteprima.
///
/// Dietro il velo c'e' un finto feed sfocato invece di uno sfondo vuoto: si
/// deve capire che qualcosa c'e' gia' e che manca solo un gesto per vederlo.
class _LockedDiscover extends StatelessWidget {
  const _LockedDiscover({required this.access});

  final DailyAccess access;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: AppBackground(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _BlurredFeed(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: palette.background,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GlyphTile(
                            icon: access.verifying
                                ? Icons.hourglass_top_rounded
                                : Icons.photo_camera_rounded,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            access.verifying
                                ? 'Ci siamo quasi.'
                                : 'Prima tocca a te.',
                            style: context.texts.displaySmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            access.verifying
                                ? 'Stiamo controllando la tua Istantanea. '
                                      'Appena e pronta, tutto questo si mette '
                                      'a fuoco.'
                                : 'Dietro c\'e gia chi ti aspetta, ma resta '
                                      'sfocato finche non fai la tua '
                                      'Istantanea. Si vede chi si fa vedere.',
                            style: context.texts.bodyLarge?.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (access.verifying)
                            const Center(child: CircularProgressIndicator())
                          else if (access.canCapture)
                            ElevatedButton(
                              onPressed: () => context.go(AppRoutes.camera),
                              child: const Text('Scatta la tua Istantanea'),
                            )
                          else ...[
                            WindowStatusCard(access: access),
                            const SizedBox(height: AppSpacing.md),
                            const Center(child: WindowScheduleLine()),
                          ],
                        ],
                      ),
                    ),
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

/// Finto feed sfocato. Non e' contenuto reale: serve solo a dare corpo al
/// velo, quindi non intercetta i tocchi.
class _BlurredFeed extends StatelessWidget {
  const _BlurredFeed();

  static const _tileHeights = <double>[172, 132, 128, 184, 156, 144];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _TileColumn(heights: _evenTiles)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _TileColumn(heights: _oddTiles)),
                ],
              ),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: ColoredBox(
                color: palette.background.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<double> get _evenTiles => [
    for (var i = 0; i < _tileHeights.length; i += 2) _tileHeights[i],
  ];

  static List<double> get _oddTiles => [
    for (var i = 1; i < _tileHeights.length; i += 2) _tileHeights[i],
  ];
}

class _TileColumn extends StatelessWidget {
  const _TileColumn({required this.heights});

  final List<double> heights;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // Le tessere hanno altezza fissa e su uno schermo basso non ci starebbero.
    // Essendo decorative si lasciano crescere oltre il bordo e si ritagliano,
    // invece di far comparire la barra gialla di overflow.
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, height) in heights.indexed) ...[
              Container(
                height: height,
                decoration: BoxDecoration(
                  // Una tessera su tre e' viola tenue: sotto il velo si
                  // intravedono forme diverse, e sembra un feed vero invece di
                  // una griglia grigia.
                  color: index.isEven ? palette.surfaceMuted : palette.brandTint,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                // Un cerchio in alto, come il volto di una foto sfocata.
                child: Align(
                  alignment: const Alignment(0, -0.45),
                  child: Container(
                    width: height * 0.34,
                    height: height * 0.34,
                    decoration: BoxDecoration(
                      color: palette.border,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}
