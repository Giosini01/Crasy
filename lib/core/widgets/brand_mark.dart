import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
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
    this.onDark = false,
    this.beta = true,
    super.key,
  });

  /// L'etichetta **beta** accanto al segno.
  ///
  /// **Sta attaccata al marchio e non in un angolo dello schermo**, ed e' il
  /// punto: chi apre l'app deve sapere che sta usando una cosa non finita
  /// **mentre** legge come si chiama, non dopo averla cercata. Una scritta in
  /// fondo alla schermata delle impostazioni non l'ha mai letta nessuno.
  ///
  /// Si spegne su un trofeo: li' il marchio non e' l'intestazione di una
  /// schermata, e' il retro di una figurina — un oggetto che si tiene, e su cui
  /// una targhetta provvisoria non ha senso.
  final bool beta;

  /// Il segno per i fondi scuri: **lettere bianche, fiamme rosse**.
  ///
  /// E' un secondo file, non un filtro sul primo. Ridipingere tutto di bianco
  /// spegnerebbe anche le fiamme, e le fiamme sono la meta' del marchio: quello
  /// che resterebbe sarebbe la parola, non il segno.
  final bool onDark;

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
    final segno = Image.asset(
      onDark
          ? 'assets/brand/crasy-wordmark-dark.png'
          : 'assets/brand/crasy-wordmark.png',
      height: size,
      fit: BoxFit.contain,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'CRASY',
    );

    if (!beta || onDark) {
      return segno;
    }

    // **La riga esterna serve, e non e' un involucro di troppo.**
    //
    // La colonna qui dentro allinea a destra — "beta" va sotto la coda della
    // "y" — ma una colonna dentro un elenco prende **tutta** la larghezza della
    // pagina, e allineare a destra vuol dire mandare a destra anche il
    // logotipo. E' successo: nella schermata di accesso il marchio e' finito
    // dall'altra parte. La riga stretta attorno tiene la colonna larga quanto
    // il segno, cosi' "a destra" vuol dire *a destra del marchio* e non *a
    // destra dello schermo*.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            segno,
            Padding(
              padding: EdgeInsets.only(top: size * 0.04, right: size * 0.02),
              // Un terzo del marchio: sotto, la parola si leggeva come una
              // macchia e non come una parola.
              child: _BetaWord(size: size * 0.36),
            ),
          ],
        ),
      ],
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

/// La barra in alto, **ferma**.
///
/// E' [CrasyHeader] con i suoi margini, pensato per stare **fuori** da cio' che
/// scorre: in cima alla schermata, con il contenuto in un [Expanded] sotto.
///
/// Perche' non scorre piu' via. Il marchio in cima e' l'unica cosa che dice in
/// che app sei; se se ne va con la prima passata di dito, dopo due schermate
/// stai guardando un elenco che potrebbe essere di chiunque. E nella home ci
/// vive dentro un dato che serve **mentre** si scorre — le partecipazioni
/// rimaste per oggi — che tornando in cima a controllare arriverebbe sempre
/// tardi.
///
/// Il prezzo e' onesto e vale la pena dirlo: settantadue punti di schermo che
/// non si possono piu' recuperare scorrendo. Su un telefono piccolo sono un
/// decimo dell'altezza. In cambio, quattro schede su cinque hanno lo stesso
/// punto fermo in cima, e la quinta — la ricerca — ce l'aveva gia'.
class CrasyHeaderBar extends StatelessWidget {
  const CrasyHeaderBar({this.middle, this.action, super.key});

  /// Cosa sta in mezzo, fra il marchio e i comandi. Vedi [CrasyHeader.middle].
  final Widget? middle;

  /// Il comando a destra, se la scheda ne ha uno.
  final Widget? action;

  /// L'aria sopra, la riga del marchio, l'aria sotto.
  ///
  /// Serve a chi deve lasciare spazio a questa barra senza indovinare un
  /// numero: un margine scritto a mano qui e' un margine che il giorno che la
  /// barra cambia altezza resta indietro.
  static const double height =
      AppSpacing.md + CrasyHeader.height + AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        // **Il margine a destra dipende da cosa c'e'.** Un bottone con l'icona
        // porta con se' il proprio spazio interno, quindi con il margine pieno
        // l'icona finirebbe otto punti piu' dentro del marchio a sinistra — uno
        // sbilanciamento che non si sa spiegare ma si vede.
        action == null ? AppSpacing.page : AppSpacing.page - AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: CrasyHeader(middle: middle, action: action),
    );
  }
}

/// La parola sotto il marchio: **be** nero, **ta** rosso.
///
/// Ripete la regola del logotipo — una meta' neutra e una in fiamme — e la
/// ripete sulle stesse due lettere finali, cosi' la seconda meta' rossa cade
/// sotto la "sy" rossa che le sta sopra. Non e' un caso che si legga come una
/// firma: e' la stessa cosa scritta due volte, in piccolo.
///
/// **Niente fondo colorato e niente riquadro.** Una pillola scura accanto a un
/// logotipo su fondo bianco e' un secondo oggetto che compete con il primo; qui
/// invece la parola appartiene al marchio, e per farlo deve essere fatta della
/// stessa sostanza — inchiostro su carta, e basta.
///
/// Il carattere e' quello di sistema al peso piu' grasso che ha, con la
/// spaziatura stretta. Le lettere del logotipo sono **disegnate** e nessun font
/// le riproduce; questo e' quanto ci si avvicina senza portarsi dietro un file
/// di caratteri solo per quattro lettere.
class _BetaWord extends StatelessWidget {
  const _BetaWord({required this.size});

  /// L'altezza delle lettere. Tutto il resto si ricava da qui, cosi' la parola
  /// cresce **insieme** al marchio invece di avere una misura sua.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'be'),
          TextSpan(
            text: 'ta',
            style: TextStyle(color: context.palette.accent),
          ),
        ],
      ),
      style: TextStyle(
        fontSize: size,
        height: 1,
        fontWeight: FontWeight.w900,
        // Stretta: il logotipo ha le lettere quasi attaccate, e una parola
        // spaziata sotto di lui sembrerebbe di un'altra famiglia.
        letterSpacing: -size * 0.02,
        color: context.palette.textPrimary,
      ),
    );
  }
}
