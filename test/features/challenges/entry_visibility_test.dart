import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/entry_moderation.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Una foto segnalata sparisce da tutte le parti, non da una.**
///
/// Il difetto che queste prove tengono chiuso: si segnalava una foto, la si vedeva
/// sparire dalla gara, e la si ritrovava intera aprendo il profilo di chi l'aveva
/// pubblicata. Il filtro esisteva ed era giusto — stava scritto dentro **una**
/// schermata, e le altre due che leggono le partecipazioni passavano da un'altra
/// strada.
///
/// E' il genere di buco per cui Apple rifiuta un'app: il tasto "segnala" c'e', si
/// preme, e la roba resta. Vale la linea guida 1.2 — segnalare deve far sparire.
void main() {
  ChallengeEntry foto({
    String id = 'foto-1',
    String userId = 'chi-ha-caricato',
    List<String> reporters = const [],
    EntryModeration moderation = EntryModeration.approved,
  }) {
    return ChallengeEntry(
      id: id,
      challengeId: 'gara-1',
      userId: userId,
      authorName: 'chi',
      mediaUrl: 'https://esempio/$id.jpg',
      createdAt: DateTime(2026, 10, 6),
      reporters: reporters,
      moderation: moderation,
    );
  }

  group('chi ha segnalato non la vede piu', () {
    test('sparisce per chi ha segnalato, resta per gli altri', () {
      final segnalata = foto(reporters: ['io']);

      expect(segnalata.isVisibleTo('io'), isFalse);
      expect(segnalata.isVisibleTo('un-altro'), isTrue);
    });

    test('e sparisce dalla lista, non solo dalla risposta', () {
      final lista = [
        foto(id: 'a'),
        foto(id: 'b', reporters: ['io']),
        foto(id: 'c'),
      ];

      // **La prova che vale per tutte le schermate insieme.** Profilo pubblico,
      // bacheca degli amici e partecipazioni di una gara passano tutti da questa
      // estensione: finche' ci passano, non possono divergere.
      expect(lista.visibiliPer('io').map((e) => e.id), ['a', 'c']);
      expect(lista.visibiliPer('un-altro').length, 3);
    });
  });

  group('il controllo sulle foto', () {
    test('una rifiutata non la vede nessuno, nemmeno chi l ha caricata', () {
      final rifiutata = foto(moderation: EntryModeration.rejected);

      expect(rifiutata.isVisibleTo('chi-ha-caricato'), isFalse);
      expect(rifiutata.isVisibleTo('un-altro'), isFalse);
      expect([rifiutata].visibiliPer('un-altro'), isEmpty);
    });

    test('una in attesa la vede solo chi l ha mandata', () {
      final attesa = foto(moderation: EntryModeration.pending);

      expect(attesa.isVisibleTo('chi-ha-caricato'), isTrue);
      expect(attesa.isVisibleTo('un-altro'), isFalse);
    });
  });

  group('chi ho bloccato', () {
    test('non lo vedo, e viene prima di ogni altra considerazione', () {
      final sua = foto(userId: 'bloccato');

      // Approvata, non segnalata da nessuno: l'unica ragione per cui non si deve
      // vedere e' che chi guarda ha deciso di non vedere quella persona.
      expect(sua.isVisibleTo('io', blocked: {'bloccato'}), isFalse);
      expect([sua].visibiliPer('io', blocked: {'bloccato'}), isEmpty);
    });
  });

  group('chi guarda senza aver fatto l accesso', () {
    test('vede le approvate e non le altre', () {
      expect(foto().isVisibleTo(null), isTrue);
      expect(
        foto(moderation: EntryModeration.pending).isVisibleTo(null),
        isFalse,
      );
      expect(
        foto(moderation: EntryModeration.rejected).isVisibleTo(null),
        isFalse,
      );
    });
  });
}
