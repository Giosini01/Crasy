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
}
