import 'dart:async';

import 'package:camera/camera.dart';
import 'package:crasy/core/theme/app_colors.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// La fotocamera di CRASY: schermo intero, un tasto, niente galleria.
///
/// **Perche' non basta quella di sistema.** Fino a ieri lo scatto passava dalla
/// fotocamera del telefono, e con quella arrivava un problema che non si poteva
/// aggiustare da qui: su iPhone, se nelle impostazioni e' acceso *"Immagine
/// speculare fotocamera anteriore"*, il selfie viene **salvato specchiato** —
/// scritte al contrario, riga dei capelli dalla parte sbagliata, e la faccia
/// che non e' quella che gli altri vedono. Quell'interruttore sta nelle
/// impostazioni del telefono, non nelle nostre.
///
/// Qui lo scatto lo facciamo noi, e vale una regola sola: **quello che vedi e'
/// quello che mandi.**
///
/// ## Lo specchio vale anche per la foto
///
/// Mentre ti inquadri, l'immagine e' ribaltata come in uno specchio: e' il modo
/// in cui ognuno e' abituato a vedere la propria faccia, e senza quel
/// ribaltamento alzare la mano destra e vederla muovere a sinistra rende
/// impossibile inquadrarsi.
///
/// **E la foto viene ribaltata insieme all'anteprima**, non lasciata come la
/// consegna il sensore. Il sensore guarda dal proprio punto di vista, quindi
/// senza quel passaggio la foto esce specchiata *rispetto a quella che hai
/// appena visto*: la riga dei capelli dalla parte sbagliata, le scritte al
/// contrario, una faccia che non e' quella che avevi inquadrato. Con
/// l'anteprima e la foto d'accordo, non c'e' nessuna sorpresa fra il tocco e
/// il risultato.
///
/// Vale solo per la lente frontale: dietro non c'e' nessuno specchio da
/// rispettare.
/// Quello che esce dalla fotocamera: il file, e da che lente arriva.
///
/// La lente serve a chi prepara la foto: **solo quella frontale va ribaltata**,
/// perche' solo li' c'e' uno specchio da rispettare.
typedef CameraShot = ({XFile file, bool mirrored});

class CrasyCamera extends StatefulWidget {
  const CrasyCamera({required this.video, super.key});

  /// Se si sta girando un video invece che scattare una foto.
  final bool video;

  /// Apre la fotocamera a schermo intero. Torna il file, o `null` se si e'
  /// tornati indietro senza scattare.
  static Future<CameraShot?> open(BuildContext context, {required bool video}) {
    return Navigator.of(context).push<CameraShot>(
      MaterialPageRoute<CameraShot>(
        fullscreenDialog: true,
        builder: (_) => CrasyCamera(video: video),
      ),
    );
  }

  /// Se per questo tipo di scatto possiamo aprire la nostra fotocamera.
  ///
  /// **Sul web vale per le foto, non per i video.** Lo specchio e' il motivo:
  /// passando dal selettore del browser, l'anteprima e' ribaltata — lo fa il
  /// browser — ma il file che ne esce non lo e', e quello che si manda in gara
  /// non e' quello che si e' visto. Con la nostra fotocamera le due cose
  /// tornano d'accordo ovunque.
  ///
  /// I video sul web restano al selettore di sistema: durata massima e formati
  /// cambiano da un browser all'altro, e li' un ripiego che funziona vale piu'
  /// di una cosa nostra che funziona a meta'.
  static bool availableFor({required bool video}) {
    if (kIsWeb) {
      return !video;
    }

    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  State<CrasyCamera> createState() => _CrasyCameraState();
}

class _CrasyCameraState extends State<CrasyCamera> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  var _frontale = false;
  var _pronta = false;
  var _sta = false;
  String? _errore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_accendi());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // **La fotocamera si spegne sempre.** Lasciarla accesa tiene occupato il
    // sensore: si torna indietro, si riapre, e la seconda volta non parte.
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    // Uscendo dall'app il sistema si riprende la fotocamera comunque: se non la
    // rilasciamo noi, al ritorno resta un'anteprima nera.
    if (state == AppLifecycleState.inactive) {
      unawaited(controller.dispose());
      _controller = null;
      _pronta = false;
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_accendi());
    }
  }

  Future<void> _accendi() async {
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }

      if (_cameras.isEmpty) {
        setState(() => _errore = 'Non troviamo nessuna fotocamera.');

        return;
      }

      final scelta = _cameras.firstWhere(
        (camera) =>
            camera.lensDirection ==
            (_frontale ? CameraLensDirection.front : CameraLensDirection.back),
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        scelta,
        // Alta e non massima: una foto da venti megapixel non si vede meglio su
        // uno schermo da telefono, ci mette il triplo a salire, e la prima cosa
        // che facciamo comunque e' stringerla.
        ResolutionPreset.high,
        enableAudio: widget.video,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();

        return;
      }

      setState(() {
        _controller = controller;
        _pronta = true;
        _errore = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _errore =
              'Non riusciamo ad aprire la fotocamera. '
              'Controlla di averci dato il permesso.',
        );
      }
    }
  }

  Future<void> _giraLaFotocamera() async {
    if (!_pronta || _sta) {
      return;
    }

    final vecchia = _controller;

    setState(() {
      _pronta = false;
      _frontale = !_frontale;
      _controller = null;
    });

    await vecchia?.dispose();
    await _accendi();
  }

  Future<void> _scatta() async {
    final controller = _controller;

    if (controller == null || !_pronta || _sta) {
      return;
    }

    setState(() => _sta = true);

    try {
      final file = widget.video
          ? await _giraIlVideo(controller)
          : await controller.takePicture();

      if (file != null && mounted) {
        Navigator.of(context).pop((file: file, mirrored: _frontale));

        return;
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errore = 'Non e\' venuta. Riprova.');
      }
    }

    if (mounted) {
      setState(() => _sta = false);
    }
  }

  Future<XFile?> _giraIlVideo(CameraController controller) async {
    if (controller.value.isRecordingVideo) {
      return controller.stopVideoRecording();
    }

    await controller.startVideoRecording();

    if (mounted) {
      setState(() {});
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final registrando = controller?.value.isRecordingVideo ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_pronta && controller != null)
            // **Lo specchio sta qui e solo qui.** Riguarda quello che si vede
            // mentre ci si inquadra, non il file che parte: `takePicture`
            // legge il sensore, non questa trasformazione.
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..scaleByDouble(_frontale ? -1.0 : 1.0, 1, 1, 1),
              child: Center(child: CameraPreview(controller)),
            )
          else
            const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.paper,
                ),
              ),
            ),
          if (_errore case final messaggio?)
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
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: AppColors.paper),
                tooltip: 'Chiudi',
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const SizedBox(width: 48),
                    _Shutter(
                      recording: registrando,
                      busy: _sta && !registrando,
                      onTap: _scatta,
                    ),
                    IconButton(
                      onPressed: registrando ? null : _giraLaFotocamera,
                      icon: const Icon(
                        Icons.cameraswitch_rounded,
                        color: AppColors.paper,
                        size: 28,
                      ),
                      tooltip: 'Gira la fotocamera',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Il tasto dello scatto: un cerchio bianco, grande come un pollice.
class _Shutter extends StatelessWidget {
  const _Shutter({
    required this.recording,
    required this.busy,
    required this.onTap,
  });

  final bool recording;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: recording ? 'Ferma' : 'Scatta',
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.paper, width: 4),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                // Rosso mentre registra: e' l'unico momento in cui il tasto
                // dice qualcosa invece di aspettare.
                color: recording ? AppColors.crasyRed : AppColors.paper,
                shape: recording ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: recording ? BorderRadius.circular(8) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
