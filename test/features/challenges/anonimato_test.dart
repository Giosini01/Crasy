import 'package:crasy/features/challenges/data/mappers/challenge_mapper.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter_test/flutter_test.dart';

Challenge _gara({
  bool anonimo = false,
  ChallengeScope scope = ChallengeScope.global,
  List<String> audience = const [Challenge.everyone],
  String autore = 'chi-la-lancia',
  String id = 'g',
}) {
  return Challenge(
    id: id,
    title: 'Una gara',
    brief: 'Fai qualcosa.',
    prizeCents: 500,
    scope: scope,
    audience: audience,
    anonimo: anonimo,
    createdByUserId: autore,
    startsAt: DateTime(2026, 10, 18, 12),
    endsAt: DateTime(2026, 10, 19, 12),
  );
}

/// **Un'anonima non porta scritto chi l'ha lanciata.**
///
/// Il documento della gara lo legge chiunque la veda. Prima dentro c'era
/// l'identificativo di chi si era nascosto — nell'autore e, fra amici, in cima
/// all'elenco di chi la vede — e la maschera reggeva solo nell'interfaccia.
void main() {
  group('la gara che parte', () {
    test('firmata: autore ed elenco come sono', () {
      final campi = ChallengeMapper.toCreateMap(
        _gara(
          scope: ChallengeScope.friends,
          audience: const ['chi-la-lancia', 'mario', 'luca'],
        ),
      );

      expect(campi['createdByUserId'], 'chi-la-lancia');
      expect(campi['audience'], ['chi-la-lancia', 'mario', 'luca']);
    });

    test('anonima: senza autore', () {
      final campi = ChallengeMapper.toCreateMap(_gara(anonimo: true));

      expect(campi['createdByUserId'], '');
      expect(campi['anonimo'], isTrue);
      // Pubblica resta pubblica.
      expect(campi['audience'], [Challenge.everyone]);
    });

    test('anonima fra amici: chi la lancia non sta fra chi la vede', () {
      final campi = ChallengeMapper.toCreateMap(
        _gara(
          anonimo: true,
          scope: ChallengeScope.friends,
          audience: const ['chi-la-lancia', 'mario', 'luca'],
        ),
      );

      expect(campi['audience'], ['mario', 'luca']);
    });

    test('una sfida anonima la vede solo chi la riceve', () {
      final campi = ChallengeMapper.toCreateMap(
        _gara(
          anonimo: true,
          scope: ChallengeScope.friends,
          audience: const ['chi-la-lancia', 'bersaglio'],
        ),
      );

      expect(campi['audience'], ['bersaglio']);
    });
  });

  group('l\'ho lanciata io?', () {
    test('la mia firmata sì, quella di un altro no', () {
      expect(lanciataDaMe(_gara(), 'chi-la-lancia', const {}), isTrue);
      expect(lanciataDaMe(_gara(), 'altro', const {}), isFalse);
    });

    test('la mia anonima sì, dal mio foglio a parte', () {
      final anonima = _gara(anonimo: true, autore: '', id: 'x');

      expect(lanciataDaMe(anonima, 'chi-la-lancia', const {'x'}), isTrue);
    });

    test('un\'anonima che non è nel mio foglio no', () {
      final anonima = _gara(anonimo: true, autore: '', id: 'x');

      expect(lanciataDaMe(anonima, 'chi-la-lancia', const {'y'}), isFalse);
    });

    test('senza accesso, niente è mio', () {
      // L'autore vuoto di un'anonima non deve combaciare con un utente vuoto.
      final anonima = _gara(anonimo: true, autore: '', id: 'x');

      expect(lanciataDaMe(anonima, null, const {'x'}), isFalse);
      expect(lanciataDaMe(anonima, '', const {'x'}), isFalse);
    });
  });
}
