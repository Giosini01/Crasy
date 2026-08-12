import 'package:crasy/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// Il logotipo di CRASY.
///
/// E' composto, non disegnato: cinque lettere del carattere di sistema in nero
/// pieno, strette fra loro, e un punto rosso. In un'app che ha deciso di non
/// avere colori, il **punto** e' l'unico posto in cui il rosso compare senza
/// essere ne' un premio ne' un comando — ed e' esattamente cosi' che un colore
/// diventa il colore di un marchio.
///
/// Il tracking negativo non e' un vezzo: a peso 800 le lettere spaziate
/// normalmente si leggono come una parola qualunque, serrate diventano un
/// segno.
class CrasyWordmark extends StatelessWidget {
  const CrasyWordmark({this.size = 22, this.onDark = false, super.key});

  final double size;

  /// Vero quando il logotipo poggia su una foto o su un fondo scuro.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = onDark ? palette.background : palette.textPrimary;

    return Semantics(
      label: 'CRASY',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'CRASY',
                style: TextStyle(color: color),
              ),
              TextSpan(
                text: '.',
                style: TextStyle(color: palette.accent),
              ),
            ],
          ),
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            height: 1,
          ),
        ),
      ),
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
