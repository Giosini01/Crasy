import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter_test/flutter_test.dart';

Challenge _gara({
  bool anonimo = false,
  String autore = 'chi-la-lancia',
  String id = 'g',
}) {
  return Challenge(
    id: id,
    title: 'Una gara',
    brief: 'Fai qualcosa.',
    prizeCents: 500,
    scope: ChallengeScope.global,
    audience: const [Challenge.everyone],
    anonimo: anonimo,
    createdByUserId: autore,
    startsAt: DateTime(2026, 10, 18, 12),
    endsAt: DateTime(2026, 10, 19, 12),
  );
}

/// **Un'anonima non porta scritto chi l'ha lanciata.**
///
/// Il documento della gara lo legge chiunque la veda. Lo scrive il server, che
/// non ci mette ne' il nome ne' l'identificativo di chi si e' nascosto: quella
/// prova sta con le prove del server, in `functions/test/integrazione.emu.js`.
///
/// Qui resta l'altra meta': il telefono di chi l'ha lanciata deve sapere che e'
/// sua, leggendolo dal suo foglio a parte.
void main() {
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
