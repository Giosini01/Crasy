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
/// Il rullo serve a **restituire l'attesa** che il prodotto si era giocato. La
/// notifica dice che il tempo e' scaduto e di proposito non dice altro; qui il
/// finale si prende i suoi secondi.
///
/// ## Come e' fatto
///
/// Cinque secondi in tutto, e non uno di piu': oltre, un'animazione che non si
/// puo' toccare smette di essere un momento e diventa un ostacolo fra una
/// persona e la cosa che era venuta a vedere.
///
///  - **il rullo** (1,8s): le foto in gara si rincorrono sempre piu' piano, con
///    un colpetto sotto il dito a ogni cambio;
///  - **lo scoppio** (0,45s): la foto vincitrice entra di scatto e i coriandoli
///    partono **dai due lati**, non dall'alto — sparati, e solo dopo cadono;
///  - **il riposo** (2,75s): il nome e il premio, il tempo di leggerli.
///
/// **Si salta con un tocco, ovunque.** Chi l'ha gia' vista, chi non ha voglia,
/// chi ha aperto per altro: un'animazione che si deve subire e' una tassa.
///
/// I coriandoli sono disegnati qui invece che presi da una libreria: sono
/// quaranta rettangoli che seguono una parabola, il codice sta in mezza
/// schermata, e vale meno di una dipendenza da tenere aggiornata per sempre.
class WinnerReveal extends StatefulWidget {
  const WinnerReveal({
    required this.challenge,
    required this.entries,
    required this.winner,
    required this.mine,
    super.key,
  });

  final Challenge challenge;

  /// Le partecipazioni che si rincorrono durante il rullo.
  final List<ChallengeEntry> entries;

  final ChallengeEntry winner;

  /// Se il vincitore sono **io**. Cambia la parola grossa, non il resto.
  final bool mine;

  /// Quanto dura tutto, dal primo colpo di tamburo all'uscita.
  static const durata = Duration(milliseconds: 5000);

  /// Apre la proclamazione sopra la schermata.
  ///
  /// **Opaca, e non si chiude toccando fuori.** Una proclamazione con lo sfondo
  /// che traspare mostrerebbe la classifica sotto — cioe' la risposta — mentre
  /// il rullo sta ancora facendo finta di non saperla.
  static Future<void> show(
    BuildContext context, {
    required Challenge challenge,
    required List<ChallengeEntry> entries,
    required ChallengeEntry winner,
    required bool mine,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xFF000000),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animazione, altra) => WinnerReveal(
        challenge: challenge,
        entries: entries,
        winner: winner,
        mine: mine,
      ),
      transitionBuilder: (context, animazione, altra, child) =>
          FadeTransition(opacity: animazione, child: child),
    );
  }

  @override
  State<WinnerReveal> createState() => _WinnerRevealState();
}

class _WinnerRevealState extends State<WinnerReveal>
    with SingleTickerProviderStateMixin {
  /// Quando finisce il rullo e comincia lo scoppio, in frazioni del totale.
  static const _scoppio = 0.36;

  /// Quando la foto ha finito di entrare.
  static const _posata = 0.45;

  late final AnimationController _tempo;
  late final List<_Coriandolo> _coriandoli;
  late final List<ChallengeEntry> _facce;

  /// Quale foto sta passando adesso nel rullo.
  var _quale = 0;

  /// L'ultimo cambio, per non battere due volte sulla stessa foto.
  var _ultimoCambio = -1;

  var _scoppiata = false;
  var _uscita = false;

  @override
  void initState() {
    super.initState();

    _facce = _sceltePerIlRullo();
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

  /// Le foto che si rincorrono: quelle in gara, la vincitrice mescolata dentro.
  ///
  /// **Al massimo otto, e nessun video.** Con trenta partecipazioni il rullo
  /// diventa un elenco e nessuna faccia si vede abbastanza da fare effetto; e
  /// un video, in un decimo di secondo, non fa in tempo nemmeno ad aprirsi —
  /// resterebbe un buco nero in mezzo alla corsa.
  List<ChallengeEntry> _sceltePerIlRullo() {
    final scelte = widget.entries
        .where((entry) => entry.mediaUrl.isNotEmpty && !entry.isVideo)
        .take(8)
        .toList();

    return scelte.isEmpty ? <ChallengeEntry>[widget.winner] : scelte;
  }

  /// Il rullo: le foto si rincorrono, sempre piu' piano.
  ///
  /// **Il rallentamento e' la cosa che fa il rullo di tamburi.** A ritmo fisso
  /// sarebbe un elenco che scorre; rallentando, l'ultima foto resta ferma
  /// giusto il tempo di far pensare che sia quella — ed e' li' che uno smette
  /// di guardare lo schermo e comincia a sperare.
  void _batti() {
    final t = _tempo.value;

    if (t >= _scoppio) {
      if (!_scoppiata) {
        _scoppiata = true;
        // Un colpo secco quando la foto entra: e' l'unico momento in cui il
        // telefono deve farsi sentire davvero.
        HapticFeedback.heavyImpact();
      }

      setState(() {});

      return;
    }

    // Il passo cresce da 55 a 340 millesimi di secondo: all'inizio le foto
    // sfarfallano, alla fine si posano una alla volta.
    final avanzamento = t / _scoppio;
    final passo = 55 + 285 * avanzamento * avanzamento;
    final passati = (_tempo.lastElapsedDuration ?? Duration.zero).inMilliseconds;
    final adesso = (passati / passo).floor();

    if (adesso != _ultimoCambio) {
      _ultimoCambio = adesso;
      HapticFeedback.selectionClick();

      setState(() => _quale = adesso % _facce.length);

      return;
    }

    setState(() {});
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
  /// **Sparati dai lati, non fatti cadere dall'alto.** Cadere e' quello che fa
  /// la neve; una vittoria fa il rumore opposto — parte da terra, si apre, e
  /// solo dopo la gravita' se li riprende.
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
      for (var i = 0; i < 44; i += 1)
        _Coriandolo(
          // Da fuori dallo schermo: cosi' non si vede nessuno comparire dal
          // nulla sul bordo.
          x0: i.isEven ? -0.03 : 1.03,
          y0: 0.62 + caso.nextDouble() * 0.12,
          // Verso l'alto e verso il centro, con una spinta diversa per ognuno:
          // uguale, partirebbero come un muro.
          vx: (i.isEven ? 1 : -1) * (0.55 + caso.nextDouble() * 0.85),
          vy: -(0.95 + caso.nextDouble() * 0.75),
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
    final foto = scoppiato
        ? widget.winner
        : _facce[_quale.clamp(0, _facce.length - 1)];

    // Quanto e' entrata la foto: da 0 a 1 nel tempo dello scoppio, con un
    // rimbalzo corto in fondo.
    final entrata = scoppiato
        ? ((t - _scoppio) / (_posata - _scoppio)).clamp(0.0, 1.0)
        : 0.0;
    final scala = scoppiato
        ? 0.82 + 0.18 * Curves.easeOutBack.transform(entrata)
        : 0.94;

    return GestureDetector(
      // Un tocco qualunque salta tutto. Vedi la nota in cima.
      onTap: _esci,
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: const Color(0xFF0A0A0B),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Titolo(scoppiato: scoppiato, mine: widget.mine),
                  const SizedBox(height: 22),
                  // **Flessibile, non a misura fissa.** Il riquadro e' quadrato
                  // e largo quanto lo schermo meno i margini: su un telefono
                  // coricato — o su un tablet — quel quadrato sarebbe piu' alto
                  // dello schermo, e la colonna traboccherebbe portandosi via
                  // il nome del vincitore. Cosi' prende quello che avanza fra
                  // il titolo e il nome, e si stringe da solo.
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 44),
                      child: Center(
                        child: Transform.scale(
                          scale: scala,
                          child: _Faccia(entry: foto, accesa: scoppiato),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Nome(
                    scoppiato: scoppiato,
                    entrata: entrata,
                    nome: widget.winner.authorName,
                    premio: widget.challenge.prizeCents,
                  ),
                ],
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
                    color: Colors.white.withValues(alpha: 0.34),
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

/// La riga grossa in cima: la domanda, poi la risposta.
class _Titolo extends StatelessWidget {
  const _Titolo({required this.scoppiato, required this.mine});

  final bool scoppiato;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    // **Durante il rullo la scritta e' bianca, dopo e' rossa.** Il rosso qui
    // non decora: in CRASY vuol dire premio, ed e' il segno che la cosa e'
    // successa davvero.
    final testo = scoppiato ? (mine ? 'HAI VINTO' : 'HA VINTO') : 'CHI VINCE?';

    return Text(
      testo,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: scoppiato ? AppColors.crasyRed : Colors.white,
        fontSize: scoppiato && mine ? 40 : 30,
        height: 1.05,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// La foto in mezzo: durante il rullo passa, alla fine resta.
class _Faccia extends StatelessWidget {
  const _Faccia({required this.entry, required this.accesa});

  final ChallengeEntry entry;

  /// Se e' la vincitrice: prende la cornice rossa e perde il velo.
  final bool accesa;

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
          border: Border.all(
            color: accesa ? AppColors.crasyRed : Colors.white24,
            width: accesa ? 3 : 1,
          ),
          boxShadow: accesa
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x55FA0000),
                    blurRadius: 44,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MediaFrame(
                url: entry.mediaUrl,
                video: entry.isVideo,
                aspectRatio: 1,
                radius: 15,
                // Il video vincitore parte da solo: qui e' la cosa che si e'
                // venuti a vedere, non un francobollo in una griglia.
                autoplay: accesa,
              ),
              // **Durante il rullo le foto stanno sotto un velo.** Senza, si
              // riesce a riconoscere chi sta passando e si capisce il finale un
              // istante prima che arrivi.
              if (!accesa)
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x8A0A0A0B),
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Il nome e il premio, che compaiono solo a cose fatte.
class _Nome extends StatelessWidget {
  const _Nome({
    required this.scoppiato,
    required this.entrata,
    required this.nome,
    required this.premio,
  });

  final bool scoppiato;
  final double entrata;
  final String nome;
  final int premio;

  @override
  Widget build(BuildContext context) {
    // Lo spazio resta occupato anche prima: senza, la foto salterebbe verso
    // l'alto proprio nell'istante in cui si vuole che stia ferma.
    if (!scoppiato) {
      return const SizedBox(height: 72);
    }

    return Opacity(
      opacity: entrata,
      child: SizedBox(
        height: 72,
        // **Rimpicciolisce invece di traboccare.** Un nome lungo, o un premio a
        // quattro cifre, uscivano dal riquadro e lasciavano a schermo la riga a
        // strisce gialle e nere — proprio sopra la vittoria.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '@$nome',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (premio > 0) ...[
                const SizedBox(height: 4),
                Text(
                  AppMoney.format(premio),
                  style: const TextStyle(
                    color: AppColors.crasyRed,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
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
