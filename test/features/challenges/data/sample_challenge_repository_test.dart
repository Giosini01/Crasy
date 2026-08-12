import 'dart:typed_data';

import 'package:crasy/features/challenges/data/repositories/firestore_challenge_repository.dart';
import 'package:crasy/features/challenges/data/repositories/sample_challenge_repository.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SampleChallengeRepository repository;

  setUp(() => repository = SampleChallengeRepository());
  tearDown(() => repository.dispose());

  final bytes = Uint8List.fromList(const [1, 2, 3]);
  final now = DateTime.now();

  /// Una challenge aperta, creata sul momento.
  ///
  /// I dati se li fabbrica ogni prova: il repository nasce vuoto, e un test che
  /// dipende da un contenuto precotto smette di dire cosa sta verificando.
  Future<Challenge> openChallenge({String title = 'Prova'}) {
    return repository.createChallenge(
      Challenge(
        id: '',
        title: title,
        brief: 'Fai qualcosa di assurdo.',
        prizeCents: 50000,
        scope: ChallengeScope.global,
        createdByUsername: 'io',
        createdByUserId: 'me',
        startsAt: now.subtract(const Duration(hours: 1)),
        endsAt: now.add(const Duration(days: 1)),
      ),
    );
  }

  test('nasce senza nessuna challenge', () async {
    expect(await repository.watchLiveChallenges().first, isEmpty);
    expect(await repository.watchEndedChallenges().first, isEmpty);
    expect(await repository.watchEntriesByUser('me').first, isEmpty);
  });

  test('una challenge lanciata compare fra quelle aperte', () async {
    final created = await openChallenge();
    final live = await repository.watchLiveChallenges().first;

    expect(live, hasLength(1));
    expect(live.first.id, created.id);
    expect(live.first.participantsCount, 0);
  });

  test('le challenge aperte sono ordinate per scadenza', () async {
    await repository.createChallenge(
      Challenge(
        id: '',
        title: 'Fra tre giorni',
        brief: 'x',
        prizeCents: 100,
        scope: ChallengeScope.global,
        startsAt: now,
        endsAt: now.add(const Duration(days: 3)),
      ),
    );
    await repository.createChallenge(
      Challenge(
        id: '',
        title: 'Fra un\'ora',
        brief: 'x',
        prizeCents: 100,
        scope: ChallengeScope.global,
        startsAt: now,
        endsAt: now.add(const Duration(hours: 1)),
      ),
    );

    final live = await repository.watchLiveChallenges().first;

    expect(live.map((challenge) => challenge.title), [
      'Fra un\'ora',
      'Fra tre giorni',
    ]);
  });

  test('partecipare aggiunge una foto e un partecipante', () async {
    final challenge = await openChallenge();

    await repository.submitEntry(
      challengeId: challenge.id,
      userId: 'me',
      authorName: 'io',
      bytes: bytes,
    );

    final after = (await repository.watchChallenge(challenge.id).first)!;
    final mine = await repository.watchEntriesByUser('me').first;

    expect(after.participantsCount, 1);
    expect(mine, hasLength(1));
    expect(mine.first.authorName, 'io');
  });

  test('la foto scattata resta visibile senza Storage', () async {
    final challenge = await openChallenge();

    final entry = await repository.submitEntry(
      challengeId: challenge.id,
      userId: 'me',
      authorName: 'io',
      bytes: bytes,
      contentType: 'image/png',
    );

    // I byte finiscono dentro l'indirizzo: e' l'unico modo perche' una foto
    // scattata in prova si veda davvero, senza un bucket dietro.
    expect(entry.mediaUrl, startsWith('data:image/png;base64,'));
    expect(entry.mediaUrl.length, greaterThan('data:image/png;base64,'.length));
  });

  test('una foto sola a testa: la seconda viene rifiutata', () async {
    final challenge = await openChallenge();

    await repository.submitEntry(
      challengeId: challenge.id,
      userId: 'me',
      authorName: 'io',
      bytes: bytes,
    );

    await expectLater(
      repository.submitEntry(
        challengeId: challenge.id,
        userId: 'me',
        authorName: 'io',
        bytes: bytes,
      ),
      throwsA(isA<AlreadyParticipatingException>()),
    );

    // Il rifiuto non deve lasciare tracce: ne' un partecipante in piu' ne' una
    // seconda foto in gara.
    final after = (await repository.watchChallenge(challenge.id).first)!;

    expect(after.participantsCount, 1);
    expect(await repository.watchEntriesByUser('me').first, hasLength(1));
  });

  test('due persone diverse partecipano entrambe', () async {
    final challenge = await openChallenge();

    await repository.submitEntry(
      challengeId: challenge.id,
      userId: 'me',
      authorName: 'io',
      bytes: bytes,
    );
    await repository.submitEntry(
      challengeId: challenge.id,
      userId: 'altra',
      authorName: 'altra',
      bytes: bytes,
    );

    final after = (await repository.watchChallenge(challenge.id).first)!;

    expect(after.participantsCount, 2);
    expect(await repository.watchEntries(challenge.id).first, hasLength(2));
  });

  test('la fiamma si mette, si toglie, e non si conta due volte', () async {
    final challenge = await openChallenge();
    final entry = await repository.submitEntry(
      challengeId: challenge.id,
      userId: 'altra',
      authorName: 'altra',
      bytes: bytes,
    );

    Future<int> votesOf() async {
      final entries = await repository.watchEntries(challenge.id).first;

      return entries.firstWhere((item) => item.id == entry.id).votes;
    }

    await repository.setVote(
      challengeId: challenge.id,
      entryId: entry.id,
      userId: 'me',
      voted: true,
    );

    // Lo stesso voto una seconda volta non deve muovere il contatore: e' il
    // caso del doppio tocco, che con dei soldi in palio non e' un dettaglio.
    await repository.setVote(
      challengeId: challenge.id,
      entryId: entry.id,
      userId: 'me',
      voted: true,
    );

    expect(await votesOf(), 1);
    expect(await repository.watchVotedEntryIds('me').first, contains(entry.id));

    await repository.setVote(
      challengeId: challenge.id,
      entryId: entry.id,
      userId: 'me',
      voted: false,
    );

    expect(await votesOf(), 0);
    expect(
      await repository.watchVotedEntryIds('me').first,
      isNot(contains(entry.id)),
    );
  });

  test('le partecipazioni di una challenge sono ordinate per fiamme', () async {
    final challenge = await openChallenge();

    for (final user in ['a', 'b', 'c']) {
      await repository.submitEntry(
        challengeId: challenge.id,
        userId: user,
        authorName: user,
        bytes: bytes,
      );
    }

    await repository.setVote(
      challengeId: challenge.id,
      entryId: 'b',
      userId: 'votante',
      voted: true,
    );

    final entries = await repository.watchEntries(challenge.id).first;

    expect(entries.first.id, 'b');
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
