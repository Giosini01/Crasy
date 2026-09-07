import 'dart:async';

import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/widgets/media_gestures.dart';
import 'package:crasy/core/widgets/video/html_video_stub.dart'
    if (dart.library.js_interop) 'package:crasy/core/widgets/video/html_video_web.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// Un video di una partecipazione.
///
/// Parte da solo, in silenzio, e va in ciclo: si scorre una gara guardando
/// venti contenuti di fila, e un video che chiede di premere play prima di
/// mostrarsi viene saltato. Il ciclo serve alla gara: trenta secondi che
/// ripartono lasciano il tempo di decidere se quella cosa merita una fiamma.
///
/// **Ma se non parte, resta comunque il primo fotogramma con un play sopra**, e
/// questa e' la correzione di un difetto che si vedeva come "i video non si
/// vedono". I browser dei telefoni rifiutano di far partire un video senza che
/// nessuno abbia toccato lo schermo, e il rifiuto arriva come un errore: prima
/// quell'errore veniva scambiato per "video rotto" e si buttava via un video
/// che funzionava benissimo. Adesso il rifiuto e' un caso previsto — si mostra
/// il fotogramma e si aspetta un dito.
///
/// ## Il primo tocco cambia mestiere al video
///
/// Finche' nessuno lo tocca e' **un contenuto che scorre**: muto, in ciclo,
/// senza un comando sopra, perche' una barra con i pulsanti in mezzo a una
/// griglia di foto dice "questo e' un lettore" invece di "questa e' la
/// partecipazione di qualcuno".
///
/// Al primo tocco diventa **una cosa che si sta guardando**: arriva l'audio —
/// chi tocca un video lo vuole guardare davvero — e arrivano i comandi, cioe'
/// la barra per andare avanti e indietro, i dieci secondi in salto, la pausa e
/// il volume. Spariscono da soli dopo qualche istante, cosi' tornano a coprire
/// il video solo quando servono; **a video fermo restano**, perche' chi ha
/// appena messo in pausa sta cercando proprio quelli.
///
/// Sul web niente di tutto questo passa di qui: il video lo disegna il browser
/// con i suoi comandi, e la regola e' la stessa. Vedi `html_video_web.dart`.
/// Quanti video possono aprirsi **nello stesso momento**.
///
/// **Senza questo numero l'app si apriva lenta, e la colpa non era della
/// rete.** Le griglie delle partecipazioni sono `GridView` con `shrinkWrap`,
/// che non e' pigro: per sapere quanto e' alto deve costruire **tutti** i
/// riquadri subito, anche i trenta che stanno sotto lo schermo. Ogni riquadro
/// con un video apriva il proprio lettore e cominciava a scaricare — trenta
/// scaricamenti in parallelo sulla stessa linea, dove il primo video, quello
/// che uno sta effettivamente guardando, si prendeva un trentesimo della banda.
///
/// Tre alla volta, in fila. I riquadri si costruiscono in ordine, quindi i
/// primi della coda sono quelli in cima allo schermo: la griglia si riempie
/// dall'alto mentre si guarda, invece di restare tutta grigia e comparire
/// insieme.
class _Coda {
  static const _insieme = 3;

  static var _aperti = 0;
  static final _attesa = <Completer<void>>[];

  /// Aspetta il proprio turno. Da rilasciare **sempre** con [esci].
  static Future<void> entra() {
    if (_aperti < _insieme) {
      _aperti += 1;

      return Future<void>.value();
    }

    final mio = Completer<void>();
    _attesa.add(mio);

    return mio.future;
  }

  /// Lascia il posto a chi aspetta.
  static void esci() {
    if (_attesa.isNotEmpty) {
      // Il posto passa di mano senza tornare libero: cosi' non si puo'
      // infilare qualcuno arrivato dopo.
      _attesa.removeAt(0).complete();

      return;
    }

    if (_aperti > 0) {
      _aperti -= 1;
    }
  }
}

class VideoFrame extends StatefulWidget {
  const VideoFrame({
    required this.url,
    this.caption,
    this.immersive = false,
    this.autoplay = true,
    super.key,
  });

  final String url;

  /// Se il video e' **la cosa che si sta guardando** e non una riga di un
  /// elenco: a schermo intero arrivano audio e comandi, nell'elenco no.
  final bool immersive;

  /// Se il video deve **partire da solo**.
  ///
  /// Vero dove il video e' il contenuto: la scheda di una gara, il feed degli
  /// amici, lo schermo intero. Li' un video che chiede di premere play viene
  /// saltato, e chi l'ha girato ha perso la sua occasione.
  ///
  /// **Falso nelle griglie**, ed e' la correzione di un difetto vero. Un
  /// quadrato di due dita non e' il contenuto: e' un indice, e nell'indice si
  /// guarda quale foto e' quale, non si guarda il video. Facendolo partire si
  /// scaricava **tutto** il file — e in ciclo, quindi per sempre, anche a
  /// schermo spento — per venti riquadri insieme. Fermo sul primo fotogramma
  /// costa una manciata di byte e si vede esattamente uguale.
  final bool autoplay;

  /// Cosa scrivere mentre il video sta arrivando.
  final String? caption;

  @override
  State<VideoFrame> createState() => _VideoFrameState();
}

class _VideoFrameState extends State<VideoFrame> {
  /// Quanto restano i comandi dopo l'ultimo tocco.
  static const _linger = Duration(seconds: 3);

  VideoPlayerController? _controller;
  Timer? _hide;
  bool _failed = false;
  bool _controls = false;

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
      _hide?.cancel();
      _controls = false;
      _open();
    }
  }

  Future<void> _open() async {
    await _Coda.entra();

    // Nel frattempo la schermata puo' essere stata chiusa, o si puo' essere
    // scorso via: il posto in coda va restituito comunque, altrimenti la coda
    // si stringe di uno a ogni riquadro sparito e alla fine non passa piu'
    // nessuno.
    if (!mounted) {
      _Coda.esci();

      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));

    try {
      await controller.initialize();
    } on Object {
      // **Solo questo e' un video rotto**: il file non si apre, il formato non
      // si sa leggere. Tutto il resto — non parte, non fa rumore — e' un video
      // che c'e'.
      await controller.dispose();
      _Coda.esci();

      if (mounted) {
        setState(() => _failed = true);
      }

      return;
    }

    // **Il posto si lascia qui**, appena il video e' pronto: la parte lenta e'
    // quella che si e' appena conclusa. Tenerlo fino alla fine vorrebbe dire
    // che tre video gia' aperti bloccano tutti gli altri finche' restano a
    // schermo, cioe' per sempre.
    _Coda.esci();

    if (!mounted) {
      await controller.dispose();

      return;
    }

    setState(() => _controller = controller);

    // Da qui in poi ogni errore si ignora: il video e' gia' a schermo, fermo
    // sul primo fotogramma, e non parte da solo. E' esattamente quello che i
    // browser dei telefoni si aspettano.
    try {
      await controller.setVolume(widget.immersive ? 1 : 0);

      // Nelle griglie si resta sul primo fotogramma: c'e' gia' il play in
      // mezzo, e chi vuole vedere il video tocca e lo apre grande.
      if (widget.autoplay) {
        await controller.setLooping(true);
        await controller.play();
      }
    } on Object {
      // Silenzio voluto: c'e' il play in mezzo allo schermo.
    }

    if (mounted) {
      setState(() {});
    }

    // A schermo intero i comandi si fanno vedere subito e poi si tolgono da
    // soli: chi ha appena aperto deve sapere che si puo' fermare, senza doverlo
    // scoprire con un tocco alla cieca.
    if (widget.immersive) {
      _keepControls();
    }
  }

  @override
  void dispose() {
    _hide?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  /// Accende i comandi e mette in conto quando spegnerli.
  ///
  /// A video fermo non si spengono: chi ha messo in pausa sta cercando proprio
  /// la barra, e vedersela sparire in mano vuol dire toccare di nuovo per
  /// riaverla.
  void _keepControls() {
    _hide?.cancel();

    if (_controller?.value.isPlaying ?? false) {
      _hide = Timer(_linger, () {
        if (mounted) {
          setState(() => _controls = false);
        }
      });
    }

    if (mounted) {
      setState(() => _controls = true);
    }
  }

  /// Un tocco fa la cosa che serve in quel momento.
  ///
  /// Senza comandi a schermo: **parte l'audio e compaiono i comandi**, che e'
  /// il passaggio da "sto scorrendo" a "sto guardando". Con i comandi gia'
  /// fuori: ferma e riprende, come su qualunque lettore.
  Future<void> _tap() async {
    final controller = _controller;

    if (controller == null) {
      return;
    }

    if (!_controls) {
      await controller.setVolume(1);
      await controller.play();
      _keepControls();

      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    _keepControls();
  }

  Future<void> _toggleVolume() async {
    final controller = _controller;

    if (controller == null) {
      return;
    }

    await controller.setVolume(controller.value.volume > 0 ? 0 : 1);
    _keepControls();
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
    // comandi. I gesti glieli passiamo noi, perche' sopra un elemento del
    // browser quelli di Flutter non arrivano. Vedi `html_video_web.dart`.
    if (kIsWeb) {
      final gestures = MediaGestures.of(context);
      final video = buildHtmlVideo(
        widget.url,
        immersive: widget.immersive,
        autoplay: widget.autoplay,
        onTap: gestures?.onTap,
        onDoubleTap: gestures?.onDoubleTap,
      );

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

    final content = Stack(
      fit: StackFit.expand,
      children: [
        // `FittedBox` con `cover`: nell'elenco il video riempie il riquadro
        // come farebbe una foto, invece di lasciare due bande nere dove le
        // proporzioni non combaciano. A schermo intero vale il contrario — li'
        // si guarda il video com'e', e tagliarne i bordi vorrebbe dire
        // nascondere meta' di quello che qualcuno ha fatto per vincere.
        FittedBox(
          fit: widget.immersive ? BoxFit.contain : BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        // Il play grande al centro c'e' **solo** quando il video e' fermo e i
        // comandi non ci sono: e' un invito, non una decorazione, e sopra un
        // video che sta gia' andando coprirebbe la cosa che si e' venuti a
        // vedere.
        if (!playing && !_controls)
          const Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              size: 56,
              color: Colors.white,
            ),
          ),
        // **Si ferma e si riprende, non si scorre.**
        //
        // C'erano i dieci secondi avanti, i dieci indietro e la barra da
        // trascinare. Sono spariti tutti e tre, ed e' una scelta sul prodotto:
        // una partecipazione dura pochi secondi e va guardata **come e' stata
        // girata**. Potendo saltare, si salta — si va al punto in cui succede
        // la cosa, si vede quella e si passa oltre — e chi ha girato quel video
        // ha lavorato anche sui secondi prima.
        //
        // C'e' anche una ragione piu' seria: con dei soldi in palio, il tempo
        // che una foto o un video si prende e' l'unica cosa che si avvicina a
        // un'attenzione vera. Una barra che permette di arrivare in fondo in
        // mezzo secondo trasforma il guardare in uno sfogliare, e sfogliando si
        // vota a caso.
        //
        // La barra bianca sotto resta, ma **non si trascina**: dice a che punto
        // si e', che e' un'informazione, non un comando.
        if (_controls) ...[
          Center(
            child: _Command(
              icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 32,
              onTap: _tap,
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 26,
            child: IgnorePointer(
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: false,
                padding: const EdgeInsets.symmetric(vertical: 8),
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Color(0x59FFFFFF),
                  backgroundColor: Color(0x40FFFFFF),
                ),
              ),
            ),
          ),
        ],
        Positioned(
          right: 8,
          bottom: 8,
          child: GestureDetector(
            onTap: _controls ? _toggleVolume : null,
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
        ),
      ],
    );

    // **Nell'elenco il video non si prende i tocchi.** Sopra di lui ci sono la
    // fiamma del doppio tocco e il tocco che apre lo schermo intero, e un
    // lettore che se li mangia per mostrare una barra di comandi in una
    // miniatura toglie due gesti veri per darne uno che li' non serve.
    if (!widget.immersive) {
      return content;
    }

    return GestureDetector(onTap: _tap, child: content);
  }
}

/// Un comando del lettore: icona bianca su un tondo scuro.
///
/// Il tondo non e' decorazione — sotto ci passa un video qualunque, e un'icona
/// bianca su una scena chiara non si vede piu'.
class _Command extends StatelessWidget {
  const _Command({required this.icon, required this.onTap, this.size = 24});

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0x8C000000),
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: size, color: Colors.white),
        ),
      ),
    );
  }
}
