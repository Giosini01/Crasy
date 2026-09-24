import 'package:flutter/material.dart';

/// **Il trofeo di chi fa giocare: una fiamma.**
///
/// Era una coppa dentro una teca di vetro, e la coppa e' il trofeo di
/// chiunque: la stessa che si vede in un'app di corse, in una di lingue, nelle
/// impostazioni di un videogioco. Disegnata bene resta una coppa, cioe' un
/// oggetto che non dice **di chi** e' il premio.
///
/// La fiamma invece e' di CRASY da prima di questo file. E' il marchio, ed e'
/// il voto: ogni foto in gara si misura in fiamme. Darla come trofeo a chi ha
/// messo i soldi chiude un cerchio — **ha pagato perche' altri se le
/// prendessero**, e adesso ne tiene una sua.
///
/// **Ferma, non animata.** Una fiamma che tremola e' un fuoco; una ferma e' un
/// oggetto, e questo e' un trofeo. Su una bacheca di venti caselle, poi, venti
/// fiamme che ballano sono una discoteca.
class FlameTrophy extends StatelessWidget {
  const FlameTrophy({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: FlamePainter(), size: Size.infinite);
  }
}

/// La fiamma, disegnata a mano e non presa da un carattere.
///
/// **Non e' un'emoji, e la differenza si vede.** Un'emoji la disegna il sistema
/// operativo: cambia su ogni telefono, e su ognuno somiglia a quella di
/// qualunque altra app. Questa e' la stessa su tutti, ed e' nostra.
class FlamePainter extends CustomPainter {
  /// **Quattro strati, dal piu' scuro al piu' chiaro.**
  ///
  /// E' il modo in cui brucia una cosa davvero: fuori il rosso profondo, dove
  /// il calore si disperde; dentro l'arancione; poi il giallo; e al centro il
  /// bianco, la parte piu' calda. Un fuoco di un colore solo e' una sagoma
  /// colorata — sono i bordi fra uno strato e l'altro a darle volume.
  ///
  /// E in fondo un soffio di viola: e' il colore che le fiamme vere hanno alla
  /// base, dove il gas non ha ancora preso. Non se ne accorge nessuno, e senza
  /// la fiamma sembra un adesivo.
  static const viola = Color(0xFF7C3AED);
  static const rosso = Color(0xFFE11D48);
  static const arancio = Color(0xFFFB923C);
  static const giallo = Color(0xFFFDE047);
  static const bianco = Color(0xFFFFFBEB);

  static const _oroAlto = Color(0xFFFFE9A3);
  static const _oroCorpo = Color(0xFFD9A62A);
  static const _oroScuro = Color(0xFF8C6D1F);

  /// La sagoma di una fiamma, con la punta in alto e la pancia in basso.
  ///
  /// Non e' un triangolo con la punta arrotondata: una fiamma **si piega**. Il
  /// fianco sinistro sale piu' ripido e la punta scappa un po' a destra, come
  /// se ci fosse una corrente d'aria — ed e' quella storia storta a farla
  /// sembrare viva invece che disegnata col righello.
  Path _fiamma(double cx, double cima, double base, double larghezza) {
    final altezza = base - cima;
    final mezza = larghezza / 2;
    final percorso = Path()..moveTo(cx + larghezza * 0.06, cima);

    // Il fianco destro: scende gonfiandosi, poi rientra sotto.
    percorso
      ..cubicTo(
        cx + mezza * 0.95,
        cima + altezza * 0.30,
        cx + mezza,
        cima + altezza * 0.62,
        cx + mezza * 0.72,
        cima + altezza * 0.84,
      )
      ..cubicTo(
        cx + mezza * 0.48,
        base,
        cx - mezza * 0.48,
        base,
        cx - mezza * 0.72,
        cima + altezza * 0.84,
      )
      // Il fianco sinistro, piu' ripido: e' la piega.
      ..cubicTo(
        cx - mezza,
        cima + altezza * 0.60,
        cx - mezza * 0.78,
        cima + altezza * 0.26,
        cx - larghezza * 0.10,
        cima + altezza * 0.10,
      )
      ..cubicTo(
        cx - larghezza * 0.02,
        cima + altezza * 0.05,
        cx + larghezza * 0.02,
        cima + altezza * 0.02,
        cx + larghezza * 0.06,
        cima,
      )
      ..close();

    return percorso;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // La fiamma occupa i tre quarti di sopra; sotto c'e' il piedistallo.
    final base = h * 0.80;
    final larghezza = w * 0.62;

    // **L'ombra a terra.** Senza, la fiamma galleggia: e' la macchia scura a
    // dire che sotto c'e' un ripiano.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.945),
        width: w * 0.52,
        height: h * 0.05,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // **L'alone caldo.** Una fiamma illumina cio' che ha attorno, e questo velo
    // rosso e' l'unica cosa che lo racconta su una pagina bianca.
    canvas.drawCircle(
      Offset(cx, h * 0.46),
      w * 0.46,
      Paint()
        ..shader =
            RadialGradient(
              colors: [rosso.withValues(alpha: 0.22), rosso.withValues(alpha: 0)],
            ).createShader(
              Rect.fromCircle(center: Offset(cx, h * 0.46), radius: w * 0.46),
            ),
    );

    // I quattro strati, uno dentro l'altro: ognuno parte piu' in basso e
    // finisce piu' in alto, cosi' i bordi restano visibili tutti.
    const strati = <(double, double, double)>[
      (0.10, 1, 1),
      (0.20, 0.86, 0.80),
      (0.34, 0.66, 0.58),
      (0.52, 0.40, 0.32),
    ];

    const coppie = <(Color, Color)>[
      (rosso, viola),
      (arancio, rosso),
      (giallo, arancio),
      (bianco, giallo),
    ];

    for (var i = 0; i < strati.length; i++) {
      final (cimaRel, altezzaRel, largRel) = strati[i];
      final (sopra, sotto) = coppie[i];
      final cima = h * cimaRel;
      final sagoma = _fiamma(
        cx,
        cima,
        cima + (base - h * 0.10) * altezzaRel,
        larghezza * largRel,
      );

      canvas.drawPath(
        sagoma,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [sopra, sotto],
          ).createShader(sagoma.getBounds()),
      );
    }

    // **Il riflesso.** Una macchia chiarissima sul fianco sinistro, dove
    // batterebbe la luce: e' quella che fa sembrare la fiamma bombata invece
    // che piatta.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - larghezza * 0.16, h * 0.42),
        width: larghezza * 0.16,
        height: h * 0.20,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    _piedistallo(canvas, size);
  }

  /// Il basamento: due lastre d'oro, una sopra l'altra.
  ///
  /// **Serve a renderla un trofeo invece che un'icona.** Una fiamma da sola e'
  /// un simbolo; una fiamma che poggia su una base e' un oggetto che qualcuno
  /// ha vinto e ha messo su una mensola.
  void _piedistallo(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final collo = Rect.fromCenter(
      center: Offset(cx, h * 0.815),
      width: w * 0.30,
      height: h * 0.045,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(collo, const Radius.circular(4)),
      Paint()
        ..shader = const LinearGradient(
          colors: [_oroAlto, _oroCorpo, _oroScuro],
          stops: [0, 0.45, 1],
        ).createShader(collo),
    );

    final zoccolo = Rect.fromCenter(
      center: Offset(cx, h * 0.885),
      width: w * 0.46,
      height: h * 0.07,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(zoccolo, const Radius.circular(5)),
      Paint()
        ..shader = const LinearGradient(
          colors: [_oroAlto, _oroCorpo, _oroScuro],
          stops: [0, 0.4, 1],
        ).createShader(zoccolo),
    );

    // Il filo di luce sullo spigolo di sopra: un metallo senza spigolo
    // illuminato e' un rettangolo giallo.
    canvas.drawLine(
      Offset(cx - w * 0.21, h * 0.853),
      Offset(cx + w * 0.21, h * 0.853),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(FlamePainter oldDelegate) => false;
}
