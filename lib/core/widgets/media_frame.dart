import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:flutter/material.dart';

/// Il riquadro in cui vive una foto.
///
/// In CRASY l'immagine e' il contenuto, quindi vale la pena che **un solo
/// widget** sappia come si comporta: che proporzione tiene, cosa mostra mentre
/// arriva, e cosa mostra se non arriva affatto.
///
/// I tre stati sono deliberatamente identici a vedersi — un rettangolo grigio
/// chiaro delle stesse dimensioni. Non c'e' una rotellina che gira, non c'e'
/// un'icona di immagine rotta: qualunque cosa succeda la pagina non si muove di
/// un pixel, e una foto che tarda non fa saltare il titolo sotto.
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

  /// Cosa scrivere sul rettangolo quando la foto non c'e'.
  ///
  /// Serve alle challenge di esempio, che non hanno un'immagine vera: invece di
  /// un buco grigio muto si legge il titolo, e la schermata resta comprensibile.
  final String? caption;

  /// Cio' che poggia **sopra** la foto, gia' ritagliato con lo stesso raggio.
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    return ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Surface(url: url, caption: caption),
            ?overlay,
          ],
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.url, required this.caption});

  final String? url;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final source = url;

    if (source == null || source.isEmpty) {
      return _Placeholder(caption: caption);
    }

    return Image.network(
      source,
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
