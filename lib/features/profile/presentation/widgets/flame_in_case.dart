import 'dart:math' as math;

import 'package:flutter/material.dart';

/// **La fiamma del marchio, dentro la teca.**
///
/// Al posto della coppa, che era il trofeo di chiunque. Questa e' la fiamma
/// del logo di CRASY — quella che brucia dentro la *sy* — ed e' anche il voto:
/// ogni foto in gara si misura in fiamme. Darla a chi ha messo i soldi chiude
/// un cerchio: ha pagato perche' altri se le prendessero, e adesso ne tiene una
/// sua sotto vetro.
///
/// **Non e' una goccia arrotondata.** La fiamma del logo e' frastagliata: ha
/// lingue di altezze diverse che si piegano, si staccano e ricadono. Una goccia
/// liscia e' l'icona del fuoco di un sistema operativo; queste punte irregolari
/// sono quelle del marchio, ed e' l'unica ragione per cui vale la pena
/// disegnarla invece di prenderla da un carattere.
class FlamePainter extends CustomPainter {
  const FlamePainter({required this.angolo});

  /// Di quanto e' girata, in radianti.
  ///
  /// **La fiamma e' dentro la teca, quindi gira con lei.** Girando la vetrina
  /// si gira anche quello che c'e' dentro: e' una cosa sola, e una fiamma che
  /// restasse ferma mentre la scatola gira sarebbe appesa a niente.
  ///
  /// Girando, la sagoma resta quella — un fuoco e' tondo, si assomiglia da
  /// tutti i lati — e a cambiare sono **la luce che scorre sul fianco** e la
  /// piega delle lingue, che si inclinano dall'altra parte come se la corrente
  /// d'aria venisse dal lato opposto.
  final double angolo;

  double get _fronte => math.cos(angolo);
  double get _lato => math.sin(angolo);

  /// I colori del logo: dal rosso cupo del bordo all'arancio acceso del cuore.
  ///
  /// **Quattro toni e non uno.** Un fuoco di un colore solo e' una sagoma
  /// colorata: sono i bordi fra uno strato e l'altro a dargli volume, ed e' lo
  /// stesso motivo per cui l'oro della cornice non e' senape.
  static const Color bordo = Color(0xFF9E1006);
  static const Color _rosso = Color(0xFFE8220A);
  static const Color _arancio = Color(0xFFFF6B00);
  static const Color _cuore = Color(0xFFFFC53D);

  /// L'oro della base, lo stesso della cornice delle figurine.
  static const Color _oroChiaro = Color(0xFFFFF0B8);
  static const Color _oroMedio = Color(0xFFE9C468);
  static const Color _oroScuro = Color(0xFFC09A33);
  static const Color _oroOmbra = Color(0xFF7E5F17);

  /// Una lingua di fuoco: parte larga dal basso, si assottiglia e si piega.
  ///
  /// [piega] e' quanto la punta scappa di lato. E' la cosa che distingue una
  /// fiamma da un triangolo: nel logo nessuna punta e' dritta, e nessuna e'
  /// piegata come le altre.
  Path _lingua({
    required double cx,
    required double base,
    required double altezza,
    required double larghezza,
    required double piega,
  }) {
    final punta = Offset(cx + piega, base - altezza);
    final mezza = larghezza / 2;

    return Path()
      ..moveTo(cx - mezza, base)
      // Il fianco sinistro sale gonfiandosi e poi rientra verso la punta.
      ..cubicTo(
        cx - mezza * 1.05,
        base - altezza * 0.42,
        punta.dx - larghezza * 0.34,
        base - altezza * 0.66,
        punta.dx,
        punta.dy,
      )
      // Il destro ridiscende piu' teso: e' l'asimmetria che la fa sembrare
      // mossa dall'aria invece che disegnata col compasso.
      ..cubicTo(
        punta.dx + larghezza * 0.20,
        base - altezza * 0.60,
        cx + mezza * 0.92,
        base - altezza * 0.34,
        cx + mezza,
        base,
      )
      ..close();
  }

  /// Le lingue di uno strato: una centrale alta e quattro laterali piu' corte.
  ///
  /// Le altezze e le pieghe sono numeri scelti a mano, non una formula: una
  /// formula le renderebbe regolari, e una fiamma regolare non esiste.
  Path _fiamma(double cx, double base, double altezza, double larghezza) {
    // La corrente d'aria cambia verso girando la teca.
    final vento = _lato * larghezza * 0.10;

    final lingue = <(double, double, double, double)>[
      // (spostamento, altezza, larghezza, piega)
      (-0.34, 0.44, 0.34, -0.10),
      (0.32, 0.52, 0.32, 0.12),
      (-0.16, 0.74, 0.44, -0.06),
      (0.18, 0.82, 0.42, 0.09),
      (0, 1, 0.62, 0.05),
    ];

    final tutte = Path();

    for (final (dx, ha, la, pi) in lingue) {
      tutte.addPath(
        _lingua(
          cx: cx + larghezza * dx,
          base: base,
          altezza: altezza * ha,
          larghezza: larghezza * la,
          piega: larghezza * pi + vento,
        ),
        Offset.zero,
      );
    }

    return tutte;
  }

  /// La sfumatura di una cosa tonda, con la luce che segue la rotazione.
  Shader _volume(Rect area, Color chiaro, Color scuro) {
    final centro = (0.34 + _fronte * 0.22).clamp(0.10, 0.86);

    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [scuro, chiaro, chiaro, scuro],
      stops: [
        0,
        (centro - 0.10).clamp(0.02, 0.9),
        (centro + 0.16).clamp(0.05, 0.95),
        1,
      ],
    ).createShader(area);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // La fiamma sta sopra, la base sotto. Il piede cade al 91% dell'altezza:
    // e' la misura che la teca si aspetta per appoggiarla sul ripiano.
    final base = h * 0.80;
    final altezza = h * 0.74;
    final larghezza = w * 0.86;

    _ombraATerra(canvas, w, h);

    // **Tre strati, uno dentro l'altro.** Il piu' grande e' il rosso cupo del
    // contorno; dentro l'arancione; al centro il cuore chiaro. Ognuno e' piu'
    // corto e piu' stretto del precedente, cosi' i bordi restano tutti
    // visibili — ed e' quello che da' profondita' a una cosa piatta.
    final strati = <(double, double, Color, Color)>[
      (1, 1, _rosso, bordo),
      (0.76, 0.70, _arancio, _rosso),
      (0.46, 0.40, _cuore, _arancio),
    ];

    for (final (ha, la, chiaro, scuro) in strati) {
      final sagoma = _fiamma(cx, base, altezza * ha, larghezza * la);

      canvas.drawPath(
        sagoma,
        Paint()..shader = _volume(sagoma.getBounds(), chiaro, scuro),
      );
    }

    _base(canvas, w, h);
  }

  /// L'ombra sotto, appena accennata: senza, la fiamma galleggia dentro la
  /// teca invece di appoggiarsi al ripiano.
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
        Paint()
          ..shader = _volume(area, _oroChiaro, _oroOmbra)
          ..blendMode = BlendMode.srcOver,
      );

      // Il filo di luce sullo spigolo di sopra: un metallo senza spigolo
      // illuminato e' un rettangolo giallo.
      canvas.drawLine(
        area.topLeft + const Offset(2, 0.6),
        area.topRight - const Offset(2, -0.6),
        Paint()
          ..color = _oroMedio.withValues(alpha: 0.9)
          ..strokeWidth = 1.1,
      );
    }

    // Una riga scura sotto lo zoccolo: e' il suo spessore visto di taglio.
    canvas.drawLine(
      Offset(cx - w * 0.27, h * 0.918),
      Offset(cx + w * 0.27, h * 0.918),
      Paint()
        ..color = _oroScuro
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(FlamePainter oldDelegate) => oldDelegate.angolo != angolo;
}
