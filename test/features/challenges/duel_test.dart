import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/entities/duel_status.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le sfide mirate: **chi le vede, a che punto stanno, e cosa non costano.**
///
/// Le tre cose messe alla prova qui sono le tre che, sbagliate, non fanno
/// esplodere niente: una sfida lanciata che non compare fra le lanciate — il
/// difetto che c'era — una sfida scaduta che continua a sembrare in attesa, e
/// una sfida che si mangia una delle cinque partecipazioni del giorno. Quella
/// terza e' la peggiore delle tre: farebbe costare l'accettare, e accettare
/// non deve costare niente.
void main() {
  _fischio();
  final now = DateTime.now();

  Challenge duel({
    required String id,
    required String from,
    required String to,
    DuelStatus status = DuelStatus.pending,
    DuelVerdict verdict = DuelVerdict.none,
    int prizeCents = 0,
    DateTime? risposta,
    Duration durata = const Duration(hours: 24),
  }) {
    return Challenge(
      id: id,
      title: 'Sfida $id',
      brief: 'Fai qualcosa.',
      prizeCents: prizeCents,
      scope: ChallengeScope.friends,
      createdByUserId: from,
      createdByUsername: from,
      targetUserId: to,
      targetUsername: to,
      duelStatus: status,
      duelVerdict: verdict,
      respondedAt: risposta,
      audience: [from, to],
      maxParticipants: 1,
      startsAt: now.subtract(const Duration(hours: 1)),
      endsAt: now.subtract(const Duration(hours: 1)).add(durata),
    );
  }

  _verdetto(duel, now);

  group('cinque ore per ripensarci', () {
    // **Un no che si puo' disfare per sempre non e' un no**: e' una risposta
    // rimandata, e chi ha lanciato la sfida resta appeso a tempo indeterminato
    // a una cosa a cui gli hanno gia' detto di no.
    Challenge rifiutata({DateTime? quando}) => duel(
      id: 'x',
      from: 'mario',
      to: 'io',
      status: DuelStatus.declined,
      risposta: quando,
    );

    test('appena detto di no si puo\' tornare indietro', () {
      final sfida = rifiutata(quando: now.subtract(const Duration(minutes: 5)));

      expect(sfida.canReconsiderAt(now), isTrue);
    });

    test('a quattro ore e mezza si fa ancora in tempo', () {
      final sfida = rifiutata(
        quando: now.subtract(const Duration(hours: 4, minutes: 30)),
      );

      expect(sfida.canReconsiderAt(now), isTrue);
    });

    test('a sei ore no', () {
      final sfida = rifiutata(quando: now.subtract(const Duration(hours: 6)));

      expect(sfida.canReconsiderAt(now), isFalse);
    });

    test('senza l\'ora della risposta si lascia passare', () {
      // La risposta la scrive il server con il suo orologio, e nell'istante fra
      // il tocco e la conferma il telefono legge quel campo ancora vuoto. Dire
      // di no li' vorrebbe dire far sparire il tasto proprio a chi ha appena
      // rifiutato — cioe' all'unica persona che lo sta guardando.
      expect(rifiutata().canReconsiderAt(now), isTrue);
    });

    test('chi non ha rifiutato non ha niente da ripensare', () {
      for (final stato in [
        DuelStatus.pending,
        DuelStatus.accepted,
        DuelStatus.completed,
      ]) {
        final sfida = duel(
          id: 'x',
          from: 'mario',
          to: 'io',
          status: stato,
          risposta: now,
        );

        expect(sfida.canReconsiderAt(now), isFalse, reason: stato.name);
      }
    });
  });

  group('gratis o con dei soldi', () {
    // **Per molto tempo era zero e basta**, con una ragione buona: fra due
    // amici il premio e' la parola data. Resta la strada normale — ed e' quella
    // che parte scelta — ma "ti do venti euro se lo fai" e' una sfida che
    // esiste, e costringerla fuori dall'app non la fa sparire: la fa succedere
    // senza che l'app ne sappia niente.
    test('senza premio si legge GRATIS, come ogni altra gara', () {
      final sfida = duel(id: 'x', from: 'io', to: 'ciccio');

      expect(sfida.prizeCents, 0);
      expect(sfida.prizeLabel, 'GRATIS');
    });

    test('con il premio si legge la cifra, e resta una sfida mirata', () {
      final sfida = duel(
        id: 'x',
        from: 'io',
        to: 'ciccio',
        prizeCents: 2000,
      );

      expect(sfida.prizeLabel, isNot('GRATIS'));
      expect(sfida.prizeLabel, contains('20'));
      // Il premio non cambia cos'e': resta una sfida a una persona sola, con
      // il suo giudizio e il suo destinatario.
      expect(sfida.isDuel, isTrue);
      expect(sfida.maxParticipants, 1);
    });

    test('i soldi non pesano sulla giornata piu\' di quanto pesi il gratis', () {
      // La sfida mirata e' roba in piu' e lo resta: se accettare una sfida con
      // dei soldi costasse una delle cinque partecipazioni, accettare
      // diventerebbe una cosa che si paga.
      final sfida = duel(
        id: 'x',
        from: 'mario',
        to: 'io',
        prizeCents: 2000,
      );

      expect(sfida.isDuel, isTrue);
    });
  });

  ProviderContainer containerWith(List<Challenge> reserved) {
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('io'),
        reservedChallengesProvider.overrideWith(
          (ref) => Stream.value(reserved),
        ),
      ],
    );

    addTearDown(container.dispose);

    return container;
  }

  group('chi vede cosa', () {
    test('una sfida lanciata finisce fra le lanciate, non fra le ricevute', () async {
      final container = containerWith([
        duel(id: 'mia', from: 'io', to: 'mario'),
      ]);

      await container.read(reservedChallengesProvider.future);

      expect(
        [for (final c in container.read(sentDuelsProvider)) c.id],
        ['mia'],
      );
      expect(container.read(receivedDuelsProvider), isEmpty);
    });

    test('una sfida ricevuta finisce fra le ricevute', () async {
      final container = containerWith([
        duel(id: 'sua', from: 'mario', to: 'io'),
      ]);

      await container.read(reservedChallengesProvider.future);

      expect(
        [for (final c in container.read(receivedDuelsProvider)) c.id],
        ['sua'],
      );
      expect(container.read(sentDuelsProvider), isEmpty);
    });

    test('le sfide non si mescolano alle missioni del party', () async {
      final container = containerWith([
        duel(id: 'sfida', from: 'io', to: 'mario'),
        Challenge(
          id: 'party',
          title: 'Per tutti',
          brief: 'Fai qualcosa.',
          prizeCents: 0,
          scope: ChallengeScope.friends,
          createdByUserId: 'io',
          createdByUsername: 'io',
          audience: const ['io', 'mario', 'luca'],
          startsAt: now.subtract(const Duration(hours: 1)),
          endsAt: now.add(const Duration(hours: 3)),
        ),
      ]);

      await container.read(reservedChallengesProvider.future);

      expect(
        [for (final c in container.read(partyChallengesProvider)) c.id],
        ['party'],
      );
      expect(
        [for (final c in container.read(myFriendChallengesProvider)) c.id],
        ['party'],
      );
    });

    test('solo le ricevute senza risposta stanno nel pallino rosso', () async {
      final container = containerWith([
        duel(id: 'a', from: 'mario', to: 'io'),
        duel(id: 'b', from: 'luca', to: 'io', status: DuelStatus.accepted),
        duel(id: 'c', from: 'io', to: 'mario'),
      ]);

      await container.read(reservedChallengesProvider.future);

      expect(container.read(pendingDuelsCountProvider), 1);
    });

    test('prima quelle su cui c\'e\' ancora qualcosa da fare', () async {
      final container = containerWith([
        duel(id: 'chiusa', from: 'mario', to: 'io', status: DuelStatus.declined),
        duel(id: 'aperta', from: 'luca', to: 'io'),
      ]);

      await container.read(reservedChallengesProvider.future);

      expect(
        [for (final c in container.read(receivedDuelsProvider)) c.id],
        ['aperta', 'chiusa'],
      );
    });
  });

  group('lo stato che dipende dall\'orologio', () {
    test('in attesa finche\' c\'e\' tempo, scaduta dopo', () {
      final sfida = duel(id: 'x', from: 'mario', to: 'io');

      expect(sfida.duelStateAt(now), DuelState.pending);
      expect(
        sfida.duelStateAt(now.add(const Duration(days: 2))),
        DuelState.expired,
      );
    });

    test('accettata e non fatta scade come le altre', () {
      final sfida = duel(
        id: 'x',
        from: 'mario',
        to: 'io',
        status: DuelStatus.accepted,
      );

      expect(sfida.duelStateAt(now), DuelState.accepted);
      expect(
        sfida.duelStateAt(now.add(const Duration(days: 2))),
        DuelState.expired,
      );
    });

    test('fatta e rifiutata sono finali: il tempo non le tocca', () {
      for (final stato in [DuelStatus.completed, DuelStatus.declined]) {
        final sfida = duel(id: 'x', from: 'mario', to: 'io', status: stato);
        final dopo = sfida.duelStateAt(now.add(const Duration(days: 30)));

        expect(
          dopo,
          stato == DuelStatus.completed
              // Fatta e non ancora guardata: resta li' ad aspettare un
              // giudizio anche un mese dopo. **Non scade**, ed e' voluto — a
              // chiuderla e' una persona, non l'orologio, e il server la chiude
              // scrivendo `expired` invece di proclamare qualcuno.
              ? DuelState.judging
              : DuelState.declined,
        );
      }
    });
  });

  group('le sfide non pesano sulla giornata', () {
    ChallengeEntry foto({
      required String challengeId,
      required bool sfida,
    }) {
      return ChallengeEntry(
        id: challengeId,
        challengeId: challengeId,
        userId: 'io',
        authorName: 'io',
        mediaUrl: 'https://esempio/$challengeId.jpg',
        isDuel: sfida,
        createdAt: DateTime.now(),
      );
    }

    ProviderContainer conFoto(List<ChallengeEntry> mie) {
      final container = ProviderContainer(
        overrides: [
          myEntriesProvider.overrideWith((ref) => Stream.value(mie)),
          liveChallengesProvider.overrideWith(
            (ref) => Stream.value(const <Challenge>[]),
          ),
          endedChallengesProvider.overrideWith(
            (ref) => Stream.value(const <Challenge>[]),
          ),
        ],
      );

      addTearDown(container.dispose);

      return container;
    }

    test('una foto normale toglie una partecipazione', () async {
      final container = conFoto([foto(challengeId: 'gara', sfida: false)]);

      await container.read(myEntriesProvider.future);

      expect(container.read(livesLeftProvider), Challenge.livesPerDay - 1);
    });

    test('una foto mandata a una sfida non toglie niente', () async {
      final container = conFoto([
        foto(challengeId: 'sfida-uno', sfida: true),
        foto(challengeId: 'sfida-due', sfida: true),
      ]);

      await container.read(myEntriesProvider.future);

      expect(container.read(livesLeftProvider), Challenge.livesPerDay);
    });

    test('le due cose convivono nella stessa giornata', () async {
      final container = conFoto([
        foto(challengeId: 'gara', sfida: false),
        foto(challengeId: 'sfida', sfida: true),
      ]);

      await container.read(myEntriesProvider.future);

      expect(container.read(livesLeftProvider), Challenge.livesPerDay - 1);
    });
  });
}

/// **Il fischio.** Rifiutare una sfida d'onore e' l'unica mossa che non costa
/// niente a chi la fa: e' il momento in cui la parola data smette di valere
/// qualcosa, se nessuno se ne accorge. Queste righe difendono il fatto che un
/// no si veda — e che su una sfida ancora in corso non ci sia niente da
/// fischiare, o il fischio diventerebbe rumore di fondo.
void _fischio() {
  group('il no si sente', () {
    test('il distintivo del rifiuto dice BUUU', () {
      expect(DuelState.declined.chipLabel, 'BUUU');
    });

    test('gli altri stati restano scritti per quello che sono', () {
      expect(DuelState.pending.chipLabel, 'IN ATTESA');
      expect(DuelState.accepted.chipLabel, 'ACCETTATA');
      expect(DuelState.completed.chipLabel, 'VINTA');
      expect(DuelState.expired.chipLabel, 'SCADUTA');
    });

    test('rifiutata e scaduta hanno una riga di commento', () {
      expect(
        DuelState.declined.fischio(mine: true, username: 'mario'),
        'Hai detto di no. Buuu.',
      );
      expect(
        DuelState.declined.fischio(mine: false, username: 'mario'),
        '@mario ha detto di no. Buuu.',
      );
      expect(
        DuelState.expired.fischio(mine: false, username: 'mario'),
        contains('Buuu'),
      );
    });

    test('su una sfida ancora viva non si fischia niente', () {
      expect(DuelState.pending.fischio(mine: true, username: 'mario'), isNull);
      expect(DuelState.accepted.fischio(mine: true, username: 'mario'), isNull);
      expect(
        DuelState.completed.fischio(mine: true, username: 'mario'),
        isNull,
      );
    });
  });
}

/// **Il buco piu' grosso che una sfida uno contro uno potesse avere.**
///
/// Con un partecipante solo, la regola che decide ogni altra gara — vince chi
/// ha piu' fiamme — qui vuol dire che vince chiunque abbia mandato qualcosa. La
/// sfida diceva "balla in mezzo alla piazza", il video e' nero, e il sistema
/// proclamava un vincitore che non aveva ballato. Queste righe difendono il
/// passaggio che mancava: **la foto la guarda chi ha chiesto la cosa**.
///
/// E difendono anche l'altra meta', che conta uguale: il silenzio di chi doveva
/// guardare non e' una bocciatura di chi ha fatto il lavoro, e le due cose non
/// si possono scrivere nello stesso modo.
void _verdetto(
  Challenge Function({
    required String id,
    required String from,
    required String to,
    DuelStatus status,
    DuelVerdict verdict,
    Duration durata,
  })
  duel,
  DateTime now,
) {
  group('la foto non vince da sola', () {
    test('fatta e non ancora guardata: sta in mezzo, non ha vinto', () {
      final sfida = duel(
        id: 'x',
        from: 'io',
        to: 'ciccio',
        status: DuelStatus.completed,
      );

      expect(sfida.duelStateAt(now), DuelState.judging);
    });

    test('giudicata valida: e\' vinta', () {
      final sfida = duel(
        id: 'x',
        from: 'io',
        to: 'ciccio',
        status: DuelStatus.completed,
        verdict: DuelVerdict.approved,
      );

      expect(sfida.duelStateAt(now), DuelState.completed);
    });

    test('bocciata: non e\' valida, e non e\' un rifiuto', () {
      final sfida = duel(
        id: 'x',
        from: 'io',
        to: 'ciccio',
        status: DuelStatus.completed,
        verdict: DuelVerdict.rejected,
      );

      // **Non e' `declined`**, ed e' la distinzione che conta: rifiutata vuol
      // dire che si e' tirata indietro, non valida vuol dire che l'ha fatta e
      // non andava bene. Confonderle e' dare a qualcuno la colpa di una cosa
      // che non ha fatto.
      expect(sfida.duelStateAt(now), DuelState.notValid);
      expect(sfida.duelStateAt(now), isNot(DuelState.declined));
    });

    test('nessuno l\'ha guardata in tempo: si chiude senza vincitore', () {
      final sfida = duel(
        id: 'x',
        from: 'io',
        to: 'ciccio',
        status: DuelStatus.completed,
        verdict: DuelVerdict.expired,
      );

      expect(sfida.duelStateAt(now), DuelState.noVerdict);
    });

    test('il silenzio non si scrive come una bocciatura', () {
      // Le due righe che leggera' chi ha fatto la sfida. Se fossero la stessa
      // frase, un amico distratto e un amico severo avrebbero lo stesso
      // aspetto — e uno dei due sta dando la colpa a chi non ce l'ha.
      final bocciata = DuelState.notValid.fischio(mine: true, username: 'io');
      final silenzio = DuelState.noVerdict.nota(mine: true, username: 'io');

      expect(bocciata, isNotNull);
      expect(silenzio, isNotNull);
      expect(bocciata, isNot(silenzio));
      expect(silenzio, contains('Non e\' colpa tua'));
    });

    test('da giudicare vuol dire che la sfida e\' ancora viva', () {
      final sfida = duel(
        id: 'x',
        from: 'io',
        to: 'ciccio',
        status: DuelStatus.completed,
      );

      // Anche un mese dopo: a chiuderla e' una persona, non l'orologio. Se
      // scadesse da sola, il lavoro gia' fatto sparirebbe per il ritardo di
      // chi doveva guardarlo.
      expect(sfida.isDuelOpenAt(now.add(const Duration(days: 30))), isTrue);
    });

    test('finite vuol dire finite', () {
      expect(DuelState.completed.isOver, isTrue);
      expect(DuelState.notValid.isOver, isTrue);
      expect(DuelState.noVerdict.isOver, isTrue);
      expect(DuelState.declined.isOver, isTrue);
      expect(DuelState.expired.isOver, isTrue);
      expect(DuelState.judging.isOver, isFalse);
      expect(DuelState.pending.isOver, isFalse);
      expect(DuelState.accepted.isOver, isFalse);
    });
  });

  group('come si legge dal database', () {
    test('i verdetti si leggono per come sono scritti', () {
      expect(DuelVerdict.fromName('approved'), DuelVerdict.approved);
      expect(DuelVerdict.fromName('rejected'), DuelVerdict.rejected);
      expect(DuelVerdict.fromName('expired'), DuelVerdict.expired);
    });

    test('senza verdetto, o con uno inventato, non c\'e\' verdetto', () {
      // **Il ripiego conta piu' del resto.** Tutte le sfide gia' sul database
      // non hanno questo campo: se un valore mancante si leggesse come
      // "approvata", il giorno dell'aggiornamento ogni sfida mai fatta
      // diventerebbe una vittoria.
      expect(DuelVerdict.fromName(null), DuelVerdict.none);
      expect(DuelVerdict.fromName(''), DuelVerdict.none);
      expect(DuelVerdict.fromName('qualcosa'), DuelVerdict.none);
      expect(DuelVerdict.none.isGiven, isFalse);
      expect(DuelVerdict.none.isApproved, isFalse);
    });

    test('una sfida vecchia, senza il campo, resta da giudicare', () {
      final vecchia = duel(
        id: 'x',
        from: 'io',
        to: 'ciccio',
        status: DuelStatus.completed,
      );

      expect(vecchia.duelVerdict, DuelVerdict.none);
      expect(vecchia.duelStateAt(now), DuelState.judging);
    });
  });
}
