import 'dart:math' as math;

import 'package:crasy/core/theme/seasons/season_skin.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget? segnoDApertura({required double misura, required Color colore}) {
    // Come la ragnatela: un segno di fili ha bisogno di piu' spazio di una
    // macchia piena per pesare uguale.
    final lato = misura * 2.0;

    return SizedBox(
      width: lato,
      height: lato,
      child: CustomPaint(painter: _Fiocco(colore: colore)),
    );
  }

  @override
  Widget? segnoDAttesa({required double misura, required Color colore}) {
    return SizedBox(
      width: misura,
      height: misura,
      child: CustomPaint(painter: _Fiocco(colore: colore)),
    );
  }

  @override
  Widget decora(BuildContext context, Widget pagina) {
    return Stack(
      children: [
        pagina,
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _NeveSulBordo())),
        ),
      ],
    );
  }
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
