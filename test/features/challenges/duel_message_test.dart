import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:flutter_test/flutter_test.dart';

/// **La riga che chi sfida scrive all'amico.**
///
/// Non e' una chat, e questi test sono il confine: una riga sola, breve,
/// facoltativa, e solo su una sfida mirata. Se qualcuno un domani la
/// riutilizzasse su una gara aperta, quelle parole private finirebbero
/// davanti a tutti i partecipanti — ed e' il genere di cosa che si scopre
/// dopo.
void main() {
  Challenge sfida({String messaggio = '', String bersaglio = 'lui'}) {
    final ora = DateTime(2026, 9, 26, 12);

    return Challenge(
      id: 'c1',
      title: 'BALLA IN STRADA',
      brief: 'Fallo davvero',
      prizeCents: 0,
      scope: ChallengeScope.friends,
      targetUserId: bersaglio,
      targetUsername: 'francesco',
      createdByUserId: 'io',
      createdByUsername: 'giosyni',
      duelMessage: messaggio,
      startsAt: ora,
      endsAt: ora.add(const Duration(hours: 24)),
    );
  }

  test('senza riga scritta non c\'e\' niente da mostrare', () {
    expect(sfida().duelMessage, isEmpty);
  });

  test('la riga resta attaccata alla sfida', () {
    expect(
      sfida(messaggio: 'Vediamo se ce la fai.').duelMessage,
      'Vediamo se ce la fai.',
    );
  });

  test('copiando la sfida la riga si puo\' cambiare', () {
    // Serve a chi legge la sfida dopo: se `copyWith` la perdesse, aprire una
    // sfida e tornare indietro la cancellerebbe dallo schermo senza che
    // nessuno l'abbia toccata.
    final prima = sfida(messaggio: 'Ci provi?');

    expect(prima.copyWith().duelMessage, 'Ci provi?');
    expect(prima.copyWith(duelMessage: 'Altro').duelMessage, 'Altro');
  });

  test('una gara senza bersaglio non e\' una sfida', () {
    // Il campo esiste sull'oggetto, ma senza qualcuno a cui e' rivolta non c'e'
    // nessuno a cui quella riga sia indirizzata: le regole del database la
    // rifiutano, e questo test tiene fermo il ragionamento.
    expect(sfida(bersaglio: '').isDuel, isFalse);
  });
}
