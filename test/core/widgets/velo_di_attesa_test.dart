import 'package:crasy/core/widgets/flame_waiting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('il velo di attesa', () {
    testWidgets('copre la barra in cima, non solo il corpo', (tester) async {
      // Il velo stava dentro lo `Stack` del corpo, e la freccia indietro in
      // cima restava toccabile durante tutto il caricamento.
      var indietro = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: VeloDiAttesa(
            acceso: true,
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => indietro++,
                ),
              ),
              body: const SizedBox.expand(),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.arrow_back), warnIfMissed: false);
      await tester.pump();

      expect(indietro, 0);
    });

    testWidgets('spento non si vede e non ferma niente', (tester) async {
      var tocchi = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: VeloDiAttesa(
            acceso: false,
            child: Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => tocchi++,
                  child: const Text('partecipa'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FlameWaiting), findsNothing);

      await tester.tap(find.text('partecipa'));
      await tester.pump();

      expect(tocchi, 1);
    });

    testWidgets('acceso toglie i tasti da sotto le dita', (tester) async {
      var tocchi = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: VeloDiAttesa(
            acceso: true,
            child: Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => tocchi++,
                  child: const Text('partecipa'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FlameWaiting), findsOneWidget);

      await tester.tap(find.text('partecipa'), warnIfMissed: false);
      await tester.pump();

      expect(tocchi, 0);
    });

    testWidgets('non copre la schermata che si apre sopra', (tester) async {
      // **Il difetto per cui questo test esiste.** Il velo e' stato per
      // un'ora nel sipario piu' esterno dell'app, e da li' copriva anche le
      // schermate aperte sopra. Chi scegliendo una foto arrivava all'editor se
      // lo trovava coperto dalla fiamma che girava — la pagina sotto resta
      // occupata finche' l'editor non si chiude — e la foto non si poteva piu'
      // inquadrare: un caricamento che non finisce mai, su una cosa che non
      // stava caricando niente.
      var tocchi = 0;

      await tester.pumpWidget(
        const MaterialApp(
          home: VeloDiAttesa(acceso: true, child: Scaffold(body: SizedBox())),
        ),
      );

      final navigatore = tester.state<NavigatorState>(find.byType(Navigator));

      navigatore.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => tocchi++,
                child: const Text('inquadra'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('inquadra'));
      await tester.pump();

      expect(tocchi, 1);
    });
  });
}
