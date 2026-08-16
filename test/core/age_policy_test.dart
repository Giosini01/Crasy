import 'package:crasy/core/moderation/age_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 12);

  group('quanti anni ha', () {
    test('conta il compleanno, non solo l\'anno', () {
      expect(AgePolicy.ageAt(DateTime(2000, 8, 12), now: now), 26);
      // Il compleanno e' domani: ha ancora venticinque anni.
      expect(AgePolicy.ageAt(DateTime(2000, 8, 13), now: now), 25);
      // L'ha compiuto ieri.
      expect(AgePolicy.ageAt(DateTime(2000, 8, 11), now: now), 26);
    });

    test('regge il cambio di mese', () {
      expect(AgePolicy.ageAt(DateTime(2000, 12, 31), now: now), 25);
      expect(AgePolicy.ageAt(DateTime(2000, 1, 1), now: now), 26);
    });
  });

  group('chi entra', () {
    test('diciotto esatti bastano', () {
      expect(AgePolicy.isAdult(DateTime(2008, 8, 12), now: now), isTrue);
    });

    test('un giorno di meno no', () {
      expect(AgePolicy.isAdult(DateTime(2008, 8, 13), now: now), isFalse);
    });

    test('un bambino no', () {
      expect(AgePolicy.isAdult(DateTime(2018, 1, 1), now: now), isFalse);
    });
  });

  test('il selettore non arriva oltre la soglia', () {
    // Il limite si vede prima: chi e' minorenne non riesce nemmeno a scegliere
    // una data che poi verrebbe rifiutata.
    final latest = AgePolicy.latestAdultBirthDate(now: now);

    expect(latest, DateTime(2008, 8, 12));
    expect(AgePolicy.isAdult(latest, now: now), isTrue);
    expect(
      AgePolicy.isAdult(latest.add(const Duration(days: 1)), now: now),
      isFalse,
    );
  });

  group('cosa dice quando rifiuta', () {
    test('senza data chiede la data', () {
      expect(AgePolicy.validate(null), isNotNull);
    });

    test('a un minorenne dice quanti anni servono', () {
      final message = AgePolicy.validate(DateTime(2015), now: now);

      expect(message, contains('18'));
    });

    test('una data futura viene respinta a parte', () {
      expect(AgePolicy.validate(DateTime(2030), now: now), contains('futuro'));
    });

    test('un maggiorenne passa', () {
      expect(AgePolicy.validate(DateTime(1990, 5, 3), now: now), isNull);
    });
  });
}
