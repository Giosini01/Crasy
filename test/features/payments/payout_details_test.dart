import 'package:crasy/features/payments/domain/entities/payout_details.dart';
import 'package:flutter_test/flutter_test.dart';

/// **I controlli sui dati del prelievo, provati uno per uno.**
///
/// Sono l'ultimo punto in cui un errore si puo' ancora correggere. Un IBAN con
/// una cifra storta che passa di qui diventa un bonifico partito verso un conto
/// che non esiste — o, peggio, verso quello di un altro — e da li' non si torna
/// indietro con un tasto.
///
/// Per questo le prove non si fermano a "accetta quello giusto": provano
/// soprattutto che **rifiuti quelli sbagliati di un soffio**, che sono gli
/// unici che arrivano davvero. Nessuno scrive un IBAN a caso: si sbaglia una
/// cifra ricopiando dal telefono, e quella e' la prova che conta.
void main() {
  group('IBAN', () {
    test('quello giusto passa', () {
      expect(PayoutValidators.iban('IT60X0542811101000000123456'), isNull);
      expect(PayoutValidators.iban('DE89370400440532013000'), isNull);
    });

    test('gli spazi e le minuscole non sono un errore', () {
      // Copiandolo dall'app della banca si porta dietro gli spazi. Rifiutarlo
      // per quello vorrebbe dire far ribattere a mano ventisette caratteri.
      expect(PayoutValidators.iban('it60 X054 2811 1010 0000 0123 456'), isNull);
    });

    test('una cifra cambiata viene rifiutata', () {
      // **La prova che vale tutte le altre.** Senza il calcolo di controllo
      // questo IBAN passerebbe: ha la forma giusta, la lunghezza giusta, e le
      // due cifre iniziali sono al loro posto.
      expect(
        PayoutValidators.iban('IT60X0542811101000000123457'),
        isNotNull,
      );
    });

    test('due cifre scambiate vengono rifiutate', () {
      expect(
        PayoutValidators.iban('IT60X0542811101000000123465'),
        isNotNull,
      );
    });

    test('a un italiano corto si dice quanti caratteri ha', () {
      final errore = PayoutValidators.iban('IT60X05428111010000001234');

      expect(errore, contains('27'));
      expect(errore, contains('25'));
    });

    test('vuoto e senza senso non passano', () {
      expect(PayoutValidators.iban(''), isNotNull);
      expect(PayoutValidators.iban('il mio conto'), isNotNull);
      expect(PayoutValidators.iban('1234567890'), isNotNull);
    });
  });

  group('codice fiscale', () {
    test('quello giusto passa', () {
      expect(PayoutValidators.fiscalCode('RSSMRA85T10A562S'), isNull);
      expect(PayoutValidators.fiscalCode('rssmra85t10a562s'), isNull);
    });

    test('la lettera finale sbagliata viene rifiutata', () {
      // Ha la forma esatta di un codice vero: lo smaschera solo il calcolo
      // dell'ultima lettera.
      expect(PayoutValidators.fiscalCode('RSSMRA85T10A562T'), isNotNull);
    });

    test('una lettera cambiata in mezzo viene rifiutata', () {
      expect(PayoutValidators.fiscalCode('RSSMRA85T10A563S'), isNotNull);
    });

    test('la forma sbagliata viene rifiutata', () {
      expect(PayoutValidators.fiscalCode('ABC'), isNotNull);
      expect(PayoutValidators.fiscalCode('RSSMRA85T10A562'), isNotNull);
      expect(PayoutValidators.fiscalCode('1234567890123456'), isNotNull);
    });
  });

  group('data di nascita', () {
    final oggi = DateTime(2026, 9, 23);

    test('un maggiorenne passa', () {
      expect(
        PayoutValidators.birthDate(DateTime(1990, 5, 3), now: oggi),
        isNull,
      );
    });

    test('il giorno del diciottesimo compleanno passa', () {
      expect(
        PayoutValidators.birthDate(DateTime(2008, 9, 23), now: oggi),
        isNull,
      );
    });

    test('il giorno prima no', () {
      // **Un minorenne non prende soldi**, e non e' una regola di prodotto: un
      // contratto con un minore non sta in piedi.
      expect(
        PayoutValidators.birthDate(DateTime(2008, 9, 24), now: oggi),
        isNotNull,
      );
    });

    test('una data assurda viene rifiutata', () {
      expect(PayoutValidators.birthDate(null), isNotNull);
      expect(
        PayoutValidators.birthDate(DateTime(1800), now: oggi),
        isNotNull,
      );
    });
  });

  group('nome', () {
    test('gli apostrofi e gli accenti sono cognomi veri', () {
      // Un controllo troppo stretto rifiuta delle persone vere per fare bella
      // figura con quelle finte.
      expect(PayoutValidators.name('D\'Amico'), isNull);
      expect(PayoutValidators.name('Nicolò'), isNull);
      expect(PayoutValidators.name('De Luca'), isNull);
    });

    test('una lettera sola non e\' un nome', () {
      expect(PayoutValidators.name('G'), isNotNull);
      expect(PayoutValidators.name('  '), isNotNull);
    });
  });

  group('completo', () {
    test('serve tutto, non quasi tutto', () {
      const quasi = PayoutDetails(
        firstName: 'Mario',
        lastName: 'Rossi',
        fiscalCode: 'RSSMRA85T10A562S',
      );

      expect(quasi.isComplete, isFalse);

      final tutto = quasi.copyWith(
        iban: 'IT60X0542811101000000123456',
        birthDate: DateTime(1985, 12, 10),
      );

      expect(tutto.isComplete, isTrue);
    });

    test('dell\'IBAN si mostrano solo le ultime quattro', () {
      // Su una schermata che qualcuno puo' guardare da sopra la spalla, un
      // IBAN intero e' piu' di quanto serva.
      const dati = PayoutDetails(iban: 'IT60X0542811101000000123456');

      expect(dati.ibanTail, endsWith('3456'));
      expect(dati.ibanTail.contains('IT60'), isFalse);
    });
  });
}
