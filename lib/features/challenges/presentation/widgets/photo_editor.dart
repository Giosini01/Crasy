import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// **La foto come sara': si inquadra e ci si scrive sopra, in una schermata.**
///
/// ## Una sola, e prima erano due
///
/// C'e' stato un passaggio in mezzo — *inquadra*, poi **Avanti**, poi *scrivi*
/// — ed e' durato poco: chi scatta vuole mandare, e un tasto che non fa altro
/// che portare alla schermata dopo e' un tasto che chiede permesso per niente.
///
/// I due passi erano nati per un problema vero, pero': **le dita sono le
/// stesse**. Un dito che trascina puo' voler dire due cose, sposto la foto o
/// sposto la frase. La risposta non era separare i momenti, era separare i
/// gesti:
///
/// - **un dito sulla frase** la sposta;
/// - **un dito altrove** sposta la foto dentro il riquadro;
/// - **due dita** ingrandiscono: la frase se partono da li' sopra, la foto se
///   partono dal resto.
///
/// Nessuna ambiguita' da risolvere, perche' il punto in cui appoggi il dito
/// dice gia' di cosa stai parlando. E' lo stesso modo di tutte le app in cui
/// si scrive sopra una foto, ed e' il motivo per cui non ha bisogno di
/// istruzioni.
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
    super.key,
  });

  final Uint8List bytes;

  /// Le proporzioni del riquadro in cui la foto andra' a finire.
  final double aspectRatio;

  @override
  State<PhotoEditor> createState() => _PhotoEditorState();
}

class _PhotoEditorState extends State<PhotoEditor> {
  final _riquadro = GlobalKey();
  final _scritte = <_Scritta>[];
  final _inquadratura = TransformationController();

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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final area = areaSempreVisibile(widget.aspectRatio);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('La tua foto'),
        actions: [
          if (_scritte.isNotEmpty)
            TextButton(
              onPressed: () => setState(_scritte.removeLast),
              child: Text(
                'TOGLI',
                style: context.texts.labelSmall?.copyWith(
                  color: palette.textFaint,
                ),
              ),
            ),
          // **"Aa", e non "SCRIVI SULLA FOTO".**
          //
          // Due lettere che tutti hanno gia' imparato altrove: nessuno deve
          // leggerle per capire cosa fanno, si riconoscono come si riconosce
          // il cestino. Stanno in cima e non in fondo perche' il fondo e' del
          // tasto che chiude il lavoro, e un comando che apre una tastiera
          // appiccicato a quello e' il tipo di vicinanza che fa sbagliare.
          IconButton(
            onPressed: _scrivi,
            tooltip: 'Scrivi sulla foto',
            icon: Text(
              'Aa',
              style: context.texts.titleMedium?.copyWith(
                color: palette.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: AppBackground(
        child: Column(
          children: [
            // **Il riquadro prende lo spazio che c'e', non quello che
            // vorrebbe.** Con una misura libera, su uno schermo basso — un
            // tablet, l'orizzontale — un riquadro quattro quinti largo quanto
            // lo schermo diventa piu' alto dello schermo stesso, e la colonna
            // sfonda: la spiegazione e il tasto finiscono sotto il bordo.
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
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadius.media,
                              ),
                              child: AspectRatio(
                                aspectRatio: widget.aspectRatio,
                                // **Il confine di cio' che verra' catturato.**
                                // Tutto quello che sta dentro questo riquadro
                                // finisce nel file; tutto quello che sta fuori
                                // non esiste. E' la stessa cosa che vede chi
                                // guarda, ed e' il punto: nessuna sorpresa fra
                                // l'anteprima e quello che parte.
                                child: RepaintBoundary(
                                  key: _riquadro,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (_proporzioni != null)
                                        _DaInquadrare(
                                          bytes: widget.bytes,
                                          proporzioniFoto: _proporzioni!,
                                          proporzioniRiquadro:
                                              widget.aspectRatio,
                                          controller: _inquadratura,
                                        )
                                      else
                                        Image.memory(
                                          widget.bytes,
                                          fit: BoxFit.cover,
                                        ),
                                      if (_scritte.isNotEmpty)
                                        // **Un solo `Positioned.fill` per
                                        // tutte le frasi.** Prima ogni frase
                                        // era un `LayoutBuilder` che
                                        // restituiva un `Positioned`, e un
                                        // `Positioned` deve stare attaccato
                                        // allo `Stack`: messo dentro
                                        // qualunque altra cosa faceva cadere
                                        // l'app nell'istante in cui si
                                        // metteva la scritta.
                                        Positioned.fill(
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
                                                        area: area,
                                                        onCambia: () =>
                                                            setState(() {}),
                                                      ),
                                                  ],
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // **Fuori dal riquadro che viene fotografato**,
                            // quindi queste righe non finiscono nella foto:
                            // sono un aiuto per chi scrive, non un segno
                            // sull'immagine. Compaiono solo quando c'e' una
                            // frase: senza, segnerebbero un limite che non
                            // riguarda nessuno.
                            if (_scritte.isNotEmpty)
                              Positioned.fill(child: _SegnaIlBordo(area: area)),
                          ],
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
              child: CrasyButton(label: 'Fatto', onPressed: _conferma),
            ),
          ],
        ),
      ),
    );
  }

  /// La riga sotto la foto: dice cosa fanno le dita, adesso.
  ///
  /// Cambia quando compare la prima frase, perche' da quel momento cambiano i
  /// gesti. Elencarli tutti da subito farebbe un manuale, e un manuale non lo
  /// legge nessuno.
  String get _spiegazione {
    if (_scritte.isEmpty) {
      return 'Trascina per scegliere cosa tenere, due dita per ingrandire. '
          'Con Aa ci scrivi sopra.';
    }

    return 'La frase si sposta con un dito e si ridimensiona con due. Resta '
        'dentro le righe tratteggiate: piu su o piu giu, nelle anteprime '
        'quadrate verrebbe tagliata.';
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
  });

  final Uint8List bytes;
  final double proporzioniFoto;
  final double proporzioniRiquadro;
  final TransformationController controller;

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

/// **La parte della foto che si vede sempre, in frazioni del riquadro.**
///
/// ## Il difetto che questa funzione esiste per togliere
///
/// Si scrive su un riquadro quattro quinti, ma la foto in giro per l'app non
/// si vede quasi mai cosi': nelle griglie delle partecipazioni, nella
/// rivelazione del vincitore e fra i vincitori recenti e' **quadrata**, e un
/// quadrato ritagliato da un quattro quinti butta via un decimo di altezza
/// sopra e un decimo sotto.
///
/// Una frase messa in cima — che e' il posto in cui la mette chiunque — nella
/// griglia **non c'era piu'**. Chi l'aveva scritta la vedeva a schermo intero
/// e dava per scontato che ci fosse ovunque.
///
/// ## Come si calcola
///
/// Dal ritaglio **piu' largo** viene il limite sopra e sotto, da quello **piu'
/// stretto** il limite ai lati. Non sono numeri scritti a mano: cambiando la
/// misura di una griglia cambia questa, e la frase si sposta di conseguenza
/// invece di sparire di nuovo.
Rect areaSempreVisibile(double riquadro) {
  // Le griglie, la rivelazione del vincitore, i vincitori recenti.
  const piuLargo = 1.0;

  // Le figurine dei trofei, piu' alte che larghe.
  const piuStretto = 0.72;

  final altezza = riquadro < piuLargo ? riquadro / piuLargo : 1.0;
  final larghezza = piuStretto < riquadro ? piuStretto / riquadro : 1.0;

  final lato = (1 - larghezza) / 2;
  final sopra = (1 - altezza) / 2;

  return Rect.fromLTRB(lato, sopra, 1 - lato, 1 - sopra);
}

/// Le due righe che segnano dove la frase non puo' andare.
///
/// **Si disegnano fuori dal `RepaintBoundary`**, quindi non finiscono nella
/// foto: sono un aiuto per chi scrive, non un segno sull'immagine. Senza, il
/// limite si sentirebbe come una frase che si incolla a meta' strada per un
/// motivo che non si vede — cioe' come un difetto.
class _SegnaIlBordo extends StatelessWidget {
  const _SegnaIlBordo({required this.area});

  final Rect area;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _BordoSicuro(area: area)),
    );
  }
}

class _BordoSicuro extends CustomPainter {
  const _BordoSicuro({required this.area});

  final Rect area;

  @override
  void paint(Canvas tela, Size misura) {
    final pennello = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1;

    for (final y in [area.top * misura.height, area.bottom * misura.height]) {
      // Tratteggiata: una riga piena si legge come una cornice della foto, e
      // chi guarda si chiede se finira' nel file.
      for (var x = 0.0; x < misura.width; x += 12) {
        tela.drawLine(Offset(x, y), Offset(x + 6, y), pennello);
      }
    }
  }

  @override
  bool shouldRepaint(_BordoSicuro vecchio) => vecchio.area != area;
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
    required this.area,
    required this.onCambia,
  });

  final _Scritta scritta;

  /// La misura del riquadro: serve a tradurre le frazioni in punti, e i punti
  /// trascinati in frazioni.
  final Size riquadro;

  /// La parte di foto che si vede sempre. La frase non ne esce.
  final Rect area;

  final VoidCallback onCambia;

  @override
  State<_ScrittaSopra> createState() => _ScrittaSopraState();
}

/// Come si vede una frase sulla foto.
///
/// Sta fuori dal widget perche' lo usano in due: chi la disegna e chi la
/// misura per sapere quanto spazio occupa. Due copie della stessa cosa
/// vorrebbero dire una frase misurata con un carattere e disegnata con un
/// altro, e un limite che casca fuori posto.
TextStyle _stile(double scala) => TextStyle(
  color: Colors.white,
  fontSize: 22 * scala,
  fontWeight: FontWeight.w800,
  height: 1.15,
  // **L'ombra non e' decorazione: e' l'unica cosa che tiene il bianco
  // leggibile.** Una frase bianca su una foto chiara — neve, un muro, il
  // cielo — sparisce, e chi la scrive se ne accorge solo dopo averla mandata.
  shadows: const [
    Shadow(blurRadius: 12, color: Colors.black54),
    Shadow(blurRadius: 3, color: Colors.black87),
  ],
);

class _ScrittaSopraState extends State<_ScrittaSopra> {
  /// Quanto era grande quando le dita si sono appoggiate.
  ///
  /// `details.scale` e' relativo all'inizio del gesto, non alla misura
  /// precedente: senza tenerla da parte, ogni nuovo pizzico ripartirebbe da
  /// uno e la frase tornerebbe alla misura iniziale.
  double _scalaAllInizio = 1;

  /// Meta' della frase, in frazioni del riquadro.
  ///
  /// Si misurano a ogni ridisegno e si tengono qui perche' servono **durante
  /// il gesto**, quando non c'e' nessun riquadro da interrogare: senza, il
  /// limite si potrebbe mettere solo al centro della frase, e una frase larga
  /// uscirebbe comunque dai lati con mezza parola.
  double _mezzaLarghezza = 0;
  double _mezzaAltezza = 0;

  /// Tiene il centro della frase dentro l'area, frase intera compresa.
  ///
  /// Il `min` e il `max` contro il mezzo non sono prudenza inutile: una frase
  /// piu' grande dell'area sicura — tre righe al triplo della misura — darebbe
  /// un limite basso sopra a quello alto, e `clamp` su quello solleva. In quel
  /// caso l'unica posizione sensata e' il centro, e la si da'.
  Offset _dentro(Offset dove) {
    final area = widget.area;

    return Offset(
      dove.dx.clamp(
        math.min(area.left + _mezzaLarghezza, 0.5),
        math.max(area.right - _mezzaLarghezza, 0.5),
      ),
      dove.dy.clamp(
        math.min(area.top + _mezzaAltezza, 0.5),
        math.max(area.bottom - _mezzaAltezza, 0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scritta = widget.scritta;
    final riquadro = widget.riquadro;
    final stile = _stile(scritta.scala);
    final largoAlMassimo = riquadro.width * 0.9;

    // **Quanto occupa davvero la frase**, battuta a mano invece di chiederlo
    // al riquadro dopo: serve adesso, per sapere di quanto tenerla lontana dal
    // bordo.
    final misurato = TextPainter(
      text: TextSpan(text: scritta.testo, style: stile),
      textAlign: TextAlign.center,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: largoAlMassimo);

    _mezzaLarghezza = misurato.width / 2 / riquadro.width;
    _mezzaAltezza = misurato.height / 2 / riquadro.height;

    // Il posto in cui si disegna e' gia' dentro i limiti anche se quello
    // salvato non lo e' piu': ingrandendo la frase l'area le sta stretta, e
    // deve rientrare da sola invece di sbordare finche' qualcuno la trascina.
    final dove = _dentro(scritta.posizione);

    return Positioned(
      left: dove.dx * riquadro.width,
      top: dove.dy * riquadro.height,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onScaleStart: (_) => _scalaAllInizio = scritta.scala,
          onScaleUpdate: (dettagli) {
            scritta.posizione = _dentro(
              Offset(
                dove.dx + dettagli.focalPointDelta.dx / riquadro.width,
                dove.dy + dettagli.focalPointDelta.dy / riquadro.height,
              ),
            );

            // **Fra meta' e tre volte.** Sotto la meta' non si legge piu' —
            // undici punti su una foto sono un graffio — e sopra il triplo una
            // riga da sessanta caratteri copre tutta la foto, cioe' esattamente
            // quello che il limite di sessanta caratteri serviva a evitare.
            scritta.scala = (_scalaAllInizio * dettagli.scale).clamp(0.5, 3.0);

            widget.onCambia();
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: largoAlMassimo),
            child: Text(
              scritta.testo,
              textAlign: TextAlign.center,
              style: stile,
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
