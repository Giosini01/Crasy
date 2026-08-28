import 'package:crasy/features/challenges/domain/commissioned_order.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:flutter_test/flutter_test.dart';

/// La bacheca di chi lancia le challenge: prima quelle aperte, poi i trofei.
void main() {
  final adesso = DateTime(2026, 8, 28, 12);

  Challenge gara({
    required String id,
    required DateTime inizio,
    required DateTime fine,
    bool conTrofeo = false,
  }) {
    return Challenge(
      id: id,
      title: id,
      brief: 'Fai qualcosa di assurdo.',
      prizeCents: 50000,
      scope: ChallengeScope.global,
      createdByUserId: 'anna',
      createdByUsername: 'anna',
      startsAt: inizio,
      endsAt: fine,
      // Un trofeo esiste quando c'e' un vincitore **e** la sua foto: sono le
      // due cose che `hasTrophy` guarda.
      winnerEntryId: conTrofeo ? 'vincitore' : null,
      winnerMediaUrl: conTrofeo ? 'https://esempio/foto.jpg' : '',
    );
  }

  test('le gare aperte stanno sopra i trofei', () {
    final trofeo = gara(
      id: 'vinta-ieri',
      inizio: adesso.subtract(const Duration(days: 2)),
      fine: adesso.subtract(const Duration(days: 1)),
      conTrofeo: true,
    );
    final aperta = gara(
      id: 'aperta-adesso',
      inizio: adesso.subtract(const Duration(hours: 1)),
      fine: adesso.add(const Duration(hours: 1)),
    );

    // In ingresso il trofeo viene per primo: se l'ordine dipendesse da come
    // arrivano, questo test passerebbe per sbaglio.
    final ordinate = commissionedOrder([trofeo, aperta], now: adesso);

    expect(ordinate.map((c) => c.id), ['aperta-adesso', 'vinta-ieri']);
  });

  test('fra le aperte viene prima quella che chiude prima', () {
    final tardi = gara(
      id: 'chiude-stasera',
      inizio: adesso.subtract(const Duration(hours: 1)),
      fine: adesso.add(const Duration(hours: 6)),
    );
    final presto = gara(
      id: 'chiude-fra-poco',
      inizio: adesso.subtract(const Duration(hours: 1)),
      fine: adesso.add(const Duration(minutes: 10)),
    );

    final ordinate = commissionedOrder([tardi, presto], now: adesso);

    expect(ordinate.map((c) => c.id), ['chiude-fra-poco', 'chiude-stasera']);
  });

  test('fra i trofei viene prima il piu\' recente', () {
    final vecchio = gara(
      id: 'vecchio',
      inizio: adesso.subtract(const Duration(days: 10)),
      fine: adesso.subtract(const Duration(days: 9)),
      conTrofeo: true,
    );
    final nuovo = gara(
      id: 'nuovo',
      inizio: adesso.subtract(const Duration(days: 2)),
      fine: adesso.subtract(const Duration(days: 1)),
      conTrofeo: true,
    );

    final ordinate = commissionedOrder([vecchio, nuovo], now: adesso);

    expect(ordinate.map((c) => c.id), ['nuovo', 'vecchio']);
  });

  test('una gara finita senza vincitore non compare', () {
    // Nessuno ha partecipato: non c'e' niente da mettere in bacheca, e non e'
    // piu' nemmeno una gara a cui si possa fare qualcosa.
    final deserta = gara(
      id: 'deserta',
      inizio: adesso.subtract(const Duration(hours: 2)),
      fine: adesso.subtract(const Duration(hours: 1)),
    );

    expect(commissionedOrder([deserta], now: adesso), isEmpty);
  });

  test('una gara non ancora cominciata non compare', () {
    final futura = gara(
      id: 'futura',
      inizio: adesso.add(const Duration(hours: 1)),
      fine: adesso.add(const Duration(hours: 2)),
    );

    expect(commissionedOrder([futura], now: adesso), isEmpty);
  });
}
