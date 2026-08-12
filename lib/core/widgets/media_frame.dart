import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:flutter/material.dart';

/// Il riquadro in cui vive una foto.
///
/// In CRASY l'immagine e' il contenuto, quindi vale la pena che **un solo
/// widget** sappia come si comporta: che proporzione tiene, cosa mostra mentre
/// arriva, e cosa fa se non arriva affatto.
///
/// Quest'ultimo caso ha una risposta sola: **non occupa spazio**. Senza un
/// indirizzo il widget sparisce del tutto invece di lasciare un rettangolo
/// grigio, perche' un rettangolo grigio non e' una foto mancante — e' una
/// schermata che sembra rotta. Una challenge senza immagine e' semplicemente
/// premio, titolo e comando, e sta benissimo cosi'.
///
/// Mentre la foto arriva il grigio c'e' invece eccome: li' lo spazio va tenuto,
/// altrimenti il titolo sotto salta appena l'immagine si posa.
class MediaFrame extends StatelessWidget {
  const MediaFrame({
    required this.url,
    this.aspectRatio = 4 / 5,
    this.radius = AppRadius.md,
    this.caption,
    this.overlay,
    super.key,
  });

  final String? url;
  final double aspectRatio;
  final double radius;

  /// Cosa scrivere sul riquadro mentre la foto sta arrivando.
  final String? caption;

  /// Cio' che poggia **sopra** la foto, gia' ritagliato con lo stesso raggio.
  final Widget? overlay;

  /// Vero se [url] contiene qualcosa da mostrare.
  static bool hasMedia(String? url) => url != null && url.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!hasMedia(url)) {
      return const SizedBox.shrink();
    }

    final borderRadius = BorderRadius.circular(radius);

    return ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Surface(url: url!, caption: caption),
            ?overlay,
          ],
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.url, required this.caption});

  final String url;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      // La foto entra con una dissolvenza breve invece di apparire di scatto.
      // E' l'unica animazione dell'immagine, e dura meno di un battito.
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return child;
        }

        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: child,
        );
      },
      loadingBuilder: (context, child, progress) {
        return progress == null ? child : _Placeholder(caption: caption);
      },
      errorBuilder: (context, error, stackTrace) {
        return _Placeholder(caption: caption);
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.caption});

  final String? caption;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = caption?.trim() ?? '';

    return ColoredBox(
      color: palette.surfaceMuted,
      child: text.isEmpty
          ? null
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  text.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.headlineSmall?.copyWith(
                    color: palette.textFaint,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
    );
  }
}
