import 'package:app_incontri/core/utils/app_date_utils.dart';
import 'package:app_incontri/features/profile/domain/entities/user_profile.dart';

abstract final class OnboardingValidators {
  static String? validateName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'Inserisci il tuo nome.';
    }

    if (name.length < 2) {
      return 'Il nome deve avere almeno 2 caratteri.';
    }

    return null;
  }

  static String? validateBirthDate(DateTime? birthDate, {DateTime? now}) {
    if (birthDate == null) {
      return 'Seleziona la tua data di nascita.';
    }

    final today = now ?? DateTime.now();

    if (birthDate.isAfter(today)) {
      return 'La data di nascita non puo essere futura.';
    }

    final age = AppDateUtils.calculateAge(birthDate, now: today);

    if (age < 18) {
      return 'Devi avere almeno 18 anni per usare Daily.';
    }

    return null;
  }

  static String? validateGender(GenderIdentity? gender) {
    if (gender == null) {
      return 'Seleziona come ti identifichi.';
    }

    return null;
  }

  static String? validateInterest(InterestPreference? interest) {
    if (interest == null) {
      return 'Seleziona chi vuoi conoscere.';
    }

    return null;
  }

  static String? validateCity(String? value) {
    final city = value?.trim() ?? '';

    if (city.isEmpty) {
      return 'Inserisci la tua citta o zona.';
    }

    if (city.length < 2) {
      return 'Inserisci una citta o zona valida.';
    }

    return null;
  }

  static bool canComplete({
    required String name,
    required DateTime? birthDate,
    required GenderIdentity? gender,
    required InterestPreference? interestedIn,
    required String city,
    DateTime? now,
  }) {
    return validateName(name) == null &&
        validateBirthDate(birthDate, now: now) == null &&
        validateGender(gender) == null &&
        validateInterest(interestedIn) == null &&
        validateCity(city) == null;
  }
}
