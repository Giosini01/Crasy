import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:crasy/core/widgets/flame_waiting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// **Una foto dalla rete che, se non arriva, riprova da sola.**
///
/// Con poca rete una foto non arrivava al primo colpo, e `Image.network` non ci
/// riprovava mai: restava il riquadro grigio finche' non si usciva e si
/// rientrava. Qui, se fallisce, si aspetta un attimo e si riprova — due
/// secondi, poi quattro, otto, sedici — e solo dopo si mostra [inErrore], con
/// un tocco per riprovare ancora.
///
/// **Sul telefono resta in memoria anche dopo aver chiuso l'app**: una foto
/// gia' vista non si riscarica, e la seconda volta la gara si apre subito
/// anche senza rete. Sul web ci pensa il browser, e l'immagine passa da
/// `Image.network`: li' serve il ripiego sull'elemento `<img>` — vedi sotto —
/// che un'altra strada non avrebbe.
///
/// Mentre arriva si vede [inAttesa], o la fiamma che gira.
class FotoDallaRete extends StatefulWidget {
  const FotoDallaRete({
    required this.url,
    this.fit = BoxFit.cover,
    this.inAttesa,
    this.inErrore,
    this.dissolvenza = true,
    super.key,
  });

  final String url;
  final BoxFit fit;

  /// Cosa si vede mentre arriva. Se manca, la fiamma che gira al centro.
  final WidgetBuilder? inAttesa;

  /// Cosa si vede quando, dopo tutti i tentativi, non e' arrivata. Riceve il
  /// gesto che la fa riprovare. Se manca, si resta su [inAttesa].
  final Widget Function(BuildContext context, VoidCallback riprova)? inErrore;

  /// Se entra con una dissolvenza breve invece di apparire di scatto.
  final bool dissolvenza;

  /// Da dove arriva una foto: dal telefono se c'e' gia', dalla rete se no.
  /// Uno solo per tutti, cosi' una foto preparata in anticipo e' la stessa
  /// che poi si mostra.
  static ImageProvider fornitore(String url) => kIsWeb
      // Su web Flutter scarica le immagini con `fetch` e le disegna sulla
      // tela, e questo richiede che il server mandi le intestazioni CORS. Il
      // bucket di Firebase Storage non le manda finche' non gliele si
      // configura a mano, e il risultato e' che **le foto non compaiono e
      // nessuno dice perche'**: niente errore, solo un riquadro vuoto.
      //
      // Con il ripiego, quando il disegno sulla tela fallisce, Flutter usa un
      // vero elemento `<img>` del browser — che le foto le mostra da sempre
      // senza chiedere permesso a nessuno.
      ? NetworkImage(
          url,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        )
      : CachedNetworkImageProvider(url);

  /// **Scarica una foto prima che serva.** A schermo intero si prepara quella
  /// dopo e quella prima mentre si guarda questa: quando si scorre, e' gia'
  /// arrivata. Non lancia mai: se non riesce, la si scarica quando serve.
  static void preparaInAnticipo(BuildContext context, String url) {
    if (url.isEmpty || url.startsWith('data:')) {
      return;
    }

    unawaited(precacheImage(fornitore(url), context, onError: (_, _) {}));
  }

  @override
  State<FotoDallaRete> createState() => _FotoDallaReteState();
}

class _FotoDallaReteState extends State<FotoDallaRete> {
  /// Quante volte e' fallita di fila. Fa anche da chiave: cambiandolo, la
  /// foto si richiede da capo.
  int _tentativo = 0;

  /// Il giro di prima e' gia' fallito e il prossimo e' in programma.
  Timer? _prossimo;

  bool _arresa = false;

  static const int _tentativiDaSoli = 4;

  @override
  void didUpdateWidget(FotoDallaRete prima) {
    super.didUpdateWidget(prima);

    if (prima.url != widget.url) {
      _prossimo?.cancel();
      _prossimo = null;
      _tentativo = 0;
      _arresa = false;
    }
  }

  @override
  void dispose() {
    _prossimo?.cancel();
    super.dispose();
  }

  ImageProvider _provider() => FotoDallaRete.fornitore(widget.url);

  /// Non e' arrivata: si riprova fra poco, sempre un po' piu' tardi.
  void _fallita() {
    if (_prossimo != null || _arresa) {
      return;
    }

    if (_tentativo >= _tentativiDaSoli) {
      // Fuori dal disegno: questo arriva mentre la foto si sta costruendo.
      scheduleMicrotask(() {
        if (mounted) {
          setState(() => _arresa = true);
        }
      });

      return;
    }

    final attesa = Duration(seconds: 2 << _tentativo);

    _prossimo = Timer(attesa, () {
      if (!mounted) {
        return;
      }

      // Si toglie dalla memoria il tentativo fallito, o tornerebbe quello.
      unawaited(_provider().evict());

      setState(() {
        _prossimo = null;
        _tentativo++;
      });
    });
  }

  void _riprova() {
    unawaited(_provider().evict());

    setState(() {
      _prossimo?.cancel();
      _prossimo = null;
      _tentativo = 0;
      _arresa = false;
    });
  }

  Widget _attesa(BuildContext context) =>
      widget.inAttesa?.call(context) ??
      const Center(child: FiammaCheGira(misura: 32));

  @override
  Widget build(BuildContext context) {
    final errore = widget.inErrore;

    if (_arresa && errore != null) {
      return errore(context, _riprova);
    }

    return Image(
      key: ValueKey('${widget.url}#$_tentativo'),
      image: _provider(),
      fit: widget.fit,
      // La foto entra con una dissolvenza breve invece di apparire di scatto.
      frameBuilder: widget.dissolvenza
          ? (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) {
                return child;
              }

              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: child,
              );
            }
          : null,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _attesa(context),
      errorBuilder: (context, error, stackTrace) {
        _fallita();

        return _attesa(context);
      },
    );
  }
}
