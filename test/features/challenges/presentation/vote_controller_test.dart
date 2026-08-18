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

    expect(voted, contains(entry.id));
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
      container.read(pendingVoteProvider(entry.id).notifier).state = true;

      expect(container.read(entryVotedProvider(entry.id)), isTrue);
      expect(container.read(entryVoteDeltaProvider(entry.id)), 1);
    });

    test('a scrittura confermata la correzione locale sparisce', () async {
      final container = guestContainer();
      final entry = await someoneElsesEntry(container);

      container.read(pendingVoteProvider(entry.id).notifier).state = true;
      await container.read(voteControllerProvider).toggle(entry, voted: true);

      // Lo stream va ascoltato perche' emetta: senza, `valueOrNull` resta a
      // null e la correzione locale sembrerebbe ancora necessaria.
      final subscription = container.listen(votedEntryIdsProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(votedEntryIdsProvider.future);

      // Il server ora dice la stessa cosa dell'utente: aggiungere ancora uno
      // al contatore lo farebbe vedere a due.
      expect(container.read(entryVotedProvider(entry.id)), isTrue);
      expect(container.read(entryVoteDeltaProvider(entry.id)), 0);
    });
  });
}
