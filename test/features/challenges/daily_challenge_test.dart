import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Come si sceglie la sfida del giorno.
///
/// Due cose contano piu' delle altre e sono provate qui: che **la scelta a mano
/// vinca sempre**, e che senza scelta a mano **tutti i telefoni arrivino alla
/// stessa gara** — altrimenti "la sfida del giorno" non e' un appuntamento, e'
/// una gara a caso diversa per ognuno.
void main() {
  final adesso = DateTime.now();
  final domani = DateTime(adesso.year, adesso.month, adesso.day + 1);

  Challenge challenge({
    required String id,
    DateTime? fine,
    bool diCrasy = false,
  }) {
    return Challenge(
      id: id,
      title: 'Gara $id',
      brief: 'Fai qualcosa.',
      prizeCents: diCrasy ? 0 : 50000,
      scope: ChallengeScope.global,
      startsAt: adesso.subtract(const Duration(hours: 1)),
      endsAt: fine ?? domani.add(const Duration(hours: 6)),
      isDaily: diCrasy,
      createdByUserId: diCrasy ? Challenge.crasyUserId : 'qualcuno',
      createdByUsername: diCrasy ? 'crasy' : 'qualcuno',
    );
  }

  ProviderContainer containerWith({
    required List<Challenge> live,
    String? scelta,
    String giorno = '2026-08-30',
  }) {
    final container = ProviderContainer(
      overrides: [
        todayKeyProvider.overrideWith((ref) => Stream.value(giorno)),
        liveChallengesProvider.overrideWith((ref) => Stream.value(live)),
        dailyPickProvider(giorno).overrideWith((ref) => Stream.value(scelta)),
      ],
    );

    addTearDown(container.dispose);

    return container;
  }

  Future<Challenge?> sfida(ProviderContainer container, String giorno) async {
    await container.read(todayKeyProvider.future);
    await container.read(liveChallengesProvider.future);
    await container.read(dailyPickProvider(giorno).future);

    return container.read(dailyChallengeProvider);
  }

  test('la scelta scritta a mano vince su tutto', () async {
    final container = containerWith(
      live: [
        challenge(id: 'a'),
        challenge(id: 'b'),
        challenge(id: 'c'),
      ],
      scelta: 'c',
    );

    expect((await sfida(container, '2026-08-30'))?.id, 'c');
  });

  test(
    'senza scelta a mano decide la funzione, e decide sempre uguale',
    () async {
      final gare = [challenge(id: 'a'), challenge(id: 'b'), challenge(id: 'c')];

      final primo = await sfida(containerWith(live: gare), '2026-08-30');
      final secondo = await sfida(containerWith(live: gare), '2026-08-30');

      expect(primo, isNotNull);
      // Due contenitori diversi sono due telefoni diversi: se qui uscissero due
      // gare, la sfida del giorno non sarebbe la stessa per tutti.
      expect(secondo?.id, primo?.id);
    },
  );

  test('cambiando giorno cambia la sfida', () async {
    final gare = [
      for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) challenge(id: id),
    ];

    final scelte = <String?>{};

    for (final giorno in [
      '2026-08-30',
      '2026-08-31',
      '2026-09-01',
      '2026-09-02',
    ]) {
      final container = containerWith(live: gare, giorno: giorno);
      scelte.add((await sfida(container, giorno))?.id);
    }

    // Non si pretende che cambi ogni singolo giorno — sarebbe pretendere una
    // cosa che una funzione non promette — ma quattro giorni di fila sulla
    // stessa gara vorrebbe dire che la data non conta niente.
    expect(scelte.length, greaterThan(1));
  });

  test(
    'una gara che finisce prima di stanotte non e\' la sfida del giorno',
    () async {
      final container = containerWith(
        live: [
          challenge(
            id: 'finisce-subito',
            fine: adesso.add(const Duration(hours: 1)),
          ),
        ],
      );

      // Alle nove di sera, una sfida del giorno gia' chiusa e' peggio di nessuna
      // sfida del giorno.
      expect(await sfida(container, '2026-08-30'), isNull);
    },
  );

  test(
    'una scelta a mano su una gara sparita non lascia il posto vuoto',
    () async {
      final container = containerWith(
        live: [
          challenge(id: 'a'),
          challenge(id: 'b'),
        ],
        scelta: 'una-che-non-c-e-piu',
      );

      expect(await sfida(container, '2026-08-30'), isNotNull);
    },
  );

  test('senza gare aperte non c\'e\' sfida del giorno', () async {
    expect(await sfida(containerWith(live: const []), '2026-08-30'), isNull);
  });

  test(
    'la sfida gratis di CRASY viene prima di qualunque scelta a mano',
    () async {
      final container = containerWith(
        live: [
          challenge(id: 'di-qualcuno'),
          challenge(id: 'daily-oggi', diCrasy: true),
        ],
        scelta: 'di-qualcuno',
      );

      // Anche con una scelta scritta a mano: la sfida del giorno di CRASY e'
      // gratis e non consuma una partecipazione, e nessuna gara di qualcun altro
      // puo' prendere quel posto mentre lei e' aperta.
      expect((await sfida(container, '2026-08-30'))?.id, 'daily-oggi');
    },
  );

  test(
    'fra due sfide di CRASY aperte vince quella che finisce prima',
    () async {
      final container = containerWith(
        live: [
          challenge(
            id: 'domani',
            diCrasy: true,
            fine: domani.add(const Duration(days: 1)),
          ),
          challenge(
            id: 'oggi',
            diCrasy: true,
            fine: domani.add(const Duration(minutes: 1)),
          ),
        ],
      );

      expect((await sfida(container, '2026-08-30'))?.id, 'oggi');
    },
  );

  test('la sfida di CRASY dice GRATIS al posto della cifra', () {
    expect(challenge(id: 'x', diCrasy: true).prizeLabel, 'GRATIS');
    expect(challenge(id: 'y').prizeLabel, isNot('GRATIS'));
  });
}
