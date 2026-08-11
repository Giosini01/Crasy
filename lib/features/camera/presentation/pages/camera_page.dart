import 'dart:math' as math;
import 'dart:typed_data';

import 'package:app_incontri/core/constants/app_routes.dart';
import 'package:app_incontri/core/errors/error_message_mapper.dart';
import 'package:app_incontri/core/theme/app_palette.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_shadows.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/core/utils/image_ops.dart';
import 'package:app_incontri/core/widgets/app_background.dart';
import 'package:app_incontri/core/widgets/brand_mark.dart';
import 'package:app_incontri/core/widgets/inline_banner.dart';
import 'package:app_incontri/features/daily/domain/entities/daily_access.dart';
import 'package:app_incontri/features/daily/domain/entities/daily_vibe.dart';
import 'package:app_incontri/features/daily/presentation/controllers/daily_capture_controller.dart';
import 'package:app_incontri/features/daily/presentation/providers/daily_providers.dart';
import 'package:app_incontri/features/daily/presentation/widgets/countdown_text.dart';
import 'package:app_incontri/features/daily/presentation/widgets/window_status_card.dart';
import 'package:app_incontri/features/stats/domain/entities/vibe_stats.dart';
import 'package:app_incontri/features/stats/presentation/providers/stats_providers.dart';
import 'package:app_incontri/features/stats/presentation/widgets/vibe_widgets.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Proporzione con cui l'Istantanea viene poi mostrata nel feed.
const double _frameRatio = 3 / 4;

/// Se il plugin della fotocamera riflette gia' lui l'immagine.
///
/// Sul web `camera_web` lo fa **di sua iniziativa e su entrambi i fronti**:
/// mette `transform: scaleX(-1)` sul video dell'anteprima e ribalta anche il
/// fotogramma sulla tela quando si scatta (entrambe in `camera.dart` del
/// pacchetto, "flip ... if it is not taken from a back camera"). Su iOS e
/// Android non riflette niente.
///
/// Il fatto che li' faccia **le due cose insieme** e' quello che conta: lo
/// scatto esce gia' girato come l'anteprima.
const bool _pluginMirrors = kIsWeb;

/// Se tocca a noi riflettere.
///
/// Un valore solo, applicato in tutti e tre i punti — anteprima, revisione,
/// file pubblicato — e da qui viene la sola garanzia che serve: **quello che
/// si vede inquadrando e' esattamente quello che si pubblica.**
///
/// Vale `false` sul web perche' li' il lavoro l'ha gia' fatto il plugin, e
/// `true` sul nativo dove non lo fa nessuno. Non e' una preferenza: e' il
/// complemento di [_pluginMirrors]. Il verso finale e' lo stesso nei due casi,
/// cambia solo chi lo mette.
const bool _selfieFlip = !_pluginMirrors;

/// La fotocamera vive **dentro l'app**, non nell'app Fotocamera del telefono.
///
/// Passando da `image_picker` si apriva la fotocamera di sistema, che su iOS
/// impone la sua schermata di conferma "Usa foto / Riscatta": una tappa in
/// piu' che Apple non permette di saltare. Con l'anteprima qui dentro si tocca
/// il tasto e si e' gia' nella revisione.
///
/// Ci si vede **allo specchio**, e allo specchio si resta: l'anteprima, la
/// revisione e il file pubblicato hanno tutti e tre lo stesso verso. Vedi
/// [_selfieFlip].
class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  bool _starting = false;
  bool _capturing = false;
  String? _error;

  bool _publishing = false;

  /// Vero appena l'Istantanea e' partita.
  ///
  /// Serve a coprire l'attesa della verifica: in quei secondi la Daily e'
  /// ancora una bozza, quindi lo stato di accesso non la vede come attiva, ma
  /// per chi ha appena scattato la foto e' gia' fatta.
  bool _published = false;

  /// L'etichetta scelta prima di scattare, se ne e' stata scelta una.
  ///
  /// Si sceglie **prima**, non dopo: dopo lo scatto la foto e' gia' partita, e
  /// una schermata "aggiungi un'etichetta" a cose fatte sarebbe la tappa in
  /// piu' che l'Istantanea a colpo unico vuole togliere.
  String? _vibe;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    // Quando l'app va in secondo piano il sistema si riprende il sensore: se
    // non lo si rilascia, al ritorno il controller resta inutilizzabile.
    if (state == AppLifecycleState.inactive) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _startCamera();
    }
  }

  /// Solo la fotocamera frontale: una Istantanea deve ritrarre chi la
  /// pubblica, e con la posteriore si fotograferebbe un panorama.
  static CameraDescription _selfieCamera(List<CameraDescription> cameras) {
    return cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
  }

  Future<void> _startCamera() async {
    if (_starting || _controller != null) {
      return;
    }

    setState(() {
      _starting = true;
      _error = null;
    });

    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }

      if (_cameras.isEmpty) {
        throw CameraException('no-camera', 'Nessuna fotocamera disponibile.');
      }

      final controller = CameraController(
        _selfieCamera(_cameras),
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _starting = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _starting = false;
        _error = _describe(error);
      });
    }
  }

  static String _describe(Object error) {
    if (error is CameraException) {
      final code = error.code.toLowerCase();

      if (code.contains('permission') || code.contains('denied')) {
        return 'Servono i permessi della fotocamera. Concedili e riprova.';
      }
    }

    return 'Non siamo riusciti ad aprire la fotocamera.';
  }

  void _disposeCamera() {
    final controller = _controller;

    if (controller == null) {
      return;
    }

    setState(() => _controller = null);
    controller.dispose();
  }

  /// Scatto **e** pubblicazione, in un gesto solo.
  ///
  /// Non c'e' schermata di conferma e non si puo' rifare: si preme una volta e
  /// l'Istantanea e' online. E' la regola dell'app messa nel gesto — una foto
  /// scelta fra venti non e' piu' un'istantanea, e' una posa. Chi puo'
  /// riscattare finche' non viene bene finisce per pubblicare la versione
  /// migliore di se', che e' esattamente quello che qui non interessa.
  ///
  /// L'unico caso in cui si torna indietro e' il guasto: se la pubblicazione
  /// non riesce la fotocamera si riapre, perche' quello non e' un ripensamento
  /// ma un errore da cui non ha senso far pagare il tentativo.
  Future<void> _captureAndPublish() async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }

    setState(() => _capturing = true);

    final Uint8List bytes;

    try {
      final file = await controller.takePicture();
      bytes = await file.readAsBytes();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _capturing = false;
          _error = _describe(error);
        });
      }

      return;
    }

    if (!mounted) {
      return;
    }

    // Il sensore si spegne subito: da qui in poi non serve piu', e tenerlo
    // acceso durante l'invio consuma e basta.
    _disposeCamera();

    setState(() {
      _capturing = false;
      _publishing = true;
    });

    // Il ribaltamento si applica **solo qui**, una volta sola, e sullo stesso
    // valore che governa l'anteprima: quello che si e' visto e' per
    // costruzione il file che parte.
    final toPublish = _selfieFlip
        ? await ImageOps.flipHorizontally(bytes)
        : bytes;

    if (!mounted) {
      return;
    }

    final published = await ref
        .read(dailyCaptureControllerProvider.notifier)
        .publish(toPublish, vibe: _vibe);

    if (!mounted) {
      return;
    }

    setState(() {
      _publishing = false;
      _published = published;
    });

    if (!published) {
      _startCamera();
    }
  }

  /// L'avvio si programma dopo il frame: `build` non puo' avere effetti
  /// collaterali, e lo stato di accesso puo' cambiare mentre la pagina e' viva.
  void _startCameraIfNeeded() {
    if (_controller != null || _starting || _error != null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startCamera();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(dailyAccessProvider);

    void releaseCamera() {
      if (_controller == null) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _disposeCamera();
        }
      });
    }

    // La giornata gia' pubblicata ha una schermata sua, e da li' non si torna
    // indietro: e' uno al giorno, e non esiste un modo di rifarla.
    if (_published || access.hasActiveDaily) {
      releaseCamera();

      return _PublishedView(access: access);
    }

    if (!access.canCapture) {
      releaseCamera();

      return _ClosedView(access: access);
    }

    _startCameraIfNeeded();

    return _LiveView(
      controller: _controller,
      access: access,
      capturing: _capturing,
      publishing: _publishing,
      error: _error,
      vibe: _vibe,
      onVibe: (value) => setState(() => _vibe = _vibe == value ? null : value),
      onCapture: _captureAndPublish,
      onRetry: () {
        setState(() => _error = null);
        _startCamera();
      },
    );
  }
}

/// Anteprima dal vivo e tasto di scatto.
class _LiveView extends ConsumerWidget {
  const _LiveView({
    required this.controller,
    required this.access,
    required this.capturing,
    required this.publishing,
    required this.error,
    required this.vibe,
    required this.onVibe,
    required this.onCapture,
    required this.onRetry,
  });

  final CameraController? controller;
  final DailyAccess access;
  final bool capturing;

  /// Lo scatto e' fatto e sta salendo: da qui non si torna indietro, e il
  /// tasto deve dirlo.
  final bool publishing;

  final String? error;

  /// L'etichetta selezionata, se c'e'.
  final String? vibe;

  final ValueChanged<String> onVibe;
  final VoidCallback onCapture;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final capture = ref.watch(dailyCaptureControllerProvider);

    // Se la pubblicazione non e' riuscita si torna qui con la fotocamera
    // riaperta: l'unico caso in cui si riscatta e' il guasto, e allora il
    // motivo va detto invece di far ripartire tutto in silenzio.
    final failure = capture.hasError
        ? ErrorMessageMapper.map(capture.error!)
        : null;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('E il tuo momento.', style: context.texts.titleLarge),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Chiude tra ', style: context.texts.bodySmall),
                        CountdownText(
                          target: access.boundary,
                          style: context.texts.labelMedium?.copyWith(
                            color: palette.brand,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // L'inquadratura prende tutto: e' l'unica cosa da guardare, e
                // lasciarle poco spazio farebbe sembrare la fotocamera un
                // riquadro dentro un modulo.
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _frameRatio,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          boxShadow: AppShadows.lifted,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          child: ColoredBox(
                            color: palette.surfaceMuted,
                            child: error != null
                                ? _ErrorState(message: error!, onRetry: onRetry)
                                : _Preview(controller: controller),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (failure != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  InlineBanner(message: failure),
                ],
                const SizedBox(height: AppSpacing.sm),
                _VibePicker(selected: vibe, onSelect: onVibe),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: _ShutterButton(
                    enabled: controller != null && !capturing && !publishing,
                    busy: capturing || publishing,
                    onPressed: onCapture,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                // Detto **prima** di premere, non dopo: e' un colpo solo, e
                // chi lo scopre a foto gia' online ha ragione a sentirsi
                // fregato.
                Text(
                  publishing
                      ? 'Sta partendo...'
                      : 'Un solo scatto. Nessuna seconda possibilita.',
                  textAlign: TextAlign.center,
                  style: context.texts.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Una sola etichetta, non una barra di categorie.
///
/// Sotto l'inquadratura c'e' **un tasto solo**: o quella scelta, o l'invito a
/// sceglierne una. Le otto voci vivono in un foglio che si apre e si chiude in
/// un gesto. Una fila di otto pillole sempre a schermo trasformerebbe la
/// pagina dello scatto in un modulo da compilare, e ruberebbe altezza alla
/// cosa che conta, che e' l'inquadratura.
class _VibePicker extends StatelessWidget {
  const _VibePicker({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String> onSelect;

  Future<void> _choose(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _VibeSheet(selected: selected),
    );

    if (picked != null) {
      onSelect(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chosen = DailyVibe.byId(selected);

    return Center(
      child: _VibeChip(
        label: chosen?.chip ?? 'Aggiungi una vibe',
        selected: chosen != null,
        onTap: () => _choose(context),
        icon: chosen == null ? Icons.add_rounded : null,
      ),
    );
  }
}

/// Le otto voci, in un foglio.
class _VibeSheet extends StatelessWidget {
  const _VibeSheet({required this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
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
            Text('Cosa stai facendo?', style: context.texts.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final vibe in DailyVibe.all)
                  _VibeChip(
                    label: vibe.chip,
                    selected: vibe.id == selected,
                    // Ritoccare quella gia' scelta la toglie: restare senza e'
                    // una scelta legittima, e merita lo stesso gesto.
                    onTap: () => Navigator.of(context).pop(vibe.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VibeChip extends StatelessWidget {
  const _VibeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Compare solo sull'invito a sceglierne una.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Scelta: viola pieno. Da scegliere: grigio. Il colore segnala una cosa
    // sola, cioe' che una scelta e' stata fatta.
    final foreground = selected ? palette.onBrand : palette.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.brand : palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: foreground),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: context.texts.bodySmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
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

class _Preview extends StatelessWidget {
  const _Preview({required this.controller});

  final CameraController? controller;

  @override
  Widget build(BuildContext context) {
    final active = controller;

    if (active == null || !active.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final preview = active.value.previewSize;

    // L'anteprima va inserita **in verticale**, non con le misure che il
    // sensore dichiara.
    //
    // La fotocamera descrive il proprio fotogramma in orizzontale (per
    // esempio 1280 x 720) anche quando il telefono e' in piedi e l'immagine
    // viene ruotata per essere mostrata. Dando al riquadro quelle misure
    // cosi' come sono, l'immagine veniva schiacciata su un lato: e' il "mi
    // vedo storto". Prendendo il lato corto come larghezza e quello lungo
    // come altezza le proporzioni tornano, e il ritaglio avviene senza
    // deformare nulla.
    final width = preview == null
        ? 3.0
        : math.min(preview.width, preview.height);
    final height = preview == null
        ? 4.0
        : math.max(preview.width, preview.height);

    return Transform.flip(
      flipX: _selfieFlip,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: width,
          height: height,
          child: CameraPreview(active),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography_outlined,
              size: 32,
              color: context.palette.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.texts.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(minimumSize: const Size(160, 48)),
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Il tasto di scatto: grande, tondo, uno solo.
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: 'Scatta la tua Istantanea',
      child: Material(
        color: enabled ? palette.brand : palette.surfaceMuted,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          customBorder: const CircleBorder(),
          child: SizedBox(
            height: 84,
            width: 84,
            child: busy
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: palette.onBrand,
                    ),
                  )
                : Icon(
                    Icons.photo_camera_rounded,
                    size: 34,
                    color: enabled ? palette.onBrand : palette.textSecondary,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Fuori fascia, fascia gia' usata, oppure giornata finita.
class _ClosedView extends StatelessWidget {
  const _ClosedView({required this.access});

  final DailyAccess access;

  /// Due sole situazioni: o la tua e' finita, o non e' ancora ora.
  static String _title(DailyAccess access) {
    if (access.limitReached || access.usedCurrentSlot) {
      return 'E sparita.';
    }

    return 'Non e ancora il momento.';
  }

  static String _subtitle(DailyAccess access) {
    if (access.limitReached || access.usedCurrentSlot) {
      return 'Domani ne avrai una nuova.';
    }

    return 'Ci si fa vedere tutti insieme, in tre momenti della giornata.';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EyebrowLabel('Istantanea'),
                    const SizedBox(height: AppSpacing.xl),
                    GlyphTile(
                      icon: access.limitReached || access.usedCurrentSlot
                          ? Icons.check_rounded
                          : Icons.schedule_rounded,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(_title(access), style: context.texts.displaySmall),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _subtitle(access),
                      style: context.texts.bodyLarge?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    WindowStatusCard(access: access),
                    const SizedBox(height: AppSpacing.md),
                    const WindowScheduleLine(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quanto manca alla scadenza dell'Istantanea.
///
/// E' il patto dell'app scritto in cifre: fra ventiquattr'ore quella foto non
/// esiste piu', ne' qui ne' sul server. Sta grande e al centro perche' e' la
/// cosa che rende diverso pubblicare qui invece che altrove.
class _ExpiryCard extends ConsumerWidget {
  const _ExpiryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final expiry = ref.watch(activeDailyExpiryProvider);

    if (expiry == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          Text(
            'Scade tra',
            style: context.texts.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          CountdownText(
            target: expiry,
            style: context.texts.displayMedium?.copyWith(
              color: palette.brand,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cos'e' successo oggi, in ordine.
///
/// Racconta **solo cio' che e' realmente avvenuto**: nessuna riga finta per
/// riempire, nessun "presto qualcuno ti vedra'". Il primo giorno saranno una
/// riga o due, ed e' giusto cosi' — una cronologia inventata si riconosce
/// subito e toglie valore a quelle vere.
class _MomentTimeline extends StatelessWidget {
  const _MomentTimeline({required this.day});

  final VibeDay day;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final events = <(IconData, String)>[
      (Icons.photo_camera_rounded, 'Sei online'),
      if (day.views > 0)
        (
          Icons.visibility_outlined,
          day.views == 1
              ? 'Qualcuno ha visto la tua istantanea'
              : '${day.views} persone hanno visto la tua istantanea',
        ),
      if (day.likes > 0)
        (
          Icons.favorite_rounded,
          day.likes == 1
              ? 'Hai ricevuto un cuore'
              : 'Hai ricevuto ${day.likes} cuori',
        ),
      if (day.matches > 0)
        (
          Icons.bolt_rounded,
          day.matches == 1 ? 'Hai fatto match' : 'Hai fatto ${day.matches} match',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EyebrowLabel('Il tuo momento'),
        const SizedBox(height: AppSpacing.sm),
        for (final (index, event) in events.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(event.$1, size: 17, color: palette.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(event.$2, style: context.texts.bodyMedium),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// La giornata gia' pubblicata: quante persone sono passate.
///
/// E' il ritorno che l'app deve a chi si e' esposto. Ha messo la faccia; la
/// cosa meno banale che possiamo dargli indietro e' sapere che qualcuno l'ha
/// guardata. I numeri salgono da soli mentre si sta qui: sono gli stessi dati
/// del server, in ascolto.
class _PublishedView extends ConsumerWidget {
  const _PublishedView({required this.access});

  final DailyAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final day = ref.watch(todayVibeProvider).valueOrNull ?? VibeDay.empty;
    final streak = ref.watch(streakProvider);
    final verifying = access.verifying;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Center(child: EyebrowLabel('Istantanea di oggi')),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      verifying ? 'Ci siamo quasi.' : 'Sei online.',
                      textAlign: TextAlign.center,
                      style: context.texts.displayMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      verifying
                          ? 'Un attimo e ti vedono.'
                          : 'Ora tocca agli altri scoprirti.',
                      textAlign: TextAlign.center,
                      style: context.texts.bodyLarge?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Il conto alla rovescia e' il fatto piu' importante di
                    // questa schermata: fra ventiquattr'ore la foto non
                    // esistera' piu'. Sta al centro, grande, e non dentro una
                    // frase.
                    if (verifying)
                      const Center(child: CircularProgressIndicator())
                    else
                      const _ExpiryCard(),
                    const SizedBox(height: AppSpacing.lg),
                    VibeDayRow(day: day),
                    if (!verifying) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _MomentTimeline(day: day),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Center(child: StreakBadge(days: streak)),
                    const SizedBox(height: AppSpacing.xl),
                    ElevatedButton(
                      onPressed: () => context.go(AppRoutes.discover),
                      child: const Text('Vai al Feed'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
