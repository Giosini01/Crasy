import 'dart:math';
import 'dart:typed_data';

import 'package:crasy/core/services/media/photo_compressor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// **Una foto con le scritte sopra sale in JPEG, non in PNG.**
///
/// L'editor disegna le frasi sulla foto intera e la restituisce in PNG: una
/// foto da milleseicento pixel cosi' pesa tre, quattro, cinque megabyte, ed
/// erano proprio quelle le foto lente da mandare e da guardare.
void main() {
  test('il PNG dell editor diventa un JPEG leggero', () {
    final foto = img.Image(width: 1600, height: 2000);

    // Grana come in una foto vera: un disegno regolare si comprimerebbe da
    // solo anche in PNG, e la prova non proverebbe niente.
    final caso = Random(7);

    for (var y = 0; y < foto.height; y++) {
      for (var x = 0; x < foto.width; x++) {
        final base = (x + y) ~/ 8;

        foto.setPixelRgb(
          x,
          y,
          (base + caso.nextInt(40)) % 256,
          (base * 2 + caso.nextInt(40)) % 256,
          (base * 3 + caso.nextInt(40)) % 256,
        );
      }
    }

    final png = img.encodePng(foto);
    final ristretta = PhotoCompressor.shrink(png);

    expect(ristretta.length, lessThan(png.length));
    expect(img.findDecoderForData(ristretta), isA<img.JpegDecoder>());
  });

  test('i pixel dell editor diventano un JPEG della stessa misura', () async {
    const larga = 400;
    const alta = 500;
    final caso = Random(3);
    final pixel = Uint8List(larga * alta * 4);

    for (var i = 0; i < pixel.length; i += 4) {
      pixel[i] = caso.nextInt(256);
      pixel[i + 1] = caso.nextInt(256);
      pixel[i + 2] = caso.nextInt(256);
      pixel[i + 3] = 255;
    }

    final jpeg = await PhotoCompressor.jpegDaPixel(
      pixel,
      larghezza: larga,
      altezza: alta,
    );
    final riletta = img.decodeJpg(jpeg)!;

    expect(riletta.width, larga);
    expect(riletta.height, alta);
    expect(jpeg.length, lessThan(pixel.length));
  });
}
