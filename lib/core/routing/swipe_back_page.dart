import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';

/// Una pagina che si tira via col dito, **e la si vede muoversi mentre lo fai**.
///
/// ## Cosa c'era prima, e perche' non bastava
///
/// Il primo tentativo era un rilevatore di gesti sopra la pagina: misurava il
/// trascinamento e, al rilascio, chiamava `pop`. Funzionava e sembrava rotto —
/// perche' **durante il gesto non succedeva niente**. Si trascinava il dito su
/// una schermata ferma, si lasciava, e solo allora la pagina scivolava via. Non
/// e' un dettaglio estetico: un gesto che non risponde mentre lo fai non si
/// capisce che c'e', e chi lo prova conclude che l'app non lo abbia.
///
/// La ragione e' che quel rilevatore non poteva far muovere niente. Sotto la
/// pagina che sta sopra c'e' quella di prima, e a disegnarle tutte e due —
/// una che esce a destra, l'altra che rientra da sinistra un po' piu' lenta —
/// e' l'animazione **della rotta**, non un widget dentro di essa. Spostare col
/// dito la pagina di sopra avrebbe scoperto il nero, non la schermata di prima.
///
/// ## Come funziona adesso
///
/// Il dito guida direttamente l'animazione della rotta: `1` e' la pagina
/// aperta, `0` e' fuori dallo schermo. Trascinando, il valore scende in
/// proporzione a quanto ci si e' spostati, e Flutter disegna **tutte e due** le
/// schermate a quel punto esatto del viaggio. Al rilascio si decide dove
/// andare: oltre meta' schermo — o con un colpo secco — si finisce di uscire e
/// la rotta si chiude; altrimenti si torna indietro.
///
/// E' cio' che fa iPhone da sempre. Lo fa anche `CupertinoPage`, ma solo se il
/// gesto **parte dai venti punti all'estrema sinistra**: qui parte da
/// qualunque punto dello schermo, che era tutto il motivo per cui ci siamo
/// messi le mani.
///
/// Durante il gesto l'animazione e' **lineare**: la pagina deve stare sotto il
/// dito, non inseguirlo con una molla. La curva torna appena si lascia.
class SwipeBackPage<T> extends Page<T> {
  const SwipeBackPage({
    required this.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => _SwipeBackRoute<T>(this);
}

class _SwipeBackRoute<T> extends PageRoute<T> {
  _SwipeBackRoute(SwipeBackPage<T> page) : super(settings: page);

  /// Sopra questa velocita' il gesto vale come deciso, per corto che sia.
  /// E' in schermi al secondo: uno vuol dire "tutto lo schermo in un secondo".
  static const double _minFlingVelocity = 1;

  Widget get _child => (settings as SwipeBackPage<T>).child;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _child;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return CupertinoPageTransition(
      primaryRouteAnimation: animation,
      secondaryRouteAnimation: secondaryAnimation,
      linearTransition: navigator?.userGestureInProgress ?? false,
      child: _Dragger(route: this, child: child),
    );
  }

  /// Se in questo momento la pagina si puo' tirare via.
  ///
  /// Sono le stesse condizioni che si pone iPhone: non si trascina la prima
  /// schermata di tutte, non si trascina qualcosa che ha gia' detto di non
  /// volersi chiudere, e non si comincia un gesto mentre ne e' in corso un
  /// altro o mentre la pagina sta gia' entrando o uscendo.
  bool get _canSwipe {
    return !isFirst &&
        !willHandlePopInternally &&
        popDisposition != RoutePopDisposition.doNotPop &&
        !fullscreenDialog &&
        animation?.status == AnimationStatus.completed &&
        secondaryAnimation?.status == AnimationStatus.dismissed &&
        !(navigator?.userGestureInProgress ?? true);
  }

  void _dragStart() {
    navigator?.didStartUserGesture();
  }

  /// Il dito ha percorso [fraction] di schermo verso destra.
  void _dragUpdate(double fraction) {
    final animation = controller;

    if (animation == null) {
      return;
    }

    animation.value = (animation.value - fraction).clamp(0.0, 1.0);
  }

  /// Il dito si e' alzato: si finisce di uscire, o si torna com'era.
  void _dragEnd(double velocity) {
    final animation = controller;
    final navigator = this.navigator;

    if (animation == null || navigator == null) {
      return;
    }

    // Un colpo secco decide da solo, anche se corto. Senza colpo, decide da
    // dove si e' arrivati: oltre meta' schermo si esce.
    const curve = Curves.fastLinearToSlowEaseIn;
    final goesBackToPlace = velocity.abs() >= _minFlingVelocity
        ? velocity <= 0
        : animation.value > 0.5;

    if (goesBackToPlace) {
      // Il tempo dipende da quanta strada resta: una pagina quasi a posto non
      // ci mette lo stesso di una a meta' schermo.
      final milliseconds = lerpDouble(800, 0, animation.value)!.floor();
      animation.animateTo(
        1,
        duration: Duration(milliseconds: milliseconds.clamp(0, 300)),
        curve: curve,
      );
    } else {
      navigator.pop();

      if (animation.isAnimating) {
        animation.animateBack(
          0,
          duration: Duration(
            milliseconds: lerpDouble(0, 800, animation.value)!.floor(),
          ),
          curve: curve,
        );
      }
    }

    if (animation.isAnimating) {
      // Il gesto e' finito solo quando l'animazione si ferma: dirlo prima
      // lascerebbe il navigatore convinto che si possa gia' cominciarne un
      // altro sopra a questo.
      void whenSettled(AnimationStatus status) {
        navigator.didStopUserGesture();
        animation.removeStatusListener(whenSettled);
      }

      animation.addStatusListener(whenSettled);
    } else {
      navigator.didStopUserGesture();
    }
  }
}

/// Il dito che guida l'animazione della rotta.
///
/// Sta **dentro** la pagina e non attorno a essa: cosi' il gesto si puo'
/// cominciare da qualunque punto, invece che dal solo bordo sinistro.
///
/// Il trascinamento verticale non lo tocca: dentro schermate che scorrono in su
/// e in giu', un gesto orizzontale non se lo prende nessun altro.
class _Dragger extends StatefulWidget {
  const _Dragger({required this.route, required this.child});

  final _SwipeBackRoute<dynamic> route;
  final Widget child;

  @override
  State<_Dragger> createState() => _DraggerState();
}

class _DraggerState extends State<_Dragger> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return GestureDetector(
      // Niente `behavior: opaque`: sotto ci sono foto da toccare e fiamme da
      // accendere, e questo widget deve prendersi solo i trascinamenti
      // orizzontali.
      onHorizontalDragStart: (details) {
        _dragging = widget.route._canSwipe;

        if (_dragging) {
          widget.route._dragStart();
        }
      },
      onHorizontalDragUpdate: (details) {
        if (_dragging && width > 0) {
          widget.route._dragUpdate(details.primaryDelta! / width);
        }
      },
      onHorizontalDragEnd: (details) {
        if (!_dragging) {
          return;
        }

        _dragging = false;
        // Verso destra la velocita' e' positiva, ed e' il verso in cui si
        // esce: il segno qui e' la differenza fra una pagina che si chiude con
        // un colpetto e una che torna indietro proprio quando la stavi
        // buttando fuori.
        widget.route._dragEnd(
          width > 0 ? details.velocity.pixelsPerSecond.dx / width : 0,
        );
      },
      onHorizontalDragCancel: () {
        if (_dragging) {
          _dragging = false;
          // Un gesto annullato non e' una decisione: la pagina torna dov'era.
          widget.route._dragEnd(0);
        }
      },
      child: widget.child,
    );
  }
}
