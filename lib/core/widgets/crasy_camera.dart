import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:crasy/core/theme/app_colors.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/flame_waiting.dart';
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
  const CrasyCamera({
    required this.video,
    this.titolo = '',
    this.durataMassima,
    super.key,
  });

  /// Se si sta girando un video invece che scattare una foto.
  final bool video;

  /// Il titolo della missione, in cima: per sapere cosa si sta scattando
  /// senza tornare indietro a rileggerlo.
  final String titolo;

  /// **Quanto puo' durare il video.** Al tetto la registrazione si ferma da
  /// sola, e il tempo che passa si vede in cima e attorno al tasto. Senza un
  /// tetto, chi girava con la fotocamera di CRASY poteva registrare quanto
  /// voleva: il limite valeva solo per i video presi dalla galleria.
  final Duration? durataMassima;

  /// Apre la fotocamera a schermo intero. Torna il file, o `null` se si e'
  /// tornati indietro senza scattare.
  static Future<CameraShot?> open(
    BuildContext context, {
    required bool video,
    String titolo = '',
    Duration? durataMassima,
  }) {
    return Navigator.of(context).push<CameraShot>(
      MaterialPageRoute<CameraShot>(
        fullscreenDialog: true,
        builder: (_) => CrasyCamera(
          video: video,
          titolo: titolo,
          durataMassima: durataMassima,
        ),
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

  /// Da quanto si sta registrando. Si aggiorna dieci volte al secondo: basta
  /// per i secondi in cima e per l'anello attorno al tasto.
  final _cronometro = Stopwatch();
  Timer? _tic;
  var _trascorso = Duration.zero;

  /// Il lampo bianco sull'inquadratura quando si scatta una foto: dice "presa"
  /// prima ancora che il file sia pronto.
  var _lampo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_accendi());
  }

  @override
  void dispose() {
    _tic?.cancel();
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

  /// Accende la fotocamera, e se non ci riesce **riprova una volta**.
  ///
  /// **Il primo tentativo puo' fallire per ragioni che passano da sole**, e
  /// sono due, tutte e due invisibili da qui.
  ///
  /// La fotocamera di prima puo' essere ancora in fase di smontaggio: chi tocca
  /// "registra di nuovo" la riapre un istante dopo averla chiusa, e per quel
  /// istante l'apparecchio risulta occupato.
  ///
  /// E l'audio: registrare un video vuole il microfono, e se un lettore video
  /// sta ancora suonando — l'anteprima di quello appena girato — il microfono
  /// non si ottiene. Quel lettore adesso si spegne prima, ma spegnersi richiede
  /// il suo tempo.
  ///
  /// Mezzo secondo e un secondo tentativo coprono tutti e due i casi. Prima
  /// bastava il primo fallimento per dire a chi guarda **"controlla il
  /// permesso"** — una frase che manda a cercare nelle impostazioni una cosa
  /// che era gia' a posto.
  Future<void> _accendi() async {
    if (await _provaAdAccendere()) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!mounted || await _provaAdAccendere()) {
      return;
    }

    if (mounted) {
      setState(
        () => _errore =
            'Non riusciamo ad aprire la fotocamera. '
            'Chiudi e riprova, o controlla di averci dato il permesso.',
      );
    }
  }

  /// Un tentativo solo. Vero se e' andata.
  Future<bool> _provaAdAccendere() async {
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }

      if (_cameras.isEmpty) {
        setState(() => _errore = 'Non troviamo nessuna fotocamera.');

        return true;
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
        // **Un video leggero sale prima, e arriva.** Senza un tetto il
        // telefono registrava a quanto gli pareva — dieci megabit al secondo e
        // piu' — e venti secondi diventavano venticinque megabyte: con poca
        // rete non partivano proprio. A tre megabit lo stesso video pesa
        // circa un terzo, e su uno schermo da telefono non si vede la
        // differenza.
        videoBitrate: widget.video ? 3000000 : null,
        audioBitrate: widget.video ? 96000 : null,
      );

      await controller.initialize();
      await _applicaIlFlash(controller);

      if (!mounted) {
        await controller.dispose();

        return true;
      }

      setState(() {
        _controller = controller;
        _pronta = true;
        _errore = null;
      });

      return true;
    } on Object catch (_) {
      return false;
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

    setState(() {
      _sta = true;
      _lampo = !widget.video;
    });

    if (_lampo) {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 140), () {
          if (mounted) {
            setState(() => _lampo = false);
          }
        }),
      );
    }

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
      _tic?.cancel();
      _cronometro.stop();

      return controller.stopVideoRecording();
    }

    await controller.startVideoRecording();

    _cronometro
      ..reset()
      ..start();
    _tic = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) {
        return;
      }

      setState(() => _trascorso = _cronometro.elapsed);

      // **Al tetto si ferma da solo**, e il video parte come se si fosse
      // toccato il tasto: lasciar registrare oltre per poi dire "troppo lungo"
      // vorrebbe dire far rifare tutto.
      final tetto = widget.durataMassima;
      if (tetto != null && _trascorso >= tetto) {
        _tic?.cancel();
        unawaited(_scatta());
      }
    });

    if (mounted) {
      setState(() => _trascorso = Duration.zero);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final registrando = controller?.value.isRecordingVideo ?? false;

    // **Come BeReal: nero, e dentro il riquadro della gara.**
    //
    // L'anteprima a tutto schermo mostrava piu' di quello che poi finiva in
    // gara: il riquadro e' quattro quinti, il telefono molto piu' lungo, e il
    // taglio arrivava dopo, nell'editor, come una sorpresa. Adesso si inquadra
    // gia' dentro lo stesso riquadro arrotondato in cui la foto verra' vista:
    // quello che vedi e' quello che mandi, anche nei bordi.
    final tetto = widget.durataMassima;
    final avanzamento = tetto == null || tetto == Duration.zero
        ? 0.0
        : (_trascorso.inMilliseconds / tetto.inMilliseconds).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // **In cima: l'uscita, e cosa si sta facendo.** La croce sta
            // nell'angolo dove le mani non arrivano per sbaglio; al centro,
            // prima il titolo della missione e, mentre si gira, i secondi.
            Row(
              children: [
                _Tondo(
                  icona: Icons.close_rounded,
                  etichetta: 'Chiudi',
                  onTap: registrando ? null : () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: registrando
                          ? _Secondi(trascorso: _trascorso, tetto: tetto)
                          : _Titolo(titolo: widget.titolo, video: widget.video),
                    ),
                  ),
                ),
                // Lo spazio della croce, dall'altra parte: il centro resta il
                // centro.
                const SizedBox(width: 60),
              ],
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    // **Il bordo dice se si sta girando**: un filo chiaro
                    // prima, rosso pieno mentre registra.
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(27),
                        border: Border.all(
                          color: registrando
                              ? AppColors.crasyRed
                              : const Color(0x24FFFFFF),
                          width: registrando ? 3 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: const Color(0xFF141414),
                              child: _Riquadro(
                                controller: _pronta ? controller : null,
                                errore: _errore,
                              ),
                            ),
                            // Il lampo dello scatto.
                            IgnorePointer(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 120),
                                opacity: _lampo ? 0.85 : 0,
                                child: const ColoredBox(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // **I tre comandi dello scatto stanno tutti a portata di
            // pollice**, sotto il riquadro e non sopra l'inquadratura: flash
            // e lente ai lati del cerchio rosso, che e' l'ultima cosa che si
            // tocca.
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Sulla lente frontale il posto resta vuoto invece di
                  // sparire: senza, lo scatto si sposterebbe di lato ogni
                  // volta che si gira la fotocamera.
                  if (_pronta && !_frontale)
                    _Tondo(
                      icona: switch (_modiDelFlash[_flash]) {
                        FlashMode.off => Icons.flash_off_rounded,
                        FlashMode.auto => Icons.flash_auto_rounded,
                        _ => Icons.flash_on_rounded,
                      },
                      etichetta: 'Flash',
                      acceso: _modiDelFlash[_flash] != FlashMode.off,
                      onTap: registrando ? null : _cambiaIlFlash,
                    )
                  else
                    const SizedBox(width: 60),
                  _Shutter(
                    recording: registrando,
                    busy: _sta && !registrando,
                    avanzamento: registrando && tetto != null
                        ? avanzamento
                        : null,
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
            // Una riga sotto il tasto: cosa succede toccandolo.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.md,
              ),
              child: Text(
                !widget.video
                    ? 'Tocca per scattare'
                    : registrando
                    ? 'Tocca per fermare'
                    : tetto == null
                    ? 'Tocca per registrare'
                    : 'Tocca per registrare · massimo ${tetto.inSeconds} '
                          'secondi',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// **In cima, prima di registrare: cosa si sta facendo.**
///
/// Il titolo della missione se c'e', in maiuscolo e su due righe al massimo;
/// altrimenti FOTO o VIDEO.
class _Titolo extends StatelessWidget {
  const _Titolo({required this.titolo, required this.video});

  final String titolo;
  final bool video;

  @override
  Widget build(BuildContext context) {
    return Text(
      titolo.isEmpty ? (video ? 'VIDEO' : 'FOTO') : titolo.toUpperCase(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.paper,
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        height: 1.25,
      ),
    );
  }
}

/// **I secondi, in cima, mentre si gira**: il pallino rosso che lampeggia, il
/// tempo passato e il tetto. Negli ultimi cinque secondi la pillola diventa
/// rossa: si sa che sta per finire senza dover fare il conto.
class _Secondi extends StatelessWidget {
  const _Secondi({required this.trascorso, required this.tetto});

  final Duration trascorso;
  final Duration? tetto;

  String _scritto(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final tetto = this.tetto;
    final quasi =
        tetto != null && tetto - trascorso <= const Duration(seconds: 5);
    // Il pallino si accende e si spegne ogni mezzo secondo.
    final acceso = (trascorso.inMilliseconds ~/ 500).isEven;
    // Il tetto si mostra come lo si e' raggiunto: mai "0:21 / 0:20".
    final mostrato = tetto != null && trascorso > tetto ? tetto : trascorso;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: quasi ? AppColors.crasyRed : const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: acceso ? 1 : 0.25,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: quasi ? AppColors.paper : AppColors.crasyRed,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            tetto == null
                ? _scritto(mostrato)
                : '${_scritto(mostrato)} / ${_scritto(tetto)}',
            style: const TextStyle(
              color: AppColors.paper,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              // Le cifre tutte larghe uguali: il numero che cambia non fa
              // ballare la pillola.
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dentro il riquadro: l'anteprima che lo riempie, o cosa c'e' da sapere.
class _Riquadro extends StatelessWidget {
  const _Riquadro({required this.controller, required this.errore});

  final CameraController? controller;
  final String? errore;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;

    if (errore case final messaggio?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Text(
            messaggio,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.paper),
          ),
        ),
      );
    }

    if (controller == null) {
      // La fotocamera che si accende: la fiamma che gira, chiara sul nero.
      return const Center(
        child: FiammaCheGira(misura: 48, colore: AppColors.paper),
      );
    }

    // **L'anteprima riempie il riquadro, come la foto nella gara.** Il sensore
    // vede in tre quarti, il riquadro e' quattro quinti: si allarga quanto
    // basta e i bordi che avanzano restano fuori — esattamente quelli che
    // l'editor, partendo centrato, lascerebbe fuori.
    //
    // **L'anteprima non la ribaltiamo noi: la ribalta gia' il sistema.** Un
    // `Transform` qui sopra annullerebbe lo specchio della lente frontale, e
    // ci si vedrebbe al contrario. Il ribaltamento serve solo sul file.
    return LayoutBuilder(
      builder: (context, box) {
        // In verticale l'anteprima e' alta 1 / aspectRatio volte la larghezza.
        final alta = box.maxWidth * controller.value.aspectRatio;

        return FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: box.maxWidth,
            height: alta,
            child: CameraPreview(controller),
          ),
        );
      },
    );
  }
}

/// Un comando della fotocamera: icona bianca dentro un tondo grigio.
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
            // **Spento, si vede spento.** Mentre si registra croce, flash e
            // lente non rispondono, e un tasto che sembra vivo e non risponde
            // si tocca tre volte prima di capirlo.
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: onTap == null ? 0.35 : 1,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Grigio chiaro e trasparente: sul nero attorno al riquadro
                  // un tondo scuro non si vedeva, e l'icona restava sola.
                  color: acceso ? AppColors.crasyRed : const Color(0x24FFFFFF),
                ),
                child: Icon(icona, color: AppColors.paper, size: 22),
              ),
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
/// **Mentre registra il cerchio rosso si stringe in un quadrato**, e attorno
/// l'anello del tempo si riempie fino al tetto: i due stati non si confondono
/// nemmeno con la coda dell'occhio, e si vede quanto resta senza leggere.
class _Shutter extends StatefulWidget {
  const _Shutter({
    required this.recording,
    required this.busy,
    required this.onTap,
    this.avanzamento,
  });

  final bool recording;
  final bool busy;
  final VoidCallback onTap;

  /// Quanto del tetto e' gia' passato, da 0 a 1. Nullo se non si registra o
  /// se un tetto non c'e'.
  final double? avanzamento;

  @override
  State<_Shutter> createState() => _ShutterState();
}

class _ShutterState extends State<_Shutter> {
  /// Il tasto si schiaccia sotto il dito, come uno vero.
  var _premuto = false;

  void _premi(bool premuto) {
    if (_premuto != premuto) {
      setState(() => _premuto = premuto);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recording = widget.recording;
    final busy = widget.busy;
    final avanzamento = widget.avanzamento;

    return Semantics(
      button: true,
      label: recording ? 'Ferma' : 'Scatta',
      child: GestureDetector(
        onTap: busy ? null : widget.onTap,
        onTapDown: busy ? null : (_) => _premi(true),
        onTapUp: (_) => _premi(false),
        onTapCancel: () => _premi(false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          scale: _premuto ? 0.9 : 1,
          child: SizedBox.square(
            dimension: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (recording)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _AnelloDelTempo(avanzamento: avanzamento),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      // Mentre registra l'anello bianco lascia il posto a
                      // quello del tempo.
                      color: recording ? Colors.transparent : AppColors.paper,
                      width: 4,
                    ),
                  ),
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.all(recording ? 21 : 6),
                    child: AnimatedOpacity(
                      // Mentre la foto sta salendo il tasto si smorza: e'
                      // l'unico modo che ha di dire "l'ho presa, aspetta"
                      // senza scriverlo.
                      duration: const Duration(milliseconds: 160),
                      opacity: busy ? 0.45 : 1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        decoration: BoxDecoration(
                          color: AppColors.crasyRed,
                          borderRadius: BorderRadius.circular(
                            recording ? 7 : 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// L'anello del tempo attorno al tasto: una pista chiara, e sopra il rosso che
/// avanza dall'alto in senso orario. Senza un tetto resta la sola pista.
class _AnelloDelTempo extends CustomPainter {
  const _AnelloDelTempo({required this.avanzamento});

  final double? avanzamento;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    final pista = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0x40FFFFFF);

    canvas.drawArc(rect, 0, 2 * math.pi, false, pista);

    final avanzamento = this.avanzamento;

    if (avanzamento == null || avanzamento <= 0) {
      return;
    }

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * avanzamento,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = AppColors.crasyRed,
    );
  }

  @override
  bool shouldRepaint(_AnelloDelTempo altro) => altro.avanzamento != avanzamento;
}
