import 'package:crasy/core/theme/app_theme.dart';
import 'package:crasy/features/challenges/domain/entities/proposta_missione.dart';
import 'package:crasy/features/challenges/presentation/pages/missione_approvata_page.dart';
import 'package:crasy/features/challenges/presentation/widgets/esito_missione.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _pagina(PropostaMissione proposta) {
  return ProviderScope(
    overrides: [
      propostaMissioneProvider('p1').overrideWith((ref) async => proposta),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const MissioneApprovataPage(propostaId: 'p1'),
    ),
  );
}

PropostaMissione _proposta(
  String stato, {
  String motivo = '',
  int premio = 500,
}) {
  return PropostaMissione(
    id: 'p1',
    stato: stato,
    title: 'Foto fuori al balcone',
    brief: 'Una foto, adesso.',
    prizeCents: premio,
    motivo: motivo,
  );
}

/// **Quello che legge chi aspetta una risposta.**
void main() {
  testWidgets('approvata: si vede cosa si paga, e il tasto c\'e\'', (
    tester,
  ) async {
    await tester.pumpWidget(_pagina(_proposta('approvata')));
    await tester.pumpAndSettle();

    expect(find.text('APPROVATA'), findsOneWidget);
    expect(find.text('FOTO FUORI AL BALCONE'), findsOneWidget);
    expect(find.text('Una foto, adesso.'), findsOneWidget);
    // Nelle prove i pagamenti sono spenti: `paymentsEnabled` e' falso.
    expect(find.text('LANCIA LA MISSIONE'), findsOneWidget);
  });

  testWidgets('rifiutata: dice il motivo, e chi ha deciso', (tester) async {
    await tester.pumpWidget(
      _pagina(_proposta('rifiutata', motivo: 'chiede di guidare col telefono')),
    );
    await tester.pumpAndSettle();

    expect(find.text('chiede di guidare col telefono'), findsOneWidget);
    expect(find.text('L’ha decisa una persona del team.'), findsOneWidget);
    expect(find.text('Non hai pagato niente.'), findsOneWidget);
    expect(find.textContaining('info@crasyapp.com'), findsOneWidget);
    expect(find.text('LANCIA LA MISSIONE'), findsNothing);
  });

  testWidgets('fermata alle parole: non dice che l\'ha decisa una persona', (
    tester,
  ) async {
    await tester.pumpWidget(_pagina(_proposta('bloccata')));
    await tester.pumpAndSettle();

    expect(find.text('L’ha decisa una persona del team.'), findsNothing);
    expect(find.text('Non hai pagato niente.'), findsOneWidget);
  });

  testWidgets('ancora in coda: si aspetta', (tester) async {
    await tester.pumpWidget(_pagina(_proposta('daControllare')));
    await tester.pumpAndSettle();

    expect(find.byType(AvvisoInControllo), findsOneWidget);
    expect(
      find.text('Ti avvisiamo appena c’è una risposta.'),
      findsOneWidget,
    );
    expect(find.text('LANCIA LA MISSIONE'), findsNothing);
  });

  testWidgets('il foglio di una missione in controllo si chiude', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => mostraMissioneInControllo(context),
              child: const Text('apri'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    expect(find.text('Una persona del team la guarda.'), findsOneWidget);
    expect(find.text('Ti avvisiamo appena c’è una risposta.'), findsOneWidget);

    await tester.tap(find.text('HO CAPITO'));
    await tester.pumpAndSettle();

    expect(find.text('Una persona del team la guarda.'), findsNothing);
  });

  testWidgets('il foglio di una missione rifiutata dice il motivo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => mostraMissioneRifiutata(
                context,
                titolo: 'Foto in autostrada',
                motivo: 'chiede di guidare col telefono',
              ),
              child: const Text('apri'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    expect(find.text('FOTO IN AUTOSTRADA'), findsOneWidget);
    expect(find.text('chiede di guidare col telefono'), findsOneWidget);
    expect(find.textContaining('info@crasyapp.com'), findsOneWidget);
  });

  testWidgets('senza un motivo non si inventa niente', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AvvisoRifiutata(titolo: '', motivo: ''),
        ),
      ),
    );

    expect(find.text('Non rispetta le regole delle missioni.'), findsOneWidget);
  });
}
