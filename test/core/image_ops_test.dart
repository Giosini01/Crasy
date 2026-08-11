import 'dart:typed_data';

import 'package:app_incontri/core/utils/image_ops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('flipHorizontally swaps the two halves of the photo', () async {
    // Immagine con la meta' sinistra rossa e la destra blu: dopo il
    // ribaltamento i due lati devono risultare scambiati.
    final source = img.Image(width: 8, height: 4);

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgb(x, y, x < 4 ? 255 : 0, 0, x < 4 ? 0 : 255);
      }
    }

    final flipped = img.decodeJpg(
      await ImageOps.flipHorizontally(img.encodeJpg(source, quality: 100)),
    )!;

    // Il JPEG non e' esatto al bit: si confronta la tinta dominante, non il
    // valore preciso.
    final left = flipped.getPixel(1, 2);
    final right = flipped.getPixel(6, 2);

    expect(left.b, greaterThan(left.r), reason: 'a sinistra ora c e il blu');
    expect(right.r, greaterThan(right.b), reason: 'a destra ora c e il rosso');
  });

  test('flipHorizontally returns the input when it is not an image', () async {
    final garbage = List<int>.filled(32, 7);

    expect(
      await ImageOps.flipHorizontally(Uint8List.fromList(garbage)),
      garbage,
    );
  });
}
