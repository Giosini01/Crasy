import 'package:flutter/material.dart';

/// La didascalia scritta **sul bordo della foto**, a elle.
///
/// Parte a meta' del lato sinistro, sale verticale fino all'angolo, gira e
/// prosegue orizzontale lungo il lato alto. Non e' un vezzo grafico: una
/// didascalia messa sotto la foto e' una riga di testo accanto a un'immagine —
/// due cose separate che si guardano una alla volta. Scritta sul bordo diventa
/// **parte dell'oggetto**, come la scritta su una polaroid: si legge insieme
/// alla foto, non dopo.
///
/// **Il testo resta un dato, non diventa pixel.** L'app lo disegna sopra
/// l'immagine ogni volta che la mostra. Cotto dentro il file sarebbe
/// immodificabile e si vedrebbe sgranato su ogni schermo diverso da quello su
/// cui e' stato scritto; cosi' invece resta nitido a qualunque ingrandimento, e
/// la foto originale resta pulita.
class CaptionFrame extends StatelessWidget {
  const CaptionFrame({
    required this.text,
    required this.child,
    this.style,
    this.inset = 10,
    super.key,
  });

  /// Cosa c'e' scritto. Vuoto vuol dire nessuna cornice.
  final String text;

  /// La foto.
  final Widget child;

  final TextStyle? style;

  /// Quanto la scritta sta dentro dal bordo.
  final double inset;

  /// Lo stile predefinito: bianco, piccolo, spaziato, con un'ombra sotto.
  ///
  /// **L'ombra e' obbligatoria e non e' decorazione.** Questa scritta cade su
  /// una foto qualunque, e su una foto chiara il bianco sparisce. Un contorno
  /// scuro appena accennato la tiene leggibile su qualsiasi cosa ci finisca
  /// sotto, senza aggiungere un fondo che coprirebbe l'immagine.
  static TextStyle defaultStyle(BuildContext context) {
    return TextStyle(
      color: Colors.white,
      fontSize: 11,
      height: 1,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w600,
      shadows: const [
        Shadow(color: Colors.black54, blurRadius: 4),
        Shadow(color: Colors.black26, blurRadius: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scritta = text.trim();

    if (scritta.isEmpty) {
      return child;
    }

    final stile = style ?? defaultStyle(context);
    final scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Senza sapere quanto e' grande la foto non si sa dove spezzare la
        // frase, e senza saperlo non si puo' disegnare niente.
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return child;
        }

        // Il tratto verticale parte a meta' altezza e arriva all'angolo:
        // e' mezza foto. Quello orizzontale e' tutto il lato alto.
        final corsaSinistra = constraints.maxHeight / 2 - inset;
        final corsaAlta = constraints.maxWidth - inset * 2;

        if (corsaSinistra <= 0 || corsaAlta <= 0) {
          return child;
        }

        final (sinistra, alto) = _dividi(
          scritta,
          stile: stile,
          scaler: scaler,
          primaCorsa: corsaSinistra,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            // Il tratto che sale. `quarterTurns: 3` gira il testo di novanta
            // gradi in senso antiorario: quello che era il suo inizio a
            // sinistra finisce **in basso**, ed e' li' che deve cominciare.
            Positioned(
              left: inset,
              top: inset,
              child: RotatedBox(
                quarterTurns: 3,
                child: SizedBox(
                  width: corsaSinistra,
                  child: Text(
                    sinistra,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: stile,
                  ),
                ),
              ),
            ),
            if (alto.isNotEmpty)
              Positioned(
                left: inset,
                right: inset,
                top: inset,
                child: Text(
                  alto,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: stile,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Spezza la frase fra il tratto che sale e quello che corre in alto.
  ///
  /// Si taglia **sull'ultimo spazio che ci sta**, non a caratteri: una parola
  /// spezzata a meta' dall'angolo non si legge piu' come una parola, e l'angolo
  /// e' gia' il punto piu' difficile da seguire con l'occhio.
  ///
  /// Se la prima parola e' cosi' lunga da non starci nemmeno da sola, si taglia
  /// dove capita: meglio una parola spezzata che una cornice vuota.
  static (String, String) _dividi(
    String testo, {
    required TextStyle stile,
    required TextScaler scaler,
    required double primaCorsa,
  }) {
    if (_larghezza(testo, stile, scaler) <= primaCorsa) {
      return (testo, '');
    }

    // Quanti caratteri ci stanno: si cerca a meta' invece che uno per uno,
    // perche' misurare del testo non e' gratis e questo gira a ogni tasto
    // mentre si scrive.
    var basso = 0;
    var alto = testo.length;

    while (basso < alto) {
      final mezzo = (basso + alto + 1) ~/ 2;

      if (_larghezza(testo.substring(0, mezzo), stile, scaler) <= primaCorsa) {
        basso = mezzo;
      } else {
        alto = mezzo - 1;
      }
    }

    if (basso <= 0) {
      return ('', testo);
    }

    final spazio = testo.lastIndexOf(' ', basso);
    final taglio = spazio > 0 ? spazio : basso;

    return (testo.substring(0, taglio), testo.substring(taglio).trimLeft());
  }

  static double _larghezza(String testo, TextStyle stile, TextScaler scaler) {
    final pittore = TextPainter(
      text: TextSpan(text: testo, style: stile),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();

    final larghezza = pittore.width;
    pittore.dispose();

    return larghezza;
  }
}
