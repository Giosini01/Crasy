import 'package:app_incontri/core/utils/app_date_utils.dart';
import 'package:app_incontri/features/profile/domain/entities/coordinates.dart';
import 'package:app_incontri/features/profile/domain/entities/profile_interests.dart';
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
      return 'Devi avere almeno 18 anni per usare Rawsy.';
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

  /// Quanto puo' essere lungo l'"Oggi...".
  ///
  /// Volutamente cortissimo: non e' una biografia, e' cosa stai facendo
  /// **oggi**. Se ci sta un paragrafo, la gente ci scrive un paragrafo, e da
  /// li' a una scheda di presentazione il passo e' breve.
  static const int icebreakerMaxLength = 80;

  /// Il rompighiaccio e' facoltativo: solo la lunghezza puo' renderlo non
  /// valido.
  static String? validateIcebreaker(String? value) {
    final icebreaker = value?.trim() ?? '';

    if (icebreaker.length > icebreakerMaxLength) {
      return 'Al massimo $icebreakerMaxLength caratteri.';
    }

    return null;
  }

  /// Gli interessi sono obbligatori: sono la base dell'affinita', e con
  /// meno del minimo ogni percentuale risulterebbe falsata.
  static String? validateInterests(List<String> interests) {
    if (interests.length < ProfileInterests.minChoices) {
      return 'Scegli almeno ${ProfileInterests.minChoices} interessi.';
    }

    return null;
  }

  /// Senza coordinate il profilo non entra in nessun feed, quindi la
  /// posizione e' obbligatoria quanto il nome.
  static String? validateLocation(Coordinates? coordinates) {
    if (coordinates == null) {
      return 'Tocca "Usa la mia posizione" per continuare.';
    }

    return null;
  }

  static bool canComplete({
    required String name,
    required DateTime? birthDate,
    required GenderIdentity? gender,
    required InterestPreference? interestedIn,
    required Coordinates? coordinates,
    DateTime? now,
  }) {
    return validateName(name) == null &&
        validateBirthDate(birthDate, now: now) == null &&
        validateGender(gender) == null &&
        validateInterest(interestedIn) == null &&
        validateLocation(coordinates) == null;
  }
}
