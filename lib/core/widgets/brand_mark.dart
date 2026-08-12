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
