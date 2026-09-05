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

  /// Il flash, fra quelli che hanno senso per quello che si sta facendo.
  ///
  /// **Tre modi per la foto, due per il video.** Sulla foto il lampo puo'
  /// partire da solo quando serve — e' quello che uno si aspetta e quasi
  /// nessuno tocca; sul video non esiste un lampo, esiste una torcia che resta
  /// accesa, e "automatica" non vorrebbe dire niente.
  var _flash = 0;

  List<FlashMode> get _modiDelFlash => widget.video
      ? const [FlashMode.off, FlashMode.torch]
      : const [FlashMode.off, FlashMode.auto, FlashMode.always];
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
      await _applicaIlFlash(controller);

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

  /// Dice alla fotocamera come deve comportarsi il flash.
  ///
  /// Non lancia: **quasi nessuna fotocamera frontale ce l'ha**, e su quelle il
  /// comando fallisce. Fallire in silenzio qui vuol dire che il comando non c'e'
  /// e basta; lasciar passare l'errore vorrebbe dire una fotocamera che non si
  /// apre per un lampo che nessuno aveva chiesto.
  Future<void> _applicaIlFlash(CameraController controller) async {
    try {
      await controller.setFlashMode(_modiDelFlash[_flash]);
    } catch (_) {
      // Vedi sopra.
    }
  }

  Future<void> _cambiaIlFlash() async {
    final controller = _controller;

    if (controller == null || !_pronta) {
      return;
    }

    setState(() => _flash = (_flash + 1) % _modiDelFlash.length);
    await _applicaIlFlash(controller);
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
        setState(() => _errore = 'Non è venuta. Riprova.');
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
            // **L'anteprima non la ribaltiamo noi: la ribalta gia' il
            // sistema.**
            //
            // C'era un `Transform` qui, e faceva danno. Il livello di anteprima
            // della fotocamera — su iPhone, su Android e nel browser — mostra
            // gia' la lente frontale come uno specchio, perche' e' l'unico modo
            // in cui uno riesce a inquadrarsi. Aggiungendone un altro sopra, i
            // due ribaltamenti si annullavano e ci si vedeva **al contrario**:
            // la scritta sulla maglietta leggibile, la riga dei capelli dalla
            // parte sbagliata, e la mano destra che si muove a sinistra.
            //
            // Il ribaltamento serve **solo sul file**, che invece arriva dal
            // sensore cosi' com'e'.
            Center(child: CameraPreview(controller))
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
          // **Niente veli sopra e sotto, e li avevo messi io.**
          //
          // Servivano a far risaltare i comandi bianchi su un'inquadratura
          // chiara. Il problema e' che l'anteprima non riempie lo schermo: il
          // sensore vede in quattro terzi, il telefono e' molto piu' lungo, e
          // sopra e sotto resta del nero. Quel nero **c'era gia'**, e il velo
          // ci si sommava: due fasce nere piu' nere del resto, con la croce
          // dentro. Sembrava un difetto, ed era un rimedio applicato a un
          // problema che in quel punto non esisteva.
          //
          // I comandi si difendono da soli: ognuno sta dentro il proprio tondo
          // scuro, che e' la stessa protezione ma solo dove serve — grande
          // quanto l'icona, non quanto lo schermo. E l'anteprima resta
          // **intera**: riempirla tagliando i lati farebbe uscire una foto piu'
          // larga di quella che si e' inquadrata, e qui vale una regola sola —
          // quello che vedi e' quello che mandi.
          // **In alto c'e' solo la via d'uscita.** La croce sta da sola
          // nell'angolo dove le mani non arrivano per sbaglio: e' il comando
          // che non deve costare un pensiero quando lo si cerca, e nemmeno
          // essere premuto per errore quando non lo si cercava.
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: _Tondo(
                icona: Icons.close_rounded,
                etichetta: 'Chiudi',
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                // **I tre comandi dello scatto stanno tutti a portata di
                // pollice.** Il flash era in cima, all'angolo opposto: per
                // accenderlo bisognava spostare la mano da sotto il telefono e
                // riprenderlo, con l'inquadratura gia' pronta. Sono le due
                // cose che si toccano *mentre* si guarda dentro — flash e
                // lente — e stanno ai lati di quella che si tocca per ultima.
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Sulla lente frontale il posto resta vuoto invece di
                    // sparire: senza, lo scatto si sposterebbe di lato ogni
                    // volta che si gira la fotocamera, e il pollice lo
                    // cercherebbe dove non c'e' piu'.
                    if (_pronta && !_frontale)
                      _Tondo(
                        icona: switch (_modiDelFlash[_flash]) {
                          FlashMode.off => Icons.flash_off_rounded,
                          FlashMode.auto => Icons.flash_auto_rounded,
                          _ => Icons.flash_on_rounded,
                        },
                        etichetta: 'Flash',
                        // Acceso e' rosso: e' l'unica cosa qui dentro che
                        // cambia come viene la foto, e deve vedersi che e'
                        // inserita.
                        acceso: _modiDelFlash[_flash] != FlashMode.off,
                        onTap: registrando ? null : _cambiaIlFlash,
                      )
                    else
                      const SizedBox(width: 60),
                    _Shutter(
                      recording: registrando,
                      busy: _sta && !registrando,
                      onTap: _scatta,
                    ),
                    _Tondo(
                      icona: Icons.cameraswitch_rounded,
                      etichetta: 'Gira la fotocamera',
                      onTap: registrando ? null : _giraLaFotocamera,
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

/// Un comando della fotocamera: icona bianca dentro un tondo scuro.
///
/// **Il tondo non e' decorazione.** Un'icona bianca appoggiata direttamente
/// sull'inquadratura scompare su qualunque cosa sia chiara, e i comandi di una
/// fotocamera devono essere trovabili senza guardarli — le mani sono impegnate
/// a tenere fermo il telefono.
class _Tondo extends StatelessWidget {
  const _Tondo({
    required this.icona,
    required this.etichetta,
    required this.onTap,
    this.acceso = false,
  });

  final IconData icona;
  final String etichetta;
  final VoidCallback? onTap;
  final bool acceso;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Semantics(
        button: true,
        label: etichetta,
        child: Tooltip(
          message: etichetta,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: acceso ? AppColors.crasyRed : const Color(0x59000000),
              ),
              child: Icon(icona, color: AppColors.paper, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

/// Il tasto dello scatto: un anello bianco e dentro il rosso di CRASY.
///
/// **Il rosso e' il segno dell'app, e qui e' al suo posto.** Dentro CRASY il
/// rosso vuol dire premio, fiamma, in corso — le cose che contano — e questo e'
/// il gesto da cui nasce tutto: senza uno scatto non c'e' una gara. Bianco come
/// su ogni altra fotocamera del mondo, era il tasto di chiunque; rosso e' il
/// nostro, ed e' anche la cosa piu' visibile dello schermo, che per un tasto da
/// premere senza guardare non e' un dettaglio.
///
/// Mentre registra si ribalta — anello rosso, dentro un quadrato bianco — cosi'
/// i due stati non si confondono nemmeno con la coda dell'occhio.
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: recording ? AppColors.crasyRed : AppColors.paper,
              width: 4,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: AnimatedOpacity(
              // Mentre la foto sta salendo il tasto si smorza: e' l'unico modo
              // che ha di dire "l'ho presa, aspetta" senza scriverlo.
              duration: const Duration(milliseconds: 160),
              opacity: busy ? 0.45 : 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: recording ? AppColors.paper : AppColors.crasyRed,
                  shape: recording ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: recording ? BorderRadius.circular(10) : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
