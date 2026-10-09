import 'dart:convert';

import 'package:crasy/features/challenges/presentation/widgets/photo_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un PNG vero di otto pixel per otto: serve solo a far decodificare qualcosa
/// all'editor, che senza le proporzioni vere della foto non disegna niente.
final Uint8List _unaFoto = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEUlEQVR4nGNoUFDAihiGlgQA2dYwAYiM7QwAAAAASUVORK5CYII=',
);

Future<void> _apri(WidgetTester tester, {bool inquadrabile = true}) async {
  // La misura di un telefono, non quella del banco di prova: l'editor e' una
  // schermata verticale, e provarla su un rettangolo orizzontale vuol dire
  // provare una cosa che nessuno vede.
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: PhotoEditor(
        bytes: _unaFoto,
        aspectRatio: 4 / 5,
        inquadrabile: inquadrabile,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

/// Batte la frase e la mette sulla foto.
Future<void> _scrivi(WidgetTester tester, String frase) async {
  await tester.tap(find.text('SCRIVI SULLA FOTO'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), frase);
  await tester.tap(find.text('Metti'));
  await tester.pumpAndSettle();
}

void main() {
  group('la frase sulla foto', () {
    testWidgets('mettere una frase non fa cadere l\'app', (tester) async {
      // **E' il controllo che vale piu' di tutti gli altri qui.** Ogni frase
      // era un `LayoutBuilder` che restituiva un `Positioned`, e un
      // `Positioned` deve stare attaccato allo `Stack`: l'app cadeva
      // nell'istante in cui si toccava "Metti", cioe' sempre.
      await _apri(tester);

      await tester.tap(find.text('AVANTI'));
      await tester.pumpAndSettle();

      await _scrivi(tester, 'ce l\'ho fatta');

      expect(tester.takeException(), isNull);
      expect(find.text('ce l\'ho fatta'), findsOneWidget);
    });

    testWidgets('nasce al centro della foto', (tester) async {
      await _apri(tester, inquadrabile: false);

      await _scrivi(tester, 'al centro');

      final foto = tester.getRect(find.byType(RepaintBoundary).last);
      final frase = tester.getRect(find.text('al centro'));

      expect(frase.center.dx, moreOrLessEquals(foto.center.dx, epsilon: 1));
      expect(frase.center.dy, moreOrLessEquals(foto.center.dy, epsilon: 1));
    });

    testWidgets('si trascina dove si vuole', (tester) async {
      await _apri(tester, inquadrabile: false);
      await _scrivi(tester, 'spostami');

      final partenza = tester.getRect(find.text('spostami')).center;

      await tester.drag(find.text('spostami'), const Offset(0, -60));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.text('spostami')).center.dy,
        lessThan(partenza.dy),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('si toglie quella messa per ultima', (tester) async {
      await _apri(tester, inquadrabile: false);

      // Senza frasi il tasto non c'e': non si offre un comando che non ha
      // niente da annullare.
      expect(find.text('TOGLI'), findsNothing);

      await _scrivi(tester, 'questa va via');
      expect(find.text('TOGLI'), findsOneWidget);

      await tester.tap(find.text('TOGLI'));
      await tester.pumpAndSettle();

      expect(find.text('questa va via'), findsNothing);
      expect(find.text('TOGLI'), findsNothing);
    });
  });

  group('la frase resta dove si vede sempre', () {
    test("l'area si calcola dai ritagli veri, non a mano", () {
      // Il riquadro e' quattro quinti; le griglie mostrano la foto quadrata e
      // le figurine a 0,72. Sopra e sotto comanda il quadrato, ai lati la
      // figurina.
      final area = areaSempreVisibile(4 / 5);

      expect(area.top, moreOrLessEquals(0.1, epsilon: 0.001));
      expect(area.bottom, moreOrLessEquals(0.9, epsilon: 0.001));
      expect(area.left, moreOrLessEquals(0.05, epsilon: 0.001));
      expect(area.right, moreOrLessEquals(0.95, epsilon: 0.001));
    });

    test('un riquadro gia quadrato non perde niente sopra e sotto', () {
      final area = areaSempreVisibile(1);

      expect(area.top, 0);
      expect(area.bottom, 1);
    });

    testWidgets('trascinandola in cima non esce dal quadrato', (tester) async {
      // **E' il difetto per cui questo esiste.** La frase si scriveva in cima,
      // si vedeva a schermo intero, e nella griglia delle partecipazioni —
      // quadrata — non c'era piu'.
      await _apri(tester, inquadrabile: false);
      await _scrivi(tester, 'ROMPIPALLE');

      final foto = tester.getRect(find.byType(RepaintBoundary).last);

      // Una trascinata ben oltre il bordo di sopra.
      await tester.drag(find.text('ROMPIPALLE'), const Offset(0, -2000));
      await tester.pumpAndSettle();

      final frase = tester.getRect(find.text('ROMPIPALLE'));
      final limite = foto.top + foto.height * 0.1;

      expect(
        frase.top,
        greaterThanOrEqualTo(limite - 1),
        reason: 'la frase intera deve restare sotto il taglio del quadrato',
      );
    });

    testWidgets('e nemmeno in fondo', (tester) async {
      await _apri(tester, inquadrabile: false);
      await _scrivi(tester, 'ROMPIPALLE');

      final foto = tester.getRect(find.byType(RepaintBoundary).last);

      await tester.drag(find.text('ROMPIPALLE'), const Offset(0, 2000));
      await tester.pumpAndSettle();

      final frase = tester.getRect(find.text('ROMPIPALLE'));

      expect(frase.bottom, lessThanOrEqualTo(foto.top + foto.height * 0.9 + 1));
    });
  });

  group('i due passi', () {
    testWidgets('dalla galleria si inquadra prima e si scrive dopo', (
      tester,
    ) async {
      await _apri(tester);

      // Al primo passo non si scrive: le dita sono della foto.
      expect(find.text('Inquadrala'), findsOneWidget);
      expect(find.text('SCRIVI SULLA FOTO'), findsNothing);
      expect(find.text('AVANTI'), findsOneWidget);

      await tester.tap(find.text('AVANTI'));
      await tester.pumpAndSettle();

      expect(find.text('Scrivici sopra'), findsOneWidget);
      expect(find.text('SCRIVI SULLA FOTO'), findsOneWidget);
      expect(find.text('VA BENE COSÌ'), findsOneWidget);
    });

    testWidgets('uno scatto appena fatto parte dal secondo passo', (
      tester,
    ) async {
      // L'inquadratura l'ha scelta il mirino un istante prima: richiederla
      // sarebbe un passo in piu' per non decidere niente.
      await _apri(tester, inquadrabile: false);

      expect(find.text('Scrivici sopra'), findsOneWidget);
      expect(find.text('AVANTI'), findsNothing);
    });

    testWidgets('la freccia torna al primo passo senza perdere niente', (
      tester,
    ) async {
      await _apri(tester);

      await tester.tap(find.text('AVANTI'));
      await tester.pumpAndSettle();
      await _scrivi(tester, 'resto qui');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Si torna a inquadrare, e la frase c'e' ancora: tornare indietro di un
      // passo non e' annullare il lavoro fatto.
      expect(find.text('Inquadrala'), findsOneWidget);
      expect(find.text('resto qui'), findsOneWidget);
    });
  });
}
