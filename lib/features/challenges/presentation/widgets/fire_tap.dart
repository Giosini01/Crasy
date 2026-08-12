import 'package:crasy/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// Doppio tocco sulla foto: fiamma.
///
/// E' il gesto che tutti conoscono gia', quindi non va spiegato — ma va
/// **confermato**: un doppio tocco che non produce niente sullo schermo lascia
/// il dubbio di non aver premuto abbastanza forte. Da qui la fiamma che sboccia
/// al centro e sparisce in poco piu' di mezzo secondo.
///
/// L'animazione parte solo quando il tocco **accende** la fiamma. Al doppio
/// tocco su una foto gia' votata non succede niente di visibile e il voto resta:
/// e' l'unico comportamento sensato, perche' nessuno fa due volte lo stesso
/// gesto per disfare quello che ha appena fatto.
///
/// Il tocco singolo resta libero: lo usa chi apre la foto o la challenge.
class FireTap extends StatefulWidget {
  const FireTap({
    required this.child,
    required this.voted,
    required this.onFire,
    this.onTap,
    super.key,
  });

  final Widget child;

  /// Se la fiamma e' gia' accesa. Serve a decidere se animare.
  final bool voted;

  /// Chiamata al doppio tocco, sempre — anche a fiamma gia' accesa, dove non
  /// deve cambiare niente.
  final VoidCallback onFire;

  final VoidCallback? onTap;

  @override
  State<FireTap> createState() => _FireTapState();
}

class _FireTapState extends State<FireTap> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final wasVoted = widget.voted;

    widget.onFire();

    if (!wasVoted) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: _handleDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          // `IgnorePointer` e non un semplice widget sopra: la fiamma copre
          // tutta la foto mentre e' visibile, e senza si mangerebbe i tocchi
          // successivi proprio nel mezzo del doppio tocco.
          IgnorePointer(child: _FireBurst(animation: _controller)),
        ],
      ),
    );
  }
}

class _FireBurst extends StatelessWidget {
  const _FireBurst({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;

        if (t == 0) {
          return const SizedBox.shrink();
        }

        // Entra di scatto e se ne va piano: la scala si ferma nel primo terzo,
        // l'opacita' occupa tutto il resto. E' il contrario di una dissolvenza
        // simmetrica, e assomiglia a come si comporta una fiamma vera.
        final scale = 0.4 + Curves.easeOutBack.transform((t * 3).clamp(0, 1));
        final opacity = t < 0.35 ? 1.0 : 1 - ((t - 0.35) / 0.65);

        return Opacity(
          opacity: opacity.clamp(0, 1),
          child: Transform.scale(
            scale: scale,
            child: Icon(
              Icons.local_fire_department,
              size: 88,
              color: palette.accent,
            ),
          ),
        );
      },
    );
  }
}
