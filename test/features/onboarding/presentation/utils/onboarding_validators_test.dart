import 'package:app_incontri/features/onboarding/presentation/utils/onboarding_validators.dart';
import 'package:app_incontri/features/profile/domain/entities/coordinates.dart';
import 'package:app_incontri/features/profile/domain/entities/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnboardingValidators', () {
    final now = DateTime(2026, 8, 8);

    test('validates name', () {
      expect(OnboardingValidators.validateName(''), isNotNull);
      expect(OnboardingValidators.validateName('A'), isNotNull);
      expect(OnboardingValidators.validateName('Anna'), isNull);
    });

    test('validates birth date and adult age', () {
      expect(OnboardingValidators.validateBirthDate(null, now: now), isNotNull);
      expect(
        OnboardingValidators.validateBirthDate(DateTime(2026, 8, 9), now: now),
        isNotNull,
      );
      expect(
        OnboardingValidators.validateBirthDate(DateTime(2010, 8, 9), now: now),
        isNotNull,
      );
      expect(
        OnboardingValidators.validateBirthDate(DateTime(2000, 1, 1), now: now),
        isNull,
      );
    });

    test('validates icebreaker length but allows it to be empty', () {
      expect(OnboardingValidators.validateIcebreaker(''), isNull);
      expect(
        OnboardingValidators.validateIcebreaker('Chiedimi del mio ultimo viaggio'),
        isNull,
      );
      expect(
        OnboardingValidators.validateIcebreaker(
          'x' * (OnboardingValidators.icebreakerMaxLength + 1),
        ),
        isNotNull,
      );
    });

    test('requires a minimum number of interests', () {
      expect(OnboardingValidators.validateInterests(const []), isNotNull);
      expect(
        OnboardingValidators.validateInterests(const ['libri', 'musica']),
        isNotNull,
      );
      expect(
        OnboardingValidators.validateInterests(
          const ['libri', 'musica', 'viaggi'],
        ),
        isNull,
      );
    });

    test('checks onboarding completion requirements', () {
      expect(
        OnboardingValidators.canComplete(
          name: 'Anna',
          birthDate: DateTime(1998, 6, 1),
          gender: GenderIdentity.woman,
          interestedIn: InterestPreference.men,
          coordinates: const Coordinates(latitude: 41.9, longitude: 12.5),
          now: now,
        ),
        isTrue,
      );
    });

    test('onboarding cannot complete without coordinates', () {
      expect(
        OnboardingValidators.canComplete(
          name: 'Anna',
          birthDate: DateTime(1998, 6, 1),
          gender: GenderIdentity.woman,
          interestedIn: InterestPreference.men,
          coordinates: null,
          now: now,
        ),
        isFalse,
      );
    });
  });
}

