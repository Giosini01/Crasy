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

  group('durata', () {
    test('e\' obbligatoria e sta fra un minuto e un giorno', () {
      expect(ChallengeDraftValidators.validateMinutes(null), isNotNull);
      expect(ChallengeDraftValidators.validateMinutes(''), isNotNull);
      expect(ChallengeDraftValidators.validateMinutes('0'), isNotNull);
      // Un minuto e' li' per provare: e' l'unico modo di vedere il giro intero
      // — si crea, si partecipa, si vota, si chiude — senza restare seduti ad
      // aspettare un'ora.
      expect(ChallengeDraftValidators.validateMinutes('1'), isNull);
      expect(ChallengeDraftValidators.validateMinutes('60'), isNull);
      expect(ChallengeDraftValidators.validateMinutes('1440'), isNull);
    });

    test('oltre le ventiquattro ore non si va', () {
      // Non e' un limite tecnico: una gara che dura una settimana non ha
      // nessuna urgenza, e l'urgenza e' meta' del motivo per cui uno esce di
      // casa a fare una foto assurda.
      expect(ChallengeDraftValidators.validateMinutes('1441'), isNotNull);
      expect(ChallengeDraftValidators.validateMinutes('9999'), isNotNull);
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
