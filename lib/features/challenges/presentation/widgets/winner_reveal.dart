import 'dart:math' as math;

import 'package:crasy/core/theme/app_colors.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Come si scopre chi ha vinto.
///
/// **Prima non si scopriva: si leggeva.** La gara finiva, e chi tornava
/// sull'app trovava una classifica gia' ordinata con il vincitore in cima —
/// un'informazione, come il saldo di un conto. Eppure quello e' l'unico momento
/// in cui CRASY ha davvero qualcosa da dire: ci sono dei soldi veri, c'e' una
/// persona che ha vinto, e fino a un istante prima non lo sapeva nessuno.
///
/// ## Come e' fatto
///
/// Cinque secondi in tutto, e non uno di piu': oltre, un'animazione che non si
/// puo' toccare smette di essere un momento e diventa un ostacolo fra una
/// persona e la cosa che era venuta a vedere.
///
///  - **il rullo** (1,8s): schermo nero e **due tamburi**, uno per lato, che
///    battono sempre piu' veloce. Non c'e' nient'altro: nessuna foto, nessuna
///    scritta;
///  - **lo scoppio**: i tamburi spariscono, la foto vincitrice entra di scatto
///    e i coriandoli partono **dai due angoli in basso**;
///  - **il riposo**: sopra la foto la frase, sotto il nome e il premio.
///
/// ## Perche' il rullo non fa vedere niente
///
/// La prima versione faceva scorrere le foto in gara, coperte da un velo, come
/// la ruota di una slot machine. Sembrava una buona idea e non lo era: dava da
/// guardare qualcosa **proprio nei secondi in cui il punto e' non vedere**.
/// Il nero non e' un vuoto da riempire — e' la cosa che rende la foto, quando
/// arriva, una notizia.
///
/// I tamburi disegnati fanno il lavoro che faceva il velo, e lo fanno meglio:
/// dicono "sta per succedere" senza mostrare niente di quello che succedera'.
///
/// **Si salta con un tocco, ovunque.** Chi l'ha gia' vista, chi non ha voglia,
/// chi ha aperto per altro: un'animazione che si deve subire e' una tassa.
class WinnerReveal extends StatefulWidget {
  const WinnerReveal({
    required this.challenge,
    required this.winner,
    required this.mine,
    super.key,
  });

  final Challenge challenge;
  final ChallengeEntry winner;

  /// Se il vincitore sono **io**. Cambia la parola grossa, non il resto.
  final bool mine;

  /// Quanto dura tutto, dal primo colpo di tamburo all'uscita.
  static const durata = Duration(milliseconds: 5000);

  /// Il riquadro dei tamburi, per le prove.
  static const chiaveDeiTamburi = Key('rullo-di-tamburi');

  /// Apre la proclamazione sopra la schermata.
  ///
  /// **Opaca, e non si chiude toccando fuori.** Una proclamazione con lo sfondo
  /// che traspare mostrerebbe la classifica sotto — cioe' la risposta — mentre
  /// il rullo sta ancora facendo finta di non saperla.
  static Future<void> show(
    BuildContext context, {
    required Challenge challenge,
    required ChallengeEntry winner,
    required bool mine,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xFF000000),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animazione, altra) =>
          WinnerReveal(challenge: challenge, winner: winner, mine: mine),
      transitionBuilder: (context, animazione, altra, child) =>
          FadeTransition(opacity: animazione, child: child),
    );
  }

  @override
  State<WinnerReveal> createState() => _WinnerRevealState();
}

class _WinnerRevealState extends State<WinnerReveal>
    with SingleTickerProviderStateMixin {
  /// Quando finiscono i tamburi e comincia lo scoppio, in frazioni del totale.
  static const _scoppio = 0.36;

  /// Quando la foto ha finito di entrare.
  static const _posata = 0.45;

  /// Quanto passa fra un colpo e l'altro: dal primo, lento, all'ultimo.
  ///
  /// **Un rullo di tamburi accelera.** E' il contrario di una slot machine, che
  /// rallenta per far sperare sull'ultima casella: qui non c'e' niente da
  /// leggere, e la tensione si costruisce con la frequenza. Il fondo sta a
  /// novanta millesimi e non piu' in basso — sotto, i colpi diventano piu'
  /// fitti di quanto il telefono riesca a farne sentire, e la vibrazione
  /// comincia a saltarne invece di infittirsi.
  static const _primoPasso = 240.0;
  static const _ultimoPasso = 90.0;

  late final AnimationController _tempo;
  late final List<_Coriandolo> _coriandoli;

  /// Quale colpo stiamo suonando, e quando e' cominciato.
  var _colpo = -1;
  var _inizioDelColpo = 0.0;

  var _scoppiata = false;
  var _uscita = false;

  @override
  void initState() {
    super.initState();

    _coriandoli = _semina();
    _tempo = AnimationController(vsync: this, duration: WinnerReveal.durata)
      ..addListener(_batti)
      ..addStatusListener((stato) {
        if (stato == AnimationStatus.completed) {
          _esci();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _tempo
      ..removeListener(_batti)
      ..dispose();
    super.dispose();
  }

  /// I millesimi di secondo passati dall'inizio.
  double get _passati =>
      (_tempo.lastElapsedDuration ?? Duration.zero).inMicroseconds / 1000;

  /// Il tamburo batte, e a ogni colpo il telefono fa un colpetto.
  ///
  /// **La vibrazione e' leggera apposta.** A ogni singolo colpo si sente poco;
  /// e' l'accelerazione a farla diventare qualcosa — venti colpetti leggeri in
  /// due secondi si trasformano in un fremito continuo sotto le dita, e quello
  /// e' il rullo. Un colpo forte ripetuto venti volte sarebbe solo fastidioso,
  /// e il telefono comincerebbe a saltarne.
  void _batti() {
    final t = _tempo.value;

    if (t >= _scoppio) {
      if (!_scoppiata) {
        _scoppiata = true;
        // **Adesso si', forte.** E' l'unico momento in cui il telefono deve
        // farsi sentire davvero: il colpo secco segna l'istante in cui la foto
        // entra, la vibrazione lunga fa da piatto finale.
        HapticFeedback.heavyImpact();
        HapticFeedback.vibrate();
      }

      setState(() {});

      return;
    }

    final passati = _passati;

    if (passati - _inizioDelColpo >= _passoAdesso(t) || _colpo < 0) {
      _colpo += 1;
      _inizioDelColpo = passati;
      HapticFeedback.lightImpact();
    }

    setState(() {});
  }

  /// Quanto dura il colpo che stiamo suonando adesso.
  double _passoAdesso(double t) {
    final avanti = (t / _scoppio).clamp(0.0, 1.0);

    return _primoPasso + (_ultimoPasso - _primoPasso) * avanti;
  }

  void _esci() {
    if (_uscita || !mounted) {
      return;
    }

    _uscita = true;
    Navigator.of(context).maybePop();
  }

  /// I coriandoli, decisi una volta sola.
  ///
  /// **Sparati dai due angoli in basso.** Cadere dall'alto e' quello che fa la
  /// neve; una vittoria fa il rumore opposto — parte da terra, si apre verso
  /// l'alto, e solo dopo la gravita' se li riprende.
  List<_Coriandolo> _semina() {
    // Un seme fisso: la stessa vittoria fa la stessa festa, invece di una
    // diversa a ogni ricostruzione della schermata.
    final caso = math.Random(7);
    const colori = <Color>[
      AppColors.crasyRed,
      AppColors.crasyRedDeep,
      Color(0xFFFFFFFF),
      Color(0xFFFFD34D),
    ];

    return <_Coriandolo>[
      for (var i = 0; i < 48; i += 1)
        _Coriandolo(
          // Appena fuori dall'angolo, cosi' non si vede nessuno comparire dal
          // nulla in mezzo allo schermo.
          x0: i.isEven ? -0.03 : 1.03,
          y0: 1.02 + caso.nextDouble() * 0.04,
          // Verso l'alto e verso il centro, con una spinta diversa per ognuno:
          // uguale, partirebbero come un muro.
          vx: (i.isEven ? 1 : -1) * (0.45 + caso.nextDouble() * 0.75),
          vy: -(1.15 + caso.nextDouble() * 0.45),
          giro: caso.nextDouble() * math.pi,
          velocitaDelGiro: (caso.nextDouble() - 0.5) * 9,
          larghezza: 5 + caso.nextDouble() * 5,
          altezza: 9 + caso.nextDouble() * 7,
          colore: colori[caso.nextInt(colori.length)],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = _tempo.value;
    final scoppiato = t >= _scoppio;

    return GestureDetector(
      // Un tocco qualunque salta tutto. Vedi la nota in cima.
      onTap: _esci,
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: const Color(0xFF000000),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!scoppiato)
              _Tamburi(
                key: WinnerReveal.chiaveDeiTamburi,
                // Da 0 a 1 dentro il colpo che stiamo suonando: e' quello che
                // fa rimbalzare la pelle e scendere la bacchetta.
                colpo:
                    ((_passati - _inizioDelColpo) / _passoAdesso(t)).clamp(
                      0.0,
                      1.0,
                    ),
                // Il rullo cresce: i tamburi si avvicinano e si allargano un
                // po' mentre accelerano.
                crescita: (t / _scoppio).clamp(0.0, 1.0),
              )
            else
              _Proclamazione(
                challenge: widget.challenge,
                winner: widget.winner,
                mine: widget.mine,
                // Quanto e' entrata la foto: da 0 a 1 nel tempo dello scoppio,
                // con un rimbalzo corto in fondo.
                entrata: ((t - _scoppio) / (_posata - _scoppio)).clamp(
                  0.0,
                  1.0,
                ),
              ),
            if (scoppiato)
              IgnorePointer(
                child: CustomPaint(
                  painter: _Coriandoli(
                    pezzi: _coriandoli,
                    // I secondi passati dallo scoppio: la parabola non sa
                    // niente dell'animazione, sa solo quanto tempo e' passato.
                    t:
                        (t - _scoppio) *
                        WinnerReveal.durata.inMilliseconds /
                        1000,
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: Center(
                child: Text(
                  'tocca per continuare',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.30),
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// I due tamburi, uno per lato, sul nero.
///
/// **Non c'e' nient'altro a schermo, ed e' il punto.** Vedi la nota in cima a
/// [WinnerReveal].
class _Tamburi extends StatelessWidget {
  const _Tamburi({required this.colpo, required this.crescita, super.key});

  /// Da 0 a 1 dentro il colpo che si sta suonando adesso.
  final double colpo;

  /// Da 0 a 1 lungo tutto il rullo.
  final double crescita;

  @override
  Widget build(BuildContext context) {
    final larghezza = MediaQuery.sizeOf(context).width;
    // Un quarto di schermo per tamburo: piu' grandi si toccherebbero, piu'
    // piccoli non si capirebbe cosa sono.
    final lato = (larghezza * 0.26).clamp(70.0, 140.0);

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Tamburo(colpo: colpo, crescita: crescita, lato: lato, destro: false),
          SizedBox(width: larghezza * 0.10),
          _Tamburo(colpo: colpo, crescita: crescita, lato: lato, destro: true),
        ],
      ),
    );
  }
}

class _Tamburo extends StatelessWidget {
  const _Tamburo({
    required this.colpo,
    required this.crescita,
    required this.lato,
    required this.destro,
  });

  final double colpo;
  final double crescita;
  final double lato;

  /// Quello di destra suona a specchio: le due bacchette si muovono verso il
  /// centro invece che nella stessa direzione, come suonerebbe una persona.
  final bool destro;

  @override
  Widget build(BuildContext context) {
    // Il tamburo si schiaccia sul colpo e torna su: il rimbalzo dura poco piu'
    // di un terzo del passo, poi sta fermo ad aspettare il prossimo.
    final schiaccio = (1 - colpo * 2.6).clamp(0.0, 1.0);
    final scala = (1 + 0.10 * schiaccio) * (0.92 + 0.08 * crescita);

    return Transform.scale(
      scale: scala,
      child: SizedBox(
        width: lato,
        height: lato * 1.15,
        child: CustomPaint(
          painter: _DisegnoDelTamburo(colpo: colpo, destro: destro),
        ),
      ),
    );
  }
}

/// Il tamburo, disegnato invece che preso da un'immagine.
///
/// Un cilindro con la pelle bianca in cima, il fusto rosso, la cordatura a
/// zigzag e una bacchetta che scende sul colpo. Sono venti righe di geometria e
/// pesano zero: un'immagine avrebbe dovuto esistere in cinque misure, restare
/// nitida su ogni schermo e non stonare quando cambia il rosso di CRASY.
class _DisegnoDelTamburo extends CustomPainter {
  const _DisegnoDelTamburo({required this.colpo, required this.destro});

  final double colpo;
  final bool destro;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final fusto = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.crasyRed;
    final pelle = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    final filo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.85);

    final cima = h * 0.34;
    final fondo = h * 0.82;
    final raggioX = w * 0.46;
    final raggioY = h * 0.10;

    // Il fondo del cilindro, e poi il fusto sopra: disegnati in quest'ordine,
    // la pancia in basso resta arrotondata senza nessuna maschera.
    canvas
      ..drawOval(
        Rect.fromCenter(
          center: Offset(w / 2, fondo),
          width: raggioX * 2,
          height: raggioY * 2,
        ),
        fusto,
      )
      ..drawRect(Rect.fromLTRB(w / 2 - raggioX, cima, w / 2 + raggioX, fondo), fusto);

    // La cordatura: sei zigzag fra il bordo di sopra e quello di sotto. E' il
    // dettaglio che fa leggere "tamburo" invece di "barattolo".
    const quanti = 6;
    final zigzag = Path();

    for (var i = 0; i <= quanti; i += 1) {
      final x = w / 2 - raggioX + (raggioX * 2) * i / quanti;
      final y = i.isEven ? cima + h * 0.06 : fondo - h * 0.06;

      if (i == 0) {
        zigzag.moveTo(x, y);
      } else {
        zigzag.lineTo(x, y);
      }
    }

    canvas
      ..drawPath(zigzag, filo)
      // La pelle, in cima. Bianca e piena: e' la parte che prende il colpo, e
      // dev'essere la cosa piu' chiara del disegno.
      ..drawOval(
        Rect.fromCenter(
          center: Offset(w / 2, cima),
          width: raggioX * 2,
          height: raggioY * 2,
        ),
        pelle,
      );

    _bacchetta(canvas, size);
    _onda(canvas, size, cima, raggioX, raggioY);
  }

  /// La bacchetta che scende sulla pelle e risale.
  void _bacchetta(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Scende in fretta e risale piano: un colpo, non un'oscillazione.
    final giu = colpo < 0.22
        ? colpo / 0.22
        : (1 - (colpo - 0.22) / 0.78).clamp(0.0, 1.0);
    final alzata = (1 - giu) * h * 0.20;

    final perno = Offset(destro ? w * 0.78 : w * 0.22, h * 0.05 + alzata);
    final punta = Offset(w * 0.5, h * 0.28 + alzata * 0.4);

    canvas.drawLine(
      perno,
      punta,
      Paint()
        ..strokeWidth = w * 0.055
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFE8D6B0),
    );
  }

  /// L'onda che si apre dalla pelle appena presa la bacchetta.
  void _onda(Canvas canvas, Size size, double cima, double rx, double ry) {
    if (colpo > 0.55) {
      return;
    }

    final apertura = colpo / 0.55;
    final resta = (1 - apertura).clamp(0.0, 1.0);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, cima),
        width: rx * 2 * (1 + apertura * 0.7),
        height: ry * 2 * (1 + apertura * 0.7),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.02
        ..color = Colors.white.withValues(alpha: 0.55 * resta),
    );
  }

  @override
  bool shouldRepaint(_DisegnoDelTamburo oldDelegate) =>
      oldDelegate.colpo != colpo;
}

/// Quello che si vede dopo il rullo: frase, foto, nome.
class _Proclamazione extends StatelessWidget {
  const _Proclamazione({
    required this.challenge,
    required this.winner,
    required this.mine,
    required this.entrata,
  });

  final Challenge challenge;
  final ChallengeEntry winner;
  final bool mine;
  final double entrata;

  @override
  Widget build(BuildContext context) {
    final scala = 0.82 + 0.18 * Curves.easeOutBack.transform(entrata);

    return SafeArea(
      child: Transform.translate(
        offset: const Offset(0, 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _Grossa(testo: 'HA VINTO', corpo: 34),
            // **Due, non venti.** La frase e la foto sono una cosa sola:
            // staccate sembrano un titolo e un'immagine finite nella stessa
            // schermata per caso. Appiccicate si leggono in un colpo d'occhio
            // solo — e questo momento dura cinque secondi, non c'e' tempo per
            // due colpi d'occhio.
            const SizedBox(height: 2),
            // **Se ha vinto un video, non si mostra niente.**
            //
            // Un lettore video che si apre dentro un'animazione da cinque secondi
            // non fa in tempo: resta un rettangolo nero per tutta la durata, e il
            // momento piu' importante dell'app diventa un buco. Il primo
            // fotogramma non ce l'abbiamo — i video non hanno una miniatura — e
            // tirarlo fuori qui vorrebbe dire aprire comunque quel lettore.
            //
            // Allora si toglie: restano la frase, il nome e il premio, che sono
            // la notizia. Il video si guarda dopo, nella gara, dove ha il tempo
            // di caricarsi.
            if (!winner.isVideo)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 44),
                  child: Center(
                    child: Transform.scale(
                      scale: scala,
                      child: _Faccia(entry: winner),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 2),
            Opacity(
              opacity: entrata,
              child: SizedBox(
                // Senza la foto il nome e' l'unica cosa rimasta a schermo, e
                // sta piu' comodo: quei settantadue punti servivano a non far
                // saltare la foto, e la foto qui non c'e'.
                height: winner.isVideo ? 140 : 72,
                // **Rimpicciolisce invece di traboccare.** Un nome lungo, o un
                // premio a quattro cifre, uscivano dal riquadro e lasciavano a
                // schermo la riga a strisce gialle e nere — proprio sopra la
                // vittoria.
                // **In cima al suo riquadro, non in mezzo.** Il riquadro e'
                // alto settantadue per tenere il posto anche prima che il nome
                // compaia — senza, la foto salterebbe verso l'alto proprio
                // nell'istante in cui deve stare ferma. Ma con il nome centrato
                // dentro, quel riquadro gli metteva attorno una decina di punti
                // di aria che nessuno aveva chiesto, e il nome finiva staccato
                // dalla foto. In cima, il posto resta occupato e il nome sta
                // appena sotto la cornice.
                child: Align(
                  alignment: Alignment.topCenter,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '@${winner.authorName}',
                          style: TextStyle(
                            color: Colors.white,
                            // **Senza la foto, il nome cresce.** Quando ha vinto
                            // un video non c'e' nient'altro a schermo: lasciarlo
                            // della misura di una didascalia sotto un riquadro
                            // che non esiste piu' lo farebbe sembrare un
                            // dettaglio, invece della notizia.
                            fontSize: winner.isVideo ? 30 : 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (challenge.prizeCents > 0) ...[
                        const SizedBox(height: 4),
                        _Grossa(
                          testo: AppMoney.format(challenge.prizeCents),
                          corpo: 26,
                        ),
                      ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una scritta grossa, bianca con il contorno rosso CRASY.
///
/// **Due Text sovrapposti, e non c'e' un altro modo.** Una scritta sola sa
/// essere piena **oppure** contornata, mai tutte e due: sotto sta il tratto,
/// sopra il pieno. E' la ragione per cui una prova che cerca questa scritta ne
/// trova due — e va bene cosi', e' il segno che il contorno c'e' ancora.
///
/// Il contorno non e' decorazione. Qui sotto passa una foto qualunque: una
/// scritta bianca su una parete chiara sparisce, e questa e' l'unica scritta
/// dell'app che non si puo' permettere di sparire.
class _Grossa extends StatelessWidget {
  const _Grossa({required this.testo, required this.corpo});

  final String testo;
  final double corpo;

  /// Quanto e' spesso il tratto, in proporzione al corpo.
  static const _spessore = 0.075;

  TextStyle _stile(Paint? tratto, Color? pieno) => TextStyle(
    color: pieno,
    foreground: tratto,
    fontSize: corpo,
    height: 1.05,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          testo,
          textAlign: TextAlign.center,
          style: _stile(
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = corpo * _spessore
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFFFFD34D),
            null,
          ),
        ),
        Text(
          testo,
          textAlign: TextAlign.center,
          style: _stile(null, Colors.white),
        ),
      ],
    );
  }
}

/// La foto vincitrice, nella sua cornice rossa.
class _Faccia extends StatelessWidget {
  const _Faccia({required this.entry});

  final ChallengeEntry entry;

  @override
  Widget build(BuildContext context) {
    // **Il quadrato c'e' anche quando la foto non c'e'.** Un riquadro che
    // sparisce perche' l'immagine non e' arrivata farebbe saltare in mezzo allo
    // schermo tutto quello che gli sta sotto, proprio nell'istante della
    // rivelazione.
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFD34D), width: 3),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x66FFD34D),
              blurRadius: 44,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: MediaFrame(
            url: entry.mediaUrl,
            video: entry.isVideo,
            aspectRatio: 1,
            radius: 15,
          ),
        ),
      ),
    );
  }
}

/// Un coriandolo, con tutto quello che gli serve per sapere dove sta.
class _Coriandolo {
  const _Coriandolo({
    required this.x0,
    required this.y0,
    required this.vx,
    required this.vy,
    required this.giro,
    required this.velocitaDelGiro,
    required this.larghezza,
    required this.altezza,
    required this.colore,
  });

  /// Da dove parte, in frazioni di schermo.
  final double x0;
  final double y0;

  /// Con che spinta, in schermi al secondo.
  final double vx;
  final double vy;

  final double giro;
  final double velocitaDelGiro;
  final double larghezza;
  final double altezza;
  final Color colore;
}

/// I coriandoli, disegnati uno per uno.
///
/// **Una parabola, non un'animazione a fotogrammi.** La posizione si calcola
/// dal tempo passato — spazio uguale velocita' per tempo, piu' mezzo di
/// accelerazione per tempo al quadrato. E' la formula che si impara a scuola,
/// ed e' il motivo per cui questi pezzi di carta sembrano avere un peso invece
/// di scivolare.
class _Coriandoli extends CustomPainter {
  const _Coriandoli({required this.pezzi, required this.t});

  final List<_Coriandolo> pezzi;

  /// I secondi passati dallo scoppio.
  final double t;

  /// Quanto tira in giu', in schermi al secondo quadrato.
  static const _gravita = 1.55;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) {
      return;
    }

    // Sbiadiscono sul finale, o sparirebbero di colpo tutti insieme.
    final resta = (1.0 - (t - 1.7) / 1.1).clamp(0.0, 1.0);

    if (resta <= 0) {
      return;
    }

    final pennello = Paint()..style = PaintingStyle.fill;

    for (final pezzo in pezzi) {
      final x = (pezzo.x0 + pezzo.vx * t) * size.width;
      final y = (pezzo.y0 + pezzo.vy * t + 0.5 * _gravita * t * t) * size.height;

      if (y > size.height + 40 || x < -40 || x > size.width + 40) {
        continue;
      }

      final angolo = pezzo.giro + pezzo.velocitaDelGiro * t;

      pennello.color = pezzo.colore.withValues(alpha: resta);

      canvas
        ..save()
        ..translate(x, y)
        ..rotate(angolo)
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: pezzo.larghezza,
            // Si assottiglia mentre gira: e' quello che fa sembrare un
            // rettangolo un pezzo di carta invece di un mattoncino.
            height: pezzo.altezza * (0.35 + 0.65 * math.cos(angolo).abs()),
          ),
          pennello,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_Coriandoli oldDelegate) => oldDelegate.t != t;
}
