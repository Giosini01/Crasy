import 'dart:math' as math;

import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/seasons/season_skin.dart';
import 'package:flutter/material.dart';

/// **Halloween: ragnatele, ragni e zucche.**
///
/// ## Il rosso non si tocca
///
/// La tentazione era l'arancione zucca. Non si fa, e non e' per gusto: in CRASY
/// il rosso dice tre cose e solo quelle — quanto si vince, cosa toccare, cosa
/// e' attivo. Diventando arancione per due settimane quel significato non si
/// sposta: si rompe, perche' chi ha imparato a cercare il rosso lo cerca ancora
/// e non lo trova. E poi rosso, nero e bianco **sono gia'** i colori di
/// Halloween — l'arancione, qui, sarebbe il quarto colore di una palette che ne
/// ha tre.
///
/// Halloween lo portano i segni. Il colore resta quello del marchio.
///
/// ## Perche' le ragnatele stanno negli angoli
///
/// Una ragnatela non si mette in mezzo a una schermata: si mette dove le
/// ragnatele stanno davvero, nell'angolo in alto dove non passa nessuno. Che e'
/// anche l'unico posto dove non copre niente — le foto delle challenge stanno al
/// centro, e un velo decorativo sopra una foto e' una foto sporca.
///
/// Sono al 7% di nero: si vedono guardandole e spariscono leggendo. Una
/// ragnatela che si nota piu' del titolo della pagina ha smesso di essere un
/// dettaglio di stagione ed e' diventata un difetto.
class HalloweenSkin extends SeasonSkin {
  const HalloweenSkin();

  /// **L'apertura: solo la fiamma.**
  ///
  /// C'e' stata una tela dietro, centrata. Si e' tolta: l'apertura e' il
  /// momento in cui l'app dice come si chiama, e lo dice la fiamma da sola.
  /// Halloween comincia appena dentro.
  @override
  Widget accompagnaApertura(
    Widget fiamma, {
    required double misura,
    required Color colore,
  }) => fiamma;

  /// **L'attesa: la fiamma dov'era.**
  ///
  /// Qui non si aggiunge niente attorno, e la ragnatela la porta [giostraDAttesa]
  /// al posto dell'arco che gira: il riquadro e' centoventotto per
  /// centoventotto, e una tela ferma dietro una tela che gira non si leggerebbe
  /// come due cose — si leggerebbe come un pasticcio.
  @override
  Widget accompagnaAttesa(
    Widget fiamma, {
    required double misura,
    required Color colore,
  }) => fiamma;

  /// **Una ragnatela su ogni PARTECIPA, e su uno su tre anche una zucca.**
  ///
  /// La ragnatela sta nell'angolo in alto a sinistra e la zucca in quello a
  /// destra, **fuori dalla parola**: l'etichetta e' centrata, e un disegno al
  /// centro di un tasto rosso con scritto PARTECIPA sopra toglie leggibilita'
  /// all'unica cosa che quel tasto deve dire.
  ///
  /// Bianco al 22%, perche' il tasto e' rosso pieno: il nero sparirebbe e il
  /// bianco pieno diventerebbe un secondo elemento da leggere.
  @override
  Widget decoraTasto(Widget tasto, {required String seme}) {
    final zucca = _sorte(seme) % 3 == 0;

    return Stack(
      children: [
        tasto,
        Positioned.fill(
          // I tocchi passano: il tasto sotto e' l'unica cosa che qui conta.
          // La tela ondeggia piano, come mossa da uno spiffero.
          child: _Vivo(
            periodo: const Duration(milliseconds: 4200),
            fase: _sorte(seme) / 997,
            disegno: (tempo) => _RagnatelaSulTasto(tempo: tempo),
          ),
        ),
        if (zucca)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ZuccaSulTasto(aDestra: true)),
            ),
          ),
      ],
    );
  }

  /// **Una ragnatela nell'angolo della missione, e a volte il suo ragno.**
  ///
  /// In alto a destra, ancorata al vertice del blocco come se continuasse oltre
  /// il bordo. Una missione su due ha anche il ragno appeso al suo filo: tutte
  /// con il ragno sarebbe una fila di ragni uguali, e smetterebbe di far
  /// sobbalzare.
  @override
  Widget decoraMissione(Widget missione, {required String seme}) {
    final ragno = _sorte(seme).isEven;

    return Stack(
      // **La larghezza di chi sta fuori, non quella del testo.** Con quella
      // del testo la tela si attaccherebbe alla fine del titolo, a meta' riga,
      // invece che al bordo della pagina.
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        missione,
        Positioned(
          top: 0,
          right: 0,
          width: 96,
          height: 140,
          // Ogni missione ha il suo tempo: il ragno di una scende mentre
          // quello della successiva risale, e l'elenco non batte all'unisono.
          child: _Vivo(
            periodo: const Duration(milliseconds: 6400),
            fase: _sorte(seme) / 997,
            disegno: (tempo) => _RagnatelaMissione(ragno: ragno, tempo: tempo),
          ),
        ),
      ],
    );
  }

  /// Un numero stabile a partire da una parola.
  ///
  /// `hashCode` di una stringa non e' garantito uguale fra due esecuzioni, e un
  /// segno che cambia tasto riaprendo l'app e' un segno che si nota per il motivo
  /// sbagliato. Questa somma e' poca matematica e sempre la stessa.
  int _sorte(String seme) {
    var somma = 0;

    for (final unita in seme.codeUnits) {
      somma = (somma + unita) % 100003;
    }

    return somma;
  }

  @override
  CustomPainter? giostraDAttesa({
    required double giro,
    required AppPalette palette,
  }) {
    return _TelaCheGira(giro: giro, colore: palette.accent, filo: palette.line);
  }

  @override
  Widget decora(BuildContext context, Widget pagina) {
    return Stack(
      children: [
        pagina,
        // **I tocchi passano attraverso.** Il velo copre tutta la schermata: se
        // ne fermasse uno, per due settimane l'angolo in alto a sinistra di ogni
        // pagina — dove c'e' la freccia indietro — sarebbe morto.
        Positioned.fill(
          child: _Vivo(
            periodo: const Duration(seconds: 9),
            disegno: (tempo) => _RagnatelePagina(tempo: tempo),
          ),
        ),
      ],
    );
  }
}

/// Il filo di una ragnatela: sempre sottile, sempre lo stesso.
Paint _filo(Color colore, double spessore) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = spessore
  ..strokeCap = StrokeCap.round
  ..color = colore;

/// **Il tempo che fa muovere le tele.**
///
/// Un giro che ricomincia all'infinito, e il disegno se lo legge da solo a ogni
/// fotogramma (`repaint`): la pagina sotto non si ricostruisce mai, si ridisegna
/// solo il velo. [fase] sposta l'inizio del giro, cosi' due tele uguali una
/// accanto all'altra non si muovono insieme come soldatini.
///
/// **Con le animazioni ridotte, sta ferma.** Chi le ha spente nelle
/// impostazioni del telefono le ha spente per un motivo, e un ragno che va su
/// e giu' in ogni pagina e' esattamente quel motivo.
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
            fermo ? const AlwaysStoppedAnimation(0.25) : _giro,
          ),
        ),
      ),
    );
  }
}

/// Su e giu', da 0 a 1 e ritorno, senza scatti alle estremita'.
double _saliscendi(double t) => 0.5 - 0.5 * math.cos(2 * math.pi * t);

/// Disegna ruotando di [angolo] attorno a [perno]: e' cosi' che una tela
/// appesa a un angolo ondeggia, imperniata dove e' attaccata.
void _ondeggiando(
  Canvas canvas,
  Offset perno,
  double angolo,
  void Function() disegna,
) {
  canvas
    ..save()
    ..translate(perno.dx, perno.dy)
    ..rotate(angolo)
    ..translate(-perno.dx, -perno.dy);
  disegna();
  canvas.restore();
}

/// Un ragno appeso: il filo da [attacco] lungo [lunghezza], e lui in fondo
/// che dondola appena di lato.
void _ragnoAppeso(
  Canvas canvas,
  Offset attacco,
  double lunghezza,
  double misura,
  double t,
  Color filo,
  Color corpo,
) {
  final dondolo = math.sin(2 * math.pi * t * 3) * misura * 0.35;
  final fondo = attacco + Offset(dondolo, lunghezza);

  canvas.drawLine(attacco, fondo, _filo(filo, 1));
  _Ragno(
    colore: corpo,
  ).disegna(canvas, fondo + Offset(0, misura * 0.85), misura);
}

/// I cerchi concentrici di una tela, che **non sono cerchi**.
///
/// Sono archi che cedono verso il centro: una tela vera e' tenuta dai raggi, e
/// fra un raggio e l'altro il filo si siede. Disegnata a cerchi perfetti
/// diventa un bersaglio.
void _anelli(
  Canvas canvas,
  Offset centro,
  double raggio,
  List<double> angoli,
  Paint penna, {
  List<double> quote = const [0.3, 0.52, 0.74, 0.95],
}) {
  for (final quota in quote) {
    final r = raggio * quota;

    for (var i = 0; i < angoli.length - 1; i++) {
      final a = angoli[i];
      final b = angoli[i + 1];
      final inizio = centro + Offset(math.cos(a) * r, math.sin(a) * r);
      final fine = centro + Offset(math.cos(b) * r, math.sin(b) * r);

      // Il punto di controllo sta sulla bisettrice, tirato dentro: il filo cede
      // verso il centro di circa un decimo.
      final mezzo = (a + b) / 2;
      final guida =
          centro +
          Offset(math.cos(mezzo) * r * 0.88, math.sin(mezzo) * r * 0.88);

      canvas.drawPath(
        Path()
          ..moveTo(inizio.dx, inizio.dy)
          ..quadraticBezierTo(guida.dx, guida.dy, fine.dx, fine.dy),
        penna,
      );
    }
  }
}

/// La ragnatela nell'angolo in alto a destra di una missione.
///
/// Un quarto di tela con il centro **sul vertice**, piu' scura di quelle della
/// pagina: sta accanto al titolo, e al 7% di nero li' sparirebbe. Con [ragno]
/// dal fondo della tela scende un filo, e in fondo al filo c'e' lui.
class _RagnatelaMissione extends CustomPainter {
  _RagnatelaMissione({required this.ragno, required this.tempo})
    : super(repaint: tempo);

  final bool ragno;
  final Animation<double> tempo;

  /// Nero al 16%: si vede, e non si legge insieme al premio rosso accanto.
  static const _inchiostro = Color(0x290A0A0B);

  @override
  void paint(Canvas canvas, Size size) {
    final t = tempo.value;
    final penna = _filo(_inchiostro, 1.1);
    final angolo = Offset(size.width, 0);
    final raggio = size.width * 0.92;

    const raggi = 5;
    final angoli = [
      for (var i = 0; i <= raggi; i++) math.pi / 2 + i * (math.pi / 2) / raggi,
    ];

    // La tela ondeggia di un paio di gradi, imperniata sull'angolo.
    _ondeggiando(canvas, angolo, 0.04 * math.sin(2 * math.pi * t), () {
      for (final a in angoli) {
        canvas.drawLine(
          angolo,
          angolo + Offset(math.cos(a) * raggio, math.sin(a) * raggio),
          penna,
        );
      }

      _anelli(
        canvas,
        angolo,
        raggio,
        angoli,
        penna,
        quote: const [0.32, 0.6, 0.86],
      );
    });

    if (!ragno) {
      return;
    }

    // **Il ragno scende e risale.** Da appena sotto la tela fino in fondo al
    // riquadro, e su di nuovo: e' il movimento che fa girare l'occhio.
    final attacco = angolo + Offset(-raggio * 0.5, raggio * 0.5);
    final corsa = size.height - 20 - attacco.dy;

    _ragnoAppeso(
      canvas,
      attacco,
      corsa * (0.15 + 0.85 * _saliscendi(t)),
      7,
      t,
      _inchiostro,
      const Color(0x8C0A0A0B),
    );
  }

  @override
  bool shouldRepaint(_RagnatelaMissione altro) =>
      altro.ragno != ragno || altro.tempo != tempo;
}

/// Un ragno, piccolo: due corpi tondi e otto zampe piegate.
class _Ragno extends CustomPainter {
  const _Ragno({required this.colore});

  final Color colore;

  @override
  void paint(Canvas canvas, Size size) {
    disegna(
      canvas,
      Offset(size.width / 2, size.height / 2),
      size.shortestSide * 0.3,
    );
  }

  /// Disegna il ragno attorno a [centro], largo circa [misura].
  ///
  /// Sta fuori da [paint] perche' serve anche alla tela dell'apertura, dove il
  /// ragno non e' il disegno ma una cosa dentro il disegno.
  void disegna(Canvas canvas, Offset centro, double misura) {
    final penna = _filo(colore, math.max(1, misura * 0.13));
    final pieno = Paint()..color = colore;

    // **Le zampe prima del corpo.** Disegnate dopo, i loro attacchi si
    // vedrebbero come otto trattini appoggiati sopra la pancia.
    for (final verso in [-1.0, 1.0]) {
      for (var i = 0; i < 4; i++) {
        // Dall'alto verso il basso: le prime zampe puntano avanti, le ultime
        // indietro. Tutte allo stesso angolo fanno un sole, non un ragno.
        final alto = -0.75 + i * 0.5;
        final ginocchio =
            centro + Offset(verso * misura, alto * misura - misura * 0.5);
        final piede = ginocchio + Offset(verso * misura * 0.75, misura * 0.55);

        canvas.drawPath(
          Path()
            ..moveTo(centro.dx, centro.dy + alto * misura * 0.3)
            ..quadraticBezierTo(ginocchio.dx, ginocchio.dy, piede.dx, piede.dy),
          penna,
        );
      }
    }

    // L'addome, piu' grosso, e la testa sopra.
    canvas.drawOval(
      Rect.fromCenter(
        center: centro + Offset(0, misura * 0.22),
        width: misura * 1.15,
        height: misura * 1.4,
      ),
      pieno,
    );
    canvas.drawCircle(centro - Offset(0, misura * 0.62), misura * 0.42, pieno);
  }

  @override
  bool shouldRepaint(_Ragno altro) => altro.colore != colore;
}

/// La tela che gira attorno al ragno, nell'attesa.
///
/// Prende il posto dell'arco e tiene la sua regola: **non e' un anello intero**.
/// E' un settore di tela — quattro raggi e i fili fra loro — che fa il giro. Un
/// anello completo che ruota sembra fermo, e questo valeva per un arco come vale
/// per una tela.
class _TelaCheGira extends CustomPainter {
  const _TelaCheGira({
    required this.giro,
    required this.colore,
    required this.filo,
  });

  /// Da 0 a 1, un giro completo.
  final double giro;

  final Color colore;

  /// La tela spenta sotto: senza, il settore sembra un pezzo staccato invece di
  /// un pezzo di qualcosa che gira.
  final Color filo;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final raggio = size.width / 2 - 2;

    final spenta = _filo(filo, 1.6);
    const raggi = 10;
    final tutti = [for (var i = 0; i <= raggi; i++) i * 2 * math.pi / raggi];

    for (var i = 0; i < raggi; i++) {
      canvas.drawLine(
        centro,
        centro +
            Offset(math.cos(tutti[i]) * raggio, math.sin(tutti[i]) * raggio),
        spenta,
      );
    }
    _anelli(canvas, centro, raggio, tutti, spenta, quote: const [0.45, 0.8]);

    // Il settore acceso: un quarto di giro, come l'arco che sostituisce.
    final da = giro * 2 * math.pi;
    final accesa = _filo(colore, 2.4);
    const passi = 3;
    final settore = [
      for (var i = 0; i <= passi; i++) da + i * (math.pi / 2) / passi,
    ];

    for (final a in settore) {
      canvas.drawLine(
        centro + Offset(math.cos(a) * raggio * 0.3, math.sin(a) * raggio * 0.3),
        centro + Offset(math.cos(a) * raggio, math.sin(a) * raggio),
        accesa,
      );
    }
    _anelli(canvas, centro, raggio, settore, accesa, quote: const [0.45, 0.8]);
  }

  @override
  bool shouldRepaint(_TelaCheGira altro) => altro.giro != giro;
}

/// Il bianco con cui si disegna sopra un tasto rosso pieno.
///
/// Al 22%: si vede inclinando lo sguardo e non si legge insieme all'etichetta.
/// Un bianco pieno qui diventerebbe una seconda cosa scritta sul tasto, e un
/// tasto con due cose scritte sopra e' un tasto che si legge due volte.
const _sulRosso = Color(0x38FFFFFF);

/// Un quarto di ragnatela nell'angolo in alto a sinistra di un tasto.
class _RagnatelaSulTasto extends CustomPainter {
  _RagnatelaSulTasto({required this.tempo}) : super(repaint: tempo);

  final Animation<double> tempo;

  @override
  void paint(Canvas canvas, Size size) {
    _ondeggiando(
      canvas,
      Offset.zero,
      0.06 * math.sin(2 * math.pi * tempo.value),
      () => _tela(canvas, size),
    );
  }

  void _tela(Canvas canvas, Size size) {
    final penna = _filo(_sulRosso, 1.1);
    // Il centro sul vertice del tasto: la tela entra dall'angolo come se
    // continuasse oltre il bordo, invece di stare appoggiata dentro.
    const angolo = Offset.zero;
    final raggio = size.height * 0.72;

    const raggi = 5;
    final angoli = [for (var i = 0; i <= raggi; i++) i * (math.pi / 2) / raggi];

    for (final a in angoli) {
      canvas.drawLine(
        angolo,
        angolo + Offset(math.cos(a) * raggio, math.sin(a) * raggio),
        penna,
      );
    }

    _anelli(
      canvas,
      angolo,
      raggio,
      angoli,
      penna,
      quote: const [0.42, 0.72, 0.98],
    );
  }

  @override
  bool shouldRepaint(_RagnatelaSulTasto altro) => altro.tempo != tempo;
}

/// Una zucca piccola sul bordo di un tasto, a sinistra o a destra.
///
/// **A costine, non una palla con il gambo.** Una zucca si riconosce dai solchi
/// verticali: il cerchio con il rametto sopra, a quattordici pixel, si legge come
/// una mela — e una mela su un tasto non dice niente a nessuno.
class _ZuccaSulTasto extends CustomPainter {
  _ZuccaSulTasto({this.aDestra = false});

  /// Dal lato opposto alla ragnatela, quando sul tasto ci sono tutte e due.
  final bool aDestra;

  @override
  void paint(Canvas canvas, Size size) {
    final alta = size.height * 0.42;
    final larga = alta * 1.22;
    final centro = Offset(
      aDestra ? size.width - larga * 0.78 : larga * 0.78,
      size.height * 0.5,
    );
    final penna = _filo(_sulRosso, 1.3);

    // Il corpo: piu' largo che alto, com'e' una zucca vera.
    canvas.drawOval(
      Rect.fromCenter(center: centro, width: larga, height: alta),
      penna,
    );

    // Le due costine interne. Sono archi, non rette: un solco diritto fa
    // sembrare la zucca un barile.
    for (final verso in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(centro.dx + verso * larga * 0.1, centro.dy - alta / 2 + 1)
          ..quadraticBezierTo(
            centro.dx + verso * larga * 0.34,
            centro.dy,
            centro.dx + verso * larga * 0.1,
            centro.dy + alta / 2 - 1,
          ),
        penna,
      );
    }

    // Il gambo, corto e piegato da una parte: diritto sembra un chiodo.
    canvas.drawPath(
      Path()
        ..moveTo(centro.dx, centro.dy - alta / 2)
        ..quadraticBezierTo(
          centro.dx + larga * 0.06,
          centro.dy - alta * 0.72,
          centro.dx + larga * 0.16,
          centro.dy - alta * 0.68,
        ),
      penna,
    );
  }

  @override
  bool shouldRepaint(_ZuccaSulTasto altro) => altro.aDestra != aDestra;
}

/// Le due ragnatele d'angolo che stanno su ogni pagina.
///
/// Un quarto di tela ancorato all'angolo, come se il muro continuasse fuori
/// dallo schermo. A destra e' piu' piccola: due tele identiche e simmetriche si
/// leggono come una cornice, e una cornice e' un elemento dell'interfaccia.
class _RagnatelePagina extends CustomPainter {
  _RagnatelePagina({required this.tempo}) : super(repaint: tempo);

  final Animation<double> tempo;

  /// Nero al 7%. **Non il rosso**: il rosso qui significa "tocca" e "si vince",
  /// e una ragnatela rossa negli angoli lo direbbe a vuoto su ogni schermata.
  static const _inchiostro = Color(0x120A0A0B);

  @override
  void paint(Canvas canvas, Size size) {
    final t = tempo.value;
    final penna = _filo(_inchiostro, 1.1);
    final lato = size.shortestSide;
    final destra = Offset(size.width, 0);

    // Le due tele ondeggiano ognuna per conto suo: la piccola piu' svelta e
    // in controtempo, come due tele mosse dalla stessa corrente d'aria.
    _ondeggiando(canvas, Offset.zero, 0.03 * math.sin(2 * math.pi * t), () {
      _quarto(canvas, Offset.zero, lato * 0.34, 0, penna);
    });
    _ondeggiando(
      canvas,
      destra,
      -0.045 * math.sin(2 * math.pi * (t * 2 + 0.3)),
      () => _quarto(canvas, destra, lato * 0.22, math.pi / 2, penna),
    );

    // **Due ragni che fanno su e giu'**, uno per tela e mai insieme: quello
    // grande scende lento fin sotto la barra in alto, quello piccolo fa due
    // corse brevi nello stesso tempo.
    _ragnoAppeso(
      canvas,
      Offset(lato * 0.2, lato * 0.24),
      lato * (0.04 + 0.26 * _saliscendi(t)),
      6,
      t,
      _inchiostro,
      const Color(0x400A0A0B),
    );
    _ragnoAppeso(
      canvas,
      Offset(size.width - lato * 0.12, lato * 0.15),
      lato * (0.02 + 0.12 * _saliscendi(t * 2 + 0.5)),
      4.5,
      t + 0.37,
      _inchiostro,
      const Color(0x380A0A0B),
    );
  }

  /// Un quarto di tela con il centro **sul vertice** dello schermo.
  ///
  /// Cosi' i raggi entrano dal nulla e la tela sembra tagliata dal bordo, invece
  /// che appoggiata dentro la pagina.
  void _quarto(
    Canvas canvas,
    Offset angolo,
    double raggio,
    double da,
    Paint penna,
  ) {
    const raggi = 6;
    final angoli = [
      for (var i = 0; i <= raggi; i++) da + i * (math.pi / 2) / raggi,
    ];

    for (final a in angoli) {
      canvas.drawLine(
        angolo,
        angolo + Offset(math.cos(a) * raggio, math.sin(a) * raggio),
        penna,
      );
    }

    _anelli(canvas, angolo, raggio, angoli, penna);
  }

  @override
  bool shouldRepaint(_RagnatelePagina altro) => altro.tempo != tempo;
}
