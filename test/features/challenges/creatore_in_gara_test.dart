import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:flutter_test/flutter_test.dart';

Challenge _gara({
  ChallengeScope scope = ChallengeScope.global,
  String bersaglio = '',
}) {
  return Challenge(
    id: 'g',
    title: 'Una gara',
    brief: 'Fai qualcosa.',
    prizeCents: 500,
    scope: scope,
    createdByUserId: 'chi-lha-lanciata',
    targetUserId: bersaglio,
    startsAt: DateTime.now(),
    endsAt: DateTime.now().add(const Duration(hours: 1)),
  );
}

/// Chi lancia una gara ci partecipa, e dove no.
///
/// La regola vera la fanno le regole del database e `closeChallenge`, che da
/// qui non si provano. Si prova la cosa su cui tutta l'app si basa per decidere
/// se mostrare il tasto: in quali gare chi lancia puo' scendere in campo.
void main() {
  group('chi lancia scende in gara', () {
    test('nelle gare pubbliche sì', () {
      // A dire chi ha vinto sono le fiamme degli altri: chi lancia e poi
      // partecipa non si sta dando niente, si sta mettendo in mezzo agli altri.
      expect(_gara().apertaAlCreatore, isTrue);
      expect(_gara(scope: ChallengeScope.country).apertaAlCreatore, isTrue);
      expect(_gara(scope: ChallengeScope.local).apertaAlCreatore, isTrue);
    });

    test('fra amici no, perché il vincitore lo scegli lui', () {
      // Partecipare a una gara in cui decidi tu e' assegnarsi il premio da
      // solo: un bonifico con dei passaggi in piu'.
      expect(_gara(scope: ChallengeScope.friends).apertaAlCreatore, isFalse);
    });

    test('nelle private no, per la stessa ragione', () {
      expect(_gara(scope: ChallengeScope.private).apertaAlCreatore, isFalse);
    });

    test('in una sfida mirata no', () {
      // Una sfida e' una domanda fatta a una persona, e chi la fa non e' fra
      // quelli a cui e' stata fatta.
      expect(_gara(bersaglio: 'un-amico').apertaAlCreatore, isFalse);
    });

    test('una sfida resta chiusa anche se è pubblica di ambito', () {
      // Il bersaglio vince sull'ambito: senza questo controllo una sfida
      // salvata con `scope: global` lascerebbe entrare chi l'ha lanciata.
      expect(
        _gara(bersaglio: 'un-amico').apertaAlCreatore,
        isFalse,
        reason: 'il bersaglio conta più dell\'ambito',
      );
    });
  });
}
