import 'dart:math' as math;

import 'package:flutter/material.dart';

/// **La fiamma di CRASY, dentro la teca.**
///
/// Al posto della coppa, che era il trofeo di chiunque. Questa e' la fiamma —
/// il marchio, e anche il voto: ogni foto in gara si misura in fiamme. Darla a
/// chi ha messo i soldi chiude un cerchio: ha pagato perche' altri se le
/// prendessero, e adesso ne tiene una sua sotto vetro.
///
/// **E' un oggetto, non un'icona.** Ha un corpo grosso e panciuto, una
/// fiammella gialla che gli brucia dentro, un braccio che si arriccia a
/// sinistra e qualche schizzo staccato che sale. E' lucida: ha un colpo di luce
/// dove la superficie si gonfia e un bordo scuro dove rientra — che e' tutto
/// cio' che serve perche' una cosa piatta sembri tonda.
class FlamePainter extends CustomPainter {
  const FlamePainter({required this.angolo});

  /// Di quanto e' girata, in radianti.
  ///
  /// **La fiamma e' dentro la teca, quindi gira con lei.** Girando la vetrina
  /// si gira anche quello che c'e' dentro: e' una cosa sola, e una fiamma che
  /// restasse ferma mentre la scatola gira sarebbe appesa a niente.
  ///
  /// Una fiamma e' tonda e da tutti i lati si somiglia: a girare non e' la
  /// sagoma, sono **la luce che scorre sul fianco**, la fiammella interna che
  /// scivola di lato e gli schizzi, che passano davanti e dietro. E' cosi' che
  /// si racconta una rotazione senza avere un modello tridimensionale.
  final double angolo;

  double get _fronte => math.cos(angolo);
  double get _lato => math.sin(angolo);

  // I colori del fuoco: dal rosso del bordo all'arancio della pancia.
  static const Color bordo = Color(0xFFC0390F);
  static const Color _rosso = Color(0xFFE2541F);
  static const Color _arancio = Color(0xFFF2853C);
  static const Color _chiaro = Color(0xFFFBA85E);

  // La fiammella interna, piu' calda.
  static const Color _gialloScuro = Color(0xFFF2A81C);
  static const Color _giallo = Color(0xFFFFCB45);
  static const Color _gialloChiaro = Color(0xFFFFE07A);

  // L'oro della base, lo stesso della cornice delle figurine.
  static const Color _oroChiaro = Color(0xFFFFF0B8);
  static const Color _oroOmbra = Color(0xFF7E5F17);

  /// Una goccia di fuoco: larga e tonda in basso, tirata a punta in alto.
  ///
  /// [inclina] sposta la punta di lato. E' la cosa che la rende una fiamma e
  /// non un uovo: nel fuoco la punta scappa sempre da qualche parte.
  Path _goccia({
    required double cx,
    required double base,
    required double altezza,
    required double larghezza,
    required double inclina,
  }) {
    final mezza = larghezza / 2;
    final punta = Offset(cx + inclina, base - altezza);

    return Path()
      // Si parte dal fondo, al centro della pancia.
      ..moveTo(cx, base)
      // Fianco destro: si gonfia largo e poi sale stretto verso la punta.
      ..cubicTo(
        cx + mezza * 1.02,
        base - altezza * 0.04,
        cx + mezza * 0.98,
        base - altezza * 0.46,
        punta.dx + larghezza * 0.10,
        base - altezza * 0.80,
      )
      ..cubicTo(
        punta.dx + larghezza * 0.05,
        base - altezza * 0.93,
        punta.dx + larghezza * 0.02,
        punta.dy,
        punta.dx,
        punta.dy,
      )
      // Fianco sinistro: rientra piu' presto, ed e' l'asimmetria che la fa
      // sembrare mossa invece che disegnata col compasso.
      ..cubicTo(
        punta.dx - larghezza * 0.16,
        base - altezza * 0.82,
        cx - mezza * 0.96,
        base - altezza * 0.50,
        cx - mezza * 1.02,
        base - altezza * 0.06,
      )
      ..cubicTo(
        cx - mezza * 1.03,
        base - altezza * 0.01,
        cx - mezza * 0.5,
        base,
        cx,
        base,
      )
      ..close();
  }

  /// La sfumatura di una cosa tonda e lucida, con la luce che segue la
  /// rotazione: chiara dove la superficie si gonfia verso di noi, scura dove
  /// rientra.
  Shader _volume(Rect area, Color chiaro, Color medio, Color scuro) {
    final centro = (0.32 + _fronte * 0.20).clamp(0.10, 0.82);

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [chiaro, medio, scuro],
      stops: [
        (centro - 0.18).clamp(0, 0.6),
        (centro + 0.22).clamp(0.2, 0.9),
        1,
      ],
    ).createShader(area);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Il piede cade al 91% dell'altezza: e' la misura che la teca si aspetta
    // per appoggiare l'oggetto sul ripiano invece di lasciarlo galleggiare.
    final base = h * 0.80;

    _ombraATerra(canvas, w, h);
    _schizzi(canvas, w, h, dietro: true);

    // **Il braccio che si arriccia a sinistra.** Sta sotto il corpo, e si
    // vede solo il pezzo che sporge: e' quello che toglie alla fiamma l'aria
    // di una goccia sola e le da' l'aria di un fuoco.
    _braccio(canvas, w, h, base);

    // **Il corpo.**
    final corpo = _goccia(
      cx: cx + w * 0.015,
      base: base,
      altezza: h * 0.70,
      larghezza: w * 0.56,
      inclina: w * 0.07 + _lato * w * 0.03,
    );

    canvas.drawPath(
      corpo,
      Paint()..shader = _volume(corpo.getBounds(), _chiaro, _arancio, bordo),
    );

    // Il bordo scuro sul lato in ombra: senza, due superfici arancioni che si
    // toccano diventano una macchia sola.
    canvas.drawPath(
      corpo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012
        ..color = bordo.withValues(alpha: 0.35),
    );

    _lucido(canvas, w, h, base);

    // **La fiammella interna**, piu' calda e piu' bassa: e' il cuore del
    // fuoco. Scivola di lato girando, ed e' il segno piu' forte che l'oggetto
    // sta ruotando davvero — una cosa dentro un'altra si sposta prima del
    // contorno.
    final dentro = _goccia(
      cx: cx + _lato * w * 0.10,
      base: base - h * 0.015,
      altezza: h * 0.34,
      larghezza: w * 0.30,
      inclina: w * 0.03,
    );

    canvas.drawPath(
      dentro,
      Paint()
        ..shader = _volume(
          dentro.getBounds(),
          _gialloChiaro,
          _giallo,
          _gialloScuro,
        ),
    );

    // Il colpo di luce sulla fiammella: piccolo e altissimo, com'e' su una
    // cosa di plastica lucida.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + _lato * w * 0.10 - w * 0.04, base - h * 0.20),
        width: w * 0.05,
        height: h * 0.07,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    _schizzi(canvas, w, h, dietro: false);
    _base(canvas, w, h);
  }

  /// Il braccio arricciato a sinistra: una virgola grassa che sale e rientra.
  void _braccio(Canvas canvas, double w, double h, double base) {
    final cx = w / 2;
    final percorso = Path()
      ..moveTo(cx - w * 0.10, base)
      ..cubicTo(
        cx - w * 0.36,
        base - h * 0.06,
        cx - w * 0.40,
        base - h * 0.30,
        cx - w * 0.26,
        base - h * 0.46,
      )
      ..cubicTo(
        cx - w * 0.30,
        base - h * 0.30,
        cx - w * 0.24,
        base - h * 0.14,
        cx - w * 0.04,
        base - h * 0.02,
      )
      ..close();

    canvas.drawPath(
      percorso,
      Paint()
        ..shader = _volume(percorso.getBounds(), _chiaro, _rosso, bordo),
    );
  }

  /// **Il colpo di luce sul corpo.** E' la riga che fa la differenza fra una
  /// sagoma arancione e un oggetto lucido: una macchia chiara e sfocata dove
  /// la pancia si gonfia verso la luce, che si sposta girando.
  void _lucido(Canvas canvas, double w, double h, double base) {
    final cx = w / 2;
    final dx = cx - w * 0.14 + _fronte * w * 0.06;

    final riflesso = Path()
      ..moveTo(dx, base - h * 0.60)
      ..cubicTo(
        dx - w * 0.10,
        base - h * 0.48,
        dx - w * 0.09,
        base - h * 0.30,
        dx - w * 0.02,
        base - h * 0.20,
      )
      ..cubicTo(
        dx - w * 0.12,
        base - h * 0.30,
        dx - w * 0.13,
        base - h * 0.50,
        dx,
        base - h * 0.60,
      )
      ..close();

    canvas.drawPath(
      riflesso,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  /// **Gli schizzi staccati.** Piccoli archi che salgono attorno alla fiamma,
  /// come scintille che si sono staccate un attimo prima.
  ///
  /// Girando, alcuni passano **davanti** al corpo e altri **dietro**: e' il
  /// trucco piu' economico per raccontare che c'e' uno spazio, e non un
  /// disegno piatto. Quelli dietro si disegnano prima del corpo, quelli davanti
  /// dopo.
  void _schizzi(Canvas canvas, double w, double h, {required bool dietro}) {
    final cx = w / 2;

    // (x, y, lunghezza, curva, spessore, quando sta dietro)
    final archi = <(double, double, double, double, double, bool)>[
      (-0.30, 0.16, 0.20, -0.06, 0.028, true),
      (0.12, 0.05, 0.16, 0.05, 0.026, false),
      (0.30, 0.10, 0.10, 0.04, 0.022, true),
      (0.26, 0.30, 0.16, 0.06, 0.024, false),
      (-0.34, 0.34, 0.09, -0.04, 0.020, true),
    ];

    for (final (x, y, lung, curva, spessore, sta) in archi) {
      if (sta != dietro) {
        continue;
      }

      // Girando, gli schizzi si spostano di lato: sono attorno alla fiamma,
      // non incollati sopra.
      final px = cx + w * x + _lato * w * 0.05;
      final py = h * y;

      final arco = Path()
        ..moveTo(px, py)
        ..quadraticBezierTo(
          px + w * curva * 2,
          py + h * lung * 0.5,
          px + w * curva,
          py + h * lung,
        );

      canvas.drawPath(
        arco,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w * spessore
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [_chiaro, _rosso],
          ).createShader(arco.getBounds().inflate(w * spessore)),
      );
    }
  }

  /// L'ombra sotto: senza, la fiamma galleggia dentro la teca invece di
  /// appoggiarsi al ripiano.
  void _ombraATerra(Canvas canvas, double w, double h) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.925),
        width: w * 0.52,
        height: h * 0.045,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  /// Il basamento d'oro: due lastre, una piu' stretta sopra.
  ///
  /// **Serve a renderla un trofeo invece che un'icona.** Una fiamma da sola e'
  /// un simbolo; una fiamma che poggia su una base e' una cosa che qualcuno ha
  /// vinto e ha messo sotto vetro.
  void _base(Canvas canvas, double w, double h) {
    final cx = w / 2;

    for (final (cy, larghezza, altezza) in <(double, double, double)>[
      (0.825, 0.34, 0.045),
      (0.885, 0.54, 0.065),
    ]) {
      final area = Rect.fromCenter(
        center: Offset(cx, h * cy),
        width: w * larghezza,
        height: h * altezza,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(area, const Radius.circular(4)),
        Paint()..shader = _volume(area, _oroChiaro, _oroChiaro, _oroOmbra),
      );

      // Il filo di luce sullo spigolo di sopra: un metallo senza spigolo
      // illuminato e' un rettangolo giallo.
      canvas.drawLine(
        area.topLeft + const Offset(2, 0.6),
        area.topRight - const Offset(2, -0.6),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..strokeWidth = 1.1,
      );
    }
  }

  @override
  bool shouldRepaint(FlamePainter oldDelegate) => oldDelegate.angolo != angolo;
}
