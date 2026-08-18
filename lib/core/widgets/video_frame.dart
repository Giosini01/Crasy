import 'package:crasy/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Un video di una partecipazione.
///
/// Parte da solo, in silenzio, e va in ciclo. Sono tre scelte insieme e sono la
/// stessa scelta: si scorre una gara guardando venti contenuti di fila, e un
/// video che chiede di premere play prima di mostrarsi viene saltato. Il suono
/// parte spento perche' nessuno vuole che il telefono cominci a parlare in
/// mezzo alla gente — si accende con un tocco, e il tocco e' l'unico comando.
///
/// Il ciclo serve alla gara: trenta secondi che ripartono lasciano il tempo di
/// decidere se quella cosa merita una fiamma.
class VideoFrame extends StatefulWidget {
  const VideoFrame({required this.url, this.caption, super.key});

  final String url;

  /// Cosa scrivere mentre il video sta arrivando.
  final String? caption;

  @override
  State<VideoFrame> createState() => _VideoFrameState();
}

class _VideoFrameState extends State<VideoFrame> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(VideoFrame oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.url != widget.url) {
      _controller?.dispose();
      _controller = null;
      _failed = false;
      _open();
    }
  }

  Future<void> _open() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
    } on Object {
      // Un video che non si apre non deve far cadere la schermata che lo
      // contiene: resta un riquadro con scritto che non si e' potuto caricare,
      // e tutto il resto della gara continua a funzionare.
      await controller.dispose();

      if (mounted) {
        setState(() => _failed = true);
      }

      return;
    }

    if (!mounted) {
      await controller.dispose();

      return;
    }

    setState(() => _controller = controller);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggleSound() {
    final controller = _controller;

    if (controller == null) {
      return;
    }

    setState(() {
      controller.setVolume(controller.value.volume > 0 ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final controller = _controller;

    if (_failed) {
      return ColoredBox(
        color: palette.surfaceMuted,
        child: Center(
          child: Text(
            'VIDEO NON DISPONIBILE',
            style: context.texts.labelSmall?.copyWith(color: palette.textFaint),
          ),
        ),
      );
    }

    if (controller == null) {
      return ColoredBox(color: palette.surfaceMuted);
    }

    return GestureDetector(
      onTap: _toggleSound,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // `FittedBox` con `cover`: il video riempie il riquadro come farebbe
          // una foto, invece di lasciare due bande nere dove le proporzioni non
          // combaciano.
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0x8C000000),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  controller.value.volume > 0
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
