import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/presentation/controllers/create_challenge_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le missioni riservate agli amici.
///
/// La riservatezza vera la fanno le regole del database — quelle non si provano
/// da qui — ma due cose si provano eccome: che il premio a zero passi **solo**
/// fra amici, e che una gara nasca con scritto dentro chi la puo' vedere.
void main() {
  test('fra amici il premio puo\' essere zero', () {
    expect(
      ChallengeDraftValidators.validatePrize('0', forFriends: true),
      isNull,
    );
  });

  test('fuori dagli amici lo zero non passa', () {
    expect(ChallengeDraftValidators.validatePrize('0'), isNotNull);
    expect(ChallengeDraftValidators.validatePrize('0,50'), isNotNull);
  });

  test('fra amici il massimo resta un limite', () {
    expect(
      ChallengeDraftValidators.validatePrize('99999999', forFriends: true),
      isNotNull,
    );
  });

  test('una gara nasce pubblica se non si dice altro', () {
    final challenge = Challenge(
      id: 'x',
      title: 'Una gara',
      brief: 'Fai qualcosa.',
      prizeCents: 500,
      scope: ChallengeScope.global,
      startsAt: DateTime.now(),
      endsAt: DateTime.now().add(const Duration(hours: 1)),
    );

    expect(challenge.audience, [Challenge.everyone]);
    expect(challenge.isForFriends, isFalse);
  });

  test('una gara per amici si riconosce dall\'ambito', () {
    final challenge = Challenge(
      id: 'x',
      title: 'Una gara',
      brief: 'Fai qualcosa.',
      prizeCents: 0,
      scope: ChallengeScope.friends,
      startsAt: DateTime.now(),
      endsAt: DateTime.now().add(const Duration(hours: 1)),
      audience: const ['io', 'un-amico'],
    );

    expect(challenge.isForFriends, isTrue);
    // Il segno che le regole cercano: una gara riservata non deve avere il
    // valore che vuol dire "tutti", o sarebbe pubblica e gratis insieme.
    expect(challenge.audience.contains(Challenge.everyone), isFalse);
    expect(challenge.scopeLabel, 'SOLO AMICI');
  });
}
