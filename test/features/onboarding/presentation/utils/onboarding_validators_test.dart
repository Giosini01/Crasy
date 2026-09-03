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
  });

  group('eta\'', () {
    final now = DateTime(2026, 8, 12);

    test('la data di nascita e\' obbligatoria', () {
      expect(OnboardingValidators.validateBirthDate(null), isNotNull);
    });

    test('sotto i diciotto non si entra', () {
      expect(
        OnboardingValidators.validateBirthDate(DateTime(2015), now: now),
        isNotNull,
      );
      expect(
        OnboardingValidators.validateBirthDate(DateTime(2000), now: now),
        isNull,
      );
    });

    test('il compleanno conta, non solo l\'anno', () {
      // Chi compie diciotto anni oggi entra, chi li compie domani no. E' il
      // confine che si sbaglia contando gli anni per differenza.
      expect(
        OnboardingValidators.validateBirthDate(DateTime(2008, 8, 12), now: now),
        isNull,
      );
      expect(
        OnboardingValidators.validateBirthDate(DateTime(2008, 8, 13), now: now),
        isNotNull,
      );
    });

    test('una data futura non e\' una data di nascita', () {
      expect(
        OnboardingValidators.validateBirthDate(DateTime(2030), now: now),
        isNotNull,
      );
    });
  });

  test('non si passa senza nome utente e data di nascita', () {
    final adult = DateTime(2000, 1, 1);

    expect(
      OnboardingValidators.canComplete(username: 'martina', birthDate: adult),
      isTrue,
    );
    expect(
      OnboardingValidators.canComplete(username: 'ab', birthDate: adult),
      isFalse,
    );
    expect(
      OnboardingValidators.canComplete(username: 'martina', birthDate: null),
      isFalse,
    );
    expect(
      OnboardingValidators.canComplete(
        username: 'martina',
        birthDate: adult,
        bio: 'a' * (OnboardingValidators.bioMaxLength + 1),
      ),
      isFalse,
    );
  });
}
