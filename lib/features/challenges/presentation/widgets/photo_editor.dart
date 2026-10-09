import 'dart:ui' as ui;

import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// **La foto come sara': si inquadra con due dita e ci si scrive sopra.**
///
/// ## Due funzioni in una schermata sola, e non per risparmiare
///
/// Inquadrare e scrivere sembrano due cose diverse e sono lo stesso problema:
/// quello che si vede qui deve finire **dentro il file** che parte, non restare
/// un effetto a schermo. Risolto una volta, vale per tutte e due — e separarle
/// avrebbe voluto dire due schermate che fanno lo stesso lavoro difficile in
/// due modi che prima o poi divergono.
///
/// ## Come finisce nel file
///
/// Non si calcolano ritagli. Il riquadro e' un `RepaintBoundary`, e quando si
/// conferma si **fotografa quel riquadro**: esce esattamente cio' che c'era
/// sullo schermo, pizzico e scritte comprese. Le coordinate di un ritaglio
/// calcolato a mano — scala, spostamento, come la foto riempie il riquadro —
/// sono tre conti che devono tornare tutti e tre, e il giorno che uno non
/// torna la foto esce tagliata storta senza che nessun errore lo dica.
///
/// **E non si perde qualita'.** La catena che segue stringe comunque il lato
/// lungo a milleseicento punti: catturare a quella misura non butta via niente
/// che sarebbe sopravvissuto un passaggio dopo.
///
/// ## Si scrive, non si disegna
///
/// Solo testo. Un pennello libero su una foto che poi finisce in una gara
/// pubblica e' una superficie su cui si puo' disegnare qualunque cosa, e
/// moderare uno scarabocchio e' molto piu' difficile che moderare una frase —
/// le parole si leggono, un disegno va guardato da una persona.
class PhotoEditor extends StatefulWidget {
  const PhotoEditor({
    required this.bytes,
    required this.aspectRatio,
    this.inquadrabile = true,
    super.key,
  });

  final Uint8List bytes;

  /// Le proporzioni del riquadro in cui la foto andra' a finire.
  final double aspectRatio;

  /// Se si puo' muovere e ingrandire.
  ///
  /// Acceso sulle foto prese dalla galleria, che arrivano di tutte le forme e
  /// vengono tagliate dal riquadro senza che nessuno abbia scelto **dove**.
  /// Su uno scatto fatto adesso il taglio lo ha gia' deciso chi inquadrava.
  final bool inquadrabile;

  @override
  State<PhotoEditor> createState() => _PhotoEditorState();
}

class _PhotoEditorState extends State<PhotoEditor> {
  final _riquadro = GlobalKey();
  final _scritte = <_Scritta>[];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Sistemala'),
        actions: [
          if (_scritte.isNotEmpty)
            TextButton(
              onPressed: () => setState(_scritte.removeLast),
              child: Text(
                'ANNULLA',
                style: context.texts.labelSmall?.copyWith(
                  color: palette.textFaint,
                ),
              ),
            ),
        ],
      ),
      body: AppBackground(
        child: Column(
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.media),
                child: AspectRatio(
                  aspectRatio: widget.aspectRatio,
                  // **Il confine di cio' che verra' catturato.** Tutto quello
                  // che sta dentro questo riquadro finisce nel file; tutto
                  // quello che sta fuori non esiste. E' la stessa cosa che
                  // vede chi guarda, ed e' il punto: non c'e' nessuna
                  // sorpresa fra l'anteprima e quello che parte.
                  child: RepaintBoundary(
                    key: _riquadro,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (widget.inquadrabile)
                          InteractiveViewer(
                            // Sotto l'uno la foto si staccherebbe dai bordi
                            // lasciando vedere il fondo: quello che esce dal
                            // riquadro e' tagliato, ma il riquadro deve
                            // restare pieno.
                            minScale: 1,
                            maxScale: 4,
                            clipBehavior: Clip.none,
                            child: Image.memory(
                              widget.bytes,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Image.memory(widget.bytes, fit: BoxFit.cover),
                        for (final scritta in _scritte)
                          _ScrittaSopra(
                            scritta: scritta,
                            onMuovi: (dove) =>
                                setState(() => scritta.posizione = dove),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.inquadrabile
                  ? 'Due dita per ingrandire e spostare. Quello che resta '
                        'dentro il riquadro è quello che mandi.'
                  : 'Quello che resta dentro il riquadro è quello che mandi.',
              textAlign: TextAlign.center,
              style: context.texts.bodySmall?.copyWith(
                color: palette.textFaint,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.lg,
              ),
              child: Column(
                children: [
                  TextButton.icon(
                    onPressed: _scrivi,
                    icon: Icon(
                      Icons.text_fields_rounded,
                      size: 18,
                      color: palette.accent,
                    ),
                    label: Text(
                      'SCRIVI SULLA FOTO',
                      style: context.texts.labelSmall?.copyWith(
                        color: palette.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  CrasyButton(label: 'Va bene così', onPressed: _conferma),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scrivi() async {
    final testo = await showDialog<String>(
      context: context,
      builder: (context) => const _ChiediIlTesto(),
    );

    if (testo == null || testo.trim().isEmpty) {
      return;
    }

    setState(() {
      _scritte.add(
        _Scritta(
          testo: testo.trim(),
          // Nasce al centro: da li' si trascina dove serve. Metterla in alto
          // vorrebbe dire che chi scrive una riga sola non la sposta mai, e
          // sarebbero tutte le foto con la frase nello stesso punto.
          posizione: const Offset(0.5, 0.5),
        ),
      );
    });
  }

  /// **Fotografa il riquadro e torna i byte.**
  ///
  /// Il rapporto di tre non e' a caso: il riquadro e' largo quanto lo schermo
  /// meno i margini — sui trecentocinquanta punti — e per tre fa poco piu' di
  /// mille pixel sul lato lungo. La catena che segue stringe comunque a
  /// milleseicento, quindi di piu' sarebbe lavoro buttato; di meno si
  /// vedrebbe.
  Future<void> _conferma() async {
    final confine =
        _riquadro.currentContext?.findRenderObject() as RenderRepaintBoundary?;

    if (confine == null) {
      Navigator.of(context).pop();

      return;
    }

    final immagine = await confine.toImage(pixelRatio: 3);
    final dati = await immagine.toByteData(format: ui.ImageByteFormat.png);
    immagine.dispose();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(dati?.buffer.asUint8List());
  }
}

/// Una frase scritta sopra la foto: cosa dice e dove sta.
class _Scritta {
  _Scritta({required this.testo, required this.posizione});

  final String testo;

  /// In frazioni del riquadro, non in pixel: cosi' resta nello stesso punto
  /// qualunque sia la misura dello schermo, e soprattutto resta dov'e' quando
  /// il riquadro viene fotografato a tre volte la risoluzione.
  Offset posizione;
}

class _ScrittaSopra extends StatelessWidget {
  const _ScrittaSopra({required this.scritta, required this.onMuovi});

  final _Scritta scritta;
  final ValueChanged<Offset> onMuovi;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, vincoli) {
        return Positioned(
          left: scritta.posizione.dx * vincoli.maxWidth,
          top: scritta.posizione.dy * vincoli.maxHeight,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: GestureDetector(
              onPanUpdate: (dettagli) {
                final nuova = Offset(
                  (scritta.posizione.dx + dettagli.delta.dx / vincoli.maxWidth)
                      .clamp(0.0, 1.0),
                  (scritta.posizione.dy + dettagli.delta.dy / vincoli.maxHeight)
                      .clamp(0.0, 1.0),
                );

                onMuovi(nuova);
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: vincoli.maxWidth * 0.9),
                child: Text(
                  scritta.testo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    // **L'ombra non e' decorazione: e' l'unica cosa che tiene
                    // il bianco leggibile.** Una frase bianca su una foto
                    // chiara — neve, un muro, il cielo — sparisce, e chi la
                    // scrive se ne accorge solo dopo averla mandata.
                    shadows: [
                      Shadow(blurRadius: 12, color: Colors.black54),
                      Shadow(blurRadius: 3, color: Colors.black87),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Il riquadro in cui si batte la frase.
class _ChiediIlTesto extends StatefulWidget {
  const _ChiediIlTesto();

  @override
  State<_ChiediIlTesto> createState() => _ChiediIlTestoState();
}

class _ChiediIlTestoState extends State<_ChiediIlTesto> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.palette.background,
      title: Text('Scrivi sulla foto', style: context.texts.titleMedium),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        maxLines: 2,
        textCapitalization: TextCapitalization.sentences,
        // Sessanta caratteri e due righe: oltre, una frase sopra una foto
        // smette di essere una didascalia e diventa un muro che copre quello
        // che c'e' sotto.
        inputFormatters: [LengthLimitingTextInputFormatter(60)],
        decoration: const InputDecoration(hintText: 'Una frase, corta'),
        onSubmitted: (testo) => Navigator.of(context).pop(testo),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Metti'),
        ),
      ],
    );
  }
}
