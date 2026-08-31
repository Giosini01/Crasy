import 'dart:typed_data';

import 'package:crasy/core/services/media/photo_compressor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Il selfie deve uscire **come lo si e' visto nell'anteprima**.
///
/// L'anteprima e' uno specchio — senza, inquadrarsi e' impossibile — quindi la
/// foto va ribaltata insieme a lei. Se le due non sono d'accordo, fra il tocco
/// e il risultato c'e' una sorpresa: scritte al contrario, riga dei capelli
/// dalla parte sbagliata.
void main() {
  /// Una foto riconoscibile: meta' sinistra nera, meta' destra bianca.
  ///
  /// Grande abbastanza da superare la soglia sotto la quale non si tocca
  /// niente, cosi' si verifica il passaggio vero e non la scorciatoia.
  img.Image dueMeta() {
    final foto = img.Image(width: 800, height: 800);

    img.fill(foto, color: img.ColorRgb8(0, 0, 0));
    img.fillRect(
      foto,
      x1: 400,
      y1: 0,
      x2: 799,
      y2: 799,
      color: img.ColorRgb8(255, 255, 255),
    );

    return foto;
  }

  bool sinistraNera(Uint8List jpeg) {
    final letta = img.decodeImage(jpeg)!;
    final pixel = letta.getPixel(letta.width ~/ 8, letta.height ~/ 2);

    return pixel.r < 128;
  }

  test('senza specchio i lati restano dove sono', () {
    final originale = img.encodeJpg(dueMeta(), quality: 92);

    expect(sinistraNera(originale), isTrue);
    expect(sinistraNera(PhotoCompressor.shrink(originale)), isTrue);
  });

  test('con lo specchio i lati si scambiano', () {
    final originale = img.encodeJpg(dueMeta(), quality: 92);

    expect(
      sinistraNera(PhotoCompressor.shrink(originale, mirror: true)),
      isFalse,
    );
  });

  test('lo specchio vale anche sulle foto piccole', () {
    // Sotto la soglia la compressione si salta per non peggiorare il file. Il
    // ribaltamento no: saltarlo vorrebbe dire mandare in gara una foto diversa
    // da quella vista, e solo per certe foto — il peggiore dei difetti, quello
    // che capita a volte.
    final piccola = img.encodeJpg(
      img.copyResize(dueMeta(), width: 40),
      quality: 40,
    );

    expect(piccola.lengthInBytes, lessThan(400 * 1024));
    expect(sinistraNera(piccola), isTrue);
    expect(
      sinistraNera(PhotoCompressor.shrink(piccola, mirror: true)),
      isFalse,
    );
  });
}
