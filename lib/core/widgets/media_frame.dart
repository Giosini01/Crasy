import 'dart:convert';
import 'dart:typed_data';

import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/widgets/video_frame.dart';
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
    this.radius = AppRadius.media,
    this.caption,
    this.overlay,
    this.video = false,
    this.autoplay = true,
    this.mine = false,
    super.key,
  });

  final String? url;

  /// Se questa e' **la mia** partecipazione.
  ///
  /// La incornicia di rosso. In una griglia di dodici quadrati tutti uguali,
  /// ritrovare la propria vuol dire leggere dodici nomi sotto le foto: il
  /// riquadro la fa saltare fuori senza leggere niente. E' l'unico posto in cui
  /// il rosso non indica ne' un premio ne' una fiamma ma **te**, e va bene
  /// cosi': in mezzo a quella griglia, tu sei la cosa che stai cercando.
  final bool mine;

  /// Se il contenuto e' un video invece che una foto.
  ///
  /// Lo dice la partecipazione, non l'indirizzo: indovinare dall'estensione del
  /// file sarebbe fragile — gli indirizzi di Storage finiscono con un gettone,
  /// non con `.mp4`.
  final bool video;

  /// Se un video deve **partire da solo**.
  ///
  /// Vero dove il contenuto e' la cosa che si guarda. **Falso nelle griglie**:
  /// li' ogni quadrato apriva il proprio lettore e mandava il video in ciclo —
  /// venti file scaricati insieme e all'infinito per venti francobolli che
  /// nessuno sta guardando. Vedi `VideoFrame.autoplay`.
  final bool autoplay;

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
            if (video)
              VideoFrame(url: url!, caption: caption, autoplay: autoplay)
            else
              _Surface(url: url!, caption: caption),
            ?overlay,
            if (mine)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: context.palette.accent, width: 2),
                    borderRadius: borderRadius,
                  ),
                ),
              ),
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

  /// Una foto che non e' su nessun server: i byte stanno dentro l'indirizzo.
  ///
  /// Serve alle challenge di esempio, dove non c'e' Storage. Senza questo, una
  /// foto appena scattata in prova non si vedrebbe da nessuna parte —
  /// esisterebbe solo come partecipazione senza immagine.
  static const _dataPrefix = 'data:';

  @override
  Widget build(BuildContext context) {
    if (url.startsWith(_dataPrefix)) {
      return Image.memory(
        _decodeDataUri(url),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _Placeholder(caption: caption),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      // Su web Flutter scarica le immagini con `fetch` e le disegna sulla tela,
      // e questo richiede che il server mandi le intestazioni CORS. Il bucket
      // di Firebase Storage non le manda finche' non gliele si configura a
      // mano, e il risultato e' che **le foto non compaiono e nessuno dice
      // perche'**: niente errore, solo un riquadro vuoto.
      //
      // Con questo, quando il disegno sulla tela fallisce, Flutter ripiega su
      // un vero elemento `<img>` del browser — che le foto le mostra da sempre
      // senza chiedere permesso a nessuno. Su telefono la riga non ha alcun
      // effetto.
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
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

/// Estrae i byte da un indirizzo `data:image/jpeg;base64,...`.
///
/// Se la stringa e' malformata torna un vuoto invece di sollevare: la foto non
/// si vedra', ma un indirizzo storto non deve far cadere la schermata che la
/// contiene.
Uint8List _decodeDataUri(String uri) {
  final comma = uri.indexOf(',');

  if (comma < 0) {
    return Uint8List(0);
  }

  try {
    return base64Decode(uri.substring(comma + 1));
  } on FormatException {
    return Uint8List(0);
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
