import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:flutter_test/flutter_test.dart';

ChallengeEntry _foto({String media = '', String thumb = ''}) {
  return ChallengeEntry(
    id: 'mary',
    challengeId: 'gara-1',
    userId: 'mary',
    authorName: 'mary56',
    mediaUrl: media,
    thumbUrl: thumb,
  );
}

/// **Quando la gara finisce, resta la miniatura.**
///
/// Chiudendo una gara il server cancella i file delle foto che non hanno
/// vinto: pesano, e passata la gara non le guarda piu' nessuno. Svuota
/// `mediaUrl` e **tiene la miniatura**, che sono poche decine di chilobyte.
///
/// Solo che ne' la griglia ne' lo schermo intero la usavano: leggevano
/// `mediaUrl` e basta. Una gara finita da due ore diventava una fila di
/// riquadri vuoti con sotto i nomi di chi aveva partecipato, e chi la apriva
/// pensava che l'app fosse rotta. E' arrivata cosi': *"mary ha partecipato ma
/// non vedo la foto"*.
void main() {
  group('la foto grande', () {
    test('e l\'originale finche\' c\'e\'', () {
      final foto = _foto(
        media: 'https://esempio/intera.jpg',
        thumb: 'https://esempio/mini.jpg',
      );

      expect(foto.urlGrande, 'https://esempio/intera.jpg');
      expect(foto.soloMiniatura, isFalse);
    });

    test('diventa la miniatura quando il server ha buttato l\'originale', () {
      // **È il caso per cui questo esiste.** Sgranata è peggio
      // dell'originale e molto meglio del nulla: dice che quella persona ha
      // giocato e cosa ha mandato, che è tutto il motivo per cui si riapre
      // una gara finita.
      final foto = _foto(thumb: 'https://esempio/mini.jpg');

      expect(foto.urlGrande, 'https://esempio/mini.jpg');
      expect(foto.soloMiniatura, isTrue);
    });

    test('resta vuota se non c\'e\' piu\' niente', () {
      // Le foto piu' vecchie di sei mesi le cancella il magazzino, miniatura
      // compresa. Li' non c'e' niente da mostrare, e va detto invece di
      // lasciare un riquadro nero.
      final foto = _foto();

      expect(foto.urlGrande, isEmpty);
      expect(foto.soloMiniatura, isFalse);
    });

    test('negli elenchi si preferisce comunque la miniatura', () {
      // Due cose diverse: negli elenchi la miniatura si usa **anche** quando
      // l'originale c'e', perche' e' piu' leggera. Qui invece si usa solo
      // quando l'originale non c'e' piu'.
      final foto = _foto(
        media: 'https://esempio/intera.jpg',
        thumb: 'https://esempio/mini.jpg',
      );

      expect(foto.previewUrl, 'https://esempio/mini.jpg');
      expect(foto.urlGrande, 'https://esempio/intera.jpg');
    });
  });
}
