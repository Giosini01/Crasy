import 'dart:io';
import 'dart:ui' as ui;

import 'package:crasy/core/services/share/share_entry.dart';
import 'package:crasy/core/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// **Una propria foto su Instagram Stories, con la missione e il marchio.**
///
/// La foto e' la protagonista: intera, senza tagli, al centro. Sopra, la
/// missione per cui e' stata scattata — e' la storia dietro la foto, ed e'
/// quello che fa venire voglia di provarci. Sotto, piccolo, il marchio.
///
/// ## Come arriva a Instagram
///
/// Con il sistema ufficiale di Meta per le Storie: su iPhone l'immagine passa
/// dagli appunti e si apre `instagram-stories://`, su Android con l'intento
/// `com.instagram.share.ADD_TO_STORY` (vedi `AppDelegate.swift` e
/// `MainActivity.kt`, canale `crasy/instagram`). **Meta chiede l'ID di
/// un'app Facebook** (`--dart-define=CRASY_META_APP_ID`): senza, o senza
/// Instagram installato, si apre la condivisione del telefono con l'immagine
/// pronta — da li' Instagram → Storia funziona lo stesso, con un tocco in piu'.
///
/// ## Il link
///
/// L'API delle Storie **non aggiunge lo sticker Link**: lo puo' mettere solo
/// chi pubblica. Quindi il link si copia negli appunti prima di aprire
/// Instagram, e si spiega in una riga come incollarlo. E' il link della foto
/// (`ShareEntry.linkTo`), che apre CRASY a chi ce l'ha e il sito a chi no, con
/// in piu' chi l'ha condivisa (`da`) per poter contare un giorno chi porta chi.
abstract final class InstagramStory {
  static const _filo = MethodChannel('crasy/instagram');

  /// L'ID dell'app su Meta, che Instagram chiede per aprire le Storie.
  static const appIdMeta = String.fromEnvironment('CRASY_META_APP_ID');

  static const larghezza = 1080;
  static const altezza = 1920;

  /// Solo sui telefoni: sul sito non c'e' Instagram da aprire.
  static bool get possibile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Il link da incollare nello sticker.
  static String link({
    required String challengeId,
    required String entryId,
    required String challengeTitle,
    required String authorName,
    required String userId,
  }) {
    final base = Uri.parse(
      ShareEntry.linkTo(
        challengeId: challengeId,
        entryId: entryId,
        challengeTitle: challengeTitle,
        authorName: authorName,
      ),
    );

    return base
        .replace(
          queryParameters: {
            ...base.queryParameters,
            'da': userId,
            'utm_source': 'instagram',
            'utm_medium': 'story',
          },
        )
        .toString();
  }

  /// La foto, scaricata dal suo indirizzo.
  static Future<Uint8List> scarica(String indirizzo) async {
    final client = HttpClient();

    try {
      final richiesta = await client.getUrl(Uri.parse(indirizzo));
      final risposta = await richiesta.close();

      if (risposta.statusCode != 200) {
        throw const ErroreStoria('La foto non si scarica. Riprova fra poco.');
      }

      return await consolidateHttpClientResponseBytes(risposta);
    } on ErroreStoria {
      rethrow;
    } on Object {
      throw const ErroreStoria(
        'La foto non si scarica: controlla la connessione.',
      );
    } finally {
      client.close();
    }
  }

  /// **Prova ad aprire direttamente le Storie.** Falso se non si puo': senza
  /// l'ID di Meta, senza Instagram, o se Instagram rifiuta.
  static Future<bool> apriLeStorie(Uint8List immagine) async {
    if (!possibile || appIdMeta.isEmpty) {
      return false;
    }

    try {
      return await _filo.invokeMethod<bool>('storia', {
            'immagine': immagine,
            'tipo': 'image/png',
            'appId': appIdMeta,
          }) ??
          false;
    } on Object {
      return false;
    }
  }

  /// Se Instagram e' installato. Nel dubbio si', e decide la condivisione.
  static Future<bool> instagramInstallato() async {
    if (!possibile) {
      return false;
    }

    try {
      return await _filo.invokeMethod<bool>('disponibile') ?? true;
    } on Object {
      return true;
    }
  }

  /// **La condivisione del telefono, con l'immagine pronta.**
  static Future<void> condividiAltrove(
    Uint8List immagine, {
    Rect? origine,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            immagine,
            mimeType: 'image/png',
            name: 'crasy-storia.png',
          ),
        ],
        sharePositionOrigin: origine,
      ),
    );
  }
}

/// Un intoppo da dire a chi stava condividendo, con parole sue.
class ErroreStoria implements Exception {
  const ErroreStoria(this.messaggio);

  final String messaggio;

  @override
  String toString() => messaggio;
}

/// **La Storia: 1080 × 1920.**
///
/// - Sotto tutto, la stessa foto a riempire, sfocata e scurita verso i bordi:
///   niente bande nere, e il colore della Storia e' quello della foto.
/// - In alto l'etichetta rossa **MISSIONE** e il titolo in grande, come le
///   card dell'app: e' la ragione per cui la foto esiste.
/// - Al centro **la foto intera**, mai tagliata ne' deformata, con gli angoli
///   arrotondati, un filo di luce sul bordo e un'ombra che la stacca.
/// - In fondo il logo ufficiale e "Scopri CRASY ↗", piccoli.
///
/// Tutto sta fra i 250 pixel in alto e i 250 in basso che Instagram copre
/// con il nome, la barra del tempo e il campo dei messaggi.
Future<Uint8List> componiLaStoria(
  Uint8List foto,
  Uint8List logo, {
  String titolo = '',
}) async {
  final immagine = await _decodifica(foto, altezzaMassima: 2400);
  final segno = await _decodifica(logo);

  try {
    const w = 1080.0;
    const h = 1920.0;
    const tutto = Rect.fromLTWH(0, 0, w, h);
    final registratore = ui.PictureRecorder();
    final tela = Canvas(registratore, tutto);
    final origine = Rect.fromLTWH(
      0,
      0,
      immagine.width.toDouble(),
      immagine.height.toDouble(),
    );
    final pennello = Paint()..filterQuality = FilterQuality.high;

    // Il fondo: la foto a riempire, sfocata; piu' scura in alto e in basso,
    // dove stanno le scritte.
    tela
      ..saveLayer(
        tutto,
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 56, sigmaY: 56),
      )
      ..drawImageRect(immagine, origine, _riempi(origine.size, tutto), pennello)
      ..restore()
      ..drawRect(
        tutto,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            const Offset(0, h),
            const [Color(0xB3000000), Color(0x59000000), Color(0xB3000000)],
            const [0, 0.5, 1],
          ),
      );

    // La missione, in alto.
    var sopraLaFoto = 290.0;
    final missione = titolo.trim();

    if (missione.isNotEmpty) {
      final etichetta = _riga(
        'MISSIONE',
        dimensione: 24,
        peso: FontWeight.w800,
        spaziatura: 5,
        larghezza: w,
      );
      final pillola = Rect.fromCenter(
        center: const Offset(w / 2, 300),
        width: etichetta.maxIntrinsicWidth + 48,
        height: 48,
      );

      tela
        ..drawRRect(
          RRect.fromRectAndRadius(pillola, const Radius.circular(24)),
          Paint()..color = AppColors.crasyRed,
        )
        ..drawParagraph(
          etichetta,
          Offset(0, pillola.center.dy - etichetta.height / 2),
        );

      final testo = _riga(
        missione.toUpperCase(),
        dimensione: 62,
        peso: FontWeight.w900,
        spaziatura: -0.5,
        larghezza: w - 160,
        righe: 2,
        interlinea: 1.05,
      );

      tela.drawParagraph(testo, const Offset(80, 350));
      sopraLaFoto = 350 + testo.height + 46;
    }

    // La foto, intera.
    final dove = _contieni(
      origine.size,
      Rect.fromLTRB(60, sopraLaFoto, w - 60, 1500),
    );
    final bordo = RRect.fromRectAndRadius(dove, const Radius.circular(44));

    tela
      ..drawRRect(
        bordo.shift(const Offset(0, 18)),
        Paint()
          ..color = const Color(0x80000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36),
      )
      ..save()
      ..clipRRect(bordo)
      ..drawImageRect(immagine, origine, dove, pennello)
      ..restore()
      ..drawRRect(
        bordo,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0x33FFFFFF),
      );

    // Il marchio, in fondo.
    const altezzaLogo = 50.0;
    final larghezzaLogo = altezzaLogo * segno.width / segno.height;

    tela.drawImageRect(
      segno,
      Rect.fromLTWH(0, 0, segno.width.toDouble(), segno.height.toDouble()),
      Rect.fromLTWH((w - larghezzaLogo) / 2, 1552, larghezzaLogo, altezzaLogo),
      pennello,
    );

    tela.drawParagraph(
      _riga(
        'Scopri CRASY ↗',
        dimensione: 27,
        peso: FontWeight.w500,
        spaziatura: 1.5,
        larghezza: w,
        colore: const Color(0xD9FFFFFF),
      ),
      const Offset(0, 1616),
    );

    final quadro = registratore.endRecording();
    final finale = await quadro.toImage(w.toInt(), h.toInt());

    try {
      final dati = await finale.toByteData(format: ui.ImageByteFormat.png);

      if (dati == null) {
        throw const ErroreStoria('Non siamo riusciti a preparare la Storia.');
      }

      return dati.buffer.asUint8List();
    } finally {
      finale.dispose();
      quadro.dispose();
    }
  } finally {
    immagine.dispose();
    segno.dispose();
  }
}

/// Una riga di testo centrata, gia' misurata.
ui.Paragraph _riga(
  String testo, {
  required double dimensione,
  required FontWeight peso,
  required double spaziatura,
  required double larghezza,
  int righe = 1,
  double? interlinea,
  Color colore = const Color(0xFFFFFFFF),
}) {
  return (ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textAlign: TextAlign.center,
            maxLines: righe,
            ellipsis: '…',
          ),
        )
        ..pushStyle(
          ui.TextStyle(
            color: colore,
            fontSize: dimensione,
            fontWeight: peso,
            letterSpacing: spaziatura,
            height: interlinea,
          ),
        )
        ..addText(testo))
      .build()
    ..layout(ui.ParagraphConstraints(width: larghezza));
}

Future<ui.Image> _decodifica(Uint8List byte, {int? altezzaMassima}) async {
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(byte);
    final descrittore = await ui.ImageDescriptor.encoded(buffer);
    // Una foto da dodici milioni di pixel non serve intera per 1920 righe:
    // si legge gia' ridotta, e la memoria del telefono ringrazia.
    final riduci =
        altezzaMassima != null && descrittore.height > altezzaMassima;
    final codec = await descrittore.instantiateCodec(
      targetHeight: riduci ? altezzaMassima : null,
      targetWidth: riduci
          ? (descrittore.width * altezzaMassima / descrittore.height).round()
          : null,
    );
    final fotogramma = await codec.getNextFrame();

    codec.dispose();
    descrittore.dispose();
    buffer.dispose();

    return fotogramma.image;
  } on Object {
    throw const ErroreStoria('Questa foto non si riesce a leggere.');
  }
}

/// Il rettangolo che copre tutta l'area, tagliando quel che avanza.
Rect _riempi(Size foto, Rect area) {
  final scala = [
    area.width / foto.width,
    area.height / foto.height,
  ].reduce((a, b) => a > b ? a : b);

  return Rect.fromCenter(
    center: area.center,
    width: foto.width * scala,
    height: foto.height * scala,
  );
}

/// Il rettangolo piu' grande che sta nell'area senza tagliare niente.
Rect _contieni(Size foto, Rect area) {
  final scala = [
    area.width / foto.width,
    area.height / foto.height,
  ].reduce((a, b) => a < b ? a : b);

  return Rect.fromCenter(
    center: area.center,
    width: foto.width * scala,
    height: foto.height * scala,
  );
}
