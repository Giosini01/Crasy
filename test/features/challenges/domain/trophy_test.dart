import 'dart:typed_data';

import 'package:crasy/features/challenges/data/repositories/sample_challenge_repository.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:flutter_test/flutter_test.dart';

/// Il trofeo: quello che resta di una gara quando la gara non c'e' piu'.
void main() {
  late SampleChallengeRepository repository;

  setUp(() {
    repository = SampleChallengeRepository();
    addTearDown(repository.dispose);
  });

  /// Una gara di Anna a cui partecipa Bruno.
  Future<(Challenge, ChallengeEntry)> garaConUnaFoto() async {
    final now = DateTime.now();
    final challenge = await repository.createChallenge(
      Challenge(
        id: '',
        title: 'Prova',
        brief: 'Fai qualcosa di assurdo.',
        prizeCents: 50000,
        scope: ChallengeScope.global,
        createdByUserId: 'anna',
        createdByUsername: 'anna',
        startsAt: now.subtract(const Duration(hours: 2)),
        endsAt: now.subtract(const Duration(hours: 1)),
      ),
    );

    final entry = await repository.submitEntry(
      challengeId: challenge.id,
      userId: 'bruno',
      authorName: 'bruno',
      bytes: Uint8List.fromList(const [1, 2, 3]),
    );

    return (challenge, entry);
  }

  test('proclamare un vincitore lascia una figurina sulla gara', () async {
    final (challenge, entry) = await garaConUnaFoto();

    expect(challenge.hasTrophy, isFalse);

    await repository.proclaimWinner(
      challengeId: challenge.id,
      winnerEntryId: entry.id,
      winnerUserId: entry.userId,
      winner: entry,
    );

    final chiusa = await repository.watchChallenge(challenge.id).first;

    // **La foto sta sulla gara, non solo sulla partecipazione.** E' il punto
    // di tutta la faccenda: la partecipazione viene cancellata quarantotto ore
    // dopo la fine, e con lei sparirebbe la prova di aver vinto.
    expect(chiusa!.hasTrophy, isTrue);
    expect(chiusa.winnerMediaUrl, entry.mediaUrl);
    expect(chiusa.winnerUsername, 'bruno');
    expect(chiusa.winnerUserId, 'bruno');
  });

  test('la figurina finisce in tutte e due le bacheche', () async {
    final (challenge, entry) = await garaConUnaFoto();

    await repository.proclaimWinner(
      challengeId: challenge.id,
      winnerEntryId: entry.id,
      winnerUserId: entry.userId,
      winner: entry,
    );

    final diBruno = await repository.watchTrophiesOf('bruno').first;
    final diAnna = await repository.watchCommissionedBy('anna').first;

    // La stessa gara, letta da due parti del tavolo: uno l'ha vinta, l'altra
    // l'ha fatta fare. Sono due orgogli diversi e devono stare tutti e due.
    expect(diBruno.map((c) => c.id), [challenge.id]);
    expect(diAnna.map((c) => c.id), [challenge.id]);
  });

  test('le bacheche degli estranei restano vuote', () async {
    final (challenge, entry) = await garaConUnaFoto();

    await repository.proclaimWinner(
      challengeId: challenge.id,
      winnerEntryId: entry.id,
      winnerUserId: entry.userId,
      winner: entry,
    );

    // Chi ha vinto non ha *commissionato*, e chi ha commissionato non ha vinto:
    // scambiare le due cose vorrebbe dire mettere in bacheca a qualcuno un
    // premio che non ha preso.
    expect(await repository.watchCommissionedBy('bruno').first, isEmpty);
    expect(await repository.watchTrophiesOf('anna').first, isEmpty);
    expect(await repository.watchTrophiesOf('carla').first, isEmpty);
  });

  test('una gara senza partecipanti non lascia niente', () async {
    final now = DateTime.now();
    final challenge = await repository.createChallenge(
      Challenge(
        id: '',
        title: 'Deserta',
        brief: 'Nessuno si e\' fatto vivo.',
        prizeCents: 10000,
        scope: ChallengeScope.global,
        createdByUserId: 'anna',
        createdByUsername: 'anna',
        startsAt: now.subtract(const Duration(hours: 2)),
        endsAt: now.subtract(const Duration(hours: 1)),
      ),
    );

    // Si chiude comunque — altrimenti verrebbe ricontrollata per sempre — ma
    // con il vincitore vuoto. Una gara a cui non ha partecipato nessuno non ha
    // niente da mettere in bacheca, e va bene cosi'.
    await repository.proclaimWinner(
      challengeId: challenge.id,
      winnerEntryId: '',
      winnerUserId: '',
    );

    final chiusa = await repository.watchChallenge(challenge.id).first;

    expect(chiusa!.hasTrophy, isFalse);
    expect(await repository.watchCommissionedBy('anna').first, isEmpty);
  });

  test('il vincitore incassa il premio meno la percentuale', () {
    final challenge = Challenge(
      id: 'x',
      title: 'Prova',
      brief: 'Prova',
      prizeCents: 50000,
      scope: ChallengeScope.global,
      startsAt: DateTime(2026),
      endsAt: DateTime(2026, 1, 2),
    );

    // Quello che va sulla figurina e' **quello che uno ha preso davvero**, non
    // il numero della vetrina: leggere 500 e ritrovarsi 450 sul conto e' il
    // genere di sorpresa che fa perdere fiducia a un'app che maneggia soldi.
    expect(challenge.payoutCents, 45000);
  });
}
