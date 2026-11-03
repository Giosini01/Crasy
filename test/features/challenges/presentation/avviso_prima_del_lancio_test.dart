import 'package:crasy/core/theme/app_theme.dart';
import 'package:crasy/features/challenges/presentation/widgets/esito_missione.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _mostra(WidgetTester tester, Widget avviso) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: avviso),
    ),
  );
}

/// **La domanda a cui risponde: quando mi prendono i soldi?**
void main() {
  testWidgets('con un premio dice che i soldi si prendono solo dopo il controllo', (
    tester,
  ) async {
    await _mostra(tester, const AvvisoPrimaDelLancio(conPremio: true));

    expect(
      find.textContaining('i soldi li prendiamo solo in quel momento'),
      findsOneWidget,
    );
    expect(find.textContaining('non paghi niente'), findsOneWidget);
    expect(find.textContaining('non paghi mai'), findsOneWidget);
  });

  testWidgets('gratis non parla di soldi', (tester) async {
    await _mostra(tester, const AvvisoPrimaDelLancio(conPremio: false));

    expect(find.textContaining('la controlliamo'), findsOneWidget);
    expect(find.textContaining('paghi'), findsNothing);
    expect(find.textContaining('soldi'), findsNothing);
  });

  testWidgets('quando passa il controllo, dice che adesso si paga', (
    tester,
  ) async {
    await _mostra(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => avvisaApprovata(context),
          child: const Text('lancia'),
        ),
      ),
    );

    await tester.tap(find.text('lancia'));
    await tester.pump();

    expect(
      find.text('Missione approvata: ora paghi il premio e parte.'),
      findsOneWidget,
    );
  });
}
