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

  /// Una gara finita, con dentro le partecipazioni chieste.
  ///
  /// [ago] dice **da quanto** e' finita, e ora e' la cosa che decide tutto: a
  /// chi l'ha lanciata restano ventiquattro ore per assegnare il premio, e
  /// prima di allora qui non si chiude niente.
  Future<(Challenge, List<ChallengeEntry>)> endedChallenge({
    required List<String> authors,
    Duration ago = const Duration(hours: 25),
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
        startsAt: now.subtract(ago + const Duration(hours: 2)),
        endsAt: now.subtract(ago),
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

  test('finita da poco non si chiude: sta ancora scegliendo', () async {
    // **E' la regola nuova, e vale un premio.** Il verdetto e' di chi ha messo i
    // soldi, e chiudere prima che il suo tempo scada vorrebbe dire toglierglielo
    // di mano e darlo al conteggio delle fiamme.
    final (challenge, entries) = await endedChallenge(
      authors: ['a', 'b'],
      ago: const Duration(minutes: 10),
    );

    await container
        .read(challengeCloserProvider)
        .closeIfNeeded(challenge, entries, entriesLoaded: true);

    expect((await reread(challenge.id)).winnerEntryId, isNull);
  });

  test('passate le ventiquattro ore vince chi ha piu\' fiamme', () async {
    final (challenge, entries) = await endedChallenge(
      authors: ['a', 'b'],
      ago: const Duration(hours: 25),
    );
    final samples = container.read(sampleChallengeRepositoryProvider);

    await samples.setVote(
      challengeId: challenge.id,
      entryId: entries[1].id,
      userId: 'chiunque',
      voted: true,
    );

    await container
        .read(challengeCloserProvider)
        .closeIfNeeded(
          challenge,
          await samples.watchEntries(challenge.id).first,
          entriesLoaded: true,
        );

    final closed = await reread(challenge.id);

    expect(closed.winnerEntryId, entries[1].id);
    // E si vede che nessuno l'ha scelto: il premio e' scaduto, non assegnato.
    expect(closed.chosenByCreator, isFalse);
  });

  test('chi ha lanciato la gara sceglie chi vuole, anche subito', () async {
    final (challenge, entries) = await endedChallenge(
      authors: ['a', 'b'],
      ago: const Duration(minutes: 5),
    );
    final samples = container.read(sampleChallengeRepositoryProvider);

    // La prima foto non ha nessuna fiamma: e' proprio il punto. Chi mette i
    // soldi sta commissionando un'opera, e la piu' votata non e' sempre quella
    // che aveva chiesto.
    await samples.setVote(
      challengeId: challenge.id,
      entryId: entries[1].id,
      userId: 'chiunque',
      voted: true,
    );

    await samples.proclaimWinner(
      challengeId: challenge.id,
      winnerEntryId: entries[0].id,
      winnerUserId: entries[0].userId,
      chosenByCreator: true,
    );

    final closed = await reread(challenge.id);

    expect(closed.winnerEntryId, entries[0].id);
    expect(closed.chosenByCreator, isTrue);
  });

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
