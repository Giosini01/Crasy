import 'dart:math' as math;

import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/seasons/season_skin.dart';
import 'package:flutter/material.dart';

/// **Halloween: due ragnatele e un ragno.**
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

  /// **L'apertura: la fiamma al centro della tela.**
  ///
  /// La fiamma resta quella che e' sempre stata, intera e in primo piano: e' il
  /// marchio, e per un mese non si mette da parte. La ragnatela le si apre
  /// **dietro, centrata**, e la fiamma finisce dove in una tela sta il ragno.
  ///
  /// ## Il mozzo non e' disegnato, perche' il mozzo e' lei
  ///
  /// Prima la tela stava di fianco, spostata in diagonale, e il motivo era che una
  /// ragnatela intera dietro una fiamma e' una fiamma spezzata in dodici pezzi: i
  /// raggi convergono tutti dove c'e' lei e le passano sopra.
  ///
  /// Il problema era il mozzo, non la posizione. Qui i raggi **cominciano oltre**
  /// la fiamma e il centro resta vuoto: la tela e' centrata e nessun filo la
  /// taglia. Ed e' anche piu' vero di una tela completa — in una ragnatela vera il
  /// centro e' il buco in cui sta chi l'ha tessuta, non un nodo di fili.
  ///
  /// La tela e' tenuta piu' tenue della fiamma. Allo stesso peso si guarderebbe
  /// lei: e' larga il doppio, e fra due segni vince sempre il piu' grande.
  @override
  Widget accompagnaApertura(
    Widget fiamma, {
    required double misura,
    required Color colore,
  }) {
    final lato = misura * 2.4;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: lato,
          height: lato,
          child: CustomPaint(
            painter: _RagnatelaPiena(
              colore: colore.withValues(alpha: 0.28),
              // Il buco in cui sta la fiamma. Poco piu' di meta' del raggio: la
              // fiamma e' alta quanto [misura] e il raggio e' circa `misura`,
              // quindi sotto il mezzo i raggi le toccherebbero le punte.
              vuoto: 0.58,
            ),
          ),
        ),
        fiamma,
      ],
    );
  }

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

  /// **Un segno su qualche tasto, non su tutti.**
  ///
  /// Uno su tre ha qualcosa addosso, e meta' di quelli e' una zucca invece di una
  /// ragnatela: a tre gare per schermata ne capita in media una, che e' la
  /// quantita' giusta perche' sembri che ottobre sia passato di qui e non che
  /// qualcuno abbia aggiunto un elemento grafico al bottone.
  ///
  /// Il segno sta nell'angolo in alto a sinistra, **fuori dalla parola**:
  /// l'etichetta e' centrata, e un disegno al centro di un tasto rosso con
  /// scritto PARTECIPA sopra e' un disegno che toglie leggibilita' all'unica
  /// cosa che quel tasto deve dire.
  ///
  /// Bianco al 22%, perche' il tasto e' rosso pieno: il nero sparirebbe e il
  /// bianco pieno diventerebbe un secondo elemento da leggere.
  @override
  Widget decoraTasto(Widget tasto, {required String seme}) {
    final sorte = _sorte(seme);

    if (sorte % 3 != 0) {
      return tasto;
    }

    return Stack(
      children: [
        tasto,
        Positioned.fill(
          // I tocchi passano: il tasto sotto e' l'unica cosa che qui conta.
          child: IgnorePointer(
            child: CustomPaint(
              painter: sorte % 6 == 0 ? _ZuccaSulTasto() : _RagnatelaSulTasto(),
            ),
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
          child: IgnorePointer(child: CustomPaint(painter: _RagnatelePagina())),
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

/// La tela intera della schermata d'apertura, con il ragno appeso.
class _RagnatelaPiena extends CustomPainter {
  const _RagnatelaPiena({required this.colore, this.vuoto = 0});

  final Color colore;

  /// Quanta parte del raggio, dal centro in fuori, resta **senza fili**.
  ///
  /// A zero la tela e' intera e ha il suo mozzo. Sopra zero il mozzo non si
  /// disegna: i raggi cominciano da qui, e quel buco e' il posto di quello che la
  /// tela ha dentro — la fiamma, nell'apertura.
  final double vuoto;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final raggio = size.width / 2 * 0.86;
    final penna = _filo(colore, size.width * 0.009);

    // Dodici raggi. Con meno la tela sembra uno spartito, con molti di piu'
    // diventa un disco pieno alla misura a cui si guarda qui.
    const raggi = 12;
    final angoli = [
      for (var i = 0; i <= raggi; i++) -math.pi / 2 + i * 2 * math.pi / raggi,
    ];

    final dentro = vuoto.clamp(0.0, 0.9);

    for (var i = 0; i < raggi; i++) {
      final a = angoli[i];
      final direzione = Offset(math.cos(a), math.sin(a));

      canvas.drawLine(
        centro + direzione * raggio * dentro,
        centro + direzione * raggio,
        penna,
      );
    }

    // Gli anelli si distribuiscono in quello che resta fuori dal buco: con il
    // mozzo vuoto, le quote fisse della tela intera finirebbero tre su quattro
    // dentro il buco e ne resterebbe uno.
    _anelli(
      canvas,
      centro,
      raggio,
      angoli,
      penna,
      quote: [
        for (final passo in const [0.0, 0.3, 0.62, 1.0])
          dentro + (1 - dentro) * (0.04 + passo * 0.92),
      ],
    );

    // **Il filo che scende e il ragno in fondo.** Senza di lui la tela e' un
    // ornamento geometrico; con lui c'e' qualcuno dentro, ed e' tutta la
    // differenza fra un disegno e una scena.
    //
    // Attaccato **fuori dal buco**: appeso al mozzo starebbe addosso alla fiamma,
    // e il ragno sotto la fiamma si legge come una macchia nera sul marchio.
    final su = math.max(dentro, 0.45);
    final attacco = centro + Offset(raggio * su * 0.72, raggio * su * 0.62);
    final appeso = attacco + Offset(0, raggio * 0.3);
    canvas.drawLine(attacco, appeso, penna);

    _Ragno(colore: colore).disegna(
      canvas,
      appeso + Offset(0, size.width * 0.045),
      size.width * 0.07,
    );
  }

  @override
  bool shouldRepaint(_RagnatelaPiena altro) =>
      altro.colore != colore || altro.vuoto != vuoto;
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
  _RagnatelaSulTasto();

  @override
  void paint(Canvas canvas, Size size) {
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
  bool shouldRepaint(_RagnatelaSulTasto altro) => false;
}

/// Una zucca piccola nell'angolo in alto a sinistra di un tasto.
///
/// **A costine, non una palla con il gambo.** Una zucca si riconosce dai solchi
/// verticali: il cerchio con il rametto sopra, a quattordici pixel, si legge come
/// una mela — e una mela su un tasto non dice niente a nessuno.
class _ZuccaSulTasto extends CustomPainter {
  _ZuccaSulTasto();

  @override
  void paint(Canvas canvas, Size size) {
    final alta = size.height * 0.42;
    final larga = alta * 1.22;
    final centro = Offset(larga * 0.78, size.height * 0.5);
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
  bool shouldRepaint(_ZuccaSulTasto altro) => false;
}

/// Le due ragnatele d'angolo che stanno su ogni pagina.
///
/// Un quarto di tela ancorato all'angolo, come se il muro continuasse fuori
/// dallo schermo. A destra e' piu' piccola: due tele identiche e simmetriche si
/// leggono come una cornice, e una cornice e' un elemento dell'interfaccia.
class _RagnatelePagina extends CustomPainter {
  _RagnatelePagina();

  /// Nero al 7%. **Non il rosso**: il rosso qui significa "tocca" e "si vince",
  /// e una ragnatela rossa negli angoli lo direbbe a vuoto su ogni schermata.
  static const _inchiostro = Color(0x120A0A0B);

  @override
  void paint(Canvas canvas, Size size) {
    final penna = _filo(_inchiostro, 1.1);
    final lato = size.shortestSide;

    _quarto(canvas, Offset.zero, lato * 0.34, 0, penna);
    _quarto(canvas, Offset(size.width, 0), lato * 0.22, math.pi / 2, penna);
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
  bool shouldRepaint(_RagnatelePagina altro) => false;
}
