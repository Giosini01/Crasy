import 'package:crasy/core/utils/app_money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gli importi tondi non portano i decimali', () {
    expect(AppMoney.format(50000), '€500');
    expect(AppMoney.format(0), '€0');
  });

  test('i decimali compaiono solo quando ci sono', () {
    expect(AppMoney.format(9950), '€99,50');
    expect(AppMoney.format(105), '€1,05');
  });

  test('le migliaia prendono il punto, come si scrive in italiano', () {
    expect(AppMoney.format(125000), '€1.250');
    expect(AppMoney.format(100000000), '€1.000.000');
  });

  test('il simbolo si puo\' cambiare', () {
    expect(AppMoney.format(50000, symbol: r'$'), r'$500');
  });

  test('un importo negativo tiene il segno davanti al simbolo', () {
    expect(AppMoney.format(-50000), '-€500');
  });

  group('lettura di un importo scritto a mano', () {
    test('i centesimi si scrivono con la virgola', () {
      expect(AppMoney.centsFrom('10,50'), 1050);
      expect(AppMoney.centsFrom('0,99'), 99);
      expect(AppMoney.centsFrom('0,01'), 1);
    });

    test('il punto vale quanto la virgola', () {
      // La tastiera numerica di un telefono in inglese offre il punto: un
      // campo che rifiuta il tasto suggerito dalla tastiera sembra rotto.
      expect(AppMoney.centsFrom('10.50'), 1050);
    });

    test('una cifra sola dopo la virgola sono decine di centesimi', () {
      // `10,5` e' dieci e cinquanta, non dieci e cinque.
      expect(AppMoney.centsFrom('10,5'), 1050);
    });

    test('un numero intero resta quello che era', () {
      expect(AppMoney.centsFrom('500'), 50000);
      expect(AppMoney.centsFrom('0'), 0);
    });

    test('gli spazi attorno non contano', () {
      expect(AppMoney.centsFrom('  10,50 '), 1050);
    });

    test('quello che non e\' un importo torna nullo', () {
      expect(AppMoney.centsFrom(null), isNull);
      expect(AppMoney.centsFrom(''), isNull);
      expect(AppMoney.centsFrom('abc'), isNull);
      expect(AppMoney.centsFrom('10,'), isNull);
      expect(AppMoney.centsFrom(',50'), isNull);
      expect(AppMoney.centsFrom('10,5,5'), isNull);
      expect(AppMoney.centsFrom('-10'), isNull);
      // Tre decimali non sono centesimi: meglio dire di no che arrotondare di
      // nascosto un numero che parla di soldi.
      expect(AppMoney.centsFrom('10,505'), isNull);
      // Nove cifre di parte intera sono il tetto: oltre, il numero non ci sta
      // piu' nei numeri interi del telefono.
      expect(AppMoney.centsFrom('1234567890'), isNull);
    });

    test('scrittura e lettura si chiudono a cerchio', () {
      expect(AppMoney.format(AppMoney.centsFrom('10,50')!), '€10,50');
      expect(AppMoney.format(AppMoney.centsFrom('500')!), '€500');
    });
  });
}
