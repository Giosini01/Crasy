import 'dart:math' as math;

import 'package:crasy/core/theme/app_colors.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/seasons/season_skin.dart';
import 'package:flutter/material.dart';

/// **Halloween: la notte dietro, i mostri accanto ai premi.**
///
/// ## I colori dell'app non si toccano, quelli dei disegni si'
///
/// In CRASY il rosso dice tre cose e solo quelle — quanto si vince, cosa
/// toccare, cosa e' attivo — e per Halloween resta li': bottoni, premi, testi e
/// caratteri sono quelli di sempre. L'arancione delle zucche, il viola della
/// notte e il giallo delle candele stanno **solo dentro i disegni**.
///
/// ## Tre livelli
///
/// - **Dietro tutto, la notte**: una luna con un pipistrello accanto al logo e
///   una collina con l'albero storto e le lapidi in fondo alla pagina. Chiari abbastanza da passarci sopra con il testo: il contenuto
///   scorre davanti, e si legge come sempre.
/// - **Accanto al premio, un personaggio**: una zucca accesa, una vedova nera
///   che scende dal suo filo, un gatto nero, i pipistrelli, un fantasma, una
///   ragnatela. Quattro missioni su dieci, le altre niente — tutte decorate
///   sarebbe una cornice, e una cornice non si guarda.
/// - **Sui tasti, qualche colata**: tre PARTECIPA su dieci gocciolano rosso
///   CRASY, il loro stesso rosso.
///
/// All'apertura la fiamma sta davanti a una luna piena con i pipistrelli che le
/// girano attorno; nell'attesa, al posto dell'arco, girano tre pipistrelli.
class HalloweenSkin extends SeasonSkin {
  const HalloweenSkin();

  /// **L'apertura: la fiamma davanti alla luna.**
  ///
  /// La fiamma resta il marchio e resta davanti: la luna le fa da fondo, e i
  /// pipistrelli le girano attorno senza mai passarle sopra.
  @override
  Widget accompagnaApertura(
    Widget fiamma, {
    required double misura,
    required Color colore,
  }) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        SizedBox.square(
          dimension: misura * 2.6,
          child: _Vivo(
            periodo: const Duration(seconds: 5),
            disegno: (tempo) => _LunaDiApertura(tempo: tempo, misura: misura),
          ),
        ),
        fiamma,
      ],
    );
  }

  /// **L'attesa: la fiamma con un alone di candela.**
  @override
  Widget accompagnaAttesa(
    Widget fiamma, {
    required double misura,
    required Color colore,
  }) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        SizedBox.square(
          dimension: misura * 1.8,
          child: const IgnorePointer(child: CustomPaint(painter: _Bagliore())),
        ),
        fiamma,
      ],
    );
  }

  /// Tre pipistrelli che girano attorno alla fiamma, al posto dell'arco.
  @override
  CustomPainter? giostraDAttesa({
    required double giro,
    required AppPalette palette,
  }) {
    return _PipistrelliInGiro(giro: giro, pista: palette.line);
  }

  /// **Sei PARTECIPA su dieci restano come sono.** Tre gocciolano — il loro
  /// stesso rosso che cola dal bordo di sotto — e uno ha una ragnatela
  /// nell'angolo. Sempre **fuori dalla parola**: un disegno al centro di un
  /// tasto con scritto PARTECIPA toglie leggibilita' all'unica cosa che quel
  /// tasto deve dire.
  ///
  /// Un seme diverso da quello della missione, cosi' tasto e missione non vanno
  /// sempre in coppia.
  @override
  Widget decoraTasto(Widget tasto, {required String seme}) {
    final sorte = _sorte(seme);
    final fase = sorte / 997;

    return switch ((sorte ~/ 12) % 10) {
      0 || 1 || 2 => Stack(
        clipBehavior: Clip.none,
        children: [
          tasto,
          // Le colate escono dal bordo di sotto e ci scendono oltre: il tasto
          // resta della sua misura, e chi tocca tocca il tasto.
          Positioned(
            left: 0,
            right: 0,
            bottom: -24,
            height: 28,
            child: _Vivo(
              periodo: const Duration(milliseconds: 5200),
              fase: fase,
              disegno: (tempo) => _Colate(tempo: tempo, sorte: sorte),
            ),
          ),
        ],
      ),
      3 => Stack(
        children: [
          tasto,
          Positioned.fill(
            child: _Vivo(
              periodo: const Duration(milliseconds: 4200),
              fase: fase,
              disegno: (tempo) => _RagnatelaSulTasto(tempo: tempo),
            ),
          ),
        ],
      ),
      _ => tasto,
    };
  }

  /// **Un personaggio accanto al premio, diverso da missione a missione.**
  ///
  /// Sta nell'angolo destro della riga del premio, che e' vuoto — il premio e'
  /// allineato a sinistra — e non scende mai sul titolo. Dove l'angolo e'
  /// occupato dal marchio ARCHIVIO non si mette niente: un disegno sopra
  /// un'etichetta la sporca, e l'etichetta conta di piu'.
  ///
  /// Lo decide l'identificativo della missione: la stessa zucca nella scheda e
  /// nella pagina, e scorrendo non cambia.
  @override
  Widget decoraMissione(
    Widget missione, {
    required String seme,
    bool angoloLibero = true,
  }) {
    if (!angoloLibero) {
      return missione;
    }

    final sorte = _sorte(seme);
    // Ogni missione ha il suo tempo: due gatti vicini non muovono la coda
    // insieme come soldatini.
    final fase = sorte / 997;
    // **Poche, e non tutte uguali.** Sei missioni su dieci non hanno niente:
    // un personaggio su ogni scheda riempie l'elenco e smette di sorprendere.
    // Delle altre, zucca, vedova nera e gatto sono i piu' frequenti; i
    // pipistrelli, il fantasma e la ragnatela si incontrano ogni tanto.
    final Widget? personaggio = switch (sorte % 10) {
      6 => _Vivo(
        periodo: const Duration(milliseconds: 2600),
        fase: fase,
        disegno: (tempo) => _ZuccaAccesa(tempo: tempo),
      ),
      7 => _Vivo(
        periodo: const Duration(milliseconds: 7000),
        fase: fase,
        disegno: (tempo) => _VedovaNera(tempo: tempo),
      ),
      8 => _Vivo(
        periodo: const Duration(milliseconds: 4200),
        fase: fase,
        disegno: (tempo) => _GattoNero(tempo: tempo),
      ),
      9 => switch ((sorte ~/ 10) % 3) {
        0 => _Vivo(
          periodo: const Duration(milliseconds: 2800),
          fase: fase,
          disegno: (tempo) => _Pipistrelli(tempo: tempo),
        ),
        1 => _Vivo(
          periodo: const Duration(milliseconds: 3400),
          fase: fase,
          disegno: (tempo) => _Fantasma(tempo: tempo),
        ),
        _ => _Vivo(
          periodo: const Duration(milliseconds: 6400),
          fase: fase,
          disegno: (tempo) => _RagnatelaMissione(tempo: tempo),
        ),
      },
      _ => null,
    };

    if (personaggio == null) {
      return missione;
    }

    return Stack(
      // **La larghezza di chi sta fuori, non quella del testo.** Con quella del
      // testo il personaggio si attaccherebbe alla fine del premio, a meta'
      // riga, invece che al bordo della pagina.
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        missione,
        Positioned(top: 0, right: 0, bottom: 0, width: 132, child: personaggio),
      ],
    );
  }

  /// **La notte, dietro la pagina.**
  ///
  /// Sta **sotto** il contenuto, non sopra: le schermate di CRASY non hanno
  /// fondi propri, quindi la luna e la collina si vedono attraverso, e il
  /// testo ci passa davanti. Niente copre niente, e i tocchi non la incontrano
  /// nemmeno.
  ///
  /// **La luna solo sulla home** ([principale]): sulle altre pagine resta la
  /// collina in fondo, e basta. Una luna ripetuta su ogni schermata smette di
  /// essere una cosa che si nota.
  @override
  Widget decora(
    BuildContext context,
    Widget pagina, {
    bool principale = false,
  }) {
    final alto = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Positioned.fill(
          child: _Vivo(
            periodo: const Duration(seconds: 16),
            disegno: (tempo) =>
                _NotteSulFondo(tempo: tempo, alto: alto, luna: principale),
          ),
        ),
        pagina,
      ],
    );
  }

  /// Un numero stabile a partire da una parola.
  ///
  /// `hashCode` di una stringa non e' garantito uguale fra due esecuzioni, e un
  /// personaggio che cambia riaprendo l'app si nota per il motivo sbagliato.
  /// **Moltiplicando, non sommando**: con la somma, le stesse lettere in ordine
  /// diverso davano lo stesso personaggio, e capitavano tre zucche di fila.
  int _sorte(String seme) {
    var numero = 17;

    for (final unita in seme.codeUnits) {
      numero = (numero * 31 + unita) & 0x3fffffff;
    }

    return numero;
  }
}

// ---------------------------------------------------------------------------
// I colori di Halloween: solo dentro i disegni
// ---------------------------------------------------------------------------

const _zucca = Color(0xFFFF7A1A);
const _zuccaChiara = Color(0xFFFFA24A);
const _zuccaScura = Color(0xFFC9500A);
const _gambo = Color(0xFF3F6B2A);

/// Il giallo di una candela dentro una zucca.
const _candela = Color(0xFFFFD45C);

/// Il viola della notte: pipistrelli e sagome. Il nero puro qui sarebbe un
/// buco; il viola si legge come notte anche a dodici pixel.
const _notte = Color(0xFF2B1640);

/// Il gatto: quasi nero, con dentro un filo di viola.
const _pelo = Color(0xFF16121D);

/// La luna: bianca, appena fredda sul bordo perche' si stacchi dal fondo.
/// Panna con l'alone arancione sembrava un sole.
const _luna = Color(0xFFFFFFFF);
const _lunaBordo = Color(0xFFEDEBF4);

/// Il filo attorno alla luna bianca: senza, su fondo bianco sparisce.
const _bordoDiLuna = Color(0x386B6680);

/// L'alone della luna: lavanda, freddo.
const _chiaroDiLuna = Color(0xFFB9A8E0);

/// Le stelline accanto alla falce.
const _stella = Color(0xFF8E7CC3);

/// Il nero di CRASY, per le facce e gli occhi.
const _nero = Color(0xFF0A0A0B);

// ---------------------------------------------------------------------------
// Il tempo che fa muovere i disegni
// ---------------------------------------------------------------------------

/// **Un giro che ricomincia all'infinito**, e il disegno se lo legge da solo a
/// ogni fotogramma (`repaint`): la pagina sotto non si ricostruisce mai, si
/// ridisegna solo il disegno. [fase] sposta l'inizio del giro.
///
/// **Con le animazioni ridotte, sta fermo.** Chi le ha spente nelle
/// impostazioni del telefono le ha spente per un motivo, e un gatto che muove
/// la coda in ogni pagina e' esattamente quel motivo.
class _Vivo extends StatefulWidget {
  const _Vivo({required this.disegno, required this.periodo, this.fase = 0});

  final CustomPainter Function(Animation<double> tempo) disegno;
  final Duration periodo;
  final double fase;

  @override
  State<_Vivo> createState() => _VivoState();
}

class _VivoState extends State<_Vivo> with SingleTickerProviderStateMixin {
  late final AnimationController _giro = AnimationController(
    vsync: this,
    duration: widget.periodo,
    value: widget.fase % 1,
  )..repeat();

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fermo = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          painter: widget.disegno(
            fermo ? const AlwaysStoppedAnimation(0.3) : _giro,
          ),
        ),
      ),
    );
  }
}

Paint _filo(Color colore, double spessore) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = spessore
  ..strokeCap = StrokeCap.round
  ..color = colore;

/// Un'ombra in terra, ovale: senza, le cose galleggiano.
void _ombra(Canvas canvas, Offset centro, double larga, {int alfa = 0x16}) {
  canvas.drawOval(
    Rect.fromCenter(center: centro, width: larga, height: larga * 0.16),
    Paint()..color = _nero.withAlpha(alfa),
  );
}

/// Un alone tondo che sfuma: la luce di una candela, di una luna.
void _alone(Canvas canvas, Offset centro, double raggio, Color colore) {
  canvas.drawCircle(
    centro,
    raggio,
    Paint()
      ..shader = RadialGradient(
        colors: [colore, colore.withAlpha(0)],
      ).createShader(Rect.fromCircle(center: centro, radius: raggio)),
  );
}

// ---------------------------------------------------------------------------
// I pipistrelli
// ---------------------------------------------------------------------------

/// **Un pipistrello**: corpo, orecchie a punta, ali a festoni che battono.
///
/// [apertura] va da -1 (ali basse) a 1 (ali alte).
void _pipistrello(
  Canvas canvas,
  Offset c,
  double s,
  double apertura,
  Color colore,
) {
  final su = -s * 0.36 * apertura;
  final ali = Path();

  // Il bordo alto va dritto alla punta, quello basso torna al corpo a tre
  // festoni: e' il festone che fa il pipistrello, non la sagoma.
  for (final verso in [-1.0, 1.0]) {
    ali
      ..moveTo(c.dx, c.dy - s * 0.08)
      ..quadraticBezierTo(
        c.dx + verso * s * 0.5,
        c.dy - s * 0.34 + su * 0.6,
        c.dx + verso * s,
        c.dy - s * 0.06 + su,
      )
      ..quadraticBezierTo(
        c.dx + verso * s * 0.84,
        c.dy + s * 0.04 + su * 0.7,
        c.dx + verso * s * 0.7,
        c.dy + s * 0.2 + su * 0.5,
      )
      ..quadraticBezierTo(
        c.dx + verso * s * 0.54,
        c.dy + s * 0.05 + su * 0.35,
        c.dx + verso * s * 0.38,
        c.dy + s * 0.22 + su * 0.2,
      )
      ..quadraticBezierTo(
        c.dx + verso * s * 0.22,
        c.dy + s * 0.07,
        c.dx,
        c.dy + s * 0.2,
      )
      ..close();
  }

  final pieno = Paint()..color = colore;

  canvas
    ..drawPath(ali, pieno)
    ..drawOval(
      Rect.fromCenter(
        center: c + Offset(0, s * 0.05),
        width: s * 0.3,
        height: s * 0.48,
      ),
      pieno,
    )
    ..drawPath(
      Path()
        ..moveTo(c.dx - s * 0.13, c.dy - s * 0.12)
        ..lineTo(c.dx - s * 0.13, c.dy - s * 0.34)
        ..lineTo(c.dx - s * 0.04, c.dy - s * 0.21)
        ..lineTo(c.dx + s * 0.04, c.dy - s * 0.21)
        ..lineTo(c.dx + s * 0.13, c.dy - s * 0.34)
        ..lineTo(c.dx + s * 0.13, c.dy - s * 0.12)
        ..close(),
      pieno,
    );
}

/// **Tre pipistrelli in volo**, a distanze diverse.
class _Pipistrelli extends CustomPainter {
  _Pipistrelli({required this.tempo}) : super(repaint: tempo);

  final Animation<double> tempo;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tempo.value;

    for (final (x, y, misura, fase) in [
      (0.58, 0.55, 19.0, 0.0),
      (0.84, 0.28, 13.0, 0.37),
      (0.34, 0.24, 9.0, 0.71),
    ]) {
      // Battono a tempi diversi e salgono e scendono di poco, ognuno per
      // conto suo.
      final battito = math.sin(2 * math.pi * (t * 4 + fase));
      final quota = math.sin(2 * math.pi * (t + fase)) * 4;
      final deriva = math.cos(2 * math.pi * (t + fase)) * 5;

      _pipistrello(
        canvas,
        Offset(size.width * x + deriva, size.height * y + quota),
        misura,
        battito,
        _notte,
      );
    }
  }

  @override
  bool shouldRepaint(_Pipistrelli altro) => altro.tempo != tempo;
}

/// **Tre pipistrelli che girano attorno alla fiamma**, al posto dell'arco.
///
/// Sotto, la pista: un anello chiaro, come la scia dell'arco di sempre. Sulle
/// attese piccole — dentro un tasto — un pipistrello sarebbe una macchia: li'
/// gira un arco arancione.
class _PipistrelliInGiro extends CustomPainter {
  const _PipistrelliInGiro({required this.giro, required this.pista});

  final double giro;
  final Color pista;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final lato = size.shortestSide;

    if (lato < 56) {
      final r = lato / 2 - 2;
      canvas
        ..drawCircle(centro, r, _filo(pista, math.max(1.5, lato * 0.05)))
        ..drawArc(
          Rect.fromCircle(center: centro, radius: r),
          giro * 2 * math.pi,
          math.pi / 2,
          false,
          _filo(_zucca, math.max(1.5, lato * 0.05)),
        );

      return;
    }

    final misura = lato * 0.13;
    final r = lato / 2 - misura;

    canvas.drawCircle(centro, r, _filo(pista, 1.4));

    for (var i = 0; i < 3; i++) {
      final angolo = (giro + i / 3) * 2 * math.pi;
      final dove = centro + Offset(math.cos(angolo), math.sin(angolo)) * r;
      final battito = math.sin(2 * math.pi * (giro * 6 + i / 3));

      _pipistrello(canvas, dove, misura, battito, _notte);
    }
  }

  @override
  bool shouldRepaint(_PipistrelliInGiro altro) => altro.giro != giro;
}

// ---------------------------------------------------------------------------
// La zucca accesa
// ---------------------------------------------------------------------------

/// **Una zucca intagliata con la candela dentro.**
///
/// Gli spicchi sfumano dal chiaro al bordo scuro, come una cosa tonda; la
/// faccia e' gialla perche' e' accesa da dentro, e la candela trema: l'alone
/// e la luce della faccia salgono e scendono di poco, a scatti morbidi.
class _ZuccaAccesa extends CustomPainter {
  _ZuccaAccesa({required this.tempo}) : super(repaint: tempo);

  final Animation<double> tempo;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tempo.value;
    // Due onde a frequenze diverse: una sola sarebbe un respiro, due sono una
    // fiamma.
    final tremito =
        0.82 +
        0.1 * math.sin(2 * math.pi * t * 3) +
        0.08 * math.sin(2 * math.pi * t * 7.3 + 1.1);
    final larga = math.min(size.height * 0.95, 66.0);
    final alta = larga * 0.82;
    final c = Offset(size.width - larga / 2 - 6, size.height - alta / 2 - 4);

    _alone(canvas, c, larga * 0.95, _candela.withAlpha((90 * tremito).round()));
    _ombra(canvas, c + Offset(0, alta * 0.47), larga * 0.95);

    // Il gambo, con il suo ricciolo.
    canvas
      ..drawPath(
        Path()
          ..moveTo(c.dx - larga * 0.06, c.dy - alta * 0.36)
          ..quadraticBezierTo(
            c.dx - larga * 0.04,
            c.dy - alta * 0.6,
            c.dx + larga * 0.1,
            c.dy - alta * 0.68,
          )
          ..lineTo(c.dx + larga * 0.14, c.dy - alta * 0.58)
          ..quadraticBezierTo(
            c.dx + larga * 0.05,
            c.dy - alta * 0.52,
            c.dx + larga * 0.07,
            c.dy - alta * 0.36,
          )
          ..close(),
        Paint()..color = _gambo,
      )
      ..drawPath(
        Path()
          ..moveTo(c.dx + larga * 0.12, c.dy - alta * 0.62)
          ..quadraticBezierTo(
            c.dx + larga * 0.3,
            c.dy - alta * 0.74,
            c.dx + larga * 0.26,
            c.dy - alta * 0.56,
          ),
        _filo(_gambo, math.max(1, larga * 0.025)),
      );

    // Gli spicchi: i due laterali piu' scuri, quelli in mezzo davanti.
    for (final (dx, w, chiaro) in [
      (-0.24, 0.56, false),
      (0.24, 0.56, false),
      (-0.11, 0.5, true),
      (0.11, 0.5, true),
    ]) {
      final rect = Rect.fromCenter(
        center: c + Offset(dx * larga, 0),
        width: larga * w,
        height: alta * (chiaro ? 0.98 : 0.9),
      );
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            radius: 0.9,
            colors: [chiaro ? _zuccaChiara : _zucca, _zuccaScura],
          ).createShader(rect),
      );
    }

    // La faccia, accesa da dentro.
    final luce = Paint()
      ..color = Color.lerp(_zuccaChiara, _candela, tremito.clamp(0, 1))!;
    final bordo = _filo(_zuccaScura, math.max(1, larga * 0.022));

    for (final verso in [-1.0, 1.0]) {
      final occhio = Path()
        ..moveTo(c.dx + verso * larga * 0.06, c.dy - alta * 0.02)
        ..lineTo(c.dx + verso * larga * 0.27, c.dy - alta * 0.02)
        ..lineTo(c.dx + verso * larga * 0.16, c.dy - alta * 0.24)
        ..close();
      canvas
        ..drawPath(occhio, luce)
        ..drawPath(occhio, bordo);
    }

    final bocca = Path()
      ..moveTo(c.dx - larga * 0.3, c.dy + alta * 0.08)
      ..lineTo(c.dx - larga * 0.16, c.dy + alta * 0.13)
      ..lineTo(c.dx - larga * 0.11, c.dy + alta * 0.05)
      ..lineTo(c.dx - larga * 0.05, c.dy + alta * 0.13)
      ..lineTo(c.dx + larga * 0.05, c.dy + alta * 0.13)
      ..lineTo(c.dx + larga * 0.11, c.dy + alta * 0.22)
      ..lineTo(c.dx + larga * 0.16, c.dy + alta * 0.13)
      ..lineTo(c.dx + larga * 0.3, c.dy + alta * 0.08)
      ..quadraticBezierTo(
        c.dx,
        c.dy + alta * 0.5,
        c.dx - larga * 0.3,
        c.dy + alta * 0.08,
      )
      ..close();
    canvas
      ..drawPath(bocca, luce)
      ..drawPath(bocca, bordo);
  }

  @override
  bool shouldRepaint(_ZuccaAccesa altro) => altro.tempo != tempo;
}

// ---------------------------------------------------------------------------
// La vedova nera
// ---------------------------------------------------------------------------

/// **Una vedova nera che scende dal suo filo**, con la clessidra rossa CRASY
/// sulla pancia.
///
/// Scende, si ferma dondolando, e risale: un ragno sempre fermo non si vede,
/// uno che va su e giu' di continuo da' fastidio. Le zampe si muovono appena.
class _VedovaNera extends CustomPainter {
  _VedovaNera({required this.tempo}) : super(repaint: tempo);

  final Animation<double> tempo;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tempo.value;
    final misura = math.min(size.height * 0.2, 13.0);
    final x = size.width * 0.66;
    final fondo = size.height - misura * 1.6;

    // Scende in un terzo del giro, resta, e risale nell'ultimo quarto.
    double discesa;
    if (t < 0.3) {
      discesa = Curves.easeOutBack.transform(t / 0.3);
    } else if (t < 0.75) {
      discesa = 1 + 0.04 * math.sin(2 * math.pi * (t - 0.3) * 2.2);
    } else {
      discesa = 1 - Curves.easeInCubic.transform((t - 0.75) / 0.25);
    }

    final y = -misura + (fondo + misura) * discesa;
    final dondolo = math.sin(2 * math.pi * t * 2) * 2.5;
    final corpo = Offset(x + dondolo, y);

    canvas.drawLine(
      Offset(x, 0),
      corpo - Offset(0, misura * 0.6),
      _filo(_nero.withAlpha(0x55), 1),
    );

    // Le zampe, prima del corpo.
    final zampe = _filo(_nero, math.max(1.2, misura * 0.14));
    final passo = math.sin(2 * math.pi * t * 5) * misura * 0.08;
    for (final verso in [-1.0, 1.0]) {
      for (var i = 0; i < 4; i++) {
        final alto = -0.6 + i * 0.42;
        final ginocchio =
            corpo +
            Offset(
              verso * misura * 1.05,
              (alto - 0.55) * misura + (i.isEven ? passo : -passo),
            );
        final piede = ginocchio + Offset(verso * misura * 0.7, misura * 0.75);

        canvas.drawPath(
          Path()
            ..moveTo(corpo.dx, corpo.dy + alto * misura * 0.3)
            ..quadraticBezierTo(ginocchio.dx, ginocchio.dy, piede.dx, piede.dy),
          zampe,
        );
      }
    }

    final addome = Rect.fromCenter(
      center: corpo + Offset(0, misura * 0.35),
      width: misura * 1.25,
      height: misura * 1.45,
    );
    canvas
      ..drawOval(
        addome,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.5),
            colors: [Color(0xFF3A3A44), _nero],
          ).createShader(addome),
      )
      ..drawCircle(
        corpo - Offset(0, misura * 0.55),
        misura * 0.42,
        Paint()..color = _nero,
      );

    // La clessidra: due triangoli rossi punta contro punta.
    final c = corpo + Offset(0, misura * 0.38);
    final s = misura * 0.26;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - s, c.dy - s * 1.3)
        ..lineTo(c.dx + s, c.dy - s * 1.3)
        ..lineTo(c.dx, c.dy)
        ..lineTo(c.dx + s, c.dy + s * 1.3)
        ..lineTo(c.dx - s, c.dy + s * 1.3)
        ..lineTo(c.dx, c.dy)
        ..close(),
      Paint()..color = AppColors.crasyRed,
    );
  }

  @override
  bool shouldRepaint(_VedovaNera altro) => altro.tempo != tempo;
}

// ---------------------------------------------------------------------------
// Il gatto nero
// ---------------------------------------------------------------------------

/// **Un gatto nero seduto**, con gli occhi gialli e la coda che si muove.
///
/// Ogni tanto chiude gli occhi. La coda disegna una esse lenta: e' quello che
/// fa vivo un gatto fermo.
class _GattoNero extends CustomPainter {
  _GattoNero({required this.tempo}) : super(repaint: tempo);

  final Animation<double> tempo;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tempo.value;
    final alto = math.min(size.height * 0.94, 64.0);
    final largo = alto * 0.62;
    final base = size.height - 3;
    final cx = size.width - largo - 14;
    final pelo = Paint()..color = _pelo;

    _ombra(canvas, Offset(cx + largo * 0.15, base), largo * 1.6);

    // La coda, dietro il corpo: parte dal fondo e sale a esse.
    final onda = math.sin(2 * math.pi * t);
    canvas.drawPath(
      Path()
        ..moveTo(cx + largo * 0.3, base - 2)
        ..cubicTo(
          cx + largo * 1.05,
          base - alto * 0.05,
          cx + largo * (0.7 + 0.25 * onda),
          base - alto * 0.45,
          cx + largo * (1.0 + 0.2 * onda),
          base - alto * 0.62,
        ),
      _filo(_pelo, largo * 0.17),
    );

    // Il corpo seduto: un ovale largo in basso, il petto sopra.
    canvas
      ..drawOval(
        Rect.fromCenter(
          center: Offset(cx, base - alto * 0.24),
          width: largo * 1.05,
          height: alto * 0.5,
        ),
        pelo,
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset(cx - largo * 0.05, base - alto * 0.47),
          width: largo * 0.62,
          height: alto * 0.4,
        ),
        pelo,
      );

    // La testa e le orecchie.
    final testa = Offset(cx - largo * 0.08, base - alto * 0.72);
    final r = largo * 0.36;
    canvas.drawCircle(testa, r, pelo);
    for (final verso in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(testa.dx + verso * r * 0.95, testa.dy - r * 0.15)
          ..lineTo(testa.dx + verso * r * 0.8, testa.dy - r * 1.45)
          ..lineTo(testa.dx + verso * r * 0.12, testa.dy - r * 0.85)
          ..close(),
        pelo,
      );
    }

    // Gli occhi: gialli, con la pupilla a fessura. Chiusi una volta per giro.
    final chiusi = t > 0.9 && t < 0.95;
    for (final verso in [-1.0, 1.0]) {
      final occhio = testa + Offset(verso * r * 0.42, r * 0.02);

      if (chiusi) {
        canvas.drawLine(
          occhio - Offset(r * 0.2, 0),
          occhio + Offset(r * 0.2, 0),
          _filo(_candela, math.max(1, r * 0.1)),
        );
        continue;
      }

      canvas
        ..drawOval(
          Rect.fromCenter(center: occhio, width: r * 0.46, height: r * 0.34),
          Paint()..color = _candela,
        )
        ..drawOval(
          Rect.fromCenter(center: occhio, width: r * 0.1, height: r * 0.3),
          Paint()..color = _nero,
        );
    }
  }

  @override
  bool shouldRepaint(_GattoNero altro) => altro.tempo != tempo;
}

// ---------------------------------------------------------------------------
// Il fantasma
// ---------------------------------------------------------------------------

/// **Un fantasma che galleggia**, con il fondo che ondeggia e le guance rosse
/// di CRASY. Bianco su bianco si vedrebbe solo il contorno: per questo ha un
/// filo grigio attorno e un'ombra sotto, che si stringe quando sale.
class _Fantasma extends CustomPainter {
  _Fantasma({required this.tempo}) : super(repaint: tempo);

  final Animation<double> tempo;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tempo.value;
    final onda = math.sin(2 * math.pi * t);
    final w = math.min(size.height * 0.7, 46.0);
    final h = w * 1.22;
    final c = Offset(size.width - w / 2 - 12, size.height / 2 - 4 + onda * 4);

    _ombra(
      canvas,
      Offset(c.dx, size.height - 4),
      w * (0.85 - onda * 0.12),
      alfa: 0x12,
    );

    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(onda * 0.07)
      ..translate(-c.dx, -c.dy);

    final top = c.dy - h / 2;
    final fondo = c.dy + h / 2;
    final corpo = Path()
      ..moveTo(c.dx - w / 2, c.dy)
      ..arcTo(Rect.fromLTWH(c.dx - w / 2, top, w, w), math.pi, math.pi, false)
      ..lineTo(c.dx + w / 2, fondo - h * 0.08);

    // Il bordo in fondo a tre onde, che scorrono.
    const onde = 3;
    final scorre = math.sin(2 * math.pi * t * 2) * h * 0.04;
    for (var i = 0; i < onde; i++) {
      final da = c.dx + w / 2 - i * w / onde;
      final a = da - w / onde;
      corpo.quadraticBezierTo(
        (da + a) / 2,
        fondo + (i.isEven ? h * 0.07 + scorre : -h * 0.09 - scorre),
        a,
        fondo - h * 0.08,
      );
    }
    corpo.close();

    canvas
      ..drawPath(corpo, Paint()..color = Colors.white)
      ..drawPath(corpo, _filo(const Color(0x380A0A0B), 1.3));

    final chiusi = t > 0.55 && t < 0.6;
    final nero = Paint()..color = _nero;
    for (final verso in [-1.0, 1.0]) {
      final occhio = Offset(c.dx + verso * w * 0.17, c.dy - h * 0.1);
      canvas
        ..drawOval(
          Rect.fromCenter(
            center: occhio,
            width: w * 0.13,
            height: chiusi ? w * 0.03 : w * 0.19,
          ),
          nero,
        )
        ..drawCircle(
          Offset(c.dx + verso * w * 0.29, c.dy + h * 0.03),
          w * 0.075,
          Paint()..color = AppColors.crasyRed.withAlpha(0x50),
        );
    }
    canvas
      ..drawOval(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy + h * 0.07),
          width: w * 0.13,
          height: w * 0.17,
        ),
        nero,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_Fantasma altro) => altro.tempo != tempo;
}

// ---------------------------------------------------------------------------
// Le ragnatele
// ---------------------------------------------------------------------------

/// I cerchi di una tela, che **non sono cerchi**: archi che cedono verso il
/// centro, come il filo fra un raggio e l'altro. A cerchi perfetti diventa un
/// bersaglio.
void _anelli(
  Canvas canvas,
  Offset centro,
  double raggio,
  List<double> angoli,
  Paint penna,
  List<double> quote,
) {
  for (final quota in quote) {
    final r = raggio * quota;

    for (var i = 0; i < angoli.length - 1; i++) {
      final a = angoli[i];
      final b = angoli[i + 1];
      final mezzo = (a + b) / 2;

      canvas.drawPath(
        Path()
          ..moveTo(centro.dx + math.cos(a) * r, centro.dy + math.sin(a) * r)
          ..quadraticBezierTo(
            centro.dx + math.cos(mezzo) * r * 0.88,
            centro.dy + math.sin(mezzo) * r * 0.88,
            centro.dx + math.cos(b) * r,
            centro.dy + math.sin(b) * r,
          ),
        penna,
      );
    }
  }
}

/// Un quarto di tela con il centro sul vertice [angolo], che parte da [da].
void _quartoDiTela(
  Canvas canvas,
  Offset angolo,
  double raggio,
  double da,
  Paint penna, {
  List<double> quote = const [0.3, 0.55, 0.8, 1.0],
}) {
  const raggi = 6;
  final angoli = [
    for (var i = 0; i <= raggi; i++) da + i * (math.pi / 2) / raggi,
  ];

  for (final a in angoli) {
    canvas.drawLine(
      angolo,
      angolo + Offset(math.cos(a), math.sin(a)) * raggio,
      penna,
    );
  }

  _anelli(canvas, angolo, raggio, angoli, penna, quote);
}

/// **La ragnatela accanto al premio**, con il suo ragno appeso. Le gocce di
/// rugiada sui fili brillano a turno.
class _RagnatelaMissione extends CustomPainter {
  _RagnatelaMissione({required this.tempo}) : super(repaint: tempo);

  final Animation<double> tempo;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tempo.value;
    final angolo = Offset(size.width, 0);
    final raggio = math.min(size.width * 0.75, size.height * 1.1);

    canvas
      ..save()
      ..translate(angolo.dx, angolo.dy)
      ..rotate(0.035 * math.sin(2 * math.pi * t))
      ..translate(-angolo.dx, -angolo.dy);
    _quartoDiTela(
      canvas,
      angolo,
      raggio,
      math.pi / 2,
      _filo(const Color(0x400A0A0B), 1.1),
    );

    // La rugiada: tre gocce, una alla volta piu' luminosa.
    for (var i = 0; i < 3; i++) {
      final a = math.pi / 2 + (i + 1.5) * (math.pi / 2) / 6;
      final dove = angolo + Offset(math.cos(a), math.sin(a)) * raggio * 0.55;
      final luce = (math.sin(2 * math.pi * (t * 2 - i / 3)) + 1) / 2;
      canvas.drawCircle(
        dove,
        1.6 + luce,
        Paint()
          ..color = const Color(
            0xFF9ED4FF,
          ).withAlpha(90 + (110 * luce).round()),
      );
    }
    canvas.restore();

    // Il ragno, appeso sotto la tela.
    final attacco = angolo + Offset(-raggio * 0.42, raggio * 0.42);
    final corsa = math.max(0.0, size.height - 12 - attacco.dy);
    final giu =
        attacco + Offset(0, corsa * (0.55 + 0.1 * math.sin(2 * math.pi * t)));
    canvas
      ..drawLine(attacco, giu, _filo(const Color(0x550A0A0B), 1))
      ..drawCircle(giu + const Offset(0, 4), 3.4, Paint()..color = _nero)
      ..drawCircle(giu, 2, Paint()..color = _nero);
    final zampe = _filo(_nero, 1);
    for (final verso in [-1.0, 1.0]) {
      for (var i = 0; i < 3; i++) {
        final dy = 1.0 + i * 2.5;
        canvas.drawLine(
          giu + Offset(0, dy + 1),
          giu + Offset(verso * 7, dy - 1 + i * 1.5),
          zampe,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RagnatelaMissione altro) => altro.tempo != tempo;
}

/// Un quarto di ragnatela bianca nell'angolo in alto a sinistra di un tasto.
class _RagnatelaSulTasto extends CustomPainter {
  _RagnatelaSulTasto({required this.tempo}) : super(repaint: tempo);

  final Animation<double> tempo;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..rotate(0.06 * math.sin(2 * math.pi * tempo.value));
    _quartoDiTela(
      canvas,
      Offset.zero,
      size.height * 0.72,
      0,
      _filo(const Color(0x40FFFFFF), 1.1),
      quote: const [0.42, 0.72, 0.98],
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RagnatelaSulTasto altro) => altro.tempo != tempo;
}

// ---------------------------------------------------------------------------
// Le colate sui tasti
// ---------------------------------------------------------------------------

/// **Il rosso del tasto che cola dal bordo di sotto.**
///
/// E' lo stesso rosso del tasto, quindi le colate sembrano il tasto che si
/// scioglie e non un disegno appoggiato. Quattro o cinque, lunghe diverse,
/// che si allungano piano; dalla prima ogni tanto si stacca una goccia.
class _Colate extends CustomPainter {
  _Colate({required this.tempo, required this.sorte}) : super(repaint: tempo);

  final Animation<double> tempo;
  final int sorte;

  static const _rosso = AppColors.crasyRedDeep;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tempo.value;
    final caso = math.Random(sorte);
    final quante = 4 + caso.nextInt(2);
    // Il bordo del tasto sta 4 punti sotto il bordo alto di questo disegno.
    const bordo = 4.0;
    final pieno = Paint()..color = _rosso;
    final lucido = Paint()..color = const Color(0x55FFFFFF);

    for (var i = 0; i < quante; i++) {
      // Lontane dagli angoli tondi del tasto, e non a passo fisso.
      final x =
          20 +
          (size.width - 40) * ((i + 0.2 + caso.nextDouble() * 0.6) / quante);
      final larga = 6.0 + caso.nextDouble() * 5;
      final massima = 8.0 + caso.nextDouble() * 12;
      final ritmo = caso.nextDouble();
      final lunga =
          bordo + massima * (0.75 + 0.25 * math.sin(2 * math.pi * (t + ritmo)));

      final colata = Path()
        ..moveTo(x - larga * 1.1, 0)
        ..quadraticBezierTo(
          x - larga / 2,
          bordo,
          x - larga / 2,
          bordo + larga * 0.6,
        )
        ..lineTo(x - larga / 2, lunga - larga / 2)
        ..arcToPoint(
          Offset(x + larga / 2, lunga - larga / 2),
          radius: Radius.circular(larga / 2),
          clockwise: false,
        )
        ..lineTo(x + larga / 2, bordo + larga * 0.6)
        ..quadraticBezierTo(x + larga / 2, bordo, x + larga * 1.1, 0)
        ..close();

      canvas
        ..drawPath(colata, pieno)
        // La goccia in fondo e' un filo piu' grossa: il peso la tira giu'.
        ..drawCircle(Offset(x, lunga - larga / 2), larga * 0.58, pieno)
        ..drawRRect(
          RRect.fromLTRBR(
            x - larga * 0.3,
            bordo + 2,
            x - larga * 0.1,
            lunga - larga * 0.7,
            const Radius.circular(2),
          ),
          lucido,
        );

      // Dalla prima si stacca una goccia, nella seconda meta' del giro.
      if (i == 0 && t > 0.55) {
        final caduta = (t - 0.55) / 0.45;
        final y = lunga + 3 + caduta * 16;
        canvas.drawCircle(
          Offset(x, y),
          larga * 0.42,
          Paint()..color = _rosso.withAlpha((255 * (1 - caduta)).round()),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Colate altro) => altro.tempo != tempo;
}

// ---------------------------------------------------------------------------
// L'apertura e l'attesa
// ---------------------------------------------------------------------------

/// Una luna piena: panna al centro, piu' calda sul bordo, con due crateri.
void _lunaPiena(Canvas canvas, Offset c, double r) {
  final rect = Rect.fromCircle(center: c, radius: r);
  canvas
    ..drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.25, -0.3),
          colors: [_luna, _lunaBordo],
        ).createShader(rect),
    )
    ..drawCircle(
      c + Offset(r * 0.3, -r * 0.25),
      r * 0.16,
      Paint()..color = const Color(0x226B6680),
    )
    ..drawCircle(
      c + Offset(-r * 0.25, r * 0.3),
      r * 0.11,
      Paint()..color = const Color(0x1C6B6680),
    )
    ..drawCircle(
      c + Offset(-r * 0.38, -r * 0.18),
      r * 0.07,
      Paint()..color = const Color(0x186B6680),
    )
    ..drawCircle(c, r, _filo(_bordoDiLuna, 1));
}

/// **Una falce di luna**: un disco a cui un altro disco toglie un morso. Con
/// un alone freddo e un filo di bordo, perche' su fondo bianco si veda.
void _falceDiLuna(Canvas canvas, Offset c, double r) {
  _alone(canvas, c, r * 2.8, _chiaroDiLuna.withAlpha(0x38));

  final falce = Path.combine(
    PathOperation.difference,
    Path()..addOval(Rect.fromCircle(center: c, radius: r)),
    Path()..addOval(
      Rect.fromCircle(center: c + Offset(r * 0.55, -r * 0.3), radius: r),
    ),
  );
  final rect = Rect.fromCircle(center: c, radius: r);

  canvas
    ..drawPath(
      falce,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_luna, _lunaBordo],
        ).createShader(rect),
    )
    ..drawPath(falce, _filo(_bordoDiLuna, 1));
}

/// **La luna dietro la fiamma**, con tre pipistrelli che le girano attorno.
class _LunaDiApertura extends CustomPainter {
  _LunaDiApertura({required this.tempo, required this.misura})
    : super(repaint: tempo);

  final Animation<double> tempo;

  /// Quanto e' grande la fiamma: la luna si misura su di lei.
  final double misura;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tempo.value;
    final c = size.center(Offset.zero);
    final r = misura * 0.78;

    _alone(canvas, c, r * 1.9, _chiaroDiLuna.withAlpha(0x55));
    _lunaPiena(canvas, c, r);

    for (var i = 0; i < 3; i++) {
      final angolo = (t + i / 3) * 2 * math.pi;
      // Un'orbita schiacciata: i pipistrelli girano attorno alla luna senza
      // mai coprire la fiamma, che sta al centro.
      final dove =
          c + Offset(math.cos(angolo) * r * 1.55, math.sin(angolo) * r * 0.75);
      _pipistrello(
        canvas,
        dove,
        misura * (0.16 + 0.04 * i),
        math.sin(2 * math.pi * (t * 6 + i / 3)),
        _notte,
      );
    }
  }

  @override
  bool shouldRepaint(_LunaDiApertura altro) => altro.tempo != tempo;
}

/// L'alone di candela dietro la fiamma piccola dell'attesa.
class _Bagliore extends CustomPainter {
  const _Bagliore();

  @override
  void paint(Canvas canvas, Size size) {
    _alone(
      canvas,
      size.center(Offset.zero),
      size.shortestSide / 2,
      _zucca.withAlpha(0x38),
    );
  }

  @override
  bool shouldRepaint(_Bagliore altro) => false;
}

// ---------------------------------------------------------------------------
// La notte dietro la pagina
// ---------------------------------------------------------------------------

/// **La notte sul fondo**: la luna con un pipistrello fra il logo e i comandi,
/// e in fondo una collina con l'albero storto e le lapidi.
///
/// La collina e' viola chiarissimo — sta dietro al testo e il testo deve
/// leggersi uguale. La luna e' l'unica cosa piena, e sta nella fascia del
/// marchio dove non passa niente. Poco, apposta: e' lo sfondo di ogni pagina.
class _NotteSulFondo extends CustomPainter {
  _NotteSulFondo({required this.tempo, required this.alto, required this.luna})
    : super(repaint: tempo);

  final Animation<double> tempo;

  /// Lo spazio della barra di stato, che la luna non deve coprire.
  final double alto;

  /// Se disegnare la luna: solo sulla home.
  final bool luna;

  /// La sagoma della collina: viola al 9%.
  static const _sagoma = Color(0x176B3FA0);

  @override
  void paint(Canvas canvas, Size size) {
    final t = tempo.value;
    final w = size.width;
    final h = size.height;

    // **Una falce di luna, nella fascia del marchio**, fra il logo e i
    // comandi: l'unico punto della pagina in cui non passa mai niente. Una
    // falce e non un disco: il disco panna con l'alone arancione si leggeva
    // come un sole.
    if (luna) {
      final dove = Offset(w * 0.6, alto + 38);

      _falceDiLuna(canvas, dove, 19);

      // Un pipistrello che le gira davanti, largo e lento, e due stelline.
      final a = t * 2 * math.pi;
      _pipistrello(
        canvas,
        dove + Offset(math.cos(a) * 46, math.sin(a) * 13 - 2),
        10,
        math.sin(2 * math.pi * t * 22),
        _notte.withAlpha(0xCC),
      );
      for (final (dx, dy, r) in [(-40.0, -10.0, 2.2), (34.0, 14.0, 1.6)]) {
        final luce = 0.5 + 0.5 * math.sin(2 * math.pi * (t * 3 + dx / 100));
        canvas.drawCircle(
          dove + Offset(dx, dy),
          r,
          Paint()..color = _stella.withAlpha(100 + (120 * luce).round()),
        );
      }
    }

    // La collina, in fondo.
    final sagoma = Paint()..color = _sagoma;
    canvas.drawPath(
      Path()
        ..moveTo(0, h)
        ..lineTo(0, h - 74)
        ..quadraticBezierTo(w * 0.22, h - 128, w * 0.48, h - 92)
        ..quadraticBezierTo(w * 0.74, h - 58, w, h - 104)
        ..lineTo(w, h)
        ..close(),
      sagoma,
    );

    // L'albero storto, a sinistra sulla collina.
    final ramo = _filo(_sagoma, 6);
    final piede = Offset(w * 0.16, h - 102);
    canvas
      ..drawPath(
        Path()
          ..moveTo(piede.dx, piede.dy + 10)
          ..quadraticBezierTo(
            piede.dx - 6,
            piede.dy - 50,
            piede.dx + 8,
            piede.dy - 92,
          ),
        _filo(_sagoma, 9),
      )
      ..drawPath(
        Path()
          ..moveTo(piede.dx + 2, piede.dy - 48)
          ..quadraticBezierTo(
            piede.dx + 30,
            piede.dy - 60,
            piede.dx + 44,
            piede.dy - 90,
          ),
        ramo,
      )
      ..drawPath(
        Path()
          ..moveTo(piede.dx - 2, piede.dy - 62)
          ..quadraticBezierTo(
            piede.dx - 26,
            piede.dy - 70,
            piede.dx - 34,
            piede.dy - 96,
          ),
        ramo,
      )
      ..drawPath(
        Path()
          ..moveTo(piede.dx + 6, piede.dy - 84)
          ..quadraticBezierTo(
            piede.dx + 16,
            piede.dy - 104,
            piede.dx + 10,
            piede.dy - 118,
          ),
        _filo(_sagoma, 4),
      );

    // Le lapidi, a destra.
    for (final (x, alta) in [(0.66, 30.0), (0.76, 38.0), (0.87, 26.0)]) {
      final base = h - 70 - (x - 0.66) * 60;
      final larga = alta * 0.62;
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          w * x - larga / 2,
          base - alta,
          w * x + larga / 2,
          base + 6,
          topLeft: Radius.circular(larga / 2),
          topRight: Radius.circular(larga / 2),
        ),
        sagoma,
      );
    }
  }

  @override
  bool shouldRepaint(_NotteSulFondo altro) =>
      altro.tempo != tempo || altro.alto != alto || altro.luna != luna;
}
