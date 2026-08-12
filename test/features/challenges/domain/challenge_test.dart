import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 12, 10);

  Challenge challenge({
    String id = 'c1',
    int prizeCents = 50000,
    ChallengeScope scope = ChallengeScope.global,
    String place = '',
    DateTime? startsAt,
    DateTime? endsAt,
  }) {
    return Challenge(
      id: id,
      title: 'Do something crazy',
      brief: 'Fai la foto piu\' pazza che riesci.',
      prizeCents: prizeCents,
      scope: scope,
      place: place,
      startsAt: startsAt ?? now.subtract(const Duration(hours: 2)),
      endsAt: endsAt ?? now.add(const Duration(hours: 5)),
    );
  }

  group('stato nel tempo', () {
    test('e\' aperta fra inizio e fine', () {
      expect(challenge().isLiveAt(now), isTrue);
      expect(challenge().isUpcomingAt(now), isFalse);
      expect(challenge().hasEndedAt(now), isFalse);
    });

    test('non e\' ancora aperta prima dell\'inizio', () {
      final future = challenge(
        startsAt: now.add(const Duration(hours: 1)),
        endsAt: now.add(const Duration(hours: 6)),
      );

      expect(future.isUpcomingAt(now), isTrue);
      expect(future.isLiveAt(now), isFalse);
    });

    test('e\' chiusa dall\'istante esatto della scadenza', () {
      final ending = challenge(endsAt: now);

      expect(ending.hasEndedAt(now), isTrue);
      expect(ending.isLiveAt(now), isFalse);
    });

    test('il tempo che manca non va mai sotto zero', () {
      final ended = challenge(endsAt: now.subtract(const Duration(hours: 3)));

      expect(ended.timeLeftAt(now), Duration.zero);
      expect(challenge().timeLeftAt(now), const Duration(hours: 5));
    });
  });

  group('come si presenta', () {
    test('il premio si scrive con il simbolo e senza decimali inutili', () {
      expect(challenge().prizeLabel, '€500');
      expect(challenge(prizeCents: 125000).prizeLabel, '€1.250');
      expect(challenge(prizeCents: 9950).prizeLabel, '€99,50');
    });

    test('il luogo vince sull\'etichetta di ripiego dell\'ambito', () {
      expect(challenge().scopeLabel, 'GLOBAL');
      expect(challenge(scope: ChallengeScope.country).scopeLabel, 'ITALIA');
      expect(
        challenge(scope: ChallengeScope.local, place: 'NAPOLI').scopeLabel,
        'NAPOLI',
      );
    });
  });

  test('le challenge di esempio si riconoscono dall\'identificativo', () {
    expect(challenge(id: '${Challenge.demoIdPrefix}global-500').isDemo, isTrue);
    expect(challenge(id: 'abc123').isDemo, isFalse);
  });

  test('un ambito sconosciuto non fa cadere la lettura', () {
    expect(ChallengeScope.fromName('marziano'), ChallengeScope.global);
    expect(ChallengeScope.fromName(null), ChallengeScope.global);
    expect(ChallengeScope.fromName('local'), ChallengeScope.local);
  });
}
