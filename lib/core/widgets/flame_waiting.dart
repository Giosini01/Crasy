import 'dart:math' as math;

import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/seasons/season_skin.dart';
import 'package:flutter/material.dart';

/// **L'attesa fra il tocco e il foglio di Stripe.**
///
/// Prima, in quei secondi, restava scritto a che punto era: *chiedo il
/// pagamento…*, *preparo il foglio…*. Serviva a noi — diceva dove si era
/// fermato quando si fermava — e a chi usa l'app diceva una cosa che non
/// voleva sapere, con le parole di chi ha scritto il programma. Chi sta
/// pagando non vuole seguire i passi: vuole sapere che sta succedendo
/// qualcosa.
///
/// Qui c'e' un quadrato con dentro la fiamma e un cerchio che le gira intorno.
/// Non dice niente, e va bene cosi': copre lo schermo, quindi dice gia' che
/// l'app sta lavorando e che non c'e' altro da toccare.
///
/// **I passi non sono spariti.** Continuano ad arrivare e finiscono nei log:
/// il giorno in cui qualcuno scrive "si blocca e non si apre niente", quella
/// riga c'e' ancora. Non la si fa piu' leggere a chi aspetta.
class FlameWaiting extends StatefulWidget {
  const FlameWaiting({super.key});

  @override
  State<FlameWaiting> createState() => _FlameWaitingState();
}

class _FlameWaitingState extends State<FlameWaiting>
    with SingleTickerProviderStateMixin {
  late final AnimationController _giro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // **Niente passa di qui finche' non ha finito.**
    //
    // Il velo fermava i tocchi, non il resto: la freccia indietro, il gesto di
    // scorrimento dal bordo e il tasto di sistema su Android portavano via la
    // schermata mentre il caricamento era a meta'. Da fuori sembra di aver
    // annullato; dentro, il caricamento va avanti e finisce su una schermata
    // che non c'e' piu'. Si resta qui finche' non e' finito.
    return PopScope(canPop: false, child: _riquadro(context));
  }

  Widget _riquadro(BuildContext context) {
    final palette = context.palette;

    return ColoredBox(
      // Il velo scuro non e' decorazione: e' quello che toglie i tasti da
      // sotto le dita. Senza, chi aspetta ritocca "paga" e si ritrova con due
      // pagamenti aperti.
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: SizedBox(
              width: 64,
              height: 64,
              child: AnimatedBuilder(
                animation: _giro,
                builder: (context, fiamma) {
                  return CustomPaint(
                    // Di stagione gira una tela di ragno invece dell'arco. La
                    // regola di sotto resta la sua: non un anello intero.
                    painter:
                        context.stagione.giostraDAttesa(
                          giro: _giro.value,
                          palette: palette,
                        ) ??
                        _Cerchio(
                          giro: _giro.value,
                          colore: palette.accent,
                          scia: palette.line,
                        ),
                    child: fiamma,
                  );
                },
                // La fiamma sta ferma al centro e **non gira con il cerchio**:
                // una fiamma che ruota si legge come una fiamma capovolta, e
                // il segno che dice CRASY non va capovolto per fare
                // un'animazione.
                child: Center(
                  child:
                      context.stagione.segnoDAttesa(
                        misura: 30,
                        colore: palette.accent,
                      ) ??
                      Icon(
                        Icons.local_fire_department,
                        size: 30,
                        color: palette.accent,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Il cerchio che gira intorno alla fiamma.
///
/// E' un arco corto, non un anello intero: un anello pieno che ruota sembra
/// fermo — non c'e' niente che si veda spostare. L'arco ha due estremi, e
/// sono quelli a dire che gira.
class _Cerchio extends CustomPainter {
  const _Cerchio({
    required this.giro,
    required this.colore,
    required this.scia,
  });

  /// Da 0 a 1, un giro completo.
  final double giro;

  final Color colore;

  /// Il cerchio appena accennato sotto l'arco: senza, l'arco sembra un
  /// frammento rotto invece che un pezzo di qualcosa che gira.
  final Color scia;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final raggio = size.width / 2 - 2;

    canvas.drawCircle(
      centro,
      raggio,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = scia,
    );

    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: raggio),
      giro * 2 * math.pi,
      // Un quarto di giro: abbastanza da vedersi, poco da lasciare addosso la
      // sensazione che manchi qualcosa.
      math.pi / 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = colore,
    );
  }

  @override
  bool shouldRepaint(_Cerchio altro) => altro.giro != giro;
}
