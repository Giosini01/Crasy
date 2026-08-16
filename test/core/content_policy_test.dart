import 'package:crasy/core/moderation/content_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le prove che contano di piu' del resto.
///
/// CRASY paga la gente per fare cose. Una consegna sbagliata non e' un
/// contenuto discutibile: e' una persona che si fa male perche' gliel'ha
/// chiesto la nostra app, in cambio di soldi nostri. Ogni riga qui sotto e' una
/// frase che **non deve poter essere pubblicata**.
void main() {
  group('autolesionismo', () {
    const forbidden = [
      'Tagliati le vene e fotografa il risultato',
      'Metti fine alla tua vita',
      'Uccidetevi e mandateci la foto',
      'Ammazzati per 500 euro',
      'La foto piu\' bella del tuo suicidio',
      'Fatti del male e mostracelo',
      'Kill yourself on camera',
    ];

    for (final text in forbidden) {
      test('rifiuta: "$text"', () {
        expect(ContentPolicy.check(text), ContentPolicy.selfHarm);
      });
    }

    test('il messaggio offre un numero da chiamare, non solo un divieto', () {
      // Chi scrive una frase del genere puo' non stare scherzando. Chiudere la
      // porta e basta e' la risposta peggiore possibile.
      expect(ContentPolicy.selfHarm.message, contains('02 2327 2327'));
    });
  });

  group('violenza e nudita\'', () {
    test('rifiuta la violenza verso gli altri', () {
      expect(
        ContentPolicy.check('Picchia un passante'),
        ContentPolicy.violence,
      );
      expect(
        ContentPolicy.check('Accoltella qualcosa e fotografa'),
        ContentPolicy.violence,
      );
    });

    test('rifiuta nudita\' e contenuti sessuali', () {
      expect(
        ContentPolicy.check('Mandaci una foto nudo'),
        ContentPolicy.sexual,
      );
      expect(ContentPolicy.check('Spogliati in strada'), ContentPolicy.sexual);
      expect(ContentPolicy.check('Foto porno'), ContentPolicy.sexual);
    });

    test('rifiuta le challenge che possono finire male davvero', () {
      expect(
        ContentPolicy.check('Fai una foto sul cornicione'),
        ContentPolicy.danger,
      );
      expect(
        ContentPolicy.check('Attraversa i binari e scatta'),
        ContentPolicy.danger,
      );
    });
  });

  group('non e\' un filtro isterico', () {
    const allowed = [
      'Fai la foto piu\' pazza che riesci',
      'Scatta la foto piu\' assurda sul lungomare',
      'La foto piu\' creativa con un oggetto della cucina',
      'Fatti una foto mentre salti',
      'Do something crazy',
      'Il tuo caffe\' piu\' brutto di sempre',
    ];

    for (final text in allowed) {
      test('lascia passare: "$text"', () {
        expect(ContentPolicy.check(text), isNull);
      });
    }

    test('un testo vuoto non e\' una violazione', () {
      expect(ContentPolicy.check(null), isNull);
      expect(ContentPolicy.check(''), isNull);
      expect(ContentPolicy.check('   '), isNull);
    });
  });

  group('non si aggira con maiuscole e accenti', () {
    test('le maiuscole non salvano', () {
      expect(ContentPolicy.check('TAGLIATI LE VENE'), ContentPolicy.selfHarm);
    });

    test('gli accenti nemmeno', () {
      expect(ContentPolicy.check('UCCÌDITI'), ContentPolicy.selfHarm);
    });
  });

  test('checkAll trova il problema in uno qualunque dei pezzi', () {
    // Titolo e consegna vengono controllati insieme: nascondere la frase in uno
    // dei due sarebbe stato il modo piu' ovvio di passare.
    expect(
      ContentPolicy.checkAll(['Titolo innocuo', 'poi tagliati le vene']),
      ContentPolicy.selfHarm,
    );
    expect(
      ContentPolicy.checkAll(['Titolo innocuo', 'consegna innocua']),
      isNull,
    );
  });
}
