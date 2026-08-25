import 'package:crasy/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// Il logotipo di CRASY.
///
/// E' il file vero del marchio, non una scritta ricomposta con il carattere di
/// sistema: "cra" in nero e "sy" in fiamme sono lettere **disegnate**, e
/// riscriverle con un font darebbe qualcosa che gli somiglia e basta.
///
/// L'immagine ha il fondo trasparente, quindi si posa ovunque. E il rosso delle
/// sue fiamme e' esattamente `AppColors.crasyFlame`, quello che l'interfaccia
/// usa per i premi: non e' una somiglianza scelta a occhio, e' il colore
/// campionato da questo file.
class CrasyWordmark extends StatelessWidget {
  const CrasyWordmark({
    this.size = header,
    this.alignment = Alignment.centerLeft,
    super.key,
  });

  /// La misura del marchio in cima a una schermata.
  ///
  /// E' una costante e non un numero scritto ogni volta: bastava un 26 al posto
  /// di un 30 e il logotipo cambiava taglia passando da una scheda all'altra —
  /// una di quelle cose che non si sanno dire ma si vedono.
  static const double header = 28;

  /// Altezza del logotipo. La larghezza segue da se': il file e' gia' ritagliato
  /// sul segno, quindi la sua proporzione e' quella vera.
  final double size;

  /// Dove si posa il segno quando lo spazio a disposizione e' piu' largo di lui.
  ///
  /// Il valore predefinito e' a sinistra, e serve: un `Image` con
  /// `BoxFit.contain` dentro un contenitore largo — una riga espansa, una lista
  /// a tutta pagina — **si centra da solo**, e il logotipo finiva in mezzo allo
  /// schermo senza che nessuno gliel'avesse chiesto.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/crasy-wordmark.png',
      height: size,
      fit: BoxFit.contain,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'CRASY',
    );
  }
}

/// L'intestazione di una scheda: il marchio a sinistra, un comando a destra.
///
/// **Esiste per una ragione sola: tenere il logotipo nello stesso punto in
/// tutte e quattro le schede.** Sembra scontato e non lo era: nella home il
/// marchio stava in una riga insieme al bottone "+", e un `IconButton` occupa
/// quarantotto punti di altezza. La riga cresceva, il logotipo si centrava
/// dentro di essa e finiva **dieci punti piu' in basso** che nelle altre
/// schermate — impossibile da spiegare guardando il codice di una pagina sola,
/// evidentissimo passando da una scheda all'altra.
///
/// Ora l'altezza e' fissa e la decide questo widget, non il bottone che ci
/// finisce dentro: con o senza comando a destra, il segno si posa sempre alla
/// stessa quota.
class CrasyHeader extends StatelessWidget {
  const CrasyHeader({this.middle, this.action, super.key});

  /// Cosa sta **in mezzo**, fra il marchio e i comandi.
  ///
  /// E' il posto piu' prezioso della schermata — l'occhio ci passa sopra ogni
  /// volta che risale in cima — quindi ci va una cosa sola e piccola. Oggi ci
  /// stanno le partecipazioni rimaste per oggi.
  ///
  /// Sta fra due spazi elastici, quindi si trova a meta' strada fra il segno e
  /// i comandi, non al centro dello schermo: e' li' che l'occhio se lo aspetta,
  /// perche' quel centro e' fatto dalle due cose che lo circondano.
  final Widget? middle;

  /// Il comando a destra, se la scheda ne ha uno. Solo la home ce l'ha.
  final Widget? action;

  /// Quanto e' alta la riga.
  ///
  /// Piu' del logotipo, e non per gusto: quarantaquattro punti sono la misura
  /// minima di una cosa che si tocca con un dito. Il marchio ci sta in mezzo,
  /// il bottone ci sta comodo, e nessuna delle due cose muove l'altra.
  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          const CrasyWordmark(),
          const Spacer(),
          ?middle,
          const Spacer(),
          ?action,
        ],
      ),
    );
  }
}

/// Il titolo di una schermata, con il punto rosso in fondo.
///
/// Il punto e' lo stesso segno che chiude il logotipo, ed e' l'unico posto in
/// cui il rosso compare senza essere ne' un premio ne' un comando. Ripeterlo in
/// cima a ogni schermata fa una cosa sola ma la fa bene: **lega le pagine al
/// marchio** senza aggiungere un logo su ognuna.
///
/// Il punto lo mette il widget, non chi lo chiama: cosi' non si finisce con
/// meta' delle schermate che ce l'hanno e meta' no.
class DisplayTitle extends StatelessWidget {
  const DisplayTitle(this.text, {this.style, super.key});

  final String text;

  /// Per i titoli che vogliono un corpo diverso da quello grande.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.toUpperCase()),
          TextSpan(
            text: '.',
            style: TextStyle(color: palette.accent),
          ),
        ],
      ),
      style: style ?? context.texts.displaySmall,
    );
  }
}

/// Una frase con dentro una parola in rosso.
///
/// Serve a una cosa sola: **far cadere l'occhio sulla parola che conta**. In
/// una schermata senza colori, una sola parola rossa in mezzo a una riga grigia
/// si legge prima di tutto il resto — quindi va scelta con attenzione, ed e'
/// sempre quella che dice cosa ci si guadagna o cosa si rischia.
///
/// Se la parola non c'e' nel testo, la frase si mostra intera e senza colore:
/// una scritta a cui manca l'evidenziazione e' molto meglio di una schermata
/// che va in errore per una parola cambiata.
class HighlightedText extends StatelessWidget {
  const HighlightedText(
    this.text, {
    required this.highlight,
    this.style,
    super.key,
  });

  final String text;

  /// La parte da colorare. La prima occorrenza, non tutte: due parole rosse
  /// nella stessa riga non guidano piu' l'occhio da nessuna parte.
  final String highlight;

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? context.texts.bodyMedium;
    final start = text.indexOf(highlight);

    if (start < 0) {
      return Text(text, style: base);
    }

    final end = start + highlight.length;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: highlight,
            style: TextStyle(
              color: context.palette.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
      style: base,
    );
  }
}

/// L'occhiello: una parola in maiuscolo piccolo e spaziato sopra un blocco.
///
/// Fa il lavoro che in un'altra app farebbe un badge colorato — dire di che
/// categoria e' una cosa — senza aggiungere ne' un fondo ne' un colore.
class EyebrowLabel extends StatelessWidget {
  const EyebrowLabel(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.texts.labelSmall?.copyWith(
        color: color ?? context.palette.textFaint,
      ),
    );
  }
}
