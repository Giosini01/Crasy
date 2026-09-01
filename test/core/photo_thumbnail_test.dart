import 'dart:typed_data';

import 'package:crasy/core/services/media/photo_compressor.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// La copia piccola che riempie gli elenchi.
///
/// **E' la voce piu' grande del conto di fine mese.** Fino a ieri ogni elenco
/// scaricava la foto intera — trecento chilobyte — per disegnarne quaranta, e
/// moltiplicato per ogni foto di ogni schermata di ogni persona diventava
/// l'ottantacinque per cento della spesa.
void main() {
  Uint8List foto({int lato = 1600}) {
    final immagine = img.Image(width: lato, height: lato);

    // Del rumore, non una tinta piatta: un quadrato tutto nero si comprime a
    // pochi byte e il confronto sui pesi non direbbe niente.
    for (var y = 0; y < lato; y += 4) {
      for (var x = 0; x < lato; x += 4) {
        img.fillRect(
          immagine,
          x1: x,
          y1: y,
          x2: x + 3,
          y2: y + 3,
          color: img.ColorRgb8((x * 7) % 256, (y * 13) % 256, (x + y) % 256),
        );
      }
    }

    return img.encodeJpg(immagine, quality: 90);
  }

  test('la miniatura ha il lato lungo giusto', () {
    final piccola = PhotoCompressor.thumbnail(foto())!;
    final letta = img.decodeImage(piccola)!;

    expect(letta.width, PhotoCompressor.thumbSide);
    expect(letta.height, PhotoCompressor.thumbSide);
  });

  test('la miniatura pesa una frazione dell\'originale', () {
    final originale = foto();
    final piccola = PhotoCompressor.thumbnail(originale)!;

    // Il numero non e' un traguardo di bellezza: e' la banda che non si paga.
    // Sotto un quinto vuol dire che il conto di fine mese si divide per cinque.
    expect(piccola.lengthInBytes * 5, lessThan(originale.lengthInBytes));
  });

  test('una foto gia\' piccola non ne ha bisogno', () {
    // Due copie della stessa cosa costano spazio e non risparmiano niente.
    expect(PhotoCompressor.thumbnail(foto(lato: 300)), isNull);
  });

  test('da qualcosa che non e\' un\'immagine non esce niente', () {
    // Non deve lanciare: una miniatura mancata non e' un motivo per far fallire
    // una partecipazione.
    expect(
      PhotoCompressor.thumbnail(Uint8List.fromList(const [1, 2, 3, 4])),
      isNull,
    );
  });

  test('nemmeno la compressione cade su un file rovinato', () {
    // Stessa trappola della miniatura: la libreria lancia un `Error`, non
    // un'eccezione. Qui il ripiego e' mandare l'originale — pesante, ma in
    // gara.
    final rovinato = Uint8List.fromList(const [9, 9, 9, 9]);

    expect(PhotoCompressor.shrink(rovinato), rovinato);
  });

  test('senza miniatura gli elenchi mostrano l\'originale', () {
    // **E' la riga che tiene in piedi tutte le foto caricate prima di oggi.**
    // Non c'e' nessuna migrazione: dove la miniatura manca si continua come
    // sempre.
    const vecchia = ChallengeEntry(
      id: 'x',
      challengeId: 'gara',
      userId: 'io',
      authorName: 'io',
      mediaUrl: 'https://esempio/intera.jpg',
    );

    expect(vecchia.previewUrl, 'https://esempio/intera.jpg');

    const nuova = ChallengeEntry(
      id: 'x',
      challengeId: 'gara',
      userId: 'io',
      authorName: 'io',
      mediaUrl: 'https://esempio/intera.jpg',
      thumbUrl: 'https://esempio/piccola.jpg',
    );

    expect(nuova.previewUrl, 'https://esempio/piccola.jpg');
  });
}
