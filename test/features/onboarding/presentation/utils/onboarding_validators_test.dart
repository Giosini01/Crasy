import 'package:app_incontri/features/onboarding/presentation/utils/onboarding_validators.dart';
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

    test('validates city', () {
      expect(OnboardingValidators.validateCity(''), isNotNull);
      expect(OnboardingValidators.validateCity('R'), isNotNull);
      expect(OnboardingValidators.validateCity('Roma'), isNull);
    });

    test('checks onboarding completion requirements', () {
      expect(
        OnboardingValidators.canComplete(
          name: 'Anna',
          birthDate: DateTime(1998, 6, 1),
          gender: GenderIdentity.woman,
          interestedIn: InterestPreference.men,
          city: 'Roma',
          now: now,
        ),
        isTrue,
      );
    });
  });
}
