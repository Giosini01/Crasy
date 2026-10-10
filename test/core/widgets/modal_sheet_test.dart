import 'package:crasy/core/widgets/modal_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Apre un foglio con dentro quello che gli si passa, su un telefono con la
/// tacca in cima.
Future<void> _apri(
  WidgetTester tester, {
  required Widget dentro,
  double strisciaInCima = 59,
}) async {
  // **La tacca si mette sulla finestra, non con un `MediaQuery` intorno.** Il
  // foglio si apre nel sipario piu' esterno, sopra tutto: un `MediaQuery`
  // messo dentro la schermata non lo vede nemmeno, e il controllo passerebbe
  // misurando uno schermo senza tacca — cioe' proprio il caso che non si
  // rompe.
  const punti = 3.0;
  tester.view.devicePixelRatio = punti;
  tester.view.physicalSize = const Size(390 * punti, 760 * punti);
  tester.view.padding = FakeViewPadding(
    top: strisciaInCima * punti,
    bottom: 34 * punti,
  );
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ModalSheet.show<void>(
              context: context,
              builder: (_) => ModalSheet(
                title: 'NOTIFICHE',
                confirmLabel: 'Chiudi',
                onConfirm: () {},
                child: dentro,
              ),
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
}

/// Tanta roba: è il foglio delle notifiche con i suoi otto interruttori.
Widget get _troppaRoba => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    for (var i = 0; i < 20; i++) SizedBox(height: 70, child: Text('riga $i')),
  ],
);

void main() {
  group('il foglio con dentro troppa roba', () {
    testWidgets('non finisce sotto l\'orologio', (tester) async {
      // **Il difetto per cui questo test esiste.** Senza un tetto, un foglio
      // pieno cresce fino al bordo dello schermo e l'intestazione con i due
      // tasti ci finisce sotto: su iPhone dietro l'orologio e la batteria. Si
      // vedono a metà e non si toccano, perché quella striscia la prende il
      // sistema — e il foglio diventa una stanza senza porta.
      await _apri(tester, dentro: _troppaRoba);

      final intestazione = tester.getRect(find.text('NOTIFICHE'));

      expect(
        intestazione.top,
        greaterThanOrEqualTo(59),
        reason: 'il titolo deve stare sotto la striscia del sistema',
      );
    });

    testWidgets('i due tasti si possono toccare', (tester) async {
      await _apri(tester, dentro: _troppaRoba);

      for (final tasto in ['Annulla', 'Chiudi']) {
        final dove = tester.getRect(find.text(tasto));

        expect(dove.top, greaterThanOrEqualTo(59), reason: tasto);
      }
    });

    testWidgets('quello che non ci sta si scorre', (tester) async {
      await _apri(tester, dentro: _troppaRoba);

      // L'ultima riga esiste ma sta sotto il bordo dello schermo: in un
      // riquadro scorrevole i figli si costruiscono tutti, quindi cercarla non
      // dice niente — bisogna guardare **dove** sta.
      final schermo =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      expect(
        tester.getRect(find.text('riga 19')).top,
        greaterThan(schermo),
        reason: 'prima di scorrere deve stare fuori',
      );

      await tester.drag(find.text('riga 2'), const Offset(0, -900));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.text('riga 19')).bottom,
        lessThanOrEqualTo(schermo),
        reason: 'scorrendo deve entrare',
      );
    });

    testWidgets('scorrendo, l\'intestazione resta ferma', (tester) async {
      // È la metà che conta: se l'intestazione scorresse via con il contenuto,
      // per chiudere bisognerebbe prima tornare in cima.
      await _apri(tester, dentro: _troppaRoba);

      final prima = tester.getRect(find.text('NOTIFICHE'));

      await tester.drag(find.text('riga 2'), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(tester.getRect(find.text('NOTIFICHE')), prima);
    });
  });

  testWidgets('un foglio corto resta corto', (tester) async {
    // Il tetto è un massimo, non una misura: i fogli piccoli non devono
    // diventare alti per colpa di questa riparazione.
    await _apri(
      tester,
      dentro: const SizedBox(height: 80, child: Text('due righe')),
    );

    final foglio = tester.getRect(find.text('NOTIFICHE'));

    expect(foglio.top, greaterThan(400), reason: 'deve restare in basso');
  });
}
