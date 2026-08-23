import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/widgets/media_gestures.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/controllers/vote_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Doppio tocco sulla foto: fiamma.
///
/// E' il gesto che tutti conoscono gia', quindi non va spiegato — ma va
/// **confermato**: un doppio tocco che non produce niente sullo schermo lascia
/// il dubbio di non aver premuto abbastanza forte. Da qui la fiamma che sboccia
/// al centro e sparisce in poco piu' di mezzo secondo.
///
/// Passa dalla stessa memoria del contatore qui sotto — `pendingVoteProvider` —
/// quindi doppio tocco e tocco sulla fiamma **sono lo stesso gesto**: prima
/// erano due comandi separati, e usati insieme contavano due volte.
class FireTap extends ConsumerStatefulWidget {
  const FireTap({
    required this.entry,
    required this.child,
    this.onTap,
    super.key,
  });

  final ChallengeEntry entry;
  final Widget child;
  final VoidCallback? onTap;

  @override
  ConsumerState<FireTap> createState() => _FireTapState();
}

class _FireTapState extends ConsumerState<FireTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDoubleTap() async {
    // A gara finita non c'e' niente da accendere: le fiamme sono quelle
    // dell'ultimo secondo, e sono gia' servite a dare dei soldi a qualcuno.
    if (!ref.read(challengeIsLiveProvider(widget.entry.challengeId))) {
      return;
    }

    // **A fiamma gia' accesa il doppio tocco non fa niente**: ne' la spegne, ne'
    // la riaccende, e nemmeno rifa' l'animazione. Nessuno ripete lo stesso
    // gesto per disfare quello che ha appena fatto, e per toglierla c'e' un
    // gesto solo — il tocco sulla fiamma rossa.
    if (ref.read(entryVotedProvider(widget.entry.voteKey))) {
      return;
    }

    _controller.forward(from: 0);
    await giveFire(context, ref, widget.entry, voted: true);
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
          // I due gesti si lasciano detti anche qui sotto: sul web un video e'
          // un elemento del browser e i tocchi di Flutter non ci arrivano, e
          // senza questo su un video non si potrebbe ne' dare la fiamma ne'
          // aprire lo schermo intero. Vedi `MediaGestures`.
          MediaGestures(
            onTap: widget.onTap,
            onDoubleTap: _handleDoubleTap,
            child: widget.child,
          ),
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
