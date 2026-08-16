import 'package:crasy/core/moderation/age_policy.dart';
import 'package:crasy/core/moderation/content_policy.dart';

abstract final class OnboardingValidators {
  /// Il nome utente e' l'unica cosa obbligatoria di tutto l'onboarding.
  ///
  /// Deve esserlo: e' la firma sotto ogni foto mandata a una challenge, e
  /// senza di essa il feed sarebbe una fila di scatti di nessuno.
  static const int usernameMinLength = 3;
  static const int usernameMaxLength = 20;

  /// Lettere minuscole, cifre, punto e trattino basso.
  ///
  /// Niente maiuscole e niente spazi, e non per pignoleria: due nomi che si
  /// leggono uguali ma si scrivono diversi — `Marta` e `marta` — in una
  /// classifica con dei soldi in palio sono un problema, non un dettaglio.
  static final RegExp _usernamePattern = RegExp(r'^[a-z0-9._]+$');

  static String? validateUsername(String? value) {
    final username = value?.trim() ?? '';

    if (username.isEmpty) {
      return 'Scegli un nome utente.';
    }

    if (username.length < usernameMinLength) {
      return 'Almeno $usernameMinLength caratteri.';
    }

    if (username.length > usernameMaxLength) {
      return 'Al massimo $usernameMaxLength caratteri.';
    }

    if (!_usernamePattern.hasMatch(username)) {
      return 'Solo minuscole, numeri, punto e trattino basso.';
    }

    // Il nome utente sta sotto ogni foto e in cima a ogni classifica: passa
    // dalla stessa porta di tutto il resto.
    return ContentPolicy.validate(username);
  }

  /// La data di nascita: obbligatoria, e almeno diciotto anni.
  static String? validateBirthDate(DateTime? birthDate, {DateTime? now}) {
    return AgePolicy.validate(birthDate, now: now);
  }

  /// Quanto puo' essere lunga la riga di presentazione.
  ///
  /// Cortissima di proposito: se ci sta un paragrafo, la gente ci scrive un
  /// paragrafo, e il profilo torna a essere il posto in cui ci si racconta
  /// invece che l'elenco di quello che si e' fatto.
  static const int bioMaxLength = 80;

  /// La bio e' facoltativa: solo la lunghezza puo' renderla non valida.
  static String? validateBio(String? value) {
    final bio = value?.trim() ?? '';

    if (bio.length > bioMaxLength) {
      return 'Al massimo $bioMaxLength caratteri.';
    }

    return ContentPolicy.validate(bio);
  }

  static const int cityMaxLength = 40;

  /// Anche la citta' e' facoltativa: serve a riconoscere le challenge locali,
  /// non a entrare.
  static String? validateCity(String? value) {
    final city = value?.trim() ?? '';

    if (city.length > cityMaxLength) {
      return 'Al massimo $cityMaxLength caratteri.';
    }

    return null;
  }

  static bool canComplete({
    required String username,
    required DateTime? birthDate,
    String bio = '',
    String city = '',
    DateTime? now,
  }) {
    return validateUsername(username) == null &&
        validateBirthDate(birthDate, now: now) == null &&
        validateBio(bio) == null &&
        validateCity(city) == null;
  }
}
