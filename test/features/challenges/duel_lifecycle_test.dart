import 'dart:typed_data';

import 'package:crasy/features/challenges/data/repositories/sample_challenge_repository.dart';
import 'package:crasy/features/challenges/domain/commissioned_order.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/entities/duel_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Il giro intero di una sfida mirata, dall'inizio alla figurina.**
///
/// E' il pezzo dell'app che abbiamo riscritto piu' volte — lancio, risposta,
/// foto, giudizio, chiusura — e ogni passaggio era stato provato per conto suo.
/// Il giro completo no, ed e' proprio dove si nascondono i guasti: non dentro
/// un passaggio, ma nel punto in cui uno finisce e comincia il successivo.
///
/// Quello che difende, in ordine:
///
/// - una sfida accettata non e' ancora vinta;
/// - la foto non la chiude: dopo la foto c'e' **il giudizio**, e finche' non
///   arriva la sfida sta in mezzo (era il buco piu' grosso — bastava mandare
///   un video nero per vincere);
/// - il giudizio la chiude **nell'istante in cui arriva**, orologio compreso,
///   che e' cio' che la fa uscire dalle ricevute e entrare fra le chiuse;
/// - approvata lascia una figurina a chi l'ha fatta, e **una sola riga** sulla
///   bacheca di chi l'ha lanciata.
void main() {
  late SampleChallengeRepository repository;

  setUp(() {
    repository = SampleChallengeRepository();
    addTearDown(repository.dispose);
  });

  /// Giovanni sfida Mario: ventiquattro ore, nessun premio.
  Future<Challenge> sfida() {
    final now = DateTime.now();

    return repository.createChallenge(
      Challenge(
        id: '',
        title: 'Balla a Baiano',
        brief: 'In mezzo alla piazza.',
        prizeCents: 0,
        scope: ChallengeScope.friends,
        createdByUserId: 'giovanni',
        createdByUsername: 'giovanni',
        targetUserId: 'mario',
        targetUsername: 'mario',
        maxParticipants: 1,
        audience: const ['giovanni', 'mario'],
        startsAt: now,
        endsAt: now.add(const Duration(hours: 24)),
      ),
    );
  }

  Future<Challenge> rileggi(String id) async =>
      (await repository.watchChallenge(id).first)!;

  test('nasce in attesa di una risposta', () async {
    final nata = await sfida();

    expect(nata.isDuel, isTrue);
    expect(nata.duelStatus, DuelStatus.pending);
    expect(nata.duelVerdict, DuelVerdict.none);
    expect(nata.duelStateAt(DateTime.now()), DuelState.pending);
  });

  test('accettata non vuol dire vinta', () async {
    final nata = await sfida();

    await repository.answerDuel(
      challengeId: nata.id,
      status: DuelStatus.accepted,
    );

    final dopo = await rileggi(nata.id);

    expect(dopo.duelStateAt(DateTime.now()), DuelState.accepted);
    expect(dopo.hasTrophy, isFalse);
  });

  test('la foto non chiude la sfida: dopo c\'e\' il giudizio', () async {
    final nata = await sfida();

    await repository.answerDuel(
      challengeId: nata.id,
      status: DuelStatus.accepted,
    );
    await repository.submitEntry(
      challengeId: nata.id,
      userId: 'mario',
      authorName: 'mario',
      bytes: Uint8List.fromList(const [1, 2, 3]),
    );
    await repository.answerDuel(
      challengeId: nata.id,
      status: DuelStatus.completed,
    );

    final dopo = await rileggi(nata.id);

    // **E' il passaggio che mancava.** Con un partecipante solo, "vince chi ha
    // piu' fiamme" vuol dire che vince chiunque abbia mandato qualcosa — anche
    // un video nero su una sfida che diceva "balla in mezzo alla piazza".
    expect(dopo.duelStateAt(DateTime.now()), DuelState.judging);
    expect(dopo.hasTrophy, isFalse);
    expect(dopo.winnerEntryId, isNull);
  });

  test('il giudizio chiude la sfida e lascia la figurina', () async {
    final nata = await sfida();

    await repository.answerDuel(
      challengeId: nata.id,
      status: DuelStatus.accepted,
    );
    final foto = await repository.submitEntry(
      challengeId: nata.id,
      userId: 'mario',
      authorName: 'mario',
      bytes: Uint8List.fromList(const [1, 2, 3]),
    );
    await repository.answerDuel(
      challengeId: nata.id,
      status: DuelStatus.completed,
    );

    await repository.judgeDuel(
      challengeId: nata.id,
      approved: true,
      entry: foto,
    );

    final dopo = await rileggi(nata.id);
    final adesso = DateTime.now();

    expect(dopo.duelStateAt(adesso), DuelState.completed);
    expect(dopo.hasTrophy, isTrue);
    expect(dopo.winnerUserId, 'mario');

    // **L'orologio si ferma insieme al verdetto.** Senza questa riga la sfida
    // restava fra le ricevute fino alla scadenza naturale — decisa, finita, e
    // ancora in cima come una cosa da fare: le schede del party guardano
    // `endsAt` per sapere cos'e' ancora in corso.
    expect(dopo.hasEndedAt(adesso), isTrue);

    // E la figurina finisce a chi l'ha fatta, non a chi l'ha chiesta.
    final suoi = await repository.watchTrophiesOf('mario').first;

    expect(suoi.map((c) => c.id), [nata.id]);
    expect(await repository.watchTrophiesOf('giovanni').first, isEmpty);
  });

  test('bocciata si chiude senza vincitore, e non e\' un rifiuto', () async {
    final nata = await sfida();

    await repository.answerDuel(
      challengeId: nata.id,
      status: DuelStatus.accepted,
    );
    final foto = await repository.submitEntry(
      challengeId: nata.id,
      userId: 'mario',
      authorName: 'mario',
      bytes: Uint8List.fromList(const [1, 2, 3]),
    );
    await repository.answerDuel(
      challengeId: nata.id,
      status: DuelStatus.completed,
    );

    await repository.judgeDuel(
      challengeId: nata.id,
      approved: false,
      entry: foto,
    );

    final dopo = await rileggi(nata.id);

    // Non `declined`: rifiutata vuol dire che si e' tirata indietro, non valida
    // vuol dire che l'ha fatta e non andava bene. Confonderle e' dare a
    // qualcuno la colpa di una cosa che non ha fatto.
    expect(dopo.duelStateAt(DateTime.now()), DuelState.notValid);
    expect(dopo.hasTrophy, isFalse);
    expect(await repository.watchTrophiesOf('mario').first, isEmpty);
  });

  test('sulla bacheca di chi l\'ha lanciata compare una volta sola', () async {
    final nata = await sfida();

    await repository.answerDuel(
      challengeId: nata.id,
      status: DuelStatus.accepted,
    );
    final foto = await repository.submitEntry(
      challengeId: nata.id,
      userId: 'mario',
      authorName: 'mario',
      bytes: Uint8List.fromList(const [1, 2, 3]),
    );
    await repository.answerDuel(
      challengeId: nata.id,
      status: DuelStatus.completed,
    );
    await repository.judgeDuel(
      challengeId: nata.id,
      approved: true,
      entry: foto,
    );

    // **Il difetto vero che questo test blocca.** `commissionedOrder` costruisce
    // due elenchi dallo stesso mucchio — le aperte e le finite — e li mette in
    // fila. Una sfida giudicata prima della scadenza rischia di stare in tutti
    // e due: la stessa targa due volte di seguito sul profilo.
    final bacheca = commissionedOrder(
      await repository.watchCommissionedBy('giovanni').first,
      now: DateTime.now(),
    );

    expect(bacheca.map((c) => c.id), [nata.id]);
  });

  test('chi ci ripensa ha cinque ore, non di piu\'', () async {
    final nata = await sfida();

    await repository.answerDuel(
      challengeId: nata.id,
      status: DuelStatus.declined,
    );

    final rifiutata = await rileggi(nata.id);
    final risposta = rifiutata.respondedAt!;

    expect(rifiutata.canReconsiderAt(risposta), isTrue);
    expect(
      rifiutata.canReconsiderAt(risposta.add(const Duration(hours: 4))),
      isTrue,
    );
    expect(
      rifiutata.canReconsiderAt(risposta.add(const Duration(hours: 6))),
      isFalse,
    );
  });
}
