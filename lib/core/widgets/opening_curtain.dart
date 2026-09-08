import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// L'icona dell'app, tenuta per un paio di secondi all'apertura.
///
/// ## Perche' un'attesa messa apposta
///
/// L'app e' pronta in poche centinaia di millisecondi, e mostrare qualcosa piu'
/// a lungo del necessario e' esattamente il tipo di cosa che di solito si
/// toglie. Qui si aggiunge, e per un motivo che non ha a che fare con il
/// caricamento: **e' il momento in cui l'app dice come si chiama**. Aprendo e
/// trovandosi subito dentro un elenco di gare, quel momento non esiste — e con
/// esso non esiste nemmeno il ricordo di quale app si sta usando.
///
/// Due secondi e due decimi: abbastanza da vedersi, troppo poco perche' venga
/// voglia di saltarlo.
///
/// ## La fiamma si accende, non compare
///
/// Era ferma. Una fiamma ferma e' un'icona — e un'icona tenuta a schermo per due
/// secondi si legge come "sta caricando", che e' l'esatto contrario di quello
/// che questi due secondi devono dire.
///
/// Adesso fa quello che fa una fiamma: **prende** in mezzo secondo — piccola,
/// poi larga, con l'alone che si apre dietro — e da li' in poi **vive**,
/// ondeggiando appena. L'ondeggio non e' regolare: sono due onde di velocita'
/// diverse sommate, e siccome i loro tempi non tornano mai insieme il movimento
/// non si ripete mai identico. Una pulsazione regolare si riconosce come
/// un'animazione; questa si riconosce come una cosa accesa.
///
/// ## E fa un suono
///
/// Due secondi e due decimi, esattamente quanto il sipario: un soffio che sale
/// e un accordo che sboccia. Nasce da `tool/suono_di_apertura.py`, per non
/// dipendere dalla licenza di qualcun altro.
///
/// **Rispetta l'interruttore del silenzioso e non ferma la musica di nessuno.**
/// Sono le due cose che rendono accettabile un suono che parte da solo: chi ha
/// il telefono muto non sente niente, e chi sta ascoltando qualcosa se lo tiene.
/// Un'app che zittisce la musica per farsi la sigla e' un'app che si disinstalla.
///
/// ## Perche' sopra e non al posto
///
/// Sta **sopra** l'app invece di essere una schermata dell'app, e la differenza
/// conta: l'app sotto si costruisce e si collega mentre il sipario e' ancora
/// alzato, quindi quando cala non c'e' niente da aspettare. Fosse una pagina
/// vera, quei due secondi si sommerebbero al caricamento invece di coprirlo.
/// Se il sipario si alza.
///
/// **Serve alle prove, e serve davvero.** Un velo che copre lo schermo per due
/// secondi e' esattamente cio' che un test non puo' aspettare: i tocchi
/// finirebbero sul velo invece che sui comandi, e ogni prova sull'interfaccia
/// diventerebbe una prova su questo. Spento li', resta acceso ovunque altro —
/// e con lui resta spento il suono, che in una prova non deve partire mai.
final openingCurtainProvider = Provider<bool>((ref) => true);

/// Se la sigla suona.
///
/// **Separato dal sipario apposta.** Una prova che vuole guardare la fiamma
/// accendersi deve poter tenere alzato il sipario **senza** far partire
/// l'audio: in una prova non c'e' nessun apparecchio che suoni, e il tentativo
/// finirebbe in un errore ingoiato — cioe' in un rumore di fondo nei registri
/// che copre quelli veri.
///
/// Spegnendolo si spegne il suono e basta: l'animazione resta.
final openingSoundProvider = Provider<bool>((ref) => true);

class OpeningCurtain extends ConsumerStatefulWidget {
  const OpeningCurtain({required this.child, super.key});

  final Widget child;

  /// Quanto resta ferma prima di andarsene.
  static const Duration hold = Duration(milliseconds: 2200);

  /// Quanto ci mette ad andarsene. Non zero: sparendo di colpo sembrerebbe un
  /// difetto, sfumando sembra che si apra.
  static const Duration fade = Duration(milliseconds: 420);

  /// La fiamma, per le prove.
  ///
  /// **Una chiave e non una ricerca per tipo.** L'unica cosa che dimostra che
  /// questa animazione esiste e' che la misura della fiamma cambi nel tempo, e
  /// per misurarla bisogna mettere le mani esattamente su quel `Transform`. Con
  /// una ricerca per tipo se ne prende un altro dell'albero — succede, e la
  /// prova passa leggendo sempre uno.
  static const chiaveDellaFiamma = Key('fiamma-dell-apertura');

  @override
  ConsumerState<OpeningCurtain> createState() => _OpeningCurtainState();
}

class _OpeningCurtainState extends ConsumerState<OpeningCurtain>
    with SingleTickerProviderStateMixin {
  bool _visible = true;
  Timer? _timer;
  late final AnimationController _fiamma;
  AudioPlayer? _lettore;

  @override
  void initState() {
    super.initState();

    _fiamma = AnimationController(vsync: this, duration: OpeningCurtain.hold)
      ..forward();

    _timer = Timer(OpeningCurtain.hold, () {
      if (mounted) {
        setState(() => _visible = false);
      }
    });

    // **Il suono si chiede dopo la prima frame.** Qui dentro `initState`
    // l'albero non e' ancora costruito, e leggere un provider prima che lo sia
    // e' il modo classico di prendersi un errore che non nomina la causa.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          ref.read(openingCurtainProvider) &&
          ref.read(openingSoundProvider)) {
        unawaited(_suona());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fiamma.dispose();
    unawaited(_lettore?.dispose());
    super.dispose();
  }

  /// Fa partire la sigla, e non disturba nessuno.
  ///
  /// **Ogni errore qui si ingoia.** Un suono che non parte non e' un guasto: e'
  /// un telefono muto, un permesso negato, un browser che non fa partire
  /// l'audio senza che qualcuno abbia toccato lo schermo. Nessuno di questi
  /// casi merita di lasciare a schermo un messaggio rosso sopra la prima cosa
  /// che si vede aprendo l'app.
  Future<void> _suona() async {
    try {
      final lettore = AudioPlayer();
      _lettore = lettore;

      await lettore.setAudioContext(
        AudioContext(
          // **`ambient` e' la scelta, e le altre no.** Vuol dire due cose
          // insieme: il tasto del silenzioso lo zittisce, e la musica di chi
          // stava ascoltando qualcosa continua. Con `playback` — il valore
          // predefinito — la sigla suonerebbe anche a telefono muto e
          // metterebbe in pausa Spotify per due secondi.
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          android: AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            // Nessuna richiesta di attenzione: non stiamo suonando musica, e
            // chiedendola metteremmo in pausa quella degli altri.
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );

      await lettore.setReleaseMode(ReleaseMode.stop);
      // Non a tutto volume: e' una firma, non un avviso.
      await lettore.play(AssetSource('audio/apertura.wav'), volume: 0.65);
    } on Object catch (_) {
      // Silenzio voluto. Vedi la nota qui sopra.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(openingCurtainProvider)) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        // **Non si toglie dall'albero: si spegne.** L'app sotto resta viva e
        // costruita per tutto il tempo, che e' il punto: il sipario copre il
        // caricamento invece di aggiungersi a esso.
        IgnorePointer(
          ignoring: !_visible,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: OpeningCurtain.fade,
            curve: Curves.easeOut,
            child: _Curtain(avanzamento: _fiamma),
          ),
        ),
      ],
    );
  }
}

class _Curtain extends StatelessWidget {
  const _Curtain({required this.avanzamento});

  final Animation<double> avanzamento;

  /// Quanto dura l'accensione, in frazioni del sipario.
  static const _accensione = 0.24;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final lato = MediaQuery.sizeOf(context).shortestSide;

    return ColoredBox(
      // **Bianco, come tutta l'app.** L'icona sulla schermata del telefono e'
      // nera, e per un attimo si e' pensato di continuarla — ma quello che si
      // apre subito dopo e' bianco, e un nero di due secondi in mezzo diventa
      // un lampo scuro fra due schermate chiare. Il colore lo porta la fiamma.
      color: palette.background,
      child: Center(
        child: AnimatedBuilder(
          animation: avanzamento,
          builder: (context, _) {
            final t = avanzamento.value;
            final presa = (t / _accensione).clamp(0.0, 1.0);

            // **Prende con uno scatto.** `easeOutBack` supera l'uno e torna
            // indietro: e' la differenza fra una cosa che si accende e una che
            // si gonfia.
            final apertura = Curves.easeOutBack.transform(presa);

            // I secondi veri: l'ondeggio deve andare al suo passo, non a quello
            // dell'animazione.
            final secondi = t * OpeningCurtain.hold.inMilliseconds / 1000;

            // **Due onde che non tornano mai insieme.** 3,1 e 5,7 volte al
            // secondo: i loro tempi non hanno un multiplo comune corto, quindi
            // la somma non si ripete e il movimento non si riconosce come un
            // ciclo. Con una sola onda si vedrebbe il battito.
            final ondeggio = presa < 1
                ? 0.0
                : 0.022 * math.sin(2 * math.pi * 3.1 * secondi) +
                      0.013 * math.sin(2 * math.pi * 5.7 * secondi + 1.3);

            final scala = 0.28 + 0.72 * apertura + ondeggio;

            return Opacity(
              // Compare in fretta, molto prima di finire di allargarsi: cosi'
              // si vede la fiamma crescere invece di vederla arrivare.
              opacity: (presa * 2.2).clamp(0.0, 1.0),
              child: SizedBox(
                width: lato * 0.6,
                height: lato * 0.6,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // L'alone dietro: e' quello che fa sembrare la fiamma una
                    // cosa che emette luce invece di un disegno rosso.
                    CustomPaint(
                      size: Size.square(lato * 0.6),
                      painter: _Alone(
                        colore: palette.accent,
                        forza: apertura * (0.55 + 0.45 * (1 + ondeggio * 12)),
                      ),
                    ),
                    // **La matrice scritta a mano invece di
                    // `Transform.scale`.** Sono la stessa cosa a schermo, ma
                    // quella scorciatoia tiene il fattore di scala per se' e
                    // dall'esterno non si legge: la prova che dimostra che
                    // questa fiamma si muove davvero non avrebbe niente da
                    // misurare, e passerebbe leggendo sempre uno.
                    Transform(
                      key: OpeningCurtain.chiaveDellaFiamma,
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(scala, scala, 1),
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        // Piu' piccola di quanto sta dentro l'icona quadrata:
                        // li' e' chiusa in un bordo che la contiene, qui ha
                        // tutto lo schermo attorno e alla stessa misura
                        // sembrerebbe enorme.
                        size: lato * 0.22,
                        color: palette.accent,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// L'alone caldo attorno alla fiamma.
///
/// Un cerchio sfumato, e nient'altro. **Non e' un'ombra**: un'ombra sta sotto
/// un oggetto e lo stacca dal fondo, questo sta **dietro** una cosa che brucia e
/// dice che sta illuminando quello che ha intorno. Su un fondo bianco e' l'unico
/// modo di far leggere "luce" invece di "disegno".
class _Alone extends CustomPainter {
  const _Alone({required this.colore, required this.forza});

  final Color colore;

  /// Da 0 (spento) a poco piu' di 1 (nel pieno di una fiammata).
  final double forza;

  @override
  void paint(Canvas canvas, Size size) {
    if (forza <= 0) {
      return;
    }

    final centro = Offset(size.width / 2, size.height / 2);
    final raggio = size.width / 2 * (0.55 + 0.45 * forza.clamp(0.0, 1.4));

    canvas.drawCircle(
      centro,
      raggio,
      Paint()
        ..shader = RadialGradient(
          colors: [
            colore.withValues(alpha: 0.22 * forza.clamp(0.0, 1.0)),
            colore.withValues(alpha: 0.10 * forza.clamp(0.0, 1.0)),
            colore.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: centro, radius: raggio)),
    );
  }

  @override
  bool shouldRepaint(_Alone oldDelegate) => oldDelegate.forza != forza;
}
