import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
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

  /// Una partecipazione di esempio, presa da una challenge che ne ha.
  Future<ChallengeEntry> demoEntry(ProviderContainer container) async {
    final samples = container.read(sampleChallengeRepositoryProvider);

    for (final challenge in await samples.watchLiveChallenges().first) {
      final entries = await samples.watchEntries(challenge.id).first;

      if (entries.isNotEmpty) {
        return entries.first;
      }
    }

    fail('Nessuna partecipazione di esempio disponibile.');
  }

  test('un ospite accende la fiamma sulle challenge di esempio', () async {
    final container = guestContainer();
    final entry = await demoEntry(container);

    final outcome = await container
        .read(voteControllerProvider)
        .toggle(entry, voted: true);

    expect(outcome, VoteOutcome.done);

    // Il numero deve muoversi davvero: e' l'unica cosa che l'utente vede.
    final updated = await container
        .read(sampleChallengeRepositoryProvider)
        .watchEntries(entry.challengeId)
        .first;

    expect(
      updated.firstWhere((item) => item.id == entry.id).votes,
      entry.votes + 1,
    );

    final voted = await container
        .read(sampleChallengeRepositoryProvider)
        .watchVotedEntryIds(guestVoterId)
        .first;

    expect(voted, contains(entry.id));
  });

  test('la fiamma si toglie con lo stesso gesto al contrario', () async {
    final container = guestContainer();
    final entry = await demoEntry(container);
    final controller = container.read(voteControllerProvider);

    await controller.toggle(entry, voted: true);
    await controller.toggle(entry, voted: false);

    final updated = await container
        .read(sampleChallengeRepositoryProvider)
        .watchEntries(entry.challengeId)
        .first;

    expect(
      updated.firstWhere((item) => item.id == entry.id).votes,
      entry.votes,
    );
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
    final entry = await demoEntry(container);

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
