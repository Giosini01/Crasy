import 'package:crasy/features/onboarding/presentation/utils/onboarding_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nome utente', () {
    test('e\' obbligatorio', () {
      expect(OnboardingValidators.validateUsername(null), isNotNull);
      expect(OnboardingValidators.validateUsername('  '), isNotNull);
    });

    test('rispetta la lunghezza minima e massima', () {
      expect(OnboardingValidators.validateUsername('ab'), isNotNull);
      expect(OnboardingValidators.validateUsername('abc'), isNull);
      expect(OnboardingValidators.validateUsername('a' * 20), isNull);
      expect(OnboardingValidators.validateUsername('a' * 21), isNotNull);
    });

    test('accetta solo minuscole, numeri, punto e trattino basso', () {
      expect(OnboardingValidators.validateUsername('martina'), isNull);
      expect(OnboardingValidators.validateUsername('mar.tina_01'), isNull);
      expect(OnboardingValidators.validateUsername('Martina'), isNotNull);
      expect(OnboardingValidators.validateUsername('mar tina'), isNotNull);
      expect(OnboardingValidators.validateUsername('mar-tina'), isNotNull);
    });
  });

  group('campi facoltativi', () {
    test('la bio vuota va bene, quella lunga no', () {
      expect(OnboardingValidators.validateBio(null), isNull);
      expect(OnboardingValidators.validateBio(''), isNull);
      expect(
        OnboardingValidators.validateBio(
          'a' * OnboardingValidators.bioMaxLength,
        ),
        isNull,
      );
      expect(
        OnboardingValidators.validateBio(
          'a' * (OnboardingValidators.bioMaxLength + 1),
        ),
        isNotNull,
      );
    });

    test('la citta\' segue la stessa regola', () {
      expect(OnboardingValidators.validateCity(null), isNull);
      expect(OnboardingValidators.validateCity('Napoli'), isNull);
      expect(
        OnboardingValidators.validateCity(
          'a' * (OnboardingValidators.cityMaxLength + 1),
        ),
        isNotNull,
      );
    });
  });

  test('si puo\' completare con il solo nome utente', () {
    expect(OnboardingValidators.canComplete(username: 'martina'), isTrue);
    expect(OnboardingValidators.canComplete(username: 'ab'), isFalse);
    expect(
      OnboardingValidators.canComplete(
        username: 'martina',
        bio: 'a' * (OnboardingValidators.bioMaxLength + 1),
      ),
      isFalse,
    );
  });
}
