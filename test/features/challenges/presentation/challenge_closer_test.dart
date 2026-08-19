import 'dart:typed_data';

import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/presentation/controllers/challenge_closer.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_repository.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    final authRepository = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
    );

    addTearDown(() {
      authRepository.dispose();
      container.dispose();
    });
  });

  /// Una gara gia' scaduta, con dentro le partecipazioni chieste.
  Future<(Challenge, List<ChallengeEntry>)> endedChallenge({
    required List<String> authors,
  }) async {
    final samples = container.read(sampleChallengeRepositoryProvider);
    final now = DateTime.now();

    final challenge = await samples.createChallenge(
      Challenge(
        id: '',
        title: 'Finita',
        brief: 'Fai qualcosa di assurdo.',
        prizeCents: 50000,
        scope: ChallengeScope.global,
        startsAt: now.subtract(const Duration(hours: 2)),
        endsAt: now.subtract(const Duration(minutes: 1)),
      ),
    );

    final entries = [
      for (final author in authors)
        await samples.submitEntry(
          challengeId: challenge.id,
          userId: author,
          authorName: author,
          bytes: Uint8List.fromList(const [1, 2, 3]),
        ),
    ];

    return (challenge, entries);
  }

  Future<Challenge> reread(String id) async {
    return (await container
        .read(sampleChallengeRepositoryProvider)
        .watchChallenge(id)
        .first)!;
  }

  test('una lista non ancora caricata non chiude niente', () async {
    final (challenge, _) = await endedChallenge(authors: ['a']);

    // E' il bug che ha proclamato "non ha partecipato nessuno" su una gara che
    // aveva un partecipante con due fiamme: la schermata si disegna prima che
    // lo stream emetta, e in quel primo istante l'elenco e' vuoto — non perche'
    // non ci sia nessuno, ma perche' non e' ancora arrivato niente.
    await container
        .read(challengeCloserProvider)
        .closeIfNeeded(challenge, const [], entriesLoaded: false);

    expect((await reread(challenge.id)).winnerEntryId, isNull);
  });

  test('a lista caricata proclama chi ha piu\' fiamme', () async {
    final (challenge, entries) = await endedChallenge(authors: ['a', 'b']);
    final samples = container.read(sampleChallengeRepositoryProvider);

    await samples.setVote(
      challengeId: challenge.id,
      entryId: entries[1].id,
      userId: 'chiunque',
      voted: true,
    );

    final voted = await samples.watchEntries(challenge.id).first;

    await container
        .read(challengeCloserProvider)
        .closeIfNeeded(challenge, voted, entriesLoaded: true);

    expect((await reread(challenge.id)).winnerEntryId, entries[1].id);

    final closed = await samples.watchEntries(challenge.id).first;

    expect(closed.firstWhere((e) => e.id == entries[1].id).isWinner, isTrue);
  });

  test(
    'senza partecipanti si chiude a vuoto, ma solo a lista caricata',
    () async {
      final (challenge, _) = await endedChallenge(authors: []);

      await container
          .read(challengeCloserProvider)
          .closeIfNeeded(challenge, const [], entriesLoaded: true);

      expect((await reread(challenge.id)).winnerEntryId, '');
    },
  );

  test('una gara ancora aperta non si tocca', () async {
    final samples = container.read(sampleChallengeRepositoryProvider);
    final now = DateTime.now();
    final challenge = await samples.createChallenge(
      Challenge(
        id: '',
        title: 'Aperta',
        brief: 'Fai qualcosa.',
        prizeCents: 1000,
        scope: ChallengeScope.global,
        startsAt: now.subtract(const Duration(minutes: 1)),
        endsAt: now.add(const Duration(hours: 1)),
      ),
    );

    await container
        .read(challengeCloserProvider)
        .closeIfNeeded(challenge, const [], entriesLoaded: true);

    expect((await reread(challenge.id)).winnerEntryId, isNull);
  });
}
