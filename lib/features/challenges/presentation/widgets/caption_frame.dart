import 'package:flutter/material.dart';

/// La didascalia scritta **lungo il bordo arrotondato della foto**.
///
/// Parte dal lato sinistro, sale, gira sopra l'angolo tondo, corre lungo il
/// lato alto e ridiscende dall'altra parte: le lettere seguono la curva una per
/// una, ognuna girata quanto serve. E' la forma delle istantanee di Instagram.
///
/// ## Perche' sul bordo e non sotto la foto
///
/// Una didascalia messa sotto e' una riga di testo **accanto** a un'immagine:
/// due cose separate, che si guardano una alla volta. Scritta sul bordo diventa
/// parte dell'oggetto — come la scritta a pennarello sul bianco di una polaroid
/// — e si legge insieme alla foto invece che dopo.
///
/// ## E perche' solo sulla foto piccola
///
/// Perche' li' serve. Nell'elenco la foto e' un rettangolo fra tanti, e la
/// scritta attorno e' l'unica cosa che dice **cosa sta succedendo li' dentro**
/// prima di aprirla. Aperta a tutto schermo la foto si guarda e basta: quella
/// stessa scritta diventerebbe una cornice messa fra l'occhio e l'immagine, nel
/// momento esatto in cui l'immagine e' l'unica cosa che si voleva vedere.
///
/// ## Il testo resta un dato, non diventa pixel
///
/// L'app lo disegna sopra l'immagine ogni volta che la mostra. Cotto dentro il
/// file sarebbe immodificabile e si vedrebbe sgranato su ogni schermo diverso
/// da quello su cui e' stato scritto; cosi' invece resta nitido a qualunque
/// misura, e la foto originale resta pulita.
class CaptionFrame extends StatelessWidget {
  const CaptionFrame({
    required this.text,
    required this.child,
    this.style,
    this.sizeFactor = 0.052,
    super.key,
  });

  /// Cosa c'e' scritto. Vuoto vuol dire nessuna scritta.
  final String text;

  /// La foto.
  final Widget child;

  /// Da cui si prendono colore, peso e ombra. La **misura** la decide la foto:
  /// vedi [sizeFactor].
  final TextStyle? style;

  /// Quanto e' alta la scritta, in frazione del lato corto della foto.
  ///
  /// **Proporzionale e non in punti fissi.** Una misura fissa e' enorme su
  /// un'anteprima e minuscola sulla stessa foto piu' grande: la scritta fa
  /// parte dell'immagine, quindi cresce con lei.
  final double sizeFactor;

  /// Sotto e sopra questi due non si va: piu' piccola non si legge, piu' grande
  /// smette di essere una cornice e diventa un cartello.
  static const double minFontSize = 9;
  static const double maxFontSize = 18;

  /// Lo stile predefinito: bianco, grasso, spaziato, con un'ombra sotto.
  ///
  /// **L'ombra e' obbligatoria e non e' decorazione.** Questa scritta cade su
  /// una foto qualunque, e su una foto chiara il bianco sparisce. Un alone
  /// scuro appena accennato la tiene leggibile su qualsiasi cosa ci finisca
  /// sotto, senza aggiungere un fondo che coprirebbe l'immagine.
  static TextStyle defaultStyle(BuildContext context) {
    return const TextStyle(
      color: Colors.white,
      fontSize: minFontSize,
      height: 1,
      fontWeight: FontWeight.w800,
      shadows: [
        Shadow(color: Colors.black87, blurRadius: 5),
        Shadow(color: Colors.black45, blurRadius: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scritta = text.trim();

    if (scritta.isEmpty) {
      return child;
    }

    final base = style ?? defaultStyle(context);

    // **Lo Stack prende la misura dalla foto, non dallo spazio disponibile.**
    //
    // Con `StackFit.expand` la pretendeva dal genitore, e dentro una colonna —
    // dove l'altezza non e' decisa da nessuno — collassava a zero: la foto
    // spariva del tutto. Succedeva nella griglia dentro la missione e
    // nell'elenco, mentre nel profilo no, perche' li' la cella della griglia
    // un'altezza la impone. Un difetto che si vede in due schermate su tre e'
    // il peggiore da cercare.
    //
    // Cosi' invece la foto detta la misura e la scritta le si posa sopra
    // riempiendo esattamente quella: funziona sia dove l'altezza c'e' sia dove
    // non c'e'.
    return Stack(
      children: [
        child,
        // Disegnare del testo lettera per lettera non e' gratis, e questo sta
        // dentro un elenco che scorre: il confine impedisce che il resto della
        // riga si ridisegni insieme a lui.
        Positioned.fill(
          child: RepaintBoundary(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CurvedCaption(
                  text: scritta,
                  style: base,
                  sizeFactor: sizeFactor,
                  scaler: MediaQuery.textScalerOf(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Il disegno vero: le lettere posate una a una lungo il percorso.
class _CurvedCaption extends CustomPainter {
  _CurvedCaption({
    required this.text,
    required this.style,
    required this.sizeFactor,
    required this.scaler,
  });

  final String text;
  final TextStyle style;
  final double sizeFactor;
  final TextScaler scaler;

  /// Quanto il percorso sta dentro dal bordo, in altezze di lettera.
  ///
  /// Le lettere stanno **fuori** dal percorso — cioe' verso il bordo della
  /// foto — quindi questo e' anche lo spazio che occupano.
  ///
  /// **Poco piu' di una lettera, non una lettera e un quinto.** Con il margine
  /// di prima la scritta galleggiava a mezza distanza fra il bordo e il centro,
  /// e li' non e' ne' una cornice ne' una didascalia: e' testo appoggiato sopra
  /// una foto. Appoggiata quasi al bordo diventa il contorno dell'immagine, che
  /// e' l'unico posto in cui una scritta puo' stare senza coprire niente.
  ///
  /// Non zero: le lettere tonde — la O, la S — sporgono un capello oltre la
  /// riga di base, e a filo esatto verrebbero tagliate dall'angolo tondo.
  static const double _insetInLines = 1.06;

  /// Quanto sono tondi gli angoli, in frazione del lato corto.
  ///
  /// Molto: e' la curva che si vede nel giro della scritta, ed e' tutto il
  /// motivo per cui questa cornice si nota. Un raggio piccolo darebbe un testo
  /// che gira uno spigolo, che e' un'altra cosa e non e' bella.
  ///
  /// Va tenuto **piu' largo dell'angolo della foto**, non uguale: la scritta
  /// corre dentro l'angolo, e una curva identica a quella del bordo le farebbe
  /// toccare il taglio proprio nel punto in cui gira. Un po' piu' aperta e le
  /// lettere seguono l'angolo restandone dentro.
  static const double _radiusFactor = 0.21;

  /// Le lettere gia' misurate, per non rifarlo a ogni fotogramma.
  final List<TextPainter> _glifi = [];
  Size? _misurateSu;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final latoCorto = size.shortestSide;
    final corpo = (latoCorto * sizeFactor).clamp(
      CaptionFrame.minFontSize,
      CaptionFrame.maxFontSize,
    );
    final inset = corpo * _insetInLines;
    final raggio = latoCorto * _radiusFactor;

    final percorso = _percorso(size, inset: inset, raggio: raggio);
    final metriche = percorso.computeMetrics().toList();

    if (metriche.isEmpty || metriche.first.length <= 0) {
      return;
    }

    final tracciato = metriche.first;

    _misura(size, corpo: corpo, lunghezzaPercorso: tracciato.length);

    if (_glifi.isEmpty) {
      return;
    }

    final larghezze = [for (final glifo in _glifi) glifo.width];
    final totale = larghezze.fold<double>(0, (somma, w) => somma + w);

    // **Centrata sul percorso**, cioe' a cavallo del lato alto: le due code
    // scendono uguali sui due fianchi. Facendola partire dall'inizio, una frase
    // corta resterebbe tutta appesa al fianco sinistro e sembrerebbe caduta li'.
    var distanza = (tracciato.length - totale) / 2;

    for (var i = 0; i < _glifi.length; i++) {
      final glifo = _glifi[i];
      final larghezza = larghezze[i];
      final tangente = tracciato.getTangentForOffset(distanza + larghezza / 2);

      distanza += larghezza;

      if (tangente == null) {
        continue;
      }

      canvas
        ..save()
        ..translate(tangente.position.dx, tangente.position.dy)
        // La lettera si gira quanto e' girato il percorso sotto di lei. Senza
        // questo sarebbero lettere dritte messe lungo una curva — il segno che
        // si e' provato a fare la cosa senza farla.
        ..rotate(-tangente.angle);

      // Meta' larghezza indietro perche' la tangente si e' presa al **centro**
      // della lettera; e tutta l'altezza in su perche' il testo si disegna
      // verso il basso, e qui la riga di base deve stare sul percorso.
      glifo.paint(canvas, Offset(-larghezza / 2, -glifo.height));

      canvas.restore();
    }
  }

  /// Il percorso: su per il fianco sinistro, sopra i due angoli tondi, giu' per
  /// il destro.
  ///
  /// **Non e' un rettangolo chiuso.** Un giro completo farebbe partire la
  /// scritta da un punto qualunque e la porterebbe a girare anche sotto, dove
  /// le lettere risulterebbero capovolte.
  Path _percorso(Size size, {required double inset, required double raggio}) {
    final sinistra = inset;
    final destra = size.width - inset;
    final alto = inset;
    // I fianchi arrivano poco oltre meta' altezza e non piu' giu': sotto c'e'
    // quasi sempre il soggetto della foto, e una scritta che scende fino in
    // fondo lo imprigiona invece di accompagnarlo.
    final basso = size.height * 0.62;

    return Path()
      ..moveTo(sinistra, basso)
      ..lineTo(sinistra, alto + raggio)
      ..arcToPoint(
        Offset(sinistra + raggio, alto),
        radius: Radius.circular(raggio),
      )
      ..lineTo(destra - raggio, alto)
      ..arcToPoint(
        Offset(destra, alto + raggio),
        radius: Radius.circular(raggio),
      )
      ..lineTo(destra, basso);
  }

  /// Misura le lettere una per una, e taglia la frase se non ci sta.
  ///
  /// **Si taglia invece di rimpicciolire.** Il corpo lo decide la foto, ed e'
  /// quello che tiene la scritta della stessa taglia su tutte: rimpicciolirla
  /// per far entrare una frase lunga vorrebbe dire una cornice diversa per ogni
  /// didascalia, e in un elenco si vedrebbe subito.
  void _misura(
    Size size, {
    required double corpo,
    required double lunghezzaPercorso,
  }) {
    if (_misurateSu == size && _glifi.isNotEmpty) {
      return;
    }

    for (final glifo in _glifi) {
      glifo.dispose();
    }

    _glifi.clear();
    _misurateSu = size;

    final stile = style.copyWith(
      fontSize: corpo,
      // La spaziatura segue il corpo: fissa, su un testo grande sparisce e su
      // uno piccolo lo sfilaccia. E su una curva serve piu' che su una riga
      // dritta, perche' girando, le lettere si stringono fra loro dal lato
      // interno.
      letterSpacing: corpo * 0.14,
    );

    // **In maiuscolo.** Le minuscole hanno le code che scendono sotto la riga
    // di base — la "g", la "p" — e su una curva quelle code puntano verso
    // l'interno della foto ognuna con la sua inclinazione: si legge peggio, e
    // si vede che e' storto. Le maiuscole stanno tutte fra due righe.
    final lettere = text.toUpperCase().characters.toList();
    var usato = 0.0;

    for (final lettera in lettere) {
      final pittore = TextPainter(
        text: TextSpan(text: lettera, style: stile),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();

      // Il margine tiene le due code lontane dal fondo dei fianchi: arrivarci
      // in punta vorrebbe dire una lettera mezza dentro e mezza fuori.
      if (usato + pittore.width > lunghezzaPercorso * 0.94) {
        pittore.dispose();
        break;
      }

      usato += pittore.width;
      _glifi.add(pittore);
    }
  }

  @override
  bool shouldRepaint(_CurvedCaption old) =>
      old.text != text || old.style != style || old.sizeFactor != sizeFactor;
}
