import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/search/presentation/providers/search_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cosa deve trovare la lente, e cosa non deve trovare.
///
/// La ricerca delle challenge e' l'unica parte che non chiede niente a
/// Firestore — gira su quello che l'app ha gia' in mano — quindi e' anche
/// l'unica che si puo' mettere alla prova senza rete: qui dentro c'e' scritto
/// in che modi ci si ricorda una gara.
void main() {
  Challenge challenge({
    required String id,
    String title = 'Una challenge',
    String brief = 'Fai qualcosa.',
    String place = '',
    String author = '',
  }) {
    final now = DateTime.now();

    return Challenge(
      id: id,
      title: title,
      brief: brief,
      place: place,
      createdByUsername: author,
      prizeCents: 50000,
      scope: ChallengeScope.global,
      startsAt: now,
      endsAt: now.add(const Duration(hours: 4)),
    );
  }

  ProviderContainer containerWith({
    List<Challenge> live = const [],
    List<Challenge> ended = const [],
  }) {
    final container = ProviderContainer(
      overrides: [
        liveChallengesProvider.overrideWith((ref) => Stream.value(live)),
        endedChallengesProvider.overrideWith((ref) => Stream.value(ended)),
      ],
    );

    addTearDown(container.dispose);

    return container;
  }

  Future<List<Challenge>> search(
    ProviderContainer container,
    String query,
  ) async {
    // I due flussi vanno attesi: un provider che legge `valueOrNull` prima che
    // il primo valore sia arrivato non trova niente, e il test passerebbe per
    // il motivo sbagliato.
    await container.read(liveChallengesProvider.future);
    await container.read(endedChallengesProvider.future);

    container.read(searchQueryProvider.notifier).state = query;

    // **Solo le aperte.** A una gara chiusa non si puo' piu' partecipare, e chi
    // cerca una missione la cerca per entrarci: le finite si guardano nella
    // scheda dei vincitori, in ordine di ora e senza scrivere niente.
    return container.read(liveChallengeResultsProvider);
  }

  /// Cosa torna con un filtro acceso.
  Future<List<Challenge>> searchWith(
    ProviderContainer container,
    String query,
    SearchFilter filter,
  ) async {
    container.read(searchFilterProvider.notifier).state = filter;

    return search(container, query);
  }

  test('senza niente scritto non si cerca niente', () async {
    final container = containerWith(
      live: [challenge(id: 'a', title: 'Il cartello')],
    );

    expect(await search(container, '   '), isEmpty);
  });

  test('si trova una gara per un pezzo del titolo', () async {
    final container = containerWith(
      live: [
        challenge(
          id: 'a',
          title:
              'Il cartello piu'
              ' assurdo',
        ),
        challenge(id: 'b', title: 'Balla in mezzo alla strada'),
      ],
    );

    final found = await search(container, 'cartello');

    expect(found.map((c) => c.id), ['a']);
  });

  test('le maiuscole non cambiano niente', () async {
    final container = containerWith(
      live: [challenge(id: 'a', title: 'Il Cartello')],
    );

    expect((await search(container, 'CARTELLO')).map((c) => c.id), ['a']);
  });

  test(
    'si trova anche dalla consegna, dal posto e da chi l\'ha lanciata',
    () async {
      final container = containerWith(
        live: [
          challenge(
            id: 'consegna',
            brief: 'Chiedi un caffe\' a uno sconosciuto',
          ),
          challenge(id: 'posto', place: 'Milano'),
          challenge(id: 'autore', author: 'luca'),
        ],
      );

      expect((await search(container, 'sconosciuto')).map((c) => c.id), [
        'consegna',
      ]);
      expect((await search(container, 'milano')).map((c) => c.id), ['posto']);
      expect((await search(container, 'luca')).map((c) => c.id), ['autore']);
    },
  );

  test('le gare chiuse non si trovano piu', () async {
    // **A una gara chiusa non si puo' piu' partecipare**, e chi cerca una
    // missione la cerca per entrarci. Prima uscivano dopo le aperte, cioe'
    // occupavano mezzo elenco con roba su cui non c'era niente da fare; per
    // guardare com'e' andata c'e' la scheda dei vincitori, che le tiene tutte
    // in ordine di ora senza dover scrivere niente.
    final container = containerWith(
      live: [challenge(id: 'aperta', title: 'Cartello aperto')],
      ended: [challenge(id: 'chiusa', title: 'Cartello chiuso')],
    );

    expect((await search(container, 'cartello')).map((c) => c.id), ['aperta']);
  });

  test('quello che non corrisponde resta fuori', () async {
    final container = containerWith(
      live: [challenge(id: 'a', title: 'Il cartello')],
      ended: [challenge(id: 'b', title: 'Il cartello')],
    );

    expect(await search(container, 'bicicletta'), isEmpty);
  });

  test('il filtro sulle aperte lascia fuori quelle finite', () async {
    final container = containerWith(
      live: [challenge(id: 'aperta', title: 'Cartello aperto')],
      ended: [challenge(id: 'chiusa', title: 'Cartello chiuso')],
    );

    final found = await searchWith(
      container,
      'cartello',
      SearchFilter.liveChallenges,
    );

    expect(found.map((c) => c.id), ['aperta']);
  });

  test('cercando le persone non si trovano gare', () async {
    final container = containerWith(
      live: [challenge(id: 'aperta', title: 'Cartello aperto')],
      ended: [challenge(id: 'chiusa', title: 'Cartello chiuso')],
    );

    expect(
      await searchWith(container, 'cartello', SearchFilter.people),
      isEmpty,
    );
  });

  test('una lettera sola non basta piu', () async {
    // Il difetto: `h` sta dentro "challenge", dentro "che", dentro mezza lingua
    // italiana. Una ricerca che risponde tutto non ha risposto niente.
    final container = containerWith(
      live: [
        challenge(
          id: 'a',
          title:
              'Il cartello piu'
              ' assurdo',
        ),
        challenge(id: 'b', title: 'Balla in mezzo alla strada'),
      ],
    );

    expect(await search(container, 'h'), isEmpty);
  });

  test('si cerca dall inizio di una parola, non a meta', () async {
    final container = containerWith(
      live: [
        challenge(id: 'cartello', title: 'Fotografa un cartello'),
        challenge(id: 'altro', title: 'Balla in cucina'),
      ],
    );

    // Nessuno si ricorda una gara dalla sua prima parola: "quella del
    // cartello" si cerca cosi'.
    expect((await search(container, 'cart')).map((c) => c.id), ['cartello']);

    // Ma un pezzo in mezzo a una parola non e' una ricerca: e' un caso.
    expect(await search(container, 'rtel'), isEmpty);
  });
}
