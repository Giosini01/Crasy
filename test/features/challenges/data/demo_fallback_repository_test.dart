import 'dart:async';

import 'package:crasy/features/challenges/data/repositories/demo_fallback_challenge_repository.dart';
import 'package:crasy/features/challenges/data/repositories/sample_challenge_repository.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un Firestore finto: emette quello che gli si dice, quando glielo si dice.
///
/// `noSuchMethod` copre tutto il resto dell'interfaccia. Qui serve un metodo
/// solo, e scrivere gli altri quindici per farli lanciare vorrebbe dire
/// quindici righe che non provano niente.
class _FakeRemote implements ChallengeRepository {
  _FakeRemote(this.ended);

  final Stream<List<Challenge>> ended;

  @override
  Stream<List<Challenge>> watchEndedChallenges() => ended;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Challenge _gara(String id) {
  final now = DateTime.now();

  return Challenge(
    id: id,
    title: 'Gara $id',
    brief: 'Fai qualcosa.',
    prizeCents: 100,
    scope: ChallengeScope.global,
    startsAt: now.subtract(const Duration(hours: 2)),
    endsAt: now.subtract(const Duration(minutes: 1)),
    participantsCount: 1,
    winnerEntryId: 'qualcuno',
  );
}

void main() {
  test(
    'le gare che finiscono dopo la prima risposta arrivano lo stesso',
    () async {
      // **E' il difetto per cui una gara appena chiusa non compariva fra i
      // vincitori.**
      //
      // Le due sorgenti — Firestore e le gare di esempio — erano unite con
      // `asyncExpand`, che mette in pausa la sorgente finche' il flusso interno
      // non finisce. Quello degli esempi non finisce mai: e' un ascolto
      // permanente. Risultato, **Firestore veniva ascoltato una volta sola** e
      // tutto quello che arrivava dopo restava in coda per sempre.
      //
      // Qui la prima risposta e' vuota — com'e' quasi sempre, perche' la prima
      // notizia arriva dalla copia locale ancora fredda — e la gara si chiude
      // subito dopo.
      final firestore = StreamController<List<Challenge>>();
      final esempi = SampleChallengeRepository();
      addTearDown(esempi.dispose);
      addTearDown(firestore.close);

      final repository = DemoFallbackChallengeRepository(
        _FakeRemote(firestore.stream),
        esempi,
      );

      final visti = <List<Challenge>>[];
      final ascolto = repository.watchEndedChallenges().listen(visti.add);
      addTearDown(ascolto.cancel);

      firestore.add(const []);
      await Future<void>.delayed(Duration.zero);

      firestore.add([_gara('appena-finita')]);
      await Future<void>.delayed(Duration.zero);

      expect(visti, isNotEmpty);
      expect(
        visti.last.map((challenge) => challenge.id),
        contains('appena-finita'),
        reason: 'la seconda risposta di Firestore non e\' arrivata',
      );
    },
  );

  test('senza gare vere si vedono quelle di esempio', () async {
    // L'altra meta' della regola, e va provata insieme: se il ripiego smettesse
    // di funzionare, chi apre l'app la prima volta troverebbe una schermata
    // vuota invece di capire a cosa serve.
    final firestore = StreamController<List<Challenge>>();
    final esempi = SampleChallengeRepository();
    addTearDown(esempi.dispose);
    addTearDown(firestore.close);

    final repository = DemoFallbackChallengeRepository(
      _FakeRemote(firestore.stream),
      esempi,
    );

    final visti = <List<Challenge>>[];
    final ascolto = repository.watchEndedChallenges().listen(visti.add);
    addTearDown(ascolto.cancel);

    firestore.add(const []);
    await Future<void>.delayed(Duration.zero);

    final demo = await esempi.watchEndedChallenges().first;

    expect(visti.last.length, demo.length);
  });
}
