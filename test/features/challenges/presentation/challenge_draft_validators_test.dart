import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/presentation/controllers/create_challenge_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le stesse condizioni sono scritte anche nelle regole di Firestore. Se qui
/// passa qualcosa che li' verrebbe rifiutato, l'utente compila tutto per poi
/// vedersi respingere l'invio senza capire perche'.
void main() {
  group('titolo', () {
    test('e\' obbligatorio e ha una lunghezza minima', () {
      expect(ChallengeDraftValidators.validateTitle(null), isNotNull);
      expect(ChallengeDraftValidators.validateTitle('  '), isNotNull);
      expect(ChallengeDraftValidators.validateTitle('ab'), isNotNull);
      expect(ChallengeDraftValidators.validateTitle('abc'), isNull);
    });

    test('non supera i sessanta caratteri', () {
      expect(
        ChallengeDraftValidators.validateTitle(
          'a' * ChallengeDraftValidators.titleMaxLength,
        ),
        isNull,
      );
      expect(
        ChallengeDraftValidators.validateTitle(
          'a' * (ChallengeDraftValidators.titleMaxLength + 1),
        ),
        isNotNull,
      );
    });
  });

  group('consegna', () {
    test('serve dire cosa bisogna fare', () {
      expect(ChallengeDraftValidators.validateBrief(''), isNotNull);
      expect(ChallengeDraftValidators.validateBrief('Fai una foto.'), isNull);
    });

    test('non diventa un tema', () {
      expect(
        ChallengeDraftValidators.validateBrief(
          'a' * (ChallengeDraftValidators.briefMaxLength + 1),
        ),
        isNotNull,
      );
    });
  });

  group('premio', () {
    test('deve essere un numero positivo', () {
      expect(ChallengeDraftValidators.validatePrize(null), isNotNull);
      expect(ChallengeDraftValidators.validatePrize(''), isNotNull);
      expect(ChallengeDraftValidators.validatePrize('0'), isNotNull);
      expect(ChallengeDraftValidators.validatePrize('abc'), isNotNull);
      expect(ChallengeDraftValidators.validatePrize('500'), isNull);
    });

    test('ha un tetto contro le dita che scivolano', () {
      expect(
        ChallengeDraftValidators.validatePrize(
          '${ChallengeDraftValidators.prizeMaxEuro}',
        ),
        isNull,
      );
      expect(
        ChallengeDraftValidators.validatePrize(
          '${ChallengeDraftValidators.prizeMaxEuro + 1}',
        ),
        isNotNull,
      );
    });
  });

  group('luogo', () {
    test('serve solo alle challenge locali', () {
      expect(
        ChallengeDraftValidators.validatePlace(ChallengeScope.global, ''),
        isNull,
      );
      expect(
        ChallengeDraftValidators.validatePlace(ChallengeScope.country, ''),
        isNull,
      );
      expect(
        ChallengeDraftValidators.validatePlace(ChallengeScope.local, ''),
        isNotNull,
      );
      expect(
        ChallengeDraftValidators.validatePlace(ChallengeScope.local, 'Napoli'),
        isNull,
      );
    });
  });
}
