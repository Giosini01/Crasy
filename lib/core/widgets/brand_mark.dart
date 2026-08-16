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
    this.size = 22,
    this.alignment = Alignment.centerLeft,
    super.key,
  });

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
