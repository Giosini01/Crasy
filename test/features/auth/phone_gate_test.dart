import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Il muro del numero di telefono: quando si apre e quando no.
///
/// **Il difetto che questo file impedisce di rifare** e' il giro infinito: si
/// verificava il numero, il profilo veniva salvato con una stringa vuota, il
/// muro non si apriva e la schermata tornava — senza nessun errore, perche' dal
/// punto di vista del codice era andato tutto bene.
void main() {
  UserProfile profilo({String phone = ''}) {
    return UserProfile(
      id: 'io',
      username: 'martina',
      birthDate: DateTime(2000, 1, 1),
      createdAt: null,
      updatedAt: null,
      onboardingCompleted: true,
      phone: phone,
    );
  }

  test('senza numero il muro resta chiuso', () {
    expect(profilo().phoneVerified, isFalse);
  });

  test('con il numero il muro si apre', () {
    expect(profilo(phone: '+393330000000').phoneVerified, isTrue);
  });

  test('una stringa vuota non e\' un numero verificato', () {
    // E' esattamente cio' che finiva nel profilo quando Firebase non
    // restituiva il numero: sembrava un salvataggio riuscito e non lo era.
    expect(profilo(phone: '').phoneVerified, isFalse);
  });

  test('il muro ha una rotta sua', () {
    // Sta fra la conferma dell'email e i consensi: prima che si possa toccare
    // qualunque cosa.
    expect(AppRoutes.verifyPhone, isNotEmpty);
    expect(AppRoutes.openToEveryone, isNot(contains(AppRoutes.verifyPhone)));
  });
}
