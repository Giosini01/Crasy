import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crasy/core/services/share/instagram_story.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Una foto finta: fondo blu, un cerchio giallo al centro.
Future<Uint8List> _foto(int w, int h) async {
  final registratore = ui.PictureRecorder();

  Canvas(registratore)
    ..drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFF2266FF),
    )
    ..drawCircle(
      Offset(w / 2, h / 2),
      (w < h ? w : h) / 4,
      Paint()..color = const Color(0xFFFFCC00),
    );

  final immagine = await registratore.endRecording().toImage(w, h);
  final dati = await immagine.toByteData(format: ui.ImageByteFormat.png);

  return dati!.buffer.asUint8List();
}

/// **La Storia: sempre 1080 × 1920, con la foto intera al centro.**
void main() {
  testWidgets(
    'verticale, orizzontale o quadrata: 1080 x 1920, foto al centro',
    (tester) async {
      await tester.runAsync(() async {
        final logo = File(
          'assets/brand/crasy-wordmark-dark.png',
        ).readAsBytesSync();

        for (final (w, h) in [(900, 1600), (1600, 900), (1000, 1000)]) {
          final storia = await componiLaStoria(await _foto(w, h), logo);
          final codec = await ui.instantiateImageCodec(storia);
          final immagine = (await codec.getNextFrame()).image;

          expect(immagine.width, InstagramStory.larghezza, reason: '$w x $h');
          expect(immagine.height, InstagramStory.altezza, reason: '$w x $h');

          // Al centro dell'area della foto c'e' il cerchio giallo, nitido: la
          // foto e' intera e non e' stata spostata ne' coperta.
          final pixel = await immagine.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final punto = (895 * 1080 + 540) * 4;

          expect(pixel!.getUint8(punto), greaterThan(200), reason: 'rosso');
          expect(pixel.getUint8(punto + 1), greaterThan(160), reason: 'verde');
          expect(pixel.getUint8(punto + 2), lessThan(90), reason: 'blu');
        }
      });
    },
  );

  test('il link della foto dice chi l\'ha condivisa e da dove', () {
    final link = Uri.parse(
      InstagramStory.link(
        challengeId: 'g1',
        entryId: 'anna',
        challengeTitle: 'Tu da piccolo',
        authorName: 'anna',
        userId: 'anna-uid',
      ),
    );

    expect(link.host, 'crasyapp.com');
    expect(link.path, '/foto');
    expect(link.queryParameters['g'], 'g1');
    expect(link.queryParameters['f'], 'anna');
    expect(link.queryParameters['da'], 'anna-uid');
    expect(link.queryParameters['utm_source'], 'instagram');
    expect(link.queryParameters['utm_medium'], 'story');
  });

  test('il tipo si legge dai primi byte', () {
    expect(
      InstagramStory.tipoDi(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47])),
      'image/png',
    );
    expect(
      InstagramStory.tipoDi(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
      'image/jpeg',
    );
  });
}
