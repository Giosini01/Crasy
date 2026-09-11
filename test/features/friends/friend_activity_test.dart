import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/domain/entities/friendship.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cosa finisce dentro "attivita' amici", e soprattutto cosa non ci finisce.
///
/// Le due liste non chiedono niente a Firestore: filtrano quello che l'app ha
/// gia' in mano. E' anche il motivo per cui vanno messe alla prova qui —
/// sbagliare il filtro non fa esplodere niente, fa vedere a qualcuno la roba di
/// gente che non conosce.
void main() {
  final now = DateTime.now();

  Challenge challenge({required String id, required String author}) {
    return Challenge(
      id: id,
      title: 'Gara $id',
      brief: 'Fai qualcosa.',
      createdByUserId: author,
      prizeCents: 50000,
      scope: ChallengeScope.global,
      startsAt: now,
      endsAt: now.add(const Duration(hours: 4)),
    );
  }

  ChallengeEntry entry({
    required String id,
    required String challengeId,
    required String userId,
    DateTime? createdAt,
  }) {
    return ChallengeEntry(
      id: id,
      challengeId: challengeId,
      userId: userId,
      authorName: userId,
      mediaUrl: 'https://esempio/$id.jpg',
      createdAt: createdAt,
    );
  }

  ProviderContainer containerWith({
    required List<String> friends,
    List<Challenge> live = const [],
    List<Challenge> reserved = const [],
    List<ChallengeEntry> entries = const [],
  }) {
    final ids = [for (final amico in friends) amico];

    final container = ProviderContainer(
      overrides: [
        myFriendsProvider.overrideWith(
          (ref) => Stream.value([
            for (final id in ids) Friend(userId: id, username: id),
          ]),
        ),
        liveChallengesProvider.overrideWith((ref) => Stream.value(live)),
        reservedChallengesProvider.overrideWith(
          (ref) => Stream.value(reserved),
        ),
        entriesOfManyProvider(
          usersKey(ids),
        ).overrideWith((ref) => Stream.value(entries)),
      ],
    );

    addTearDown(container.dispose);

    return container;
  }

  Future<void> attendi(ProviderContainer container, List<String> ids) async {
    // I flussi vanno aspettati: letti prima del primo valore darebbero liste
    // vuote, e il test passerebbe per il motivo sbagliato.
    await container.read(myFriendsProvider.future);
    await container.read(liveChallengesProvider.future);
    await container.read(reservedChallengesProvider.future);

    if (ids.isNotEmpty) {
      await container.read(entriesOfManyProvider(usersKey(ids)).future);
    }
  }

  test('fra le missioni ci sono solo quelle lanciate dagli amici', () async {
    final container = containerWith(
      friends: ['amico'],
      live: [
        challenge(id: 'sua', author: 'amico'),
        challenge(id: 'di-uno-a-caso', author: 'sconosciuto'),
      ],
    );

    await attendi(container, ['amico']);

    expect(container.read(friendChallengesProvider).map((c) => c.id), ['sua']);
  });

  test(
    'le foto sono solo quelle degli amici, e solo nelle gare aperte',
    () async {
      final entries = [
        entry(id: 'a', challengeId: 'aperta', userId: 'amico'),
        // La gara di questa e' finita: la fiamma non si puo' piu' dare, e una
        // foto su cui non si puo' fare niente qui non ci sta.
        entry(id: 'b', challengeId: 'chiusa', userId: 'amico'),
        entry(id: 'c', challengeId: 'aperta', userId: 'sconosciuto'),
      ];

      final container = containerWith(
        friends: ['amico'],
        live: [challenge(id: 'aperta', author: 'chiunque')],
        entries: entries,
      );

      await attendi(container, ['amico']);

      expect(container.read(friendEntriesProvider).map((e) => e.id), ['a']);
    },
  );

  test('le foto degli amici nel party compaiono in IN GARA', () async {
    final party = Challenge(
      id: 'party',
      title: 'Gara fra amici',
      brief: 'Fai qualcosa insieme.',
      createdByUserId: 'amico',
      prizeCents: 0,
      scope: ChallengeScope.friends,
      startsAt: now,
      endsAt: now.add(const Duration(hours: 4)),
      audience: const ['io', 'amico'],
    );
    final container = containerWith(
      friends: ['amico'],
      reserved: [party],
      entries: [entry(id: 'nel-party', challengeId: 'party', userId: 'amico')],
    );

    await attendi(container, ['amico']);

    expect(container.read(friendChallengesProvider).map((c) => c.id), [
      'party',
    ]);
    expect(container.read(friendEntriesProvider).map((e) => e.id), [
      'nel-party',
    ]);
  });

  test('le foto piu\' recenti stanno in cima', () async {
    final container = containerWith(
      friends: ['amico'],
      live: [challenge(id: 'aperta', author: 'chiunque')],
      entries: [
        entry(
          id: 'vecchia',
          challengeId: 'aperta',
          userId: 'amico',
          createdAt: now.subtract(const Duration(hours: 3)),
        ),
        entry(id: 'appena-partita', challengeId: 'aperta', userId: 'amico'),
        entry(
          id: 'recente',
          challengeId: 'aperta',
          userId: 'amico',
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
      ],
    );

    await attendi(container, ['amico']);

    // Senza data vuol dire mandata adesso, e Firestore non ha ancora fatto in
    // tempo a timbrarla: sta con le piu' recenti, non in fondo.
    expect(container.read(friendEntriesProvider).map((e) => e.id), [
      'appena-partita',
      'recente',
      'vecchia',
    ]);
  });

  test('senza amici non si guarda niente', () async {
    final container = containerWith(
      friends: [],
      live: [challenge(id: 'una', author: 'sconosciuto')],
    );

    await attendi(container, []);

    expect(container.read(friendChallengesProvider), isEmpty);
    expect(container.read(friendEntriesProvider), isEmpty);
  });
}
