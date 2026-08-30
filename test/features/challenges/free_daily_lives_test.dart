import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// La sfida del giorno e' gratis **e non consuma una delle cinque**.
///
/// Se le consumasse sarebbe un imbroglio: si presenta come un fuoriprogramma
/// per divertirsi, e si porterebbe via un quinto di quello che serve per
/// giocarsi le gare dove ci sono i soldi.
void main() {
  final adesso = DateTime.now();

  Challenge challenge({required String id, bool diCrasy = false}) {
    return Challenge(
      id: id,
      title: 'Gara $id',
      brief: 'Fai qualcosa.',
      prizeCents: diCrasy ? 0 : 50000,
      scope: ChallengeScope.global,
      startsAt: adesso.subtract(const Duration(hours: 2)),
      endsAt: adesso.add(const Duration(hours: 6)),
      isDaily: diCrasy,
    );
  }

  ChallengeEntry entry(String challengeId) {
    return ChallengeEntry(
      id: 'mia',
      challengeId: challengeId,
      userId: 'io',
      authorName: 'io',
      mediaUrl: 'https://esempio/foto.jpg',
      createdAt: adesso,
    );
  }

  Future<int> vite({
    required List<Challenge> live,
    required List<ChallengeEntry> mie,
  }) async {
    final container = ProviderContainer(
      overrides: [
        liveChallengesProvider.overrideWith((ref) => Stream.value(live)),
        endedChallengesProvider.overrideWith(
          (ref) => Stream.value(const <Challenge>[]),
        ),
        myEntriesProvider.overrideWith((ref) => Stream.value(mie)),
      ],
    );

    addTearDown(container.dispose);

    // I flussi vanno aspettati: letti prima del primo valore le partecipazioni
    // risultano zero, e restano cinque vite comunque — il test passerebbe per
    // il motivo sbagliato proprio dove non deve.
    await container.read(liveChallengesProvider.future);
    await container.read(endedChallengesProvider.future);
    await container.read(myEntriesProvider.future);

    return container.read(livesLeftProvider);
  }

  test('una gara normale toglie una partecipazione', () async {
    expect(
      await vite(
        live: [challenge(id: 'a')],
        mie: [entry('a')],
      ),
      Challenge.livesPerDay - 1,
    );
  });

  test('la sfida del giorno non toglie niente', () async {
    expect(
      await vite(
        live: [challenge(id: 'daily-oggi', diCrasy: true)],
        mie: [entry('daily-oggi')],
      ),
      Challenge.livesPerDay,
    );
  });

  test('le cinque restano cinque anche facendo tutte e due', () async {
    expect(
      await vite(
        live: [
          challenge(id: 'daily-oggi', diCrasy: true),
          challenge(id: 'vera'),
        ],
        mie: [entry('daily-oggi'), entry('vera')],
      ),
      Challenge.livesPerDay - 1,
    );
  });
}
