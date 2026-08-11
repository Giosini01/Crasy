import 'package:app_incontri/core/theme/app_palette.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:flutter/material.dart';

/// Il logotipo "Rawsy".
///
/// E' il file vero del marchio, non una scritta ricostruita col carattere
/// dell'app: un logotipo ha lettere disegnate, e riscriverlo col font di
/// sistema darebbe qualcosa che gli somiglia e basta.
///
/// Ne esistono **due versioni**, ed e' una necessita', non una scelta di
/// gusto: nell'originale "Raw" e' bianco, e su un fondo chiaro sparirebbe.
/// Sul chiaro "Raw" diventa quindi quasi nero; la coda "sy" resta viola in
/// entrambe, perche' e' quella a portare il marchio.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({this.height = 26, this.onDark = false, super.key});

  /// Altezza del logotipo. La larghezza segue da se': l'immagine e' gia'
  /// ritagliata sul segno, quindi la sua proporzione e' quella vera.
  final double height;

  /// Vero quando il logotipo poggia su una foto o su una superficie scura.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      onDark ? 'assets/brand/rawsy.png' : 'assets/brand/rawsy-light.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Rawsy',
    );
  }
}

/// Etichetta di sezione in maiuscoletto spaziato.
class EyebrowLabel extends StatelessWidget {
  const EyebrowLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.texts.labelSmall?.copyWith(
        color: context.palette.textSecondary,
      ),
    );
  }
}

/// Riquadro con icona per le sezioni ancora vuote.
class GlyphTile extends StatelessWidget {
  const GlyphTile({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: palette.brandTint,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, size: 26, color: palette.brand),
    );
  }
}
