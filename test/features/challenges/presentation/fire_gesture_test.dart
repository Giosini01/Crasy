import 'dart:typed_data';

import 'package:crasy/core/utils/provider_cache.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/presentation/controllers/vote_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_repository.dart';

/// I due gesti della fiamma, provati dove si vedono: sul numero a schermo.
///
/// Le prove qui sotto sono la regola scritta a parole:
///
/// - doppio tocco su una foto non votata: la fiamma si accende e il numero fa
///   **+1**;
/// - doppio tocco di nuovo: **non succede niente**;
/// - tocco sulla fiamma accesa: **-1**, e si spegne.
///
/// Il numero e' quello vero che arriva dal repository, non uno finto tenuto dal
/// test: e' l'unico modo di accorgersi se la correzione locale si somma a un
/// contatore che il voto ce l'ha gia' dentro — cioe' il difetto per cui un mi
/// piace ne contava due.
final _entriesProvider = StreamProvider.family<List<ChallengeEntry>, String>(
  (ref, challengeId) =>
      ref.watch(sampleChallengeRepositoryProvider).watchEntries(challengeId),
);

class _Harness extends ConsumerWidget {
  const _Harness({required this.challengeId, required this.entryId});

  final String challengeId;
  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries =
        ref.watch(_entriesProvider(challengeId)).valueOrNull ??
        const <ChallengeEntry>[];
    final found = entries.where((entry) => entry.id == entryId);

    if (found.isEmpty) {
      return const Text('niente', textDirection: TextDirection.ltr);
    }

    final entry = found.first;
    final voted = ref.watch(entryVotedProvider(entry.voteKey));
    // Come nell'app: a gara finita i due gesti non ci sono proprio. `VoteButton`
    // disegna il numero senza il tocco sopra, e `FireTap` non ascolta il doppio
    // tocco.
    final live = ref.watch(challengeIsLiveProvider(entry.challengeId));

    return Column(
      children: [
        // **Il conto vero, non quello che si vede.**
        //
        // A gara aperta le fiamme degli altri sono nascoste — `visibleVotes`
        // torna nulla e a schermo c'e' un trattino — ma qui si sta provando la
        // *meccanica* del voto, non cosa si mostra. Il numero vero e' quello
        // che il gesto deve muovere; che poi sia coperto lo prova la riga
        // sotto.
        Text(
          '${ref.watch(voteIntentProvider(entry.voteKey))?.votes ?? entry.votes}',
          key: const Key('conto'),
          textDirection: TextDirection.ltr,
        ),
        Text(
          votesLabel(visibleVotes(ref, entry)),
          key: const Key('conto-visibile'),
          textDirection: TextDirection.ltr,
        ),
        Text(
          voted ? 'accesa' : 'spenta',
          key: const Key('stato'),
          textDirection: TextDirection.ltr,
        ),
        // I due gesti veri dell'app: il doppio tocco chiede sempre di
        // accendere, la fiamma sotto ribalta quello che c'e'.
        TextButton(
          key: const Key('doppio-tocco'),
          onPressed: live
              ? () => giveFire(context, ref, entry, voted: true)
              : null,
          child: const Text('doppio'),
        ),
        TextButton(
          key: const Key('fiamma'),
          onPressed: live
              ? () => giveFire(context, ref, entry, voted: !voted)
              : null,
          child: const Text('fiamma'),
        ),
      ],
    );
  }
}

void main() {
  late FakeAuthRepository authRepository;

  setUp(() {
    authRepository = FakeAuthRepository();
    addTearDown(authRepository.dispose);
  });

  /// Cosa c'e' scritto a schermo adesso: il numero e lo stato della fiamma.
  (String conto, String stato) Function() readScreen(WidgetTester tester) {
    return () => (
      (tester.widget(find.byKey(const Key('conto'))) as Text).data!,
      (tester.widget(find.byKey(const Key('stato'))) as Text).data!,
    );
  }

  /// Quello che si vede davvero sotto la foto: un numero, o il trattino.
  String Function() readVisible(WidgetTester tester) {
    return () =>
        (tester.widget(find.byKey(const Key('conto-visibile'))) as Text).data!;
  }

  Future<void> pumpEntry(WidgetTester tester, {bool ended = false}) async {
    late String challengeId;
    late String entryId;

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        // Niente attesa prima di spegnere gli ascolti: qui si verifica proprio
        // che si spengano, e un timer da un minuto resterebbe appeso.
        providerCacheProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);

    final samples = container.read(sampleChallengeRepositoryProvider);
    final now = DateTime.now();
    final challenge = await samples.createChallenge(
      Challenge(
        id: '',
        title: 'Prova',
        brief: 'Fai qualcosa di assurdo.',
        prizeCents: 50000,
        scope: ChallengeScope.global,
        startsAt: now.subtract(const Duration(hours: 2)),
        endsAt: ended
            ? now.subtract(const Duration(minutes: 1))
            : now.add(const Duration(days: 1)),
      ),
    );

    final entry = await samples.submitEntry(
      challengeId: challenge.id,
      userId: 'altra',
      authorName: 'altra',
      bytes: Uint8List.fromList(const [1, 2, 3]),
    );

    challengeId = challenge.id;
    entryId = entry.id;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: _Harness(challengeId: challengeId, entryId: entryId),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('il doppio tocco accende la fiamma e conta uno', (tester) async {
    await pumpEntry(tester);
    final read = readScreen(tester);

    expect(read(), ('0', 'spenta'));

    await tester.tap(find.byKey(const Key('doppio-tocco')));
    await tester.pumpAndSettle();

    expect(read(), ('1', 'accesa'));
  });

  testWidgets('il doppio tocco ripetuto non fa niente', (tester) async {
    await pumpEntry(tester);
    final read = readScreen(tester);

    await tester.tap(find.byKey(const Key('doppio-tocco')));
    await tester.pumpAndSettle();

    // **Il caso per cui e' stato rifatto tutto.** Qui prima si vedeva due: la
    // correzione locale si sommava a un contatore che il voto ce l'aveva gia'.
    await tester.tap(find.byKey(const Key('doppio-tocco')));
    await tester.pumpAndSettle();

    expect(read(), ('1', 'accesa'));
  });

  testWidgets('la fiamma accesa si spegne e toglie uno', (tester) async {
    await pumpEntry(tester);
    final read = readScreen(tester);

    await tester.tap(find.byKey(const Key('doppio-tocco')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fiamma')));
    await tester.pumpAndSettle();

    expect(read(), ('0', 'spenta'));
  });

  testWidgets('accendi e spegni dieci volte: si torna sempre a zero', (
    tester,
  ) async {
    await pumpEntry(tester);
    final read = readScreen(tester);

    for (var round = 0; round < 10; round++) {
      await tester.tap(find.byKey(const Key('doppio-tocco')));
      await tester.pumpAndSettle();

      expect(read(), ('1', 'accesa'), reason: 'giro $round');

      await tester.tap(find.byKey(const Key('fiamma')));
      await tester.pumpAndSettle();

      expect(read(), ('0', 'spenta'), reason: 'giro $round');
    }
  });

  testWidgets('la fiamma spenta si accende toccandola', (tester) async {
    await pumpEntry(tester);
    final read = readScreen(tester);

    await tester.tap(find.byKey(const Key('fiamma')));
    await tester.pumpAndSettle();

    expect(read(), ('1', 'accesa'));
  });
  testWidgets('a gara finita la fiamma smette di essere un comando', (
    tester,
  ) async {
    await pumpEntry(tester, ended: true);
    final read = readScreen(tester);

    // **E' la riga che protegge i soldi.** La classifica allo scadere del
    // tempo e' quella che ha deciso chi incassa: una fiamma arrivata dopo la
    // sposterebbe da una persona a un'altra.
    await tester.tap(find.byKey(const Key('doppio-tocco')));
    await tester.pumpAndSettle();

    expect(read(), ('0', 'spenta'));

    await tester.tap(find.byKey(const Key('fiamma')));
    await tester.pumpAndSettle();

    expect(read(), ('0', 'spenta'));
  });

  testWidgets('a gara aperta le fiamme degli altri non si vedono', (
    tester,
  ) async {
    await pumpEntry(tester);
    final visibile = readVisible(tester);

    // **E' l'altra meta' del gioco.** Con i numeri in chiaro si vota chi sta
    // gia' vincendo, chi e' indietro molla a meta' gara, e chi vuole comprare
    // dei voti sa esattamente quanti gliene mancano.
    expect(visibile(), '–');

    await tester.tap(find.byKey(const Key('doppio-tocco')));
    await tester.pumpAndSettle();

    // La fiamma e' partita — il conto vero lo dice — ma il numero resta
    // coperto: chi vota non deve poter misurare l'effetto del proprio voto.
    expect(readScreen(tester)(), ('1', 'accesa'));
    expect(visibile(), '–');
  });

  testWidgets('a gara finita si rivela tutto', (tester) async {
    await pumpEntry(tester, ended: true);

    expect(readVisible(tester)(), '0');
  });
}
