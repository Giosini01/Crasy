import 'package:crasy/core/theme/app_theme.dart';
import 'package:crasy/core/widgets/opening_curtain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Il sipario dell'apertura: la fiamma che si accende, e il suo congedo.
///
/// **Il suono qui non parte mai**, e non e' un dettaglio della prova: in una
/// prova non c'e' nessun apparecchio che suoni, e il tentativo finirebbe in un
/// errore ingoiato — cioe' in rumore nei registri che copre quello vero. Lo
/// spegne `openingSoundProvider`, che esiste proprio per questo.
void main() {
  Widget conIlSipario() => ProviderScope(
    overrides: [
      // Il sipario acceso: e' quello che si vuole guardare.
      openingCurtainProvider.overrideWithValue(true),
      openingSoundProvider.overrideWithValue(false),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const OpeningCurtain(child: Scaffold(body: Text('la home'))),
    ),
  );

  /// Quanto e' grande adesso la fiamma.
  double quantoEGrande(WidgetTester tester) {
    final trasformazione = tester.widget<Transform>(
      find.byKey(OpeningCurtain.chiaveDellaFiamma),
    );

    // **L'asse x, non `getMaxScaleOnAxis`.** Quella prende il massimo fra i
    // tre assi, e l'asse z qui vale sempre uno: per qualunque fiamma piu'
    // piccola del normale rispondeva 1,0 — cioe' la prova misurava una
    // costante e sarebbe passata anche con l'animazione spenta.
    return trasformazione.transform.storage[0];
  }

  testWidgets('la fiamma si accende invece di comparire', (tester) async {
    await tester.pumpWidget(conIlSipario());
    await tester.pump();

    final appena = quantoEGrande(tester);

    // Mezzo secondo dopo, l'accensione e' finita.
    await tester.pump(const Duration(milliseconds: 550));
    final accesa = quantoEGrande(tester);

    // **Questa e' la prova che conta.** Se qualcuno togliesse l'animazione, la
    // fiamma resterebbe della stessa misura dal primo all'ultimo istante e
    // nient'altro nel codice se ne accorgerebbe.
    expect(
      accesa,
      greaterThan(appena * 1.5),
      reason: 'la fiamma deve crescere, non comparire gia\' grande',
    );

    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('e poi respira, senza mai stare ferma', (tester) async {
    await tester.pumpWidget(conIlSipario());
    // Oltre l'accensione: da qui in poi c'e' solo l'ondeggio.
    await tester.pump(const Duration(milliseconds: 700));

    final misure = <double>[];

    for (var i = 0; i < 6; i += 1) {
      await tester.pump(const Duration(milliseconds: 60));
      misure.add(quantoEGrande(tester));
    }

    // Nessuna delle sei misure uguale alla prima: una fiamma ferma e' un'icona.
    expect(
      misure.toSet().length,
      greaterThan(1),
      reason: 'dopo l\'accensione la fiamma deve continuare a muoversi',
    );

    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('se ne va da sola e lascia l app sotto', (tester) async {
    await tester.pumpWidget(conIlSipario());
    await tester.pump();

    // L'app sotto c'e' gia' dal primo istante: il sipario **copre** il
    // caricamento invece di aggiungersi a esso.
    expect(find.text('la home'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 4));

    final velo = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));

    expect(velo.opacity, 0);
    expect(find.text('la home'), findsOneWidget);
  });

  testWidgets('spento, non c e proprio', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [openingCurtainProvider.overrideWithValue(false)],
        child: const MaterialApp(
          home: OpeningCurtain(child: Scaffold(body: Text('la home'))),
        ),
      ),
    );

    expect(find.byIcon(Icons.local_fire_department_rounded), findsNothing);
    expect(find.text('la home'), findsOneWidget);
  });
}
