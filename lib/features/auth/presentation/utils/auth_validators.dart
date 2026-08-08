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
