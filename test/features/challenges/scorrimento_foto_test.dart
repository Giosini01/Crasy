import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/widgets/fullscreen_media.dart';
import 'package:flutter_test/flutter_test.dart';

ChallengeEntry _foto({required String gara, required String chi}) {
  return ChallengeEntry(
    id: chi,
    challengeId: gara,
    userId: chi,
    authorName: chi,
    mediaUrl: 'https://esempio/$gara-$chi.jpg',
  );
}

/// Scorrere le foto di una persona sul suo profilo.
///
/// **Il difetto che questi controlli esistono per fermare.** Una
/// partecipazione ha come identificativo l'uid di chi l'ha mandata — e' cosi'
/// che il database garantisce una foto sola a testa per gara — quindi tutte
/// le foto della stessa persona, in gare diverse, hanno lo stesso `id`.
///
/// Sul profilo di qualcuno le foto in gara vengono da gare diverse. La vista a
/// schermo intero le teneva in una mappa per `id`, e quella mappa le faceva
/// collassare in una sola: si apriva la prima, c'era scritto "1 / 4", e
/// scorrendo si vedeva quattro volte la stessa foto.
void main() {
  group('due foto della stessa persona in gare diverse', () {
    final primaGara = _foto(gara: 'gara-1', chi: 'giosyni');
    final secondaGara = _foto(gara: 'gara-2', chi: 'giosyni');

    test('hanno lo stesso identificativo', () {
      // E' il fatto da cui nasceva tutto. Se un giorno cambiasse, questo
      // controllo lo dice invece di lasciare in giro una chiave che non serve
      // piu' a niente.
      expect(primaGara.id, secondaGara.id);
    });

    test('ma chiavi diverse', () {
      expect(primaGara.chiave, isNot(secondaGara.chiave));
    });

    test('e in una mappa restano due', () {
      // La mappa e' esattamente quella della vista a schermo intero: per `id`
      // ne resta una, per chiave restano tutte.
      final perId = {
        for (final foto in [primaGara, secondaGara]) foto.id: foto,
      };

      final perChiave = {
        for (final foto in [primaGara, secondaGara]) foto.chiave: foto,
      };

      expect(perId.length, 1, reason: 'è questo che faceva vedere la stessa');
      expect(perChiave.length, 2);
    });
  });

  group('due foto nella stessa gara', () {
    test('hanno già identificativi diversi, e la chiave non cambia niente', () {
      // Nella griglia di una gara il difetto non c'era: li' gli `id` sono di
      // persone diverse. La chiave non deve rompere il caso che funzionava.
      final mia = _foto(gara: 'gara-1', chi: 'giosyni');
      final sua = _foto(gara: 'gara-1', chi: 'chiara56');

      expect(mia.chiave, isNot(sua.chiave));
      expect(
        {
          for (final foto in [mia, sua]) foto.chiave,
        }.length,
        2,
      );
    });
  });

  group('le foto di una persona, scorse dal suo profilo', () {
    // Quattro gare diverse, sempre la stessa persona: e' esattamente cio' che
    // c'e' sul profilo di qualcuno.
    final sue = [
      for (var i = 1; i <= 4; i++) _foto(gara: 'gara-$i', chi: 'giosyni'),
    ];

    final ordine = [for (final foto in sue) foto.chiave];

    test('restano quattro, e sono quattro foto diverse', () {
      final scorribili = nellOrdineDiPrima(
        ordine: ordine,
        aperte: sue,
        vive: const [],
      );

      expect(scorribili.length, 4);
      expect(
        scorribili.map((foto) => foto.mediaUrl).toSet().length,
        4,
        reason: 'prima erano quattro copie della stessa',
      );
    });

    test('nell ordine in cui erano, non riordinate', () {
      final scorribili = nellOrdineDiPrima(
        ordine: ordine,
        aperte: sue.reversed.toList(),
        vive: const [],
      );

      expect(scorribili.map((foto) => foto.challengeId).toList(), [
        'gara-1',
        'gara-2',
        'gara-3',
        'gara-4',
      ]);
    });

    test('i numeri di adesso aggiornano solo la foto giusta', () {
      // Arriva la versione viva della seconda, con una fiamma in piu'. Le
      // altre tre non si devono muovere: prima, con la mappa per `id`, quella
      // sola riscriveva tutte e quattro.
      final aggiornata = ChallengeEntry(
        id: 'giosyni',
        challengeId: 'gara-2',
        userId: 'giosyni',
        authorName: 'giosyni',
        mediaUrl: 'https://esempio/gara-2-giosyni.jpg',
        votes: 7,
      );

      final scorribili = nellOrdineDiPrima(
        ordine: ordine,
        aperte: sue,
        vive: [aggiornata],
      );

      expect(scorribili.map((foto) => foto.votes).toList(), [0, 7, 0, 0]);
    });

    test('una foto sparita esce dall elenco invece di lasciare un buco', () {
      final scorribili = nellOrdineDiPrima(
        ordine: ordine,
        aperte: sue.where((foto) => foto.challengeId != 'gara-3').toList(),
        vive: const [],
      );

      expect(scorribili.length, 3);
      expect(
        scorribili.map((foto) => foto.challengeId),
        isNot(contains('gara-3')),
      );
    });
  });

  test('la chiave porta dentro la gara, e si rilegge', () {
    // La vista la usa per sapere da quale gara viene la foto sotto le dita.
    expect(primaDellaGara.chiave.split('/').first, 'gara-9');
  });
}

final primaDellaGara = _foto(gara: 'gara-9', chi: 'tony92');
