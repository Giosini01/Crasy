import 'dart:typed_data';

import 'package:crasy/features/challenges/presentation/controllers/participation_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Quanto puo' pesare quello che si manda.**
///
/// Senza questo controllo il file partiva, saliva per mezzo minuto e veniva
/// rifiutato alla fine da Storage con un errore che parlava di permessi: il
/// nome sbagliato per un problema di dimensione, davanti a chi aveva appena
/// aspettato il caricamento.
///
/// I numeri qui dentro devono restare uguali a quelli di `storage.rules`.
/// Quando divergono non si rompe niente in modo visibile — torna solo il
/// vecchio guasto, con il suo errore che non nomina la causa.
void main() {
  PickedMedia roba({required int mega, bool video = false}) {
    return PickedMedia(
      bytes: Uint8List(mega * 1024 * 1024),
      isVideo: video,
      contentType: video ? 'video/mp4' : 'image/jpeg',
    );
  }

  group('video', () {
    test('un video normale passa', () {
      expect(roba(mega: 30, video: true).troppoGrande, isNull);
    });

    test('sopra i cento viene fermato prima di partire', () {
      final problema = roba(mega: 120, video: true).troppoGrande;

      expect(problema, isNotNull);
      // **Il messaggio dice i numeri.** "Video troppo grande" non fa sapere a
      // nessuno se deve tagliarne due secondi o rinunciare.
      expect(problema, contains('120'));
      expect(problema, contains('100'));
    });

    test('esattamente al limite non passa', () {
      // Le regole scrivono `<`, non `<=`: se qui passasse, il rifiuto
      // arriverebbe dall'altra parte, che e' esattamente cio' che si evita.
      expect(roba(mega: 100, video: true).troppoGrande, isNotNull);
    });
  });

  group('foto', () {
    test('una foto stretta passa', () {
      expect(roba(mega: 2).troppoGrande, isNull);
    });

    test('una foto enorme viene fermata', () {
      expect(roba(mega: 20).troppoGrande, isNotNull);
    });

    test('il limite della foto non e\' quello del video', () {
      // Venti megabyte: troppi per una foto, nemmeno un quarto del tetto di un
      // video. Se i due limiti si confondessero, questo test si accorgerebbe.
      expect(roba(mega: 20).troppoGrande, isNotNull);
      expect(roba(mega: 20, video: true).troppoGrande, isNull);
    });
  });
}
