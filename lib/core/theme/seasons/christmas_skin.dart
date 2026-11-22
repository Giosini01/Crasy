import 'dart:math' as math;

import 'package:crasy/core/theme/seasons/season_skin.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// **Natale: un fiocco e la neve sui bordi.**
///
/// ## Perche' esiste adesso e non a dicembre
///
/// Scritta a ottobre insieme a Halloween, questa pelle non serve a nessuno per
/// due mesi. Si scrive comunque, e per una ragione sola: **un impianto che ha
/// una sola stagione dentro non e' un impianto, e' quella stagione scritta con
/// piu' passaggi.** Finche' c'e' un unico caso, ogni scelta su cosa una stagione
/// possa cambiare e' una scelta fatta guardando le ragnatele — e a dicembre si
/// scopre che il punto giusto da cui appendere la neve non c'era.
///
/// Con due, i tre innesti sono gli stessi per entrambe, e si sa che bastano.
///
/// ## Il verde non entra
///
/// Vale la stessa regola di Halloween, e il motivo e' lo stesso: il rosso di
/// CRASY e' gia' il rosso di Natale. Un verde accanto a lui non aggiungerebbe
/// Natale — aggiungerebbe un secondo colore d'accento, e due accenti sono zero
/// accenti. La neve e' grigia, come i filetti.
class ChristmasSkin extends SeasonSkin {
  const ChristmasSkin();

  /// **La fiamma davanti, tre fiocchi attorno.**
  ///
  /// Vale la regola di ottobre, ed e' la regola: la fiamma e' il marchio e non si
  /// mette da parte per una festa. I fiocchi le stanno intorno a misure diverse,
  /// e nessuno dei tre e' dietro di lei — una fiamma che scalda ha dello spazio
  /// sgombro attorno, e dei fiocchi appoggiati sopra dicono il contrario.
  @override
  Widget accompagnaApertura(
    Widget fiamma, {
    required double misura,
    required Color colore,
  }) {
    // Dove sta ciascun fiocco rispetto al centro, e quanto e' grande: in
    // frazioni della fiamma, cosi' seguono la scala dell'animazione.
    const posti = [
      (Offset(-1.15, -0.85), 0.42),
      (Offset(1.05, -0.5), 0.3),
      (Offset(-0.8, 0.95), 0.24),
      (Offset(0.2, -1.35), 0.2),
      (Offset(1.3, 0.55), 0.26),
      (Offset(-1.45, 0.1), 0.18),
      (Offset(0.7, 1.25), 0.2),
      (Offset(-0.35, -1.6), 0.14),
      (Offset(1.6, -1.1), 0.16),
      (Offset(-1.7, -1.4), 0.12),
    ];

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        for (final (dove, quanto) in posti)
          Transform.translate(
            offset: dove * misura,
            child: SizedBox(
              width: misura * quanto,
              height: misura * quanto,
              child: CustomPaint(
                painter: _Fiocco(colore: colore.withValues(alpha: 0.45)),
              ),
            ),
          ),
        fiamma,
      ],
    );
  }

  /// **Un fiocco su qualche tasto.** Uno su tre, deciso dal seme: vedi
  /// `HalloweenSkin.decoraTasto` per il perche' non e' a caso.
  @override
  Widget decoraTasto(Widget tasto, {required String seme}) {
    var somma = 0;

    for (final unita in seme.codeUnits) {
      somma = (somma + unita) % 100003;
    }

    if (somma % 3 != 0) {
      return tasto;
    }

    return Stack(
      children: [
        tasto,
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: const Alignment(-0.92, -0.5),
              child: SizedBox(
                width: 13,
                height: 13,
                // Bianco al 22%: il tasto sotto e' rosso pieno, e l'etichetta
                // resta l'unica cosa da leggere.
                child: CustomPaint(
                  painter: _Fiocco(colore: const Color(0x38FFFFFF)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// **Neve e palline, dietro.** I fiocchi cadono su tutta la pagina e le
  /// palline pendono dall'alto, ma **dietro** i contenuti: si vedono negli
  /// spazi fra le carte e scompaiono dietro foto e riquadri, come fuori da
  /// una finestra. Davanti resta solo la neve posata sul bordo. Ogni pagina
  /// ha le palline in un punto suo.
  @override
  Widget decora(BuildContext context, Widget pagina) {
    var dove = '';

    // Dove si e': l'indirizzo della pagina, che decide la disposizione delle
    // palline. Fuori dal router (l'apertura, i fogli) basta il nome.
    try {
      dove = GoRouterState.of(context).matchedLocation;
    } on Object {
      dove = ModalRoute.of(context)?.settings.name ?? '';
    }

    return Stack(
      children: [
        const Positioned.fill(child: IgnorePointer(child: _NeveCheCade())),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(child: CustomPaint(painter: _Palline(dove))),
          ),
        ),
        pagina,
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _NeveSulBordo())),
        ),
      ],
    );
  }

  /// **Accanto al marchio, una cosa diversa per scheda**: l'alberello sulle
  /// missioni, un regalo fra gli amici, il bastoncino sul profilo, il
  /// leccalecca fra i vincitori, un fiocco nella ricerca.
  @override
  Widget decoraMarchio(
    Widget marchio, {
    required double misura,
    String seme = '',
  }) {
    final (CustomPainter disegno, double larga, double alta) = switch (seme) {
      'amici' => (_Regalo(), 0.8, 0.8),
      'profilo' => (_Bastoncino(), 0.45, 1.05),
      'vincitori' => (_Leccalecca(), 0.62, 1.1),
      'cerca' => (_Fiocco(colore: const Color(0xFFC3CCD8)), 0.7, 0.7),
      _ => (_Albero(), 0.78, 1.1),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        marchio,
        SizedBox(width: misura * 0.18),
        SizedBox(
          width: misura * larga,
          height: misura * alta,
          child: CustomPaint(painter: disegno),
        ),
      ],
    );
  }

  /// Un fiocco nell'angolo della riga del premio, se l'angolo e' libero.
  @override
  Widget decoraMissione(
    Widget missione, {
    required String seme,
    bool angoloLibero = true,
  }) {
    if (!angoloLibero) {
      return missione;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        missione,
        Positioned(
          top: -4,
          right: -2,
          child: IgnorePointer(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CustomPaint(
                painter: _Fiocco(colore: const Color(0xFFC9D3DE)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// **I fiocchi che scendono, dietro i contenuti**: pochi, piccoli e chiari,
/// quasi impercettibili — si notano solo guardando. Grigio chiaro, perche' sul
/// fondo bianco la neve bianca non si vede. Con le animazioni ridotte dal
/// telefono restano fermi.
class _NeveCheCade extends StatefulWidget {
  const _NeveCheCade();

  @override
  State<_NeveCheCade> createState() => _NeveCheCadeState();
}

class _NeveCheCadeState extends State<_NeveCheCade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tempo = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (MediaQuery.disableAnimationsOf(context)) {
      _tempo
        ..stop()
        ..value = 0.37;
    } else if (!_tempo.isAnimating) {
      _tempo.repeat();
    }
  }

  @override
  void dispose() {
    _tempo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(painter: _Fiocchi(_tempo), willChange: true),
    );
  }
}

class _Fiocchi extends CustomPainter {
  _Fiocchi(this.tempo) : super(repaint: tempo);

  final Animation<double> tempo;

  static const _quanti = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tempo.value;

    for (var i = 0; i < _quanti; i++) {
      // Ogni fiocco ha la sua strada, sempre la stessa: posizione, velocita',
      // misura e partenza vengono dal suo numero.
      final caso = math.Random(i * 7919 + 17);
      final x0 = caso.nextDouble();
      final velocita = 0.6 + caso.nextDouble() * 0.8;
      final partenza = caso.nextDouble();
      final raggio = 1.1 + caso.nextDouble() * 1.3;
      final giro = (t * velocita + partenza) % 1;
      final y = giro * size.height;
      final x =
          x0 * size.width + math.sin((t * 2 + partenza) * math.pi * 2) * 10;
      // Compaiono in cima e si spengono in fondo, invece di apparire e
      // sparire di colpo.
      final alfa = 0.3 * math.min(1, math.min(giro * 12, (1 - giro) * 8));

      canvas.drawCircle(
        Offset(x, y),
        raggio,
        Paint()..color = const Color(0xFFC3CCD8).withValues(alpha: alfa),
      );
    }
  }

  @override
  bool shouldRepaint(_Fiocchi vecchio) => false;
}

/// **L'alberello**: tre piani innevati, qualche pallina, la stella.
class _Albero extends CustomPainter {
  _Albero();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 60;
    final sy = size.height / 84;

    Offset p(double x, double y) => Offset(x * sx, y * sy);

    Path piano(double cima, double base, double mezzaBase) => Path()
      ..moveTo(p(30, cima).dx, p(30, cima).dy)
      ..lineTo(p(30 + mezzaBase, base).dx, p(30 + mezzaBase, base).dy)
      ..lineTo(p(30 - mezzaBase, base).dx, p(30 - mezzaBase, base).dy)
      ..close();

    canvas
      ..drawRect(
        Rect.fromLTWH(p(26, 68).dx, p(26, 68).dy, 8 * sx, 12 * sy),
        Paint()..color = const Color(0xFF7A4B2A),
      )
      ..drawPath(piano(4, 32, 20), Paint()..color = const Color(0xFF1D6B4A))
      ..drawPath(piano(18, 52, 26), Paint()..color = const Color(0xFF1D6B4A))
      ..drawPath(piano(34, 72, 30), Paint()..color = const Color(0xFF124D35));

    final neve = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * sx
      ..strokeCap = StrokeCap.round;

    for (final (y, mezza) in [(31.0, 12.0), (51.0, 19.0), (71.0, 24.0)]) {
      canvas.drawPath(
        Path()
          ..moveTo(p(30 - mezza, y).dx, p(30 - mezza, y).dy)
          ..quadraticBezierTo(
            p(30, y - 5).dx,
            p(30, y - 5).dy,
            p(30 + mezza, y).dx,
            p(30 + mezza, y).dy,
          ),
        neve,
      );
    }

    const palline = [
      (22.0, 42.0, Color(0xFFFA0000)),
      (38.0, 38.0, Color(0xFFE7B04A)),
      (16.0, 62.0, Color(0xFFE7B04A)),
      (32.0, 58.0, Color(0xFFFA0000)),
      (46.0, 64.0, Color(0xFFFA0000)),
    ];

    for (final (x, y, colore) in palline) {
      canvas.drawCircle(p(x, y), 3 * sx, Paint()..color = colore);
    }

    final stella = Path();

    for (var i = 0; i < 10; i++) {
      final angolo = -math.pi / 2 + i * math.pi / 5;
      final raggio = (i.isEven ? 6.5 : 2.8) * sx;
      final punto =
          p(30, 6) + Offset(math.cos(angolo), math.sin(angolo)) * raggio;

      if (i == 0) {
        stella.moveTo(punto.dx, punto.dy);
      } else {
        stella.lineTo(punto.dx, punto.dy);
      }
    }

    canvas.drawPath(stella..close(), Paint()..color = const Color(0xFFE7B04A));
  }

  @override
  bool shouldRepaint(_Albero vecchio) => false;
}

/// Un fiocco di neve: sei braccia, ognuna con due rametti.
///
/// Sei e non otto, e non e' un dettaglio da manuale: un fiocco a sei braccia si
/// riconosce come neve, a otto come una stella — e una stella, in un'app che
/// assegna premi, dice "valutazione".
class _Fiocco extends CustomPainter {
  const _Fiocco({required this.colore});

  final Color colore;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final raggio = size.width / 2 * 0.82;
    final penna = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.width * 0.035)
      ..strokeCap = StrokeCap.round
      ..color = colore;

    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      final direzione = Offset(math.cos(a), math.sin(a));
      final punta = centro + direzione * raggio;

      canvas.drawLine(centro, punta, penna);

      // I rametti, a due altezze. Un braccio nudo e' un raggio di ruota; sono
      // questi a fare la neve.
      for (final quota in [0.52, 0.82]) {
        final nodo = centro + direzione * raggio * quota;
        final apertura = raggio * (1 - quota) * 0.85;

        for (final verso in [-1.0, 1.0]) {
          final b = a + verso * 0.7;
          canvas.drawLine(
            nodo,
            nodo + Offset(math.cos(b), math.sin(b)) * apertura,
            penna,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Fiocco altro) => altro.colore != colore;
}

/// La neve posata sul bordo alto, e qualche fiocco fermo.
///
/// **Non cade.** Una neve animata su ogni pagina dell'app vuol dire un
/// ridisegno continuo dietro ogni schermata, batteria compresa, per guardare
/// una cosa che nessuno guarda la seconda volta. Posata, resta un dettaglio.
class _NeveSulBordo extends CustomPainter {
  _NeveSulBordo();

  /// Lo stesso grigio dei filetti, appena piu' presente.
  static const _neve = Color(0x14000000);

  @override
  void paint(Canvas canvas, Size size) {
    final pieno = Paint()..color = _neve;

    // La cresta: una fascia bassa che cola in tre gobbe, come la neve
    // sull'intelaiatura di una finestra.
    final gobba = size.width / 3;
    final cresta = Path()..moveTo(0, 0);

    for (var i = 0; i < 3; i++) {
      cresta.quadraticBezierTo(
        gobba * i + gobba / 2,
        size.shortestSide * (i.isEven ? 0.055 : 0.038),
        gobba * (i + 1),
        size.shortestSide * 0.012,
      );
    }

    cresta
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(cresta, pieno);

    // Tre fiocchi fermi in alto, a misure diverse. Allineati o uguali si
    // leggerebbero come un elemento dell'interfaccia.
    const posti = [Offset(0.18, 0.1), Offset(0.62, 0.07), Offset(0.85, 0.14)];
    const misure = [0.028, 0.018, 0.022];

    for (var i = 0; i < posti.length; i++) {
      canvas.drawCircle(
        Offset(size.width * posti[i].dx, size.height * posti[i].dy),
        size.shortestSide * misure[i],
        pieno,
      );
    }
  }

  @override
  bool shouldRepaint(_NeveSulBordo altro) => false;
}

/// **Le palline appese**, dietro i contenuti, con una disposizione diversa
/// per ogni pagina: due agli angoli sulle missioni, una scaletta a sinistra
/// fra gli amici, una grande a destra sul profilo, tre larghe fra i
/// vincitori, un grappolo al centro nella ricerca. Le altre pagine ne
/// prendono una delle cinque, sempre la stessa per la stessa pagina.
class _Palline extends CustomPainter {
  _Palline(this.dove);

  final String dove;

  /// Ogni pallina: dove pende (frazione della larghezza), quanto e' lungo il
  /// filo, quanto e' grande.
  static const _disposizioni = [
    [(0.12, 92.0, 11.0), (0.86, 64.0, 9.0)],
    [(0.1, 140.0, 12.0), (0.24, 96.0, 10.0), (0.38, 62.0, 8.0)],
    [(0.68, 70.0, 9.0), (0.84, 132.0, 13.0)],
    [(0.22, 60.0, 9.0), (0.5, 104.0, 11.0), (0.78, 72.0, 9.0)],
    [(0.44, 74.0, 9.0), (0.52, 118.0, 12.0), (0.6, 86.0, 9.0)],
  ];

  int get _quale {
    if (dove.startsWith('/challenges')) {
      return 0;
    }

    if (dove.startsWith('/amici')) {
      return 1;
    }

    if (dove.startsWith('/profile')) {
      return 2;
    }

    if (dove.startsWith('/winners')) {
      return 3;
    }

    if (dove.startsWith('/cerca')) {
      return 4;
    }

    var somma = 0;

    for (final unita in dove.codeUnits) {
      somma = (somma * 31 + unita) % 100003;
    }

    return somma % _disposizioni.length;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const colori = [Color(0xFFFA0000), Color(0xFFE7B04A)];
    final filo = Paint()
      ..color = const Color(0xFFD5D5DA)
      ..strokeWidth = 1;
    final disposizione = _disposizioni[_quale];

    for (var i = 0; i < disposizione.length; i++) {
      final (dx, lungo, raggio) = disposizione[i];
      final x = size.width * dx;
      final colore = colori[i % colori.length];
      final centro = Offset(x, lungo + raggio);

      canvas
        ..drawLine(Offset(x, 0), Offset(x, lungo), filo)
        ..drawRect(
          Rect.fromCenter(
            center: Offset(x, lungo + 1),
            width: raggio * 0.7,
            height: 4,
          ),
          Paint()..color = const Color(0xFFB9B9C0),
        )
        ..drawCircle(centro, raggio, Paint()..color = colore)
        ..drawCircle(
          centro + Offset(-raggio * 0.35, -raggio * 0.35),
          raggio * 0.28,
          Paint()..color = const Color(0x80FFFFFF),
        );
    }
  }

  @override
  bool shouldRepaint(_Palline vecchio) => vecchio.dove != dove;
}

/// **Un regalo**: rosso, nastro bianco, fiocco.
class _Regalo extends CustomPainter {
  _Regalo();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bianco = Paint()..color = const Color(0xFFFFFFFF);

    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.06, h * 0.4, w * 0.88, h * 0.6),
          Radius.circular(w * 0.08),
        ),
        Paint()..color = const Color(0xFFFA0000),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, h * 0.27, w, h * 0.18),
          Radius.circular(w * 0.05),
        ),
        Paint()..color = const Color(0xFFD90000),
      )
      ..drawRect(Rect.fromLTWH(w * 0.43, h * 0.27, w * 0.14, h * 0.73), bianco);

    final fiocco = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07;

    for (final lato in [-1.0, 1.0]) {
      canvas
        ..save()
        ..translate(w * 0.5 + lato * w * 0.17, h * 0.18)
        ..rotate(lato * 0.35)
        ..drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: w * 0.36,
            height: h * 0.2,
          ),
          fiocco,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_Regalo vecchio) => false;
}

/// **Il bastoncino di zucchero**: un uncino bianco a righe rosse.
class _Bastoncino extends CustomPainter {
  _Bastoncino();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final spessore = w * 0.32;
    final percorso = Path()
      ..moveTo(w * 0.3, h * 0.98)
      ..lineTo(w * 0.3, h * 0.3)
      ..arcToPoint(Offset(w * 0.8, h * 0.3), radius: Radius.circular(w * 0.25))
      ..lineTo(w * 0.8, h * 0.4);

    canvas.drawPath(
      percorso,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = spessore
        ..strokeCap = StrokeCap.round,
    );

    final rosso = Paint()
      ..color = const Color(0xFFFA0000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = spessore;

    for (final tratto in percorso.computeMetrics()) {
      for (var d = 0.0; d < tratto.length; d += spessore * 1.6) {
        canvas.drawPath(
          tratto.extractPath(d, math.min(d + spessore * 0.7, tratto.length)),
          rosso,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Bastoncino vecchio) => false;
}

/// **Il leccalecca a spirale**: spicchi rossi e bianchi, il bastoncino sotto.
class _Leccalecca extends CustomPainter {
  _Leccalecca();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final raggio = w * 0.46;
    final centro = Offset(w / 2, raggio + 1);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.45, centro.dy, w * 0.1, h - centro.dy),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = const Color(0xFFEDE6D8),
    );

    const spicchi = 12;

    for (var i = 0; i < spicchi; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: centro, radius: raggio),
        i * math.pi * 2 / spicchi + 0.3,
        math.pi * 2 / spicchi,
        true,
        Paint()
          ..color = i.isEven
              ? const Color(0xFFFA0000)
              : const Color(0xFFFFFFFF),
      );
    }

    canvas.drawCircle(
      centro,
      raggio,
      Paint()
        ..color = const Color(0xFFF1D0D0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_Leccalecca vecchio) => false;
}
