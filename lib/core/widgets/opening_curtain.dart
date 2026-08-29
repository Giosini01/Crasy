import 'dart:async';

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
/// diventerebbe una prova su questo. Spento li', resta acceso ovunque altro.
final openingCurtainProvider = Provider<bool>((ref) => true);

class OpeningCurtain extends ConsumerStatefulWidget {
  const OpeningCurtain({required this.child, super.key});

  final Widget child;

  /// Quanto resta ferma prima di andarsene.
  static const Duration hold = Duration(milliseconds: 2200);

  /// Quanto ci mette ad andarsene. Non zero: sparendo di colpo sembrerebbe un
  /// difetto, sfumando sembra che si apra.
  static const Duration fade = Duration(milliseconds: 420);

  @override
  ConsumerState<OpeningCurtain> createState() => _OpeningCurtainState();
}

class _OpeningCurtainState extends ConsumerState<OpeningCurtain> {
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(OpeningCurtain.hold, () {
      if (mounted) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
            child: const _Curtain(),
          ),
        ),
      ],
    );
  }
}

class _Curtain extends StatelessWidget {
  const _Curtain();

  @override
  Widget build(BuildContext context) {
    final lato = MediaQuery.sizeOf(context).shortestSide;

    return ColoredBox(
      // **Bianco, come tutta l'app.** L'icona sulla schermata del telefono e'
      // nera, e per un attimo si e' pensato di continuarla — ma quello che si
      // apre subito dopo e' bianco, e un nero di due secondi in mezzo diventa
      // un lampo scuro fra due schermate chiare. Il colore lo porta la fiamma.
      color: context.palette.background,
      child: Center(
        child: Icon(
          Icons.local_fire_department_rounded,
          // Piu' piccola di quanto sta dentro l'icona quadrata: li' e' chiusa
          // in un bordo che la contiene, qui ha tutto lo schermo attorno e
          // alla stessa misura sembrerebbe enorme.
          size: lato * 0.22,
          color: context.palette.accent,
        ),
      ),
    );
  }
}
