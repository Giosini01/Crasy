import 'dart:typed_data';

import 'package:crasy/features/challenges/data/repositories/sample_challenge_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SampleChallengeRepository repository;

  setUp(() => repository = SampleChallengeRepository());
  tearDown(() => repository.dispose());

  final bytes = Uint8List.fromList(const [1, 2, 3]);

  Future<String> firstLiveChallengeId() async {
    final live = await repository.watchLiveChallenges().first;

    return live.first.id;
  }

  /// La prima challenge aperta che ha gia' delle partecipazioni.
  ///
  /// Serve alle prove sul voto: la challenge che scade prima e' quella locale,
  /// che nasce vuota di proposito per far vedere anche quel caso.
  Future<String> challengeWithEntriesId() async {
    final live = await repository.watchLiveChallenges().first;

    for (final challenge in live) {
      if ((await repository.watchEntries(challenge.id).first).isNotEmpty) {
        return challenge.id;
      }
    }

    fail('Nessuna challenge di esempio ha delle partecipazioni.');
  }

  test('parte con delle challenge aperte e una conclusa', () async {
    final live = await repository.watchLiveChallenges().first;
    final ended = await repository.watchEndedChallenges().first;

    expect(live, isNotEmpty);
    expect(ended, isNotEmpty);
    expect(ended.first.winnerEntryId, isNotNull);
  });

  test('le challenge aperte sono ordinate per scadenza', () async {
    final live = await repository.watchLiveChallenges().first;
    final deadlines = live.map((challenge) => challenge.endsAt).toList();

    expect(deadlines, orderedEquals([...deadlines]..sort()));
  });

  test('partecipare aggiunge una foto e un partecipante', () async {
    final challengeId = await firstLiveChallengeId();
    final before = (await repository.watchChallenge(challengeId).first)!;

    await repository.submitEntry(
      challengeId: challengeId,
      userId: 'me',
      authorName: 'io',
      bytes: bytes,
    );

    final after = (await repository.watchChallenge(challengeId).first)!;
    final mine = await repository.watchEntriesByUser('me').first;

    expect(after.participantsCount, before.participantsCount + 1);
    expect(mine, hasLength(1));
    expect(mine.first.authorName, 'io');
  });

  test('rimandare una foto la sostituisce senza contare due volte', () async {
    final challengeId = await firstLiveChallengeId();

    await repository.submitEntry(
      challengeId: challengeId,
      userId: 'me',
      authorName: 'io',
      bytes: bytes,
    );

    final afterFirst = (await repository.watchChallenge(challengeId).first)!;

    await repository.submitEntry(
      challengeId: challengeId,
      userId: 'me',
      authorName: 'io',
      bytes: bytes,
    );

    final afterSecond = (await repository.watchChallenge(challengeId).first)!;

    expect(afterSecond.participantsCount, afterFirst.participantsCount);
    expect(await repository.watchEntriesByUser('me').first, hasLength(1));
  });

  test('il voto si mette, si toglie, e non si conta due volte', () async {
    final challengeId = await challengeWithEntriesId();
    final entries = await repository.watchEntries(challengeId).first;
    final entry = entries.first;

    await repository.setVote(
      challengeId: challengeId,
      entryId: entry.id,
      userId: 'me',
      voted: true,
    );

    // Lo stesso voto una seconda volta non deve muovere il contatore: e' il
    // caso del doppio tocco, che con dei soldi in palio non e' un dettaglio.
    await repository.setVote(
      challengeId: challengeId,
      entryId: entry.id,
      userId: 'me',
      voted: true,
    );

    var voted = await repository.watchVotedEntryIds('me').first;
    var current = (await repository.watchEntries(challengeId).first).firstWhere(
      (item) => item.id == entry.id,
    );

    expect(voted, contains(entry.id));
    expect(current.votes, entry.votes + 1);

    await repository.setVote(
      challengeId: challengeId,
      entryId: entry.id,
      userId: 'me',
      voted: false,
    );

    voted = await repository.watchVotedEntryIds('me').first;
    current = (await repository.watchEntries(challengeId).first).firstWhere(
      (item) => item.id == entry.id,
    );

    expect(voted, isNot(contains(entry.id)));
    expect(current.votes, entry.votes);
  });

  test('le partecipazioni di una challenge sono ordinate per voti', () async {
    final challengeId = await challengeWithEntriesId();
    final entries = await repository.watchEntries(challengeId).first;
    final votes = entries.map((entry) => entry.votes).toList();

    expect(votes, orderedEquals([...votes]..sort((a, b) => b.compareTo(a))));
  });

  test('partecipare a una challenge che non esiste fallisce', () async {
    expect(
      () => repository.submitEntry(
        challengeId: 'non-esiste',
        userId: 'me',
        authorName: 'io',
        bytes: bytes,
      ),
      throwsA(isA<SampleChallengeMissingException>()),
    );
  });
}
