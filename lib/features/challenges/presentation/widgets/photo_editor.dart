import 'dart:async';
import 'dart:ui' as ui;

import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// **La foto come sara': prima si inquadra, poi ci si scrive sopra.**
///
/// ## Due passi, e non una schermata sola
///
/// All'inizio erano insieme: si pizzicava la foto e si scriveva sopra nello
/// stesso momento. Non funzionava, e il motivo e' che **le dita sono le
/// stesse**. Un dito che trascina sulla foto puo' voler dire due cose — sposto
/// l'inquadratura, sposto la frase — e due dita che si allargano altre due:
/// ingrandisco la foto, ingrandisco la frase. Chiunque scriva qualcosa si
/// ritrova a spostare la foto provando a spostare la scritta.
///
/// Divisi in due passi la domanda non si pone piu': nel primo le dita parlano
/// alla foto, nel secondo alla frase. Si va avanti con un tasto e si torna
/// indietro con la freccia, senza perdere niente di quello che si era fatto.
///
/// Chi fa lo scatto adesso parte dal secondo: l'inquadratura l'ha appena
/// scelta col mirino, e un passo che chiede di rifarla e' un passo di troppo.
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
/// E' anche il motivo per cui la frase finisce **dentro la foto** e non resta
/// una sovrimpressione dell'app: quello che si vede nel riquadro e' il file.
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
  /// Su uno scatto fatto adesso il taglio lo ha gia' deciso chi inquadrava, e
  /// il primo passo si salta.
  final bool inquadrabile;

  @override
  State<PhotoEditor> createState() => _PhotoEditorState();
}

class _PhotoEditorState extends State<PhotoEditor> {
  final _riquadro = GlobalKey();
  final _scritte = <_Scritta>[];
  final _inquadratura = TransformationController();

  /// A che passo si e': inquadrare, o scrivere.
  ///
  /// Chi arriva da uno scatto comincia dal secondo: l'inquadratura l'ha scelta
  /// col mirino un istante prima.
  late bool _scrivendo = !widget.inquadrabile;

  /// Le proporzioni vere della foto, lette dal file.
  ///
  /// **Senza, non si puo' spostare niente.** Finche' l'immagine veniva
  /// semplicemente stretta dentro il riquadro con `cover`, a ingrandimento uno
  /// non c'era nessuna parte fuori da far entrare: la foto era gia' tutta li',
  /// tagliata, e l'unico modo di muoverla era ingrandirla — cioe' tagliarne
  /// ancora di piu'. Su una verticale era il caso peggiore: non si poteva
  /// scegliere se tenere la testa o i piedi.
  ///
  /// Sapendo quanto e' alta davvero, la si mette nel riquadro alla sua misura
  /// e cio' che avanza si sposta.
  double? _proporzioni;

  @override
  void initState() {
    super.initState();
    unawaited(_misura());
  }

  @override
  void dispose() {
    _inquadratura.dispose();
    super.dispose();
  }

  Future<void> _misura() async {
    final decodificata = await decodeImageFromList(widget.bytes);

    if (!mounted) {
      return;
    }

    setState(() {
      _proporzioni = decodificata.width / decodificata.height;
    });

    decodificata.dispose();
  }

  /// Se la freccia indietro deve tornare al primo passo invece di uscire.
  bool get _tornaIndietroAlPrimoPasso => _scrivendo && widget.inquadrabile;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // **Il gesto laterale di Android porta indietro di un passo, non fuori.**
    // Senza, chi al secondo passo fa il gesto che si fa cento volte al giorno
    // perde anche l'inquadratura che aveva scelto al primo.
    return PopScope(
      canPop: !_tornaIndietroAlPrimoPasso,
      onPopInvokedWithResult: (fatto, _) {
        if (!fatto) {
          setState(() => _scrivendo = false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () {
              if (_tornaIndietroAlPrimoPasso) {
                setState(() => _scrivendo = false);

                return;
              }

              Navigator.of(context).pop();
            },
          ),
          title: Text(_scrivendo ? 'Scrivici sopra' : 'Inquadrala'),
          actions: [
            if (_scrivendo && _scritte.isNotEmpty)
              TextButton(
                onPressed: () => setState(_scritte.removeLast),
                child: Text(
                  'TOGLI',
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
              // **Il riquadro prende lo spazio che c'e', non quello che
              // vorrebbe.** Con due `Spacer` e una misura libera, su uno
              // schermo basso — orizzontale, un tablet — un riquadro quattro
              // quinti largo quanto lo schermo diventa piu' alto dello schermo
              // stesso, e la colonna sfonda: la spiegazione e i tasti finiscono
              // sotto il bordo, cioe' spariscono.
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.page,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadius.media,
                            ),
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
                                    if (widget.inquadrabile &&
                                        _proporzioni != null)
                                      _DaInquadrare(
                                        bytes: widget.bytes,
                                        proporzioniFoto: _proporzioni!,
                                        proporzioniRiquadro: widget.aspectRatio,
                                        controller: _inquadratura,
                                        // Al secondo passo la foto si ferma: le dita da
                                        // li' in poi parlano alla frase, e un visore che
                                        // risponde ancora e' esattamente l'ambiguita'
                                        // che i due passi esistono per togliere.
                                        gesti: !_scrivendo,
                                      )
                                    else
                                      Image.memory(
                                        widget.bytes,
                                        fit: BoxFit.cover,
                                      ),
                                    if (_scritte.isNotEmpty)
                                      // **Un solo `Positioned.fill` per tutte le
                                      // frasi.** Prima ogni frase era un `LayoutBuilder`
                                      // che restituiva un `Positioned`, e un
                                      // `Positioned` deve stare attaccato allo `Stack`:
                                      // messo dentro qualunque altra cosa fa cadere
                                      // l'app nell'istante in cui si mette la scritta.
                                      // Qui la misura del riquadro la si legge una volta
                                      // e lo `Stack` interno ha i suoi `Positioned` come
                                      // figli diretti.
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          // Al primo passo le frasi si vedono — serve a
                                          // sapere cosa si sta inquadrando — ma non
                                          // prendono i tocchi, che sono della foto.
                                          ignoring: !_scrivendo,
                                          child: LayoutBuilder(
                                            builder: (context, vincoli) =>
                                                Stack(
                                                  children: [
                                                    for (final scritta
                                                        in _scritte)
                                                      _ScrittaSopra(
                                                        scritta: scritta,
                                                        riquadro: Size(
                                                          vincoli.maxWidth,
                                                          vincoli.maxHeight,
                                                        ),
                                                        onCambia: () =>
                                                            setState(() {}),
                                                      ),
                                                  ],
                                                ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.page,
                        ),
                        child: Text(
                          _spiegazione,
                          textAlign: TextAlign.center,
                          style: context.texts.bodySmall?.copyWith(
                            color: palette.textFaint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  0,
                  AppSpacing.page,
                  AppSpacing.lg,
                ),
                child: _scrivendo ? _tastiDelloScrivere(context) : _tastoAvanti,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _spiegazione {
    if (!_scrivendo) {
      return widget.inquadrabile
          ? 'Trascina per scegliere cosa tenere, due dita per ingrandire. '
                'Quello che resta dentro il riquadro è quello che mandi.'
          : 'Quello che resta dentro il riquadro è quello che mandi.';
    }

    return _scritte.isEmpty
        ? 'Se vuoi, aggiungi una frase sopra la foto. Oppure manda la foto '
              'così com\'è.'
        : 'Trascinala dove vuoi. Due dita per farla più grande o più piccola.';
  }

  Widget get _tastoAvanti => CrasyButton(
    label: 'Avanti',
    onPressed: () => setState(() => _scrivendo = true),
  );

  Widget _tastiDelloScrivere(BuildContext context) {
    final palette = context.palette;

    return Column(
      children: [
        TextButton.icon(
          onPressed: _scrivi,
          icon: Icon(
            Icons.text_fields_rounded,
            size: 18,
            color: palette.accent,
          ),
          label: Text(
            _scritte.isEmpty ? 'SCRIVI SULLA FOTO' : 'SCRIVI UN\'ALTRA FRASE',
            style: context.texts.labelSmall?.copyWith(color: palette.accent),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        CrasyButton(label: 'Va bene così', onPressed: _conferma),
      ],
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

/// **La foto dentro il riquadro, alla sua misura vera e spostabile.**
///
/// ## Il difetto che questa classe esiste per togliere
///
/// Prima la foto veniva stretta nel riquadro con `cover` e data in pasto a un
/// `InteractiveViewer`. A ingrandimento uno non si muoveva di un pixel, e il
/// motivo e' che non c'era **niente fuori**: l'immagine era gia' tagliata alla
/// misura del riquadro, e quello che avanzava era stato buttato prima che
/// qualcuno potesse sceglierlo. L'unico modo di spostarla era ingrandirla,
/// cioe' tagliare ancora di piu' per vedere una parte diversa.
///
/// Su una foto verticale era il caso peggiore e il piu' comune: in un riquadro
/// quattro quinti una foto da telefono perde un quarto della sua altezza, e non
/// si poteva decidere se perderla in cima o in fondo.
///
/// ## Come funziona adesso
///
/// La foto entra alla sua **misura intera** — piu' alta del riquadro se e'
/// verticale, piu' larga se e' orizzontale — e `constrained: false` dice al
/// visore di non stringerla. Quello che avanza esce dai bordi e si trascina
/// dentro.
///
/// I bordi li tiene il visore stesso: con un margine nullo non lascia che il
/// bordo della foto entri nel riquadro, quindi non si puo' scoprire il fondo.
/// Non c'e' nessun calcolo da fare e nessun conto che possa sbagliare.
///
/// Parte **centrata**: il taglio predefinito resta quello di prima, e chi non
/// tocca niente ottiene esattamente cio' che otteneva. Si sposta chi vuole.
class _DaInquadrare extends StatefulWidget {
  const _DaInquadrare({
    required this.bytes,
    required this.proporzioniFoto,
    required this.proporzioniRiquadro,
    required this.controller,
    this.gesti = true,
  });

  final Uint8List bytes;
  final double proporzioniFoto;
  final double proporzioniRiquadro;
  final TransformationController controller;

  /// Se le dita muovono ancora la foto.
  ///
  /// Spento al secondo passo: l'inquadratura resta quella scelta — il
  /// controller non si tocca — ma le dita da li' in poi sono della frase.
  final bool gesti;

  @override
  State<_DaInquadrare> createState() => _DaInquadrareState();
}

class _DaInquadrareState extends State<_DaInquadrare> {
  Size? _ultimoRiquadro;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, vincoli) {
        final larghezza = vincoli.maxWidth;
        final altezza = vincoli.maxHeight;

        // La misura con cui la foto copre il riquadro: il lato corto combacia,
        // l'altro avanza. E' lo stesso conto che fa `BoxFit.cover` — qui pero'
        // quello che avanza resta, invece di essere tagliato via subito.
        final piuAlta = widget.proporzioniFoto < widget.proporzioniRiquadro;
        final fotoLarga = piuAlta
            ? larghezza
            : altezza * widget.proporzioniFoto;
        final fotoAlta = piuAlta ? larghezza / widget.proporzioniFoto : altezza;

        final riquadro = Size(larghezza, altezza);

        if (_ultimoRiquadro != riquadro) {
          _ultimoRiquadro = riquadro;

          // Centrata di partenza, **dopo questo fotogramma**: scrivere sul
          // controller durante la costruzione vuol dire chiedere un ridisegno
          // mentre il ridisegno e' in corso, ed e' l'errore che si legge come
          // "setState durante build" senza nessun legame con la causa.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.controller.value = Matrix4.identity()
                ..translateByDouble(
                  -(fotoLarga - larghezza) / 2,
                  -(fotoAlta - altezza) / 2,
                  0,
                  1,
                );
            }
          });
        }

        return InteractiveViewer(
          transformationController: widget.controller,
          // **Non stringere la foto nel riquadro.** E' questa riga a rendere
          // possibile lo spostamento: senza, il visore ridimensiona il figlio
          // alla propria misura e non resta niente fuori da far entrare.
          constrained: false,
          panEnabled: widget.gesti,
          scaleEnabled: widget.gesti,
          minScale: 1,
          maxScale: 4,
          // Margine nullo: il bordo della foto non puo' entrare nel riquadro,
          // quindi il fondo non si scopre mai.
          boundaryMargin: EdgeInsets.zero,
          child: SizedBox(
            width: fotoLarga,
            height: fotoAlta,
            child: Image.memory(widget.bytes, fit: BoxFit.fill),
          ),
        );
      },
    );
  }
}

/// Una frase scritta sopra la foto: cosa dice, dove sta, quanto e' grande.
class _Scritta {
  _Scritta({required this.testo, required this.posizione});

  final String testo;

  /// In frazioni del riquadro, non in pixel: cosi' resta nello stesso punto
  /// qualunque sia la misura dello schermo, e soprattutto resta dov'e' quando
  /// il riquadro viene fotografato a tre volte la risoluzione.
  Offset posizione;

  /// Quanto e' stata ingrandita con due dita. Uno e' la misura di partenza.
  double scala = 1;
}

/// Una frase sopra la foto: si trascina con un dito, si ridimensiona con due.
///
/// **Un gesto solo per tutte e due le cose**, non due gesti separati:
/// `onScaleUpdate` arriva anche con un dito — e in quel caso `scale` vale uno e
/// si muove soltanto. Tenere un `onPanUpdate` accanto a un `onScaleUpdate`
/// vuol dire due riconoscitori che si contendono le stesse dita, e il secondo
/// dito che appoggi fa saltare la frase.
class _ScrittaSopra extends StatefulWidget {
  const _ScrittaSopra({
    required this.scritta,
    required this.riquadro,
    required this.onCambia,
  });

  final _Scritta scritta;

  /// La misura del riquadro: serve a tradurre le frazioni in punti, e i punti
  /// trascinati in frazioni.
  final Size riquadro;

  final VoidCallback onCambia;

  @override
  State<_ScrittaSopra> createState() => _ScrittaSopraState();
}

class _ScrittaSopraState extends State<_ScrittaSopra> {
  /// Quanto era grande quando le dita si sono appoggiate.
  ///
  /// `details.scale` e' relativo all'inizio del gesto, non alla misura
  /// precedente: senza tenerla da parte, ogni nuovo pizzico ripartirebbe da
  /// uno e la frase tornerebbe alla misura iniziale.
  double _scalaAllInizio = 1;

  /// La misura di partenza della frase, in punti.
  static const double _misuraBase = 22;

  @override
  Widget build(BuildContext context) {
    final scritta = widget.scritta;
    final riquadro = widget.riquadro;

    return Positioned(
      left: scritta.posizione.dx * riquadro.width,
      top: scritta.posizione.dy * riquadro.height,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onScaleStart: (_) => _scalaAllInizio = scritta.scala,
          onScaleUpdate: (dettagli) {
            scritta.posizione = Offset(
              (scritta.posizione.dx +
                      dettagli.focalPointDelta.dx / riquadro.width)
                  .clamp(0.0, 1.0),
              (scritta.posizione.dy +
                      dettagli.focalPointDelta.dy / riquadro.height)
                  .clamp(0.0, 1.0),
            );

            // **Fra meta' e tre volte.** Sotto la meta' non si legge piu' —
            // undici punti su una foto sono un graffio — e sopra il triplo una
            // riga da sessanta caratteri copre tutta la foto, cioe' esattamente
            // quello che il limite di sessanta caratteri serviva a evitare.
            scritta.scala = (_scalaAllInizio * dettagli.scale).clamp(0.5, 3.0);

            widget.onCambia();
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: riquadro.width * 0.9),
            child: Text(
              scritta.testo,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: _misuraBase * scritta.scala,
                fontWeight: FontWeight.w800,
                height: 1.15,
                // **L'ombra non e' decorazione: e' l'unica cosa che tiene
                // il bianco leggibile.** Una frase bianca su una foto
                // chiara — neve, un muro, il cielo — sparisce, e chi la
                // scrive se ne accorge solo dopo averla mandata.
                shadows: const [
                  Shadow(blurRadius: 12, color: Colors.black54),
                  Shadow(blurRadius: 3, color: Colors.black87),
                ],
              ),
            ),
          ),
        ),
      ),
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
