import 'dart:typed_data';

import 'package:crasy/core/services/media/photo_compressor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  /// Una foto finta ma vera: rumore, perche' una tinta piatta si comprime
  /// talmente bene da non dimostrare niente.
  Uint8List photo(int width, int height) {
    final image = img.Image(width: width, height: height);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixelRgb(x, y, (x * 7 + y * 13) % 255, (x * 3) % 255, y % 255);
      }
    }

    return img.encodeJpg(image, quality: 100);
  }

  test('una foto grande diventa molto piu\' leggera', () {
    final original = photo(3000, 2000);
    final shrunk = PhotoCompressor.shrink(original);

    expect(shrunk.lengthInBytes, lessThan(original.lengthInBytes));

    final decoded = img.decodeImage(shrunk)!;

    expect(decoded.width, PhotoCompressor.maxSide);
    expect(decoded.height, closeTo(1067, 1));
  });

  test('una foto verticale si misura sul lato lungo', () {
    final decoded = img.decodeImage(PhotoCompressor.shrink(photo(2000, 3000)))!;

    expect(decoded.height, PhotoCompressor.maxSide);
    expect(decoded.width, lessThan(PhotoCompressor.maxSide));
  });

  test('una foto gia\' piccola non si tocca', () {
    final small = Uint8List.fromList(List<int>.filled(1000, 7));

    expect(PhotoCompressor.shrink(small), same(small));
  });

  test('un file che non e\' un\'immagine torna com\'e\'', () {
    // Un HEIC di iPhone, o un file rotto: non deve far fallire la
    // partecipazione. Nel dubbio sale l'originale.
    final garbage = Uint8List.fromList(
      List<int>.generate(600 * 1024, (index) => index % 251),
    );

    expect(PhotoCompressor.shrink(garbage), same(garbage));
  });
}
