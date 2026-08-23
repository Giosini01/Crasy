import 'package:crasy/core/routing/swipe_back_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tornare indietro col dito, e vederlo mentre succede.
///
/// La prova che conta e' la prima: **a meta' gesto la pagina deve essersi
/// spostata**. Prima non lo faceva — si trascinava su una schermata ferma e
/// solo al rilascio scivolava via — ed e' esattamente il difetto per cui il
/// gesto sembrava non esserci.
void main() {
  Future<void> open(WidgetTester tester) async {
    final navigator = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Center(child: Text('prima'))),
      ),
    );

    navigator.currentState!.push(
      SwipeBackPage<void>(
        child: const Scaffold(body: Center(child: Text('dentro'))),
      ).createRoute(navigator.currentContext!),
    );

    await tester.pumpAndSettle();

    expect(find.text('dentro'), findsOneWidget);
  }

  testWidgets('la pagina si muove mentre la trascini', (tester) async {
    await open(tester);

    final start = tester.getTopLeft(find.text('dentro')).dx;

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('dentro')),
    );
    await gesture.moveBy(const Offset(150, 0));
    await tester.pump();

    // Il dito e' ancora giu': la schermata deve essere gia' scivolata a destra.
    expect(
      tester.getTopLeft(find.text('dentro')).dx,
      greaterThan(start + 100),
      reason: 'la pagina deve seguire il dito, non aspettare il rilascio',
    );

    // E sotto si vede quella di prima, che rientra da sinistra.
    expect(find.text('prima'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('oltre meta schermo la pagina si chiude', (tester) async {
    await open(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('dentro')),
    );
    await gesture.moveBy(const Offset(600, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('dentro'), findsNothing);
    expect(find.text('prima'), findsOneWidget);
  });

  testWidgets('lasciando a meta strada la pagina torna dov era', (
    tester,
  ) async {
    await open(tester);

    final start = tester.getTopLeft(find.text('dentro')).dx;

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('dentro')),
    );
    // Poco piu' di un centinaio di punti su ottocento: il dito ha cambiato
    // idea, e la schermata deve rimettersi a posto da sola.
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('dentro'), findsOneWidget);
    expect(tester.getTopLeft(find.text('dentro')).dx, start);
  });
}
