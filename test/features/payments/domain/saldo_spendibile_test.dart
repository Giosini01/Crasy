import 'package:crasy/features/payments/domain/entities/saldo_spendibile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('basta solo quello che si puo\' spendere adesso', () {
    const saldo = SaldoSpendibile(spendibileCents: 10, inArrivoCents: 90);

    expect(saldo.basta(10), isTrue);
    expect(saldo.basta(100), isFalse);
  });

  test('il motivo dice la cifra in arrivo e quando', () {
    final conData = SaldoSpendibile(
      spendibileCents: 10,
      inArrivoCents: 90,
      inArrivoEntro: DateTime(2026, 11, 5),
    );
    const senzaData = SaldoSpendibile(spendibileCents: 10, inArrivoCents: 90);

    expect(
      conData.spiegaA(100),
      'Hai €1, ma €0,90 sono ancora in arrivo: Stripe li rende spendibili '
      'entro il 5 novembre.',
    );
    expect(senzaData.spiegaA(100), contains('fra qualche giorno'));
  });

  test('se non c\'e\' niente in arrivo non si parla di arrivi', () {
    const saldo = SaldoSpendibile(spendibileCents: 10, inArrivoCents: 0);

    expect(saldo.spiegaA(100), 'Hai €1, ma adesso puoi spenderne €0,10.');
  });
}
