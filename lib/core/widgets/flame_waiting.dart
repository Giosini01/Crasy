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
                  child: context.stagione.accompagnaAttesa(
                    Icon(
                      Icons.local_fire_department,
                      size: 30,
                      color: palette.accent,
                    ),
                    misura: 30,
                    colore: palette.accent,
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

/// **Il velo di attesa, sopra tutto lo schermo.**
///
/// ## Il difetto che questo widget esiste per togliere
///
/// [FlameWaiting] veniva messo dentro la schermata — un `Positioned.fill`
/// nello `Stack` del corpo — e copriva **soltanto il corpo**. Sopra restavano
/// scoperti la barra in cima con la freccia indietro, la barra delle schede in
/// fondo, e su una gara il tasto PARTECIPA che vive fuori dal corpo: chiari,
/// toccabili, come se non stesse succedendo niente. Durante un caricamento
/// lungo — un video dalla galleria, un pagamento — quei tasti si toccano, e
/// ognuno fa partire una seconda volta una cosa che e' gia' in corso.
///
/// Un velo che copre tre quarti di schermo e' peggio di nessun velo: dice che
/// l'app sta lavorando **e** lascia credere che si possa fare altro.
///
/// ## Come fa a stare sopra la barra in cima
///
/// Si mette nel sipario piu' esterno dell'app, quello sopra al quale non c'e'
/// piu' niente, invece che dentro la schermata. Da li' copre tutto: le barre,
/// le schede, i fogli aperti.
///
/// Si usa come prima — `if (occupato) const VeloDiAttesa()` — e il widget non
/// occupa spazio dove lo si scrive: quello che si vede lo disegna il sipario.
///
/// ## Perche' il tasto indietro resta bloccato da qui
///
/// Il blocco deve stare **dentro la schermata**, non nel sipario: il tasto
/// indietro lo intercetta chi conosce la propria pagina, e il sipario non sta
/// dentro nessuna pagina. Percio' qui resta la sola cosa che occupa il posto in
/// cui lo si scrive: il divieto di tornare indietro. Senza, si esce con il
/// gesto laterale e il caricamento va avanti su una schermata che non c'e'
/// piu'.
class VeloDiAttesa extends StatefulWidget {
  const VeloDiAttesa({super.key});

  @override
  State<VeloDiAttesa> createState() => _VeloDiAttesaState();
}

class _VeloDiAttesaState extends State<VeloDiAttesa> {
  OverlayEntry? _velo;

  @override
  void initState() {
    super.initState();

    // **Dopo il fotogramma, non durante.** Infilare qualcosa nel sipario
    // mentre lo schermo si sta costruendo vuol dire chiedere un ridisegno a
    // ridisegno in corso, che e' l'errore "markNeedsBuild durante build".
    WidgetsBinding.instance.addPostFrameCallback((_) => _apri());
  }

  void _apri() {
    if (!mounted || _velo != null) {
      return;
    }

    final sipario = Overlay.maybeOf(context, rootOverlay: true);

    if (sipario == null) {
      return;
    }

    _velo = OverlayEntry(
      // **Assorbe i tocchi, tutti.** E' la meta' che conta: oscurare senza
      // fermare le dita lascia che si tocchi PARTECIPA attraverso il velo, e
      // chi aspetta lo tocca — proprio perche' non vede che e' cambiato
      // qualcosa.
      builder: (_) => const AbsorbPointer(child: FlameWaiting()),
    );

    sipario.insert(_velo!);
  }

  @override
  void dispose() {
    _velo?.remove();
    _velo = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Niente a schermo: il velo lo disegna il sipario. Qui resta il divieto di
    // tornare indietro, che per funzionare deve stare dentro la pagina.
    return const PopScope(canPop: false, child: SizedBox.shrink());
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
