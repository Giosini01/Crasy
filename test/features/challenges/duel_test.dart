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
    Duration durata = const Duration(hours: 24),
  }) {
    return Challenge(
      id: id,
      title: 'Sfida $id',
      brief: 'Fai qualcosa.',
      prizeCents: 0,
      scope: ChallengeScope.friends,
      createdByUserId: from,
      createdByUsername: from,
      targetUserId: to,
      targetUsername: to,
      duelStatus: status,
      audience: [from, to],
      maxParticipants: 1,
      startsAt: now.subtract(const Duration(hours: 1)),
      endsAt: now.subtract(const Duration(hours: 1)).add(durata),
    );
  }

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

    test('completata e rifiutata sono finali: il tempo non le tocca', () {
      for (final stato in [DuelStatus.completed, DuelStatus.declined]) {
        final sfida = duel(id: 'x', from: 'mario', to: 'io', status: stato);
        final dopo = sfida.duelStateAt(now.add(const Duration(days: 30)));

        expect(
          dopo,
          stato == DuelStatus.completed
              ? DuelState.completed
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
      expect(DuelState.completed.chipLabel, 'COMPLETATA');
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
