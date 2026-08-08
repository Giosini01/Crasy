import 'package:app_incontri/features/auth/presentation/utils/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthValidators', () {
    test('validates email format', () {
      expect(AuthValidators.validateEmail(''), isNotNull);
      expect(AuthValidators.validateEmail('invalid'), isNotNull);
      expect(AuthValidators.validateEmail('test@example.com'), isNull);
    });

    test('validates password length', () {
      expect(AuthValidators.validatePassword(''), isNotNull);
      expect(AuthValidators.validatePassword('1234567'), isNotNull);
      expect(AuthValidators.validatePassword('12345678'), isNull);
    });

    test('validates password confirmation', () {
      expect(
        AuthValidators.validatePasswordConfirmation(
          password: '12345678',
          confirmation: '',
        ),
        isNotNull,
      );
      expect(
        AuthValidators.validatePasswordConfirmation(
          password: '12345678',
          confirmation: '87654321',
        ),
        isNotNull,
      );
      expect(
        AuthValidators.validatePasswordConfirmation(
          password: '12345678',
          confirmation: '12345678',
        ),
        isNull,
      );
    });
  });
}
