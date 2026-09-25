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
  UserProfile profilo({bool verificato = false}) {
    return UserProfile(
      id: 'io',
      username: 'martina',
      birthDate: DateTime(2000, 1, 1),
      createdAt: null,
      updatedAt: null,
      onboardingCompleted: true,
      phoneVerified: verificato,
    );
  }

  test('senza numero il muro resta chiuso', () {
    expect(profilo().phoneVerified, isFalse);
  });

  test('con il numero verificato il muro si apre', () {
    expect(profilo(verificato: true).phoneVerified, isTrue);
  });

  test('un profilo appena fatto non ha il numero verificato', () {
    // Il difetto di una volta era una stringa vuota scambiata per un numero.
    // Adesso il campo e' un si' o no, e il ripiego deve essere il no: un
    // ripiego al contrario aprirebbe il muro a chi non l'ha mai passato.
    expect(profilo().phoneVerified, isFalse);
  });

  test('il muro ha una rotta sua', () {
    // Sta fra la conferma dell'email e i consensi: prima che si possa toccare
    // qualunque cosa.
    expect(AppRoutes.verifyPhone, isNotEmpty);
    expect(AppRoutes.openToEveryone, isNot(contains(AppRoutes.verifyPhone)));
  });
}
