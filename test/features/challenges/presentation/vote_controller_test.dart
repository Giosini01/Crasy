import 'dart:typed_data';

import 'package:crasy/features/auth/domain/entities/app_user.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/presentation/controllers/vote_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_repository.dart';

void main() {
  ProviderContainer guestContainer() {
    final authRepository = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
    );

    addTearDown(() {
      authRepository.dispose();
      container.dispose();
    });

    return container;
  }

  /// Una partecipazione di qualcun altro a una challenge locale.
  ///
  /// Senza Firebase configurato il repository dell'app **e'** quello in
  /// memoria, quindi la challenge creata qui e' esattamente quella su cui
  /// lavora il controller.
  Future<ChallengeEntry> someoneElsesEntry(ProviderContainer container) async {
    final samples = container.read(sampleChallengeRepositoryProvider);
    final now = DateTime.now();

    final challenge = await samples.createChallenge(
      Challenge(
        id: '',
        title: 'Prova',
        brief: 'Fai qualcosa di assurdo.',
        prizeCents: 50000,
        scope: ChallengeScope.global,
        startsAt: now.subtract(const Duration(hours: 1)),
        endsAt: now.add(const Duration(days: 1)),
      ),
    );

    return samples.submitEntry(
      challengeId: challenge.id,
      userId: 'altra',
      authorName: 'altra',
      bytes: Uint8List.fromList(const [1, 2, 3]),
    );
  }

  /// Aspetta che il server dica davvero di si'.
  ///
  /// `votedEntryIdsProvider.future` non basta: si era gia' risolto con
  /// l'elenco **di prima del voto**, e il valore nuovo arriva un giro di eventi
  /// piu' tardi. Aspettare quello sbagliato faceva fallire la prova per un
  /// motivo che non c'entrava niente con quello che si voleva provare.
  Future<void> untilConfirmed(
    ProviderContainer container,
    String voteKey,
  ) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      final confirmed =
          container.read(votedEntryIdsProvider).valueOrNull ?? const <String>{};

      if (confirmed.contains(voteKey)) {
        return;
      }

      await Future<void>.delayed(Duration.zero);
    }

    fail('la conferma del voto non arriva mai');
  }

  test('un ospite accende la fiamma sulle challenge locali', () async {
    final container = guestContainer();
    final entry = await someoneElsesEntry(container);

    final outcome = await container
        .read(voteControllerProvider)
        .toggle(entry, voted: true);

    expect(outcome, VoteOutcome.done);

    // Il numero deve muoversi davvero: e' l'unica cosa che l'utente vede.
    final updated = await container
        .read(sampleChallengeRepositoryProvider)
        .watchEntries(entry.challengeId)
        .first;

    expect(updated.firstWhere((item) => item.id == entry.id).votes, 1);

    final voted = await container
        .read(sampleChallengeRepositoryProvider)
        .watchVotedEntryIds(guestVoterId)
        .first;

    expect(voted, contains(entry.voteKey));
  });

  test('la fiamma si toglie con lo stesso gesto al contrario', () async {
    final container = guestContainer();
    final entry = await someoneElsesEntry(container);
    final controller = container.read(voteControllerProvider);

    await controller.toggle(entry, voted: true);
    await controller.toggle(entry, voted: false);

    final updated = await container
        .read(sampleChallengeRepositoryProvider)
        .watchEntries(entry.challengeId)
        .first;

    expect(updated.firstWhere((item) => item.id == entry.id).votes, 0);
  });

  test('su una challenge vera l\'ospite viene mandato a registrarsi', () async {
    final container = guestContainer();

    const realEntry = ChallengeEntry(
      id: 'entry-1',
      challengeId: 'challenge-vera',
      userId: 'altro',
      authorName: 'altro',
      mediaUrl: 'https://esempio/foto.jpg',
    );

    expect(
      await container
          .read(voteControllerProvider)
          .toggle(realEntry, voted: true),
      VoteOutcome.needsAccount,
    );
  });

  test('la propria foto si puo\' votare', () async {
    final container = guestContainer();
    final entry = await someoneElsesEntry(container);

    // Sembra un buco e non lo e': possono farlo tutti, quindi non sposta la
    // classifica di un millimetro. A tenere onesta la gara e' un'altra regola —
    // chi lancia la challenge non ci partecipa.
    expect(
      await container
          .read(voteControllerProvider)
          .toggle(entry.copyWith(userId: guestVoterId), voted: true),
      VoteOutcome.done,
    );

    final updated = await container
        .read(sampleChallengeRepositoryProvider)
        .watchEntries(entry.challengeId)
        .first;

    expect(updated.firstWhere((item) => item.id == entry.id).votes, 1);
  });

  group('la memoria della fiamma', () {
    test('la richiesta congela il numero invece di correggerlo', () async {
      final container = guestContainer();
      final entry = await someoneElsesEntry(container);

      // **Il numero per intero, non un "+1" da sommare.** Sommare una
      // correzione al contatore del server e' cio' che faceva comparire +2:
      // contatore e elenco dei voti arrivano da due ascolti diversi, e nel
      // mezzo il contatore aveva gia' dentro il voto che la correzione stava
      // per aggiungere di nuovo.
      container
          .read(voteIntentsProvider.notifier)
          .want(entry.voteKey, const VoteIntent(voted: true, votes: 1));

      expect(container.read(entryVotedProvider(entry.voteKey)), isTrue);
      expect(container.read(voteIntentProvider(entry.voteKey))?.votes, 1);
    });

    test('a scrittura confermata la richiesta sparisce da sola', () async {
      final container = guestContainer();
      final entry = await someoneElsesEntry(container);

      container
          .read(voteIntentsProvider.notifier)
          .want(entry.voteKey, const VoteIntent(voted: true, votes: 1));

      await container.read(voteControllerProvider).toggle(entry, voted: true);

      // Lo stream va ascoltato perche' emetta: senza, la conferma non arriva
      // mai e la richiesta resterebbe li' per sempre.
      final subscription = container.listen(votedEntryIdsProvider, (_, _) {});
      addTearDown(subscription.close);
      await untilConfirmed(container, entry.voteKey);

      // Da qui in poi il numero congelato e quello del server dicono la stessa
      // cosa, quindi la richiesta non serve piu' e togliendola non si vede
      // niente cambiare.
      expect(container.read(voteIntentsProvider), isEmpty);
      expect(container.read(entryVotedProvider(entry.voteKey)), isTrue);
    });
  });

  group('le fiamme non vanno mai sotto zero', () {
    test('togliere un voto mai dato non fa scendere il contatore', () async {
      final container = guestContainer();
      final entry = await someoneElsesEntry(container);
      final samples = container.read(sampleChallengeRepositoryProvider);

      // Nessuno ha mai votato questa foto, e qualcuno prova a togliere una
      // fiamma. Non e' un caso di scuola: succedeva con le foto scritte prima
      // che il campo del contatore esistesse, e sotto la foto compariva "-1".
      await container.read(voteControllerProvider).toggle(entry, voted: false);

      final updated = await samples.watchEntries(entry.challengeId).first;

      expect(updated.firstWhere((item) => item.id == entry.id).votes, 0);
    });

    test(
      'mettere e togliere piu\' volte torna sempre al punto di partenza',
      () async {
        final container = guestContainer();
        final entry = await someoneElsesEntry(container);
        final controller = container.read(voteControllerProvider);
        final samples = container.read(sampleChallengeRepositoryProvider);

        for (var round = 0; round < 5; round++) {
          await controller.toggle(entry, voted: true);
          await controller.toggle(entry, voted: false);
        }

        final updated = await samples.watchEntries(entry.challengeId).first;

        expect(updated.firstWhere((item) => item.id == entry.id).votes, 0);
      },
    );

    test('due tocchi rapidi contano per uno solo', () async {
      final container = guestContainer();
      final entry = await someoneElsesEntry(container);
      final controller = container.read(voteControllerProvider);

      // Non si aspetta la prima: e' proprio il caso che rompeva il conto, due
      // scritture in volo insieme sulla stessa foto.
      final first = controller.toggle(entry, voted: true);
      final second = controller.toggle(entry, voted: true);
      await Future.wait([first, second]);

      final updated = await container
          .read(sampleChallengeRepositoryProvider)
          .watchEntries(entry.challengeId)
          .first;

      expect(updated.firstWhere((item) => item.id == entry.id).votes, 1);
    });

    test('acceso e spento in rapida successione: vince l\'ultimo', () async {
      final container = guestContainer();
      final entry = await someoneElsesEntry(container);
      final controller = container.read(voteControllerProvider);

      final first = controller.toggle(entry, voted: true);
      final second = controller.toggle(entry, voted: false);
      await Future.wait([first, second]);

      final updated = await container
          .read(sampleChallengeRepositoryProvider)
          .watchEntries(entry.challengeId)
          .first;

      expect(updated.firstWhere((item) => item.id == entry.id).votes, 0);

      final voted = await container
          .read(sampleChallengeRepositoryProvider)
          .watchVotedEntryIds(guestVoterId)
          .first;

      expect(voted, isNot(contains(entry.voteKey)));
    });
  });

  group('due gare, due voti distinti', () {
    /// La stessa persona in due challenge diverse.
    ///
    /// E' il caso che rompeva tutto: una partecipazione si chiama come chi
    /// l'ha mandata, quindi la sua foto ha lo **stesso** identificativo in ogni
    /// gara a cui partecipa.
    Future<List<ChallengeEntry>> sameAuthorTwice(
      ProviderContainer container,
    ) async {
      final samples = container.read(sampleChallengeRepositoryProvider);
      final now = DateTime.now();
      final entries = <ChallengeEntry>[];

      for (var index = 0; index < 2; index++) {
        final challenge = await samples.createChallenge(
          Challenge(
            id: '',
            title: 'Gara $index',
            brief: 'Fai qualcosa di assurdo.',
            prizeCents: 50000,
            scope: ChallengeScope.global,
            startsAt: now.subtract(const Duration(hours: 1)),
            endsAt: now.add(const Duration(days: 1)),
          ),
        );

        entries.add(
          await samples.submitEntry(
            challengeId: challenge.id,
            userId: 'stessa-persona',
            authorName: 'stessa',
            bytes: Uint8List.fromList(const [1, 2, 3]),
          ),
        );
      }

      return entries;
    }

    test('votare in una gara non accende la fiamma nell\'altra', () async {
      final container = guestContainer();
      final entries = await sameAuthorTwice(container);

      expect(
        entries[0].id,
        entries[1].id,
        reason: 'lo stesso nome, di proposito',
      );
      expect(entries[0].voteKey, isNot(entries[1].voteKey));

      await container
          .read(voteControllerProvider)
          .toggle(entries[0], voted: true);

      final subscription = container.listen(votedEntryIdsProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(votedEntryIdsProvider.future);

      expect(container.read(entryVotedProvider(entries[0].voteKey)), isTrue);
      expect(
        container.read(entryVotedProvider(entries[1].voteKey)),
        isFalse,
        reason: 'la foto nell\'altra gara non e\' stata votata da nessuno',
      );
    });

    test('e non fa scendere il conto dell\'altra', () async {
      final container = guestContainer();
      final entries = await sameAuthorTwice(container);
      final controller = container.read(voteControllerProvider);
      final samples = container.read(sampleChallengeRepositoryProvider);

      await controller.toggle(entries[0], voted: true);
      // Il gesto che spostava un voto da una foto all'altra: togliere una
      // fiamma nella seconda gara, dove non era mai stata data.
      await controller.toggle(entries[1], voted: false);

      final first = await samples.watchEntries(entries[0].challengeId).first;
      final second = await samples.watchEntries(entries[1].challengeId).first;

      expect(first.single.votes, 1);
      expect(second.single.votes, 0);
    });
  });

  group('tre fiamme per gara', () {
    /// Una gara con dentro quante foto servono.
    Future<(String, List<ChallengeEntry>)> garaCon(
      ProviderContainer container,
      int quante,
    ) async {
      final samples = container.read(sampleChallengeRepositoryProvider);
      final now = DateTime.now();
      final challenge = await samples.createChallenge(
        Challenge(
          id: '',
          title: 'Tre fiamme',
          brief: 'Fai qualcosa.',
          prizeCents: 5000,
          scope: ChallengeScope.global,
          startsAt: now.subtract(const Duration(hours: 1)),
          endsAt: now.add(const Duration(days: 1)),
        ),
      );

      final entries = [
        for (var i = 0; i < quante; i++)
          await samples.submitEntry(
            challengeId: challenge.id,
            userId: 'autore$i',
            authorName: 'autore$i',
            bytes: Uint8List.fromList(const [1, 2, 3]),
          ),
      ];

      return (challenge.id, entries);
    }

    test('si comincia con tre', () async {
      final container = guestContainer();
      final (challengeId, _) = await garaCon(container, 4);

      expect(container.read(firesLeftProvider(challengeId)), 3);
    });

    test('ogni fiamma accesa ne toglie una', () async {
      final container = guestContainer();
      final (challengeId, entries) = await garaCon(container, 4);
      final controller = container.read(voteControllerProvider);
      final subscription = container.listen(votedEntryIdsProvider, (_, _) {});
      addTearDown(subscription.close);

      await controller.toggle(entries[0], voted: true);
      await untilConfirmed(container, entries[0].voteKey);

      expect(container.read(firesLeftProvider(challengeId)), 2);

      await controller.toggle(entries[1], voted: true);
      await untilConfirmed(container, entries[1].voteKey);
      await controller.toggle(entries[2], voted: true);
      await untilConfirmed(container, entries[2].voteKey);

      expect(container.read(firesLeftProvider(challengeId)), 0);
    });

    test('togliendone una se ne riprende una', () async {
      final container = guestContainer();
      final (challengeId, entries) = await garaCon(container, 4);
      final controller = container.read(voteControllerProvider);
      final subscription = container.listen(votedEntryIdsProvider, (_, _) {});
      addTearDown(subscription.close);

      await controller.toggle(entries[0], voted: true);
      await untilConfirmed(container, entries[0].voteKey);

      expect(container.read(firesLeftProvider(challengeId)), 2);

      // Il conto e' di quante ne stanno accese, non di quante volte si e'
      // toccato: ripensarci non costa niente.
      await controller.toggle(entries[0], voted: false);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(firesLeftProvider(challengeId)), 3);
    });

    test('in un\'altra gara se ne hanno altre tre', () async {
      final container = guestContainer();
      final (primaId, primaEntries) = await garaCon(container, 3);
      final (secondaId, _) = await garaCon(container, 3);
      final controller = container.read(voteControllerProvider);
      final subscription = container.listen(votedEntryIdsProvider, (_, _) {});
      addTearDown(subscription.close);

      for (final entry in primaEntries) {
        await controller.toggle(entry, voted: true);
        await untilConfirmed(container, entry.voteKey);
      }

      expect(container.read(firesLeftProvider(primaId)), 0);
      expect(container.read(firesLeftProvider(secondaId)), 3);
    });
  });

  group('cambiando account', () {
    /// Un contenitore con dentro una persona vera, non un ospite.
    (ProviderContainer, FakeAuthRepository) containerCon(String userId) {
      final authRepository = FakeAuthRepository(
        currentUser: AppUser(id: userId, email: '$userId@esempio.it'),
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
      );

      addTearDown(() {
        authRepository.dispose();
        container.dispose();
      });

      return (container, authRepository);
    }

    test('le fiamme di uno non si vedono addosso a un altro', () async {
      final (container, auth) = containerCon('anna');

      // Lo stato dell'accesso va ascoltato o resta fermo su "sto caricando":
      // e' un Notifier, e senza nessuno in ascolto non si accorge di niente.
      final sessione = container.listen(authStateProvider, (_, _) {});
      addTearDown(sessione.close);
      await Future<void>.delayed(Duration.zero);

      const voteKey = 'gara-1__foto-1';

      // Anna accende la fiamma. La richiesta resta in volo — e' esattamente il
      // momento in cui prima si rompeva: se l'account cambia adesso, la
      // conferma che arriva e' di un'altra persona e non chiude piu' niente.
      container
          .read(voteIntentsProvider.notifier)
          .want(voteKey, const VoteIntent(voted: true, votes: 1));

      expect(container.read(entryVotedProvider(voteKey)), isTrue);

      // Entra Bruno.
      auth.becomes(const AppUser(id: 'bruno', email: 'bruno@esempio.it'));
      await Future<void>.delayed(Duration.zero);

      // **Bruno non ha votato niente.** Prima qui la fiamma era accesa, e il
      // numero sotto la foto diceva uno: il gesto di Anna attribuito a lui.
      expect(container.read(voteIntentsProvider), isEmpty);
      expect(container.read(entryVotedProvider(voteKey)), isFalse);
    });

    test('nemmeno le fiamme rimaste da spendere si portano dietro', () async {
      final (container, auth) = containerCon('anna');
      final sessione = container.listen(authStateProvider, (_, _) {});
      addTearDown(sessione.close);
      await Future<void>.delayed(Duration.zero);

      final intents = container.read(voteIntentsProvider.notifier);

      for (var i = 0; i < Challenge.firesPerChallenge; i++) {
        intents.want(
          'gara-1__foto-$i',
          const VoteIntent(voted: true, votes: 1),
        );
      }

      expect(container.read(firesLeftProvider('gara-1')), 0);

      auth.becomes(const AppUser(id: 'bruno', email: 'bruno@esempio.it'));
      await Future<void>.delayed(Duration.zero);

      // Bruno entra con le sue tre fiamme intatte. Se il conto si portasse
      // dietro quello di Anna, si ritroverebbe una gara in cui non puo' votare
      // senza aver mai toccato niente.
      expect(
        container.read(firesLeftProvider('gara-1')),
        Challenge.firesPerChallenge,
      );
    });
  });
}
