import 'package:crasy/core/theme/app_theme.dart';
import 'package:crasy/features/profile/presentation/widgets/streak_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Il distintivo della serie, e quando non c'e'.**
///
/// La regola che conta e' quella che nasconde: "1 giorno di fila" non e' una
/// serie, e' aver giocato oggi — cioe' la cosa normale. Addosso a chiunque, il
/// distintivo smette di dire qualcosa proprio nel punto in cui dovrebbe
/// cominciare a valere.
void main() {
  Future<void> mostra(WidgetTester tester, int giorni) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: Center(child: StreakBadge(giorni: giorni))),
      ),
    );
  }

  testWidgets('a due giorni compare, e dice quanti sono', (tester) async {
    await mostra(tester, 2);

    expect(find.text('2 GIORNI DI FILA'), findsOneWidget);
  });

  testWidgets('a un giorno non compare niente', (tester) async {
    await mostra(tester, 1);

    expect(find.byIcon(Icons.local_fire_department_rounded), findsNothing);
    expect(find.textContaining('FILA'), findsNothing);
  });

  testWidgets('a zero giorni non compare niente', (tester) async {
    await mostra(tester, 0);

    expect(find.byIcon(Icons.local_fire_department_rounded), findsNothing);
  });

  testWidgets('la versione stretta mostra solo il numero', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(child: StreakBadge(giorni: 12, compatto: true)),
        ),
      ),
    );

    expect(find.text('12'), findsOneWidget);
    expect(find.textContaining('FILA'), findsNothing);
  });
}
