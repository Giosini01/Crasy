import 'dart:convert';
import 'dart:typed_data';

import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/widgets/flame_waiting.dart';
import 'package:crasy/core/widgets/foto_dalla_rete.dart';
import 'package:crasy/core/widgets/video_frame.dart';
import 'package:crasy/features/challenges/domain/entities/ritaglio.dart';
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
    this.muted = false,
    this.soundOnTap = false,
    this.mine = false,
    this.ritaglio,
    this.anteprima,
    super.key,
  });

  final String? url;

  /// **La miniatura della stessa foto, da mostrare mentre arriva [url].**
  ///
  /// Le schede a tutta larghezza mostrano l'originale — la miniatura li' si
  /// vedrebbe sgranata — ma l'originale pesa quattro volte tanto, e con poca
  /// rete al suo posto c'era la fiamma che girava. La miniatura invece e'
  /// leggera, e quasi sempre gia' sul telefono: si vede subito, e la foto
  /// nitida ci si posa sopra appena arriva.
  final String? anteprima;

  /// Se il video va guardato senza audio: lo decide chi l'ha mandato.
  final bool muted;

  /// Se il tocco sul video accende e spegne l'audio invece di aprire i comandi.
  final bool soundOnTap;

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

  /// **La cornice scelta nell'editor**, se c'e'. La foto e' intera; qui se ne
  /// mostra solo la parte inquadrata, come la si e' vista prima di mandarla.
  /// Vale solo nei riquadri quattro quinti, che sono quelli dell'editor: in
  /// un riquadro di altra forma la cornice si deformerebbe, e si torna al
  /// taglio al centro.
  final Ritaglio? ritaglio;

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
              VideoFrame(
                url: url!,
                caption: caption,
                autoplay: autoplay,
                muted: muted,
              )
            else
              _Surface(
                url: url!,
                anteprima: anteprima,
                caption: caption,
                ritaglio: (aspectRatio - 4 / 5).abs() < 0.01 ? ritaglio : null,
              ),
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
  const _Surface({
    required this.url,
    required this.caption,
    this.ritaglio,
    this.anteprima,
  });

  final String url;
  final String? caption;
  final Ritaglio? ritaglio;

  /// Vedi [MediaFrame.anteprima].
  final String? anteprima;

  /// Una foto che non e' su nessun server: i byte stanno dentro l'indirizzo.
  ///
  /// Serve alle challenge di esempio, dove non c'e' Storage. Senza questo, una
  /// foto appena scattata in prova non si vedrebbe da nessuna parte —
  /// esisterebbe solo come partecipazione senza immagine.
  static const _dataPrefix = 'data:';

  @override
  Widget build(BuildContext context) {
    final cornice = ritaglio;

    if (cornice == null) {
      return _immagine(BoxFit.cover);
    }

    // **La foto intera, ingrandita e spostata fino a riempire il riquadro con
    // la sola parte inquadrata.** In frazioni: se la cornice e' meta' della
    // foto, la foto si disegna due volte il riquadro, e si sposta indietro di
    // quanto la cornice stava avanti.
    return LayoutBuilder(
      builder: (context, vincoli) {
        final larga = vincoli.maxWidth / cornice.larghezza;
        final alta = vincoli.maxHeight / cornice.altezza;

        return ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: -cornice.x * larga,
                top: -cornice.y * alta,
                width: larga,
                height: alta,
                child: _immagine(BoxFit.fill),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _immagine(BoxFit fit) {
    if (url.startsWith(_dataPrefix)) {
      return Image.memory(
        _decodeDataUri(url),
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            _Placeholder(caption: caption),
      );
    }

    // **Se non arriva, riprova da sola**, e resta sul telefono: vedi
    // [FotoDallaRete]. Mentre arriva, la fiamma che gira sopra il riquadro;
    // se dopo tutti i tentativi non e' arrivata, un tocco per riprovare.
    return FotoDallaRete(
      url: url,
      fit: fit,
      inAttesa: (context) {
        final piccola = anteprima ?? '';

        return Stack(
          fit: StackFit.expand,
          children: [
            _Placeholder(caption: caption),
            // La miniatura sotto, se c'e' e non e' la stessa foto: vedi
            // [MediaFrame.anteprima]. Finche' non arriva nemmeno lei, la
            // fiamma.
            if (piccola.isNotEmpty && piccola != url)
              FotoDallaRete(
                url: piccola,
                fit: fit,
                dissolvenza: false,
                inAttesa: (context) =>
                    const Center(child: FiammaCheGira(misura: 32)),
              )
            else
              const Center(child: FiammaCheGira(misura: 32)),
          ],
        );
      },
      inErrore: (context, riprova) => GestureDetector(
        onTap: riprova,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Placeholder(caption: caption),
            Center(
              child: Icon(
                Icons.refresh_rounded,
                color: context.palette.textFaint,
                semanticLabel: 'Riprova a caricare la foto',
              ),
            ),
          ],
        ),
      ),
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
