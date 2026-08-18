import 'package:crasy/features/payments/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sotto il minimo non si preleva', () {
    expect(const Wallet(balanceCents: 999).canWithdraw, isFalse);
    expect(const Wallet(balanceCents: 1000).canWithdraw, isTrue);
    expect(const Wallet().canWithdraw, isFalse);
  });

  test('un premio si legge in entrata, un prelievo in uscita', () {
    const prize = WalletMovement(
      id: 'a',
      amountCents: 45000,
      challengeTitle: 'Do something crazy',
    );
    const withdrawal = WalletMovement(id: 'b', amountCents: -45000);

    expect(prize.isPrize, isTrue);
    expect(prize.label, 'DO SOMETHING CRAZY');
    expect(withdrawal.isPrize, isFalse);
    expect(withdrawal.label, 'Prelievo');
  });

  test('un premio senza titolo si chiama comunque in qualche modo', () {
    const movement = WalletMovement(id: 'c', amountCents: 100);

    expect(movement.label, 'Premio vinto');
  });
}
