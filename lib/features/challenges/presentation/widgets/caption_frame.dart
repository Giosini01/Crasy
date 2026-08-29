import 'package:flutter/material.dart';

/// La didascalia come una **nuvoletta** posata sulla foto.
///
/// E' la forma delle istantanee di Instagram: un rettangolo bianco con gli
/// angoli tondissimi, il testo scuro dentro, e sotto a sinistra due bollicine
/// che scendono verso chi l'ha detta.
///
/// ## Perche' una nuvoletta e non una riga sotto la foto
///
/// Una didascalia messa sotto e' una riga di testo **accanto** a un'immagine:
/// due cose separate, che si guardano una alla volta. Dentro la foto invece
/// diventa parte dell'oggetto, e si legge insieme. E la forma della nuvoletta
/// aggiunge la cosa che nessun rettangolo dice: che quelle parole le ha **dette
/// qualcuno**. Non e' una didascalia da catalogo, e' una voce.
///
/// Prima correva sul bordo a elle — su per il lato sinistro e poi lungo quello
/// alto. Era bello e sbagliato: su una foto verticale la frase girava l'angolo
/// e l'occhio doveva girare con lei, quindi si leggeva **dopo** aver deciso di
/// leggerla. Una nuvoletta si legge senza deciderlo.
///
/// ## Il testo resta un dato, non diventa pixel
///
/// L'app lo disegna sopra l'immagine ogni volta che la mostra. Cotto dentro il
/// file sarebbe immodificabile e si vedrebbe sgranato su ogni schermo diverso
/// da quello su cui e' stato scritto; cosi' invece resta nitido a qualunque
/// ingrandimento, e la foto originale resta pulita.
class CaptionFrame extends StatelessWidget {
  const CaptionFrame({
    required this.text,
    required this.child,
    this.style,
    this.sizeFactor = 0.045,
    super.key,
  });

  /// Cosa c'e' scritto. Vuoto vuol dire nessuna nuvoletta.
  final String text;

  /// La foto.
  final Widget child;

  /// Da cui si prendono colore e peso. La **misura** la decide la foto: vedi
  /// [sizeFactor].
  final TextStyle? style;

  /// Quanto e' alta la scritta, in frazione del lato corto della foto.
  ///
  /// **Proporzionale e non in punti fissi.** Una misura fissa e' grande su
  /// un'anteprima e minuscola sulla stessa foto a tutto schermo: la nuvoletta
  /// fa parte dell'immagine, quindi cresce con lei — come farebbe un adesivo
  /// appiccicato sopra.
  final double sizeFactor;

  /// Sotto e sopra questi due non si va.
  ///
  /// Il minimo perche' una scritta piu' piccola non si legge; il massimo perche'
  /// su una foto molto grande la nuvoletta smetterebbe di essere un dettaglio e
  /// diventerebbe un cartello.
  static const double minFontSize = 12;
  static const double maxFontSize = 20;

  /// Quanto la nuvoletta sta dentro dal bordo, in frazione del lato corto.
  static const double _insetFactor = 0.045;

  /// Lo stile predefinito: scuro su bianco, come su Instagram.
  ///
  /// **Niente bianco su foto.** La scritta bianca senza fondo obbliga a
  /// un'ombra per restare leggibile su un'immagine chiara, e un'ombra su una
  /// lettera bianca e' sempre un compromesso che si vede. Con il fondo pieno la
  /// leggibilita' non dipende piu' da cosa c'e' sotto.
  static TextStyle defaultStyle(BuildContext context) {
    return const TextStyle(
      color: Color(0xFF141414),
      fontSize: minFontSize,
      height: 1.25,
      fontWeight: FontWeight.w600,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scritta = text.trim();

    if (scritta.isEmpty) {
      return child;
    }

    final base = style ?? defaultStyle(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Senza sapere quanto e' grande la foto non si sa quanto fare grande la
        // nuvoletta, e una misura indovinata sarebbe sbagliata su meta' degli
        // schermi.
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return child;
        }

        final latoCorto = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final inset = latoCorto * _insetFactor;
        final corpo = (latoCorto * sizeFactor).clamp(minFontSize, maxFontSize);

        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            // **In basso a sinistra, non in mezzo.** E' il posto in cui su
            // Instagram sta la nuvoletta rispetto a chi parla, ed e' anche il
            // posto che copre meno la foto: il soggetto di uno scatto sta quasi
            // sempre al centro o in alto.
            Positioned(
              left: inset,
              bottom: inset,
              right: inset,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: _Bubble(
                  text: scritta,
                  style: base.copyWith(fontSize: corpo),
                  maxWidth: (constraints.maxWidth - inset * 2) * 0.82,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// La nuvoletta vera e propria, con la sua coda di bollicine.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.style,
    required this.maxWidth,
  });

  final String text;
  final TextStyle style;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final corpo = style.fontSize ?? CaptionFrame.minFontSize;

    // Tutto in proporzione al corpo: cosi' la nuvoletta cresce **intera** con
    // la foto. Con margini fissi, ingrandendo il testo la scritta finirebbe
    // contro il bordo bianco.
    final orizzontale = corpo * 0.95;
    final verticale = corpo * 0.62;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: orizzontale,
              vertical: verticale,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              // **Il raggio segue l'altezza, quindi su una riga sola e' una
              // pillola.** E' quello che rende la forma *curvata* invece che
              // "un rettangolo con gli angoli smussati": la differenza fra le
              // due sta tutta in quanto il raggio si avvicina a mezza altezza.
              borderRadius: BorderRadius.circular(corpo * 1.6),
              boxShadow: [
                // Appena accennata, e serve: una nuvoletta bianca su una foto
                // molto chiara sparirebbe nel fondo, e quello che resterebbe
                // sarebbe del testo scuro sospeso nel nulla.
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: corpo * 0.7,
                  offset: Offset(0, corpo * 0.15),
                ),
              ],
            ),
            child: Text(
              text,
              // Quattro righe e poi si taglia. Una nuvoletta che copre mezza
              // foto ha smesso di essere un commento alla foto.
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ),
        // **La coda: due bollicine che scendono.** E' il segno che trasforma un
        // riquadro in una cosa detta da qualcuno. Sono due e di misura diversa
        // perche' una sola sembra un errore di allineamento, e tre sembrano un
        // caricamento in corso.
        Padding(
          padding: EdgeInsets.only(left: corpo * 0.9, top: corpo * 0.22),
          child: _Dot(size: corpo * 0.42),
        ),
        Padding(
          padding: EdgeInsets.only(left: corpo * 0.7, top: corpo * 0.16),
          child: _Dot(size: corpo * 0.24),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: size * 0.8,
          ),
        ],
      ),
    );
  }
}
