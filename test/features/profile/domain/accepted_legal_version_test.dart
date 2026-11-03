import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _chiHaAccettato(String versione) => UserProfile(
  id: 'user-1',
  username: 'martina',
  birthDate: DateTime(2000, 1, 1),
  createdAt: null,
  updatedAt: null,
  onboardingCompleted: true,
  legalVersion: versione,
);

void main() {
  test('i testi nuovi si riaccettano', () {
    expect(_chiHaAccettato('1.3').acceptedLegalVersion('1.4'), isFalse);
    expect(_chiHaAccettato('1.9').acceptedLegalVersion('1.10'), isFalse);
    expect(_chiHaAccettato('1').acceptedLegalVersion('1.1'), isFalse);
  });

  test('la stessa versione, o una piu nuova, non si richiede', () {
    expect(_chiHaAccettato('1.4').acceptedLegalVersion('1.4'), isTrue);
    expect(_chiHaAccettato('1.5').acceptedLegalVersion('1.4'), isTrue);
    expect(_chiHaAccettato('1.10').acceptedLegalVersion('1.9'), isTrue);
    expect(_chiHaAccettato('2.0').acceptedLegalVersion('1.9'), isTrue);
    expect(_chiHaAccettato('1.1').acceptedLegalVersion('1'), isTrue);
  });

  test('chi non ha accettato niente, o qualcosa di illeggibile, si ferma', () {
    expect(_chiHaAccettato('').acceptedLegalVersion('1.4'), isFalse);
    expect(_chiHaAccettato('vecchia').acceptedLegalVersion('1.4'), isFalse);
    expect(_chiHaAccettato('1.x').acceptedLegalVersion('1.4'), isFalse);
  });
}
