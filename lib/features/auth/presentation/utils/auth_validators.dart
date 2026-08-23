import 'package:crasy/core/moderation/email_policy.dart';

abstract final class AuthValidators {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Inserisci la tua email.';
    }

    if (!_emailPattern.hasMatch(email)) {
      return 'Inserisci un indirizzo email valido.';
    }

    return null;
  }

  /// L'email di **chi si registra**, che ha un controllo in piu'.
  ///
  /// Sta separato da [validateEmail] di proposito: il divieto vale alla nascita
  /// di un account, non all'ingresso. Chi si e' registrato ieri con un dominio
  /// che oggi finisce nell'elenco deve poter continuare a entrare — chiudere
  /// fuori qualcuno che e' gia' dentro, magari con delle foto in gara, sarebbe
  /// una punizione per una regola scritta dopo.
  static String? validateNewEmail(String? value) {
    final problema = validateEmail(value);

    if (problema != null) {
      return problema;
    }

    return EmailPolicy.validate(value);
  }

  static String? validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Inserisci una password.';
    }

    if (password.length < 8) {
      return 'La password deve avere almeno 8 caratteri.';
    }

    return null;
  }

  static String? validatePasswordConfirmation({
    required String? password,
    required String? confirmation,
  }) {
    final confirmationValue = confirmation ?? '';

    if (confirmationValue.isEmpty) {
      return 'Conferma la password.';
    }

    if (password != confirmationValue) {
      return 'Le password non coincidono.';
    }

    return null;
  }
}
