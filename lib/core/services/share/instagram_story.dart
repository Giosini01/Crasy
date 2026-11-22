import 'dart:io';
import 'dart:ui' as ui;

import 'package:crasy/core/services/share/share_entry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// **Una propria foto su Instagram Stories.**
///
/// Chi condivide vuole far vedere una bella foto di se', non fare pubblicita'
/// a CRASY: la foto prende quasi tutto lo spazio, intera e senza tagli, e il
/// marchio sta in basso, piccolo — il logo e "Scopri CRASY ↗". Oppure la foto
/// da sola, se si preferisce.
///
/// ## Come arriva a Instagram
///
/// Con il sistema ufficiale di Meta per le Storie: su iPhone la foto passa
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

  /// Il tipo dell'immagine, letto dai primi byte.
  static String tipoDi(Uint8List byte) {
    if (byte.length > 3 && byte[0] == 0x89 && byte[1] == 0x50) {
      return 'image/png';
    }

    return 'image/jpeg';
  }

  /// **Prova ad aprire direttamente le Storie.** Falso se non si puo': senza
  /// l'ID di Meta, senza Instagram, o se Instagram rifiuta.
  static Future<bool> apriLeStorie(Uint8List immagine, String tipo) async {
    if (!possibile || appIdMeta.isEmpty) {
      return false;
    }

    try {
      return await _filo.invokeMethod<bool>('storia', {
            'immagine': immagine,
            'tipo': tipo,
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

  /// **La condivisione del telefono, con l'immagine pronta.** Torna falso se
  /// chi condivide ci ha ripensato.
  static Future<bool> condividiAltrove(
    Uint8List immagine,
    String tipo, {
    Rect? origine,
  }) async {
    final esito = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            immagine,
            mimeType: tipo,
            name: tipo == 'image/png' ? 'crasy-storia.png' : 'crasy-foto.jpg',
          ),
        ],
        sharePositionOrigin: origine,
      ),
    );

    return esito.status != ShareResultStatus.dismissed;
  }
}

/// Un intoppo da dire a chi stava condividendo, con parole sue.
class ErroreStoria implements Exception {
  const ErroreStoria(this.messaggio);

  final String messaggio;

  @override
  String toString() => messaggio;
}

/// **La Storia: 1080 × 1920, la foto al centro, il marchio in fondo.**
///
/// Sotto, la stessa foto ingrandita a riempire, sfocata e scurita: e' cio'
/// che fanno le Storie belle, e tiene la foto intera senza bande nere. Sopra,
/// la foto vera, **intera e senza deformazioni**, il piu' grande possibile
/// fra la striscia in alto (dove Instagram mette nome e tasti) e quella in
/// basso, dove stanno il logo e la scritta: niente le passa sopra.
Future<Uint8List> componiLaStoria(Uint8List foto, Uint8List logo) async {
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

    // Il fondo: la foto a riempire, sfocata e scurita.
    tela
      ..saveLayer(
        tutto,
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 48, sigmaY: 48),
      )
      ..drawImageRect(immagine, origine, _riempi(origine.size, tutto), pennello)
      ..restore()
      ..drawRect(tutto, Paint()..color = const Color(0x73000000));

    // La foto, intera.
    final dove = _contieni(
      origine.size,
      const Rect.fromLTRB(56, 170, w - 56, 1620),
    );
    final bordo = RRect.fromRectAndRadius(dove, const Radius.circular(40));

    tela
      ..drawRRect(
        bordo.shift(const Offset(0, 14)),
        Paint()
          ..color = const Color(0x66000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
      )
      ..save()
      ..clipRRect(bordo)
      ..drawImageRect(immagine, origine, dove, pennello)
      ..restore();

    // Il marchio: piccolo, in fondo, sopra la parte sfocata.
    const altezzaLogo = 54.0;
    final larghezzaLogo = altezzaLogo * segno.width / segno.height;

    tela.drawImageRect(
      segno,
      Rect.fromLTWH(0, 0, segno.width.toDouble(), segno.height.toDouble()),
      Rect.fromLTWH((w - larghezzaLogo) / 2, 1700, larghezzaLogo, altezzaLogo),
      pennello,
    );

    final scritta =
        (ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
              ..pushStyle(
                ui.TextStyle(
                  color: const Color(0xD9FFFFFF),
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
              )
              ..addText('Scopri CRASY ↗'))
            .build()
          ..layout(const ui.ParagraphConstraints(width: w));

    tela.drawParagraph(scritta, const Offset(0, 1782));

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
