import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:flutter_test/flutter_test.dart';

/// Il tetto ai partecipanti, e cosa si legge sulla scheda.
///
/// **Un euro fra dieci persone e' una scommessa, un euro fra cinquecento e' una
/// presa in giro.** Il tetto e' la regola che tiene la gara giocabile: qui si
/// verifica che i posti si contino bene e che "al completo" arrivi esattamente
/// quando deve.
void main() {
  Challenge gara({int max = 10, int dentro = 0}) {
    final now = DateTime.now();

    return Challenge(
      id: 'gara',
      title: 'Una gara',
      brief: 'Fai qualcosa.',
      prizeCents: 100,
      scope: ChallengeScope.global,
      startsAt: now.subtract(const Duration(hours: 1)),
      endsAt: now.add(const Duration(hours: 5)),
      maxParticipants: max,
      participantsCount: dentro,
    );
  }

  test('senza tetto non ci sono posti da contare', () {
    expect(gara(max: 0, dentro: 999).spotsLeft, isNull);
    expect(gara(max: 0, dentro: 999).isFull, isFalse);
  });

  test('i posti calano man mano che entra gente', () {
    expect(gara(dentro: 0).spotsLeft, 10);
    expect(gara(dentro: 7).spotsLeft, 3);
  });

  test('a posti finiti la gara e\' al completo', () {
    expect(gara(dentro: 10).spotsLeft, 0);
    expect(gara(dentro: 10).isFull, isTrue);
  });

  test('undici dentro dieci non fa un numero negativo', () {
    // Due persone che mandano nello stesso istante possono passare entrambe:
    // la regola sul database legge il conto prima che l'altra scriva. Undici
    // in gara non rovina niente, ma "-1 posti" sarebbe una schermata rotta.
    expect(gara(dentro: 11).spotsLeft, 0);
    expect(gara(dentro: 11).isFull, isTrue);
  });

  test('la riga della folla non dice mai come sta andando', () {
    // **E' il punto di tutta la faccenda.** Questa riga sta dove prima c'era la
    // classifica: puo' dire quanti sono e quanti posti restano, mai chi vince.
    expect(gara(dentro: 7).crowdLabel, '7 IN GARA · 3 POSTI');
    expect(gara(dentro: 10).crowdLabel, '10 IN GARA · AL COMPLETO');
    expect(gara(max: 0, dentro: 40).crowdLabel, '40 IN GARA');
  });

  test('i tetti fra cui si sceglie sono quattro, e uno e\' senza limite', () {
    expect(Challenge.participantCaps, [10, 25, 50, 0]);
  });
}
