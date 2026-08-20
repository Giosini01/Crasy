import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/widgets/video/html_video_stub.dart'
    if (dart.library.js_interop) 'package:crasy/core/widgets/video/html_video_web.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// Un video di una partecipazione.
///
/// Prova a partire da solo, in silenzio, e va in ciclo: si scorre una gara
/// guardando venti contenuti di fila, e un video che chiede di premere play
/// prima di mostrarsi viene saltato.
///
/// **Ma se non parte, resta comunque il primo fotogramma con un play sopra**, e
/// questa e' la correzione di un difetto che si vedeva come "i video non si
/// vedono". I browser dei telefoni rifiutano di far partire un video senza che
/// nessuno abbia toccato lo schermo, e il rifiuto arriva come un errore: prima
/// quell'errore veniva scambiato per "video rotto" e si buttava via un video
/// che funzionava benissimo. Adesso il rifiuto e' un caso previsto — si mostra
/// il fotogramma e si aspetta un dito.
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

    // Sul web non si apre nessun lettore: ci pensa l'elemento del browser.
    if (!kIsWeb) {
      _open();
    }
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
    } on Object {
      // **Solo questo e' un video rotto**: il file non si apre, il formato non
      // si sa leggere. Tutto il resto — non parte, non fa rumore — e' un video
      // che c'e'.
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

    // Da qui in poi ogni errore si ignora: il video e' gia' a schermo, fermo
    // sul primo fotogramma, e non parte da solo. E' esattamente quello che i
    // browser dei telefoni si aspettano.
    try {
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
    } on Object {
      // Silenzio voluto: c'e' il play in mezzo allo schermo.
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Un tocco fa la cosa che serve in quel momento.
  ///
  /// Fermo: parte, e **con l'audio** — chi tocca un video fermo lo vuole
  /// guardare davvero. Gia' in corso: accende o spegne il suono, perche' nessuno
  /// vuole che il telefono cominci a parlare in mezzo alla gente.
  Future<void> _tap() async {
    final controller = _controller;

    if (controller == null) {
      return;
    }

    if (!controller.value.isPlaying) {
      await controller.setVolume(1);
      await controller.play();
    } else {
      await controller.setVolume(controller.value.volume > 0 ? 0 : 1);
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // **Sul web il video lo disegna il browser, non Flutter.**
    //
    // Il lettore di Flutter aspetta che il browser dichiari il video "pronto",
    // e iPhone quel momento non lo raggiunge mai finche' qualcuno non tocca
    // play: restava un rettangolo grigio, per sempre, senza nemmeno un errore.
    // Con l'elemento vero decidiamo noi quanto caricare e chi disegna i
    // comandi. Vedi `html_video_web.dart`.
    if (kIsWeb) {
      final video = buildHtmlVideo(widget.url);

      if (video != null) {
        return video;
      }
    }

    final controller = _controller;

    if (_failed) {
      // Anche qui si offre una via d'uscita invece di un vicolo cieco: il file
      // c'e', e il browser da solo — fuori dall'app — quasi sempre lo apre.
      return ColoredBox(
        color: palette.surfaceMuted,
        child: Center(
          child: TextButton(
            onPressed: () => launchUrl(
              Uri.parse(widget.url),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(
              'APRI IL VIDEO',
              style: context.texts.labelSmall?.copyWith(color: palette.accent),
            ),
          ),
        ),
      );
    }

    if (controller == null) {
      return ColoredBox(color: palette.surfaceMuted);
    }

    final playing = controller.value.isPlaying;
    final muted = controller.value.volume == 0;

    return GestureDetector(
      onTap: _tap,
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
          // Il play grande al centro c'e' **solo** quando il video e' fermo: e'
          // un invito, non una decorazione, e sopra un video che sta gia'
          // andando coprirebbe la cosa che si e' venuti a vedere.
          if (!playing)
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 56,
                color: Colors.white,
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
                  muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  size: 14,
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
