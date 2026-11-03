import 'package:crasy/features/payments/domain/entities/ledger_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('una riga nuova con la carta dice quanto ha pagato davvero', () {
    const riga = LedgerEntry(
      id: 'a',
      kind: 'challengePayment',
      amountCents: -200,
      source: 'card',
      note: 'Premio messo in palio',
      pagatoCents: 229,
    );

    expect(riga.cifra, -229);
    expect(riga.nota, '€2 di premio più €0,29 di spese');
    expect(riga.isIn, isFalse);
  });

  test('una riga vecchia con la carta dice che e\' solo il premio', () {
    const riga = LedgerEntry(
      id: 'a',
      kind: 'challengePayment',
      amountCents: -200,
      source: 'card',
      note: 'Premio messo in palio',
    );

    expect(riga.cifra, -200);
    expect(riga.nota, 'Solo il premio: la carta ha pagato anche le spese');
  });

  test('le altre righe restano come sono', () {
    const dalPortafoglio = LedgerEntry(
      id: 'a',
      kind: 'challengePayment',
      amountCents: -100,
      source: 'wallet',
      note: 'Premio messo in palio, pagato col portafoglio',
    );
    const rimborso = LedgerEntry(
      id: 'b',
      kind: 'refund',
      amountCents: 229,
      source: 'card',
      note: 'Rimborso: non ha partecipato nessuno',
    );

    expect(dalPortafoglio.cifra, -100);
    expect(dalPortafoglio.nota, dalPortafoglio.note);
    expect(rimborso.cifra, 229);
    expect(rimborso.nota, rimborso.note);
    expect(rimborso.isIn, isTrue);
  });
}
