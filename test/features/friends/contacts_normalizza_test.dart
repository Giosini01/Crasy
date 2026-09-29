import 'package:crasy/features/friends/data/repositories/contacts_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Il punto in cui questa funzione si rompe senza dirlo.**
///
/// Se un numero viene riscritto anche solo con uno spazio di differenza,
/// l'impronta cambia e l'amico non si trova. Non compare nessun errore: la
/// sezione dice "non c'e' nessuno" e sembra che l'app abbia guardato. E' il
/// motivo per cui questi casi stanno scritti qui invece che essere provati a
/// mano su un telefono.
void main() {
  String? pulito(String numero) =>
      ContactsRepository.normalizza(numero, prefisso: '+39');

  group('come la gente scrive i numeri in rubrica', () {
    test('un cellulare italiano senza prefisso prende il +39', () {
      expect(pulito('3471234567'), '+393471234567');
    });

    test('gli spazi e i trattini non contano', () {
      expect(pulito('347 123 45 67'), '+393471234567');
      expect(pulito('347-123-4567'), '+393471234567');
      expect(pulito('(347) 123 4567'), '+393471234567');
    });

    test('il prefisso gia' ' scritto resta com\'e\'', () {
      expect(pulito('+39 347 1234567'), '+393471234567');
    });

    test('lo 0039 della vecchia maniera diventa +39', () {
      expect(pulito('0039 347 1234567'), '+393471234567');
    });

    test('un numero straniero non si tocca', () {
      expect(pulito('+33 6 12 34 56 78'), '+33612345678');
    });

    test('i modi diversi di scrivere lo stesso numero finiscono uguali', () {
      final tutti = {
        pulito('3471234567'),
        pulito('347 1234567'),
        pulito('+393471234567'),
        pulito('0039 347 1234567'),
      };

      expect(tutti.length, 1, reason: 'sono lo stesso numero');
    });
  });

  group('quello che numero non e\'', () {
    test('i numeri brevi dei servizi si scartano', () {
      expect(pulito('112'), isNull);
      expect(pulito('4243'), isNull);
    });

    test('il vuoto e il testo si scartano', () {
      expect(pulito(''), isNull);
      expect(pulito('casa'), isNull);
    });

    test('un numero assurdamente lungo si scarta', () {
      expect(pulito('+391234567890123456'), isNull);
    });

    test('in Italia lo zero del fisso resta dopo il prefisso', () {
      // 081 e' Napoli. In Italia, diversamente dagli altri paesi, lo zero fa
      // parte del numero anche dall'estero: +39 081…, non +39 81…. Il test
      // di prima diceva il contrario, ed era il numero che non esiste.
      expect(pulito('0811234567'), '+390811234567');
    });

    test("fuori dall'Italia lo zero iniziale cade", () {
      expect(
        ContactsRepository.normalizza('030 1234567', prefisso: '+49'),
        '+49301234567',
      );
    });

    test('il 39 davanti a dieci cifre e il paese scritto senza il piu', () {
      expect(pulito('39 347 123 4567'), '+393471234567');
    });

    test('un cellulare che comincia per 39 resta un cellulare', () {
      // 393 e' un prefisso di cellulare italiano: dieci cifre, niente paese.
      expect(pulito('393 123 4567'), '+393931234567');
    });
  });
}
