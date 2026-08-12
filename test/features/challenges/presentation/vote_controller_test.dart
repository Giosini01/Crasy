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

  test('nessuno vota la propria foto', () async {
    final container = guestContainer();
    final entry = await someoneElsesEntry(container);

    // L'ospite firma con `guestVoterId`: una partecipazione con quel nome e'
    // la sua, e con dei soldi in palio auto-votarsi e' il primo modo in cui si
    // prova a barare.
    expect(
      await container
          .read(voteControllerProvider)
          .toggle(entry.copyWith(userId: guestVoterId), voted: true),
      VoteOutcome.ownEntry,
    );
  });
}
