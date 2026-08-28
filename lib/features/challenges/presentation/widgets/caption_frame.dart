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
    this.sizeFactor = 0.085,
    super.key,
  });

  /// Cosa c'e' scritto. Vuoto vuol dire nessuna cornice.
  final String text;

  /// La foto.
  final Widget child;

  /// Da cui si prendono colore, peso e ombra. La **misura** la decide la foto:
  /// vedi [sizeFactor].
  final TextStyle? style;

  /// Quanto e' alta la scritta, in frazione del lato corto della foto.
  ///
  /// **Proporzionale e non in punti fissi.** Una misura fissa e' grande su
  /// un'anteprima e minuscola sulla stessa foto a tutto schermo: la scritta fa
  /// parte dell'immagine, quindi deve crescere con lei, come farebbe una scritta
  /// vera stampata sopra.
  final double sizeFactor;

  /// Sotto questa misura non si scende, nemmeno per far entrare tutto.
  ///
  /// Una didascalia rimpicciolita fino a diventare illeggibile non e' piu' una
  /// didascalia. Da qui in giu' si preferisce tagliare la coda.
  static const double minFontSize = 13;

  /// Quanto la scritta sta dentro dal bordo, in frazione del lato corto.
  static const double _insetFactor = 0.035;

  /// Lo stile predefinito: bianco, grasso, spaziato, con un'ombra sotto.
  ///
  /// **L'ombra e' obbligatoria e non e' decorazione.** Questa scritta cade su
  /// una foto qualunque, e su una foto chiara il bianco sparisce. Un contorno
  /// scuro appena accennato la tiene leggibile su qualsiasi cosa ci finisca
  /// sotto, senza aggiungere un fondo che coprirebbe l'immagine.
  ///
  /// Il corpo scritto qui e' solo un ripiego: quello vero lo calcola [build]
  /// sulla misura della foto.
  static TextStyle defaultStyle(BuildContext context) {
    return const TextStyle(
      color: Colors.white,
      fontSize: minFontSize,
      height: 1,
      fontWeight: FontWeight.w700,
      shadows: [
        Shadow(color: Colors.black87, blurRadius: 6),
        Shadow(color: Colors.black45, blurRadius: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scritta = text.trim();

    if (scritta.isEmpty) {
      return child;
    }

    final base = style ?? defaultStyle(context);
    final scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Senza sapere quanto e' grande la foto non si sa dove spezzare la
        // frase, e senza saperlo non si puo' disegnare niente.
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return child;
        }

        final latoCorto = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final inset = latoCorto * _insetFactor;

        // **All'angolo le due scritte si darebbero addosso.**
        //
        // La fascia verticale e' larga quanto e' alta una riga di testo, cioe'
        // quanto il corpo. Facendo partire quella orizzontale dallo stesso
        // bordo sinistro, le prime lettere di sopra cadrebbero sulle ultime di
        // lato: un groviglio proprio nel punto in cui l'occhio deve girare.
        // Alla misura piccola erano dieci pixel e non si notava; ingrandendo il
        // testo diventa la prima cosa che si vede.
        //
        // Quindi la riga di sopra comincia **dopo** la fascia, con un po' d'aria
        // in mezzo. Quel vuoto e' l'angolo, ed e' giusto che ci sia: e' li' che
        // la frase gira.
        final corpoVoluto = latoCorto * sizeFactor;
        final angolo = corpoVoluto * 1.35;

        // Il tratto verticale parte a meta' altezza e arriva all'angolo: e'
        // mezza foto. Quello orizzontale e' il lato alto meno l'angolo.
        final corsaSinistra = constraints.maxHeight / 2 - inset;
        final corsaAlta = constraints.maxWidth - inset * 2 - angolo;

        if (corsaSinistra <= 0 || corsaAlta <= 0) {
          return child;
        }

        // L'angolo si toglie usando il corpo **voluto**, non quello che uscira'
        // dal calcolo: se il testo poi rimpicciolisce, la corsa vera sara' un
        // po' piu' lunga di quella su cui si e' deciso. Sbagliare da questa
        // parte vuol dire un po' di spazio avanzato; dall'altra, una parola
        // tagliata.
        final stile = _stileCheEntra(
          scritta,
          base: base,
          scaler: scaler,
          corpoVoluto: corpoVoluto,
          corsaTotale: corsaSinistra + corsaAlta,
        );

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
                // Dopo l'angolo, non dal bordo: e' qui che si evita il
                // groviglio con le ultime lettere del tratto che sale.
                left: inset + angolo,
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

  /// Il corpo piu' grande con cui la frase ci sta ancora tutta.
  ///
  /// **Serve perche' la cornice ha una lunghezza fissa.** Il percorso e' mezza
  /// altezza piu' una larghezza, e quel tanto e' quello: ingrandendo il testo si
  /// arriva presto al punto in cui l'ultima parola cade oltre l'angolo in basso
  /// a destra e sparisce senza dire niente. Una didascalia tagliata a meta' e'
  /// peggio di una didascalia un po' piu' piccola.
  ///
  /// Si parte dal corpo voluto e si scende a scalini finche' entra, mai sotto
  /// [minFontSize]: sotto quella misura non si legge piu' comunque, e a quel
  /// punto tanto vale tagliare.
  ///
  /// La spaziatura fra le lettere segue il corpo: fissa, su un testo grande
  /// diventa invisibile e su uno piccolo lo sfilaccia.
  static TextStyle _stileCheEntra(
    String testo, {
    required TextStyle base,
    required TextScaler scaler,
    required double corpoVoluto,
    required double corsaTotale,
  }) {
    var corpo = corpoVoluto < minFontSize ? minFontSize : corpoVoluto;

    // Otto scalini bastano a dimezzare il corpo, e sono otto misurazioni: questo
    // conto gira a ogni tasto mentre si scrive, e non deve pesare.
    for (var scalino = 0; scalino < 8; scalino++) {
      final stile = base.copyWith(
        fontSize: corpo,
        letterSpacing: corpo * 0.06,
      );

      // Il margine di sicurezza copre lo spazio che si perde tagliando la frase
      // su una parola invece che su un carattere qualunque.
      if (_larghezza(testo, stile, scaler) <= corsaTotale * 0.94) {
        return stile;
      }

      final piuPiccolo = corpo * 0.9;

      if (piuPiccolo < minFontSize) {
        break;
      }

      corpo = piuPiccolo;
    }

    return base.copyWith(fontSize: corpo, letterSpacing: corpo * 0.06);
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
