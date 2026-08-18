import 'package:crasy/features/payments/domain/entities/prize_status.dart';
import 'package:crasy/features/payments/domain/prize_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('la percentuale di CRASY', () {
    test('e\' il dieci per cento del premio', () {
      expect(PrizeLedger.commissionCents(50000), 5000);
      expect(PrizeLedger.payoutCents(50000), 45000);
    });

    test('quando non torna esatta, ci guadagna il vincitore', () {
      // 999 centesimi al 10% fa 99,9. Arrotondando per eccesso CRASY si
      // prenderebbe un centesimo in piu' del dovuto: si arrotonda per difetto.
      expect(PrizeLedger.commissionCents(999), 99);
      expect(PrizeLedger.payoutCents(999), 900);
    });

    test('premio e percentuale tornano sempre al totale', () {
      for (final prize in [1, 99, 100, 333, 1234, 50000, 100000000]) {
        expect(
          PrizeLedger.commissionCents(prize) + PrizeLedger.payoutCents(prize),
          prize,
          reason: 'su $prize centesimi si perde o si crea denaro',
        );
      }
    });

    test('un premio a zero non produce numeri strani', () {
      expect(PrizeLedger.commissionCents(0), 0);
      expect(PrizeLedger.payoutCents(0), 0);
      expect(PrizeLedger.chargeCents(0), 0);
      expect(PrizeLedger.commissionCents(-100), 0);
    });
  });

  group('quello che paga chi lancia la challenge', () {
    test('e\' il premio piu\' le commissioni, non il premio meno', () {
      // Cinquecento euro di premio: chi lancia ne paga poco piu' di 507, e il
      // montepremi che resta e' esattamente cinquecento.
      final charge = PrizeLedger.chargeCents(50000);

      expect(charge, greaterThan(50000));
      expect(charge, lessThan(51000));
    });

    test('l\'addebito copre davvero la commissione di Stripe', () {
      // E' il conto che conta piu' di tutti: se l'addebito fosse anche solo un
      // centesimo troppo basso, la differenza la pagherebbe il vincitore.
      for (final prize in [500, 1000, 5000, 50000, 250000, 100000000]) {
        final charge = PrizeLedger.chargeCents(prize);
        final stripeTakes =
            (charge * PrizeLedger.processingBasisPoints) ~/ 10000 +
            PrizeLedger.processingFixedCents;

        expect(
          charge - stripeTakes,
          greaterThanOrEqualTo(prize),
          reason: 'su $prize centesimi il montepremi non ci arriva intero',
        );
      }
    });

    test('non si paga piu\' del necessario', () {
      // Il centesimo in piu' e' accettabile, l'euro in piu' no: l'arrotondamento
      // per eccesso deve restare un arrotondamento.
      for (final prize in [500, 5000, 50000]) {
        final charge = PrizeLedger.chargeCents(prize);
        final stripeTakes =
            (charge * PrizeLedger.processingBasisPoints) ~/ 10000 +
            PrizeLedger.processingFixedCents;

        expect(charge - stripeTakes - prize, lessThan(2));
      }
    });

    test('la commissione dichiarata e\' la differenza vera', () {
      expect(
        PrizeLedger.processingFeeCents(50000),
        PrizeLedger.chargeCents(50000) - 50000,
      );
    });
  });

  group('lo stato del premio', () {
    test('una challenge si vede solo se e\' stata pagata', () {
      expect(PrizeStatus.unpaid.isVisible, isFalse);
      expect(PrizeStatus.held.isVisible, isTrue);
      expect(PrizeStatus.paidOut.isVisible, isTrue);
      expect(PrizeStatus.refunded.isVisible, isFalse);
    });

    test('i soldi sono fermi su CRASY solo mentre la gara e\' aperta', () {
      expect(PrizeStatus.held.isEscrowed, isTrue);
      expect(PrizeStatus.paidOut.isEscrowed, isFalse);
    });

    test('una challenge senza lo stato scritto non e\' mai stata pagata', () {
      // Sono quelle nate prima che il pagamento esistesse. Leggerle come
      // "pagate" significherebbe dire che dei soldi ci sono quando nessuno li
      // ha mai messi.
      expect(PrizeStatus.fromName(null), PrizeStatus.unpaid);
      expect(PrizeStatus.fromName('boh'), PrizeStatus.unpaid);
      expect(PrizeStatus.fromName('held'), PrizeStatus.held);
    });
  });
}
