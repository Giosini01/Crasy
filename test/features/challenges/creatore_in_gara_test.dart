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
  group('ho vinto io?', () {
    Challenge vinta(String da) => Challenge(
      id: 'g',
      title: 'Una gara',
      brief: 'Fai qualcosa.',
      prizeCents: 200,
      scope: ChallengeScope.global,
      createdByUserId: 'chi-lha-lanciata',
      winnerUserId: da,
      startsAt: DateTime.now(),
      endsAt: DateTime.now().add(const Duration(hours: 1)),
    );

    test('si, se il vincitore sono io', () {
      expect(vinta('tony92').hoVintoIo('tony92'), isTrue);
    });

    test('no, se ha vinto un altro', () {
      expect(vinta('tony92').hoVintoIo('giosyni'), isFalse);
    });

    test('una gara chiusa senza vincitore non la vince nessuno', () {
      // **La trappola per cui questo controllo esiste.** Il campo del
      // vincitore e' vuoto quando una gara si chiude senza, e confrontando due
      // stringhe vuote l'app direbbe "hai vinto" a chiunque la apra.
      expect(vinta('').hoVintoIo(''), isFalse);
      expect(vinta('').hoVintoIo('tony92'), isFalse);
    });

    test('chi guarda senza essere entrato non ha vinto niente', () {
      expect(vinta('tony92').hoVintoIo(null), isFalse);
      expect(vinta('tony92').hoVintoIo(''), isFalse);
    });
  });

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
