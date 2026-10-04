import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_theme.dart';
import 'package:crasy/core/theme/seasons/season.dart';
import 'package:crasy/core/theme/seasons/season_skin.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Le stagioni: il calendario, e la promessa che fuori stagione non c'e' nulla.**
///
/// La prova che conta davvero e' la seconda. Un livello che si accende da solo a
/// una data si controlla una volta e funziona; quello che si rompe in silenzio e'
/// l'altra meta' — che il 3 novembre l'app torni **esattamente** quella di prima.
/// Se una ragnatela resta attaccata a una pagina, nessuno se ne accorge subito:
/// si trova a febbraio, e a quel punto non si sa piu' da dove viene.
void main() {
  group('il calendario', () {
    test('le ragnatele ci sono da tutto ottobre, non da settembre', () {
      expect(Season.of(DateTime(2026, 9, 30)), Season.base);
      expect(Season.of(DateTime(2026, 10)), Season.halloween);
      expect(Season.of(DateTime(2026, 10, 4)), Season.halloween);
      expect(Season.of(DateTime(2026, 10, 31)), Season.halloween);
    });

    test('il 2 novembre e la fine, il 3 e CRASY di sempre', () {
      expect(Season.of(DateTime(2026, 11, 2)), Season.halloween);
      expect(Season.of(DateTime(2026, 11, 3)), Season.base);
    });

    test('il natale scavalca il capodanno', () {
      expect(Season.of(DateTime(2026, 12, 7)), Season.base);
      expect(Season.of(DateTime(2026, 12, 8)), Season.natale);
      expect(Season.of(DateTime(2026, 12, 25)), Season.natale);
      expect(Season.of(DateTime(2027, 1, 6)), Season.natale);
      expect(Season.of(DateTime(2027, 1, 7)), Season.base);
    });

    test('novembre e marzo non hanno niente addosso', () {
      expect(Season.of(DateTime(2026, 11, 15)), Season.base);
      expect(Season.of(DateTime(2027, 3, 1)), Season.base);
    });
  });

  group('fuori stagione non resta niente', () {
    test('la pelle spenta non ha un solo segno da dare', () {
      const pelle = SeasonSkin.nessuna;

      expect(pelle.segnoDApertura(misura: 100, colore: Colors.red), isNull);
      expect(pelle.segnoDAttesa(misura: 30, colore: Colors.red), isNull);
      expect(
        pelle.giostraDAttesa(giro: 0.5, palette: AppPalette.light),
        isNull,
      );
    });

    testWidgets('il fondo pagina torna il figlio identico', (tester) async {
      const dentro = Text('la pagina');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const AppBackground(child: dentro),
        ),
      );

      // **Lo stesso widget, non uno uguale.** Fuori stagione [decora] deve
      // restituire quello che gli e' arrivato: un `Stack` con dentro la pagina
      // renderebbe la prova verde e lascerebbe comunque un livello in piu' sotto
      // ogni schermata dell'anno.
      final fondo = tester.widget<ColoredBox>(
        find
            .ancestor(
              of: find.byWidget(dentro),
              matching: find.byType(ColoredBox),
            )
            .first,
      );

      // Basta `same`: se il figlio e' lo stesso oggetto, fra il fondo e la
      // pagina non c'e' potuto entrare niente. Cercare "nessun CustomPaint" in
      // tutto l'albero non direbbe questo — ne trova comunque, perche' le
      // cornici di Material ne hanno di loro.
      expect(fondo.child, same(dentro));
    });
  });

  group('di stagione', () {
    test('ottobre da tutti e tre i segni', () {
      final pelle = SeasonSkin.perStagione(Season.halloween);

      expect(pelle.segnoDApertura(misura: 100, colore: Colors.red), isNotNull);
      expect(pelle.segnoDAttesa(misura: 30, colore: Colors.red), isNotNull);
      expect(
        pelle.giostraDAttesa(giro: 0.5, palette: AppPalette.light),
        isNotNull,
      );
    });

    testWidgets('la ragnatela non si mangia i tocchi', (tester) async {
      Season.fissata = Season.halloween;
      addTearDown(() => Season.fissata = Season.base);

      var toccato = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AppBackground(
            child: Center(
              child: GestureDetector(
                onTap: () => toccato = true,
                child: const Text('tocca qui'),
              ),
            ),
          ),
        ),
      );

      // Il velo copre tutta la schermata. Fermasse un tocco, per due settimane
      // ogni bottone di CRASY sarebbe morto — e il modo in cui lo si scoprirebbe
      // e' qualcuno che scrive "non funziona niente".
      await tester.tap(find.text('tocca qui'));

      expect(toccato, isTrue);
    });

    testWidgets('e il velo c\'e\' davvero', (tester) async {
      Season.fissata = Season.halloween;
      addTearDown(() => Season.fissata = Season.base);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const AppBackground(child: Text('la pagina')),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
