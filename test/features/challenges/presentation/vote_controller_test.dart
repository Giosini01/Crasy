import 'dart:typed_data';

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

  group('la memoria condivisa della fiamma', () {
    test('il doppio tocco e la fiamma sotto sono lo stesso gesto', () async {
      final container = guestContainer();
      final entry = await someoneElsesEntry(container);

      // Il doppio tocco sulla foto scrive qui. E' l'unico posto in cui lo
      // scrive: prima il contatore sotto teneva una copia sua, e chi faceva
      // tutti e due i gesti vedeva il numero salire di due.
      container.read(pendingVoteProvider(entry.voteKey).notifier).state = true;

      expect(container.read(entryVotedProvider(entry.voteKey)), isTrue);
      expect(container.read(entryVoteDeltaProvider(entry.voteKey)), 1);
    });

    test('a scrittura confermata la correzione locale sparisce', () async {
      final container = guestContainer();
      final entry = await someoneElsesEntry(container);

      container.read(pendingVoteProvider(entry.voteKey).notifier).state = true;
      await container.read(voteControllerProvider).toggle(entry, voted: true);

      // Lo stream va ascoltato perche' emetta: senza, `valueOrNull` resta a
      // null e la correzione locale sembrerebbe ancora necessaria.
      final subscription = container.listen(votedEntryIdsProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(votedEntryIdsProvider.future);

      // Il server ora dice la stessa cosa dell'utente: aggiungere ancora uno
      // al contatore lo farebbe vedere a due.
      expect(container.read(entryVotedProvider(entry.voteKey)), isTrue);
      expect(container.read(entryVoteDeltaProvider(entry.voteKey)), 0);
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

  test('il numero a schermo non puo\' essere negativo', () async {
    final container = guestContainer();
    final entry = await someoneElsesEntry(container);

    // Lo stato che produceva il "-1": il server dice zero fiamme, l'elenco dei
    // voti dati dice ancora di si', e la correzione locale vale meno uno.
    // Somma: meno uno. Il conto e' giusto, il numero non ha senso.
    container.read(pendingVoteProvider(entry.voteKey).notifier).state = true;
    await container.read(voteControllerProvider).toggle(entry, voted: true);
    await container.read(votedEntryIdsProvider.future);
    container.read(pendingVoteProvider(entry.voteKey).notifier).state = false;

    final delta = container.read(entryVoteDeltaProvider(entry.voteKey));
    final zeroVotes = entry.copyWith(votes: 0);
    final shown = zeroVotes.votes + delta;

    expect(delta, -1);
    expect(shown, -1, reason: 'e\' proprio la somma che andava fermata');
    expect(shown < 0 ? 0 : shown, 0);
  });

  test('a scrittura riuscita la correzione locale si spegne', () async {
    final container = guestContainer();
    final entry = await someoneElsesEntry(container);

    // La correzione locale vale solo mentre la scrittura e' in volo. Restando
    // accesa dopo, il numero mostrato resta appeso al valore letto prima del
    // voto e non si muove piu': era il difetto che si vedeva guardando una foto
    // a schermo intero.
    container.read(pendingVoteProvider(entry.voteKey).notifier).state = true;
    await container.read(voteControllerProvider).toggle(entry, voted: true);
    container.read(pendingVoteProvider(entry.voteKey).notifier).state = null;

    final subscription = container.listen(votedEntryIdsProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(votedEntryIdsProvider.future);

    expect(container.read(entryVotedProvider(entry.voteKey)), isTrue);
    expect(container.read(entryVoteDeltaProvider(entry.voteKey)), 0);
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
}
