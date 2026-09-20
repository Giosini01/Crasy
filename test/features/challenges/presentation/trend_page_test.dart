import 'package:crasy/core/theme/app_theme.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/presentation/pages/winners_page.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// **La classifica provata da fuori, come la vede chi la guarda.**
///
/// Che la somma sia giusta lo dicono gia' le prove sul calcolo. Qui si prova
/// l'altra meta', che e' quella che si rompe davvero: fra il conto e lo schermo
/// ci sono tre schede da cambiare, un podio che riordina i primi tre per
/// metterli secondo‑primo‑terzo, un elenco che si ferma a cinquanta e una riga
/// che deve accendersi solo per chi sta guardando. Sono tutte cose che possono
/// smettere di funzionare senza che nessun calcolo sbagli — e nessuna di loro
/// darebbe un errore: darebbe una classifica che dice la cosa sbagliata con
/// l'aria di essere a posto.
void main() {
  Challenge chiusa({
    required String id,
    required int euro,
    required String lancia,
    String? vince,
  }) {
    return Challenge(
      id: id,
      title: id,
      brief: 'Fai qualcosa.',
      prizeCents: euro * 100,
      scope: ChallengeScope.global,
      createdByUserId: 'id-$lancia',
      createdByUsername: lancia,
      winnerUserId: vince == null ? '' : 'id-$vince',
      winnerUsername: vince ?? '',
      winnerEntryId: vince == null ? null : 'foto',
      startsAt: DateTime(2026),
      endsAt: DateTime(2026, 1, 2),
    );
  }

  /// Dieci vittorie da un euro contro una da cento: il caso su cui tutta la
  /// classifica si regge.
  final chiuse = <Challenge>[
    for (var i = 0; i < 10; i++)
      chiusa(id: 'piccola$i', euro: 1, lancia: 'mecenate', vince: 'assiduo'),
    chiusa(id: 'grossa', euro: 100, lancia: 'mecenate', vince: 'unaVolta'),
    chiusa(id: 'media', euro: 30, lancia: 'spilorcio', vince: 'terzo'),
    chiusa(id: 'piccina', euro: 5, lancia: 'spilorcio', vince: 'quarto'),
  ];

  Future<void> apri(WidgetTester tester, {String? io}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          endedChallengesProvider.overrideWith((ref) => Stream.value(chiuse)),
          currentUserIdProvider.overrideWithValue(io),
          // Le facce non c'entrano con la classifica, e senza database non
          // arriverebbero comunque: restano le iniziali.
          publicProfileProvider.overrideWith((ref, id) => Stream.value(null)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const WinnersPage()),
      ),
    );
    await tester.pump();
  }

  /// Chi sta sul podio, **da sinistra a destra**.
  ///
  /// Si guarda dove sono finiti sullo schermo e non in che ordine stanno
  /// scritti nel codice: l'ordine del podio e' una cosa che si vede con gli
  /// occhi, e una prova che leggesse l'albero dei widget direbbe di si' anche
  /// a un podio disegnato al contrario.
  List<String> podio(WidgetTester tester) {
    final nomi = find.textContaining('@');
    final sopra = [
      for (var i = 0; i < nomi.evaluate().length; i++)
        (
          testo: tester.widget<Text>(nomi.at(i)).data!,
          punto: tester.getCenter(nomi.at(i)),
        ),
    ]..sort((a, b) => a.punto.dy.compareTo(b.punto.dy));

    // I tre piu' in alto sono il podio; tutto il resto e' l'elenco sotto.
    final tre = sopra.take(3).toList()
      ..sort((a, b) => a.punto.dx.compareTo(b.punto.dx));

    return [for (final riga in tre) riga.testo];
  }

  testWidgets('comandano i soldi, non le presenze', (tester) async {
    await apri(tester);

    // **E' la prova che vale piu' di tutte.** Chi ha vinto dieci gare da un
    // euro ha vinto piu' volte di chiunque, e deve stare sotto a chi ne ha
    // vinta una da cento: se un giorno qualcuno cambiasse l'ordinamento per
    // "quante gare", questa riga e' l'unica cosa che se ne accorgerebbe.
    expect(find.text('@unaVolta'), findsOneWidget);
    expect(find.text('@assiduo'), findsOneWidget);

    // L'ordine sul podio e' secondo, primo, terzo: e' dove l'occhio si aspetta
    // di trovarli, e in fila uno-due-tre il primo sembrerebbe solo quello a
    // sinistra.
    // Secondo, primo, terzo. Il primo sta in mezzo, e il secondo e' chi ha
    // preso la seconda cifra piu' alta — non chi ha gareggiato di piu': con
    // dieci vittorie da un euro, `assiduo` finisce terzo.
    expect(podio(tester), ['@terzo', '@unaVolta', '@assiduo']);
  });

  testWidgets('dal quarto in giu\' si passa all\'elenco', (tester) async {
    await apri(tester);

    // Il quarto non e' un gradino mancato: comincia un'altra cosa, e la
    // scritta serve a dirlo.
    expect(find.text('DAL QUARTO IN GIÙ'), findsOneWidget);
    expect(find.text('@quarto'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('la propria riga si riconosce', (tester) async {
    await apri(tester, io: 'id-quarto');

    // Senza un segno, ritrovarsi vuol dire leggere cinquanta nomi.
    expect(find.text('@quarto · tu'), findsOneWidget);
    expect(find.text('@assiduo'), findsOneWidget);
  });

  testWidgets('chi non guarda nessuno non ha righe accese', (tester) async {
    await apri(tester);

    expect(find.textContaining('· tu'), findsNothing);
  });

  testWidgets('chi fa giocare e\' un\'altra classifica', (tester) async {
    await apri(tester);

    await tester.tap(find.text('CHI FA GIOCARE'));
    await tester.pumpAndSettle();

    // Cambia proprio la domanda: qui contano i soldi messi in palio, quindi
    // compaiono i padroni delle gare e spariscono i vincitori.
    expect(find.text('@mecenate'), findsOneWidget);
    expect(find.text('@spilorcio'), findsOneWidget);
    expect(find.text('@unaVolta'), findsNothing);
  });

  testWidgets('senza gare chiuse non c\'e\' un podio vuoto', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          endedChallengesProvider.overrideWith(
            (ref) => Stream.value(const <Challenge>[]),
          ),
          currentUserIdProvider.overrideWithValue(null),
          publicProfileProvider.overrideWith((ref, id) => Stream.value(null)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const WinnersPage()),
      ),
    );
    await tester.pump();

    // Tre gradini vuoti si leggono come un errore di caricamento. Meglio dire
    // che non e' ancora successo niente.
    expect(
      find.textContaining('il podio si riempie da solo'),
      findsOneWidget,
    );
    expect(find.textContaining('@'), findsNothing);
  });
}
