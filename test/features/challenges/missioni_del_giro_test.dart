import 'package:crasy/core/theme/app_theme.dart';
import 'package:crasy/features/challenges/domain/entities/missione_pronta.dart';
import 'package:crasy/features/challenges/domain/repositories/catalogo_missioni.dart';
import 'package:crasy/features/challenges/presentation/pages/create_challenge_page.dart';
import 'package:crasy/features/challenges/presentation/providers/missioni_pronte_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un catalogo in memoria: si comporta come quello vero, senza rete.
class _CatalogoFinto implements CatalogoMissioni {
  _CatalogoFinto(this.missioni);

  final List<MissionePronta> missioni;

  @override
  Future<int> quante() async => missioni.length;

  @override
  Future<List<MissionePronta>> daPosto(int posto, int quante) async {
    return [
      for (var i = 0; i < quante && i < missioni.length; i++)
        missioni[(posto + i) % missioni.length],
    ];
  }
}

/// Un catalogo che non risponde.
class _CatalogoRotto implements CatalogoMissioni {
  @override
  Future<int> quante() => throw StateError('rete giu');

  @override
  Future<List<MissionePronta>> daPosto(int posto, int quante) {
    throw StateError('rete giu');
  }
}

List<MissionePronta> _finte(int quante) {
  const tipi = [
    CategoriaMissione.hot,
    CategoriaMissione.abilita,
    CategoriaMissione.pazza,
  ];

  return [
    for (var i = 0; i < quante; i++)
      MissionePronta(
        titolo: 'MISSIONE $i',
        consegna: 'Fai la cosa numero $i.',
        categoria: tipi[i % tipi.length],
      ),
  ];
}

void main() {
  // A novembre: nessuna stagione in mezzo.
  final adesso = DateTime.utc(2026, 11, 15, 12);

  Future<List<MissionePronta>> giro(
    CatalogoMissioni catalogo,
    DateTime quando,
  ) {
    return missioniDelGiro(catalogo, chi: 'anna', quando: quando);
  }

  Set<String> titoli(List<MissionePronta> missioni) {
    return {for (final missione in missioni) missione.titolo};
  }

  test('ne consiglia dieci', () async {
    expect(await giro(_CatalogoFinto(_finte(240)), adesso), hasLength(10));
  });

  test('riaprendo dopo dieci minuti sono altre dieci', () async {
    final catalogo = _CatalogoFinto(_finte(240));
    final prime = await giro(catalogo, adesso);
    final dopo = await giro(catalogo, adesso.add(MissionePronta.ogni));

    expect(titoli(prime).intersection(titoli(dopo)), isEmpty);
  });

  test('riaprendo subito sono le stesse', () async {
    final catalogo = _CatalogoFinto(_finte(240));
    final prime = await giro(catalogo, adesso);
    final subito = await giro(catalogo, adesso.add(const Duration(minutes: 3)));

    expect(titoli(subito), titoli(prime));
  });

  test('una riga che il modulo rifiuterebbe non si consiglia', () async {
    final catalogo = _CatalogoFinto([
      ..._finte(9),
      const MissionePronta(
        titolo: 'UNA FOTO IN REGGISENO',
        consegna: 'Scritta a mano nel database.',
        categoria: CategoriaMissione.hot,
      ),
    ]);

    final pronte = await giro(catalogo, adesso);

    expect(pronte, hasLength(9));
    expect(titoli(pronte), isNot(contains('UNA FOTO IN REGGISENO')));
  });

  test('a ottobre quelle di Halloween entrano in testa', () async {
    final pronte = await giro(
      _CatalogoFinto(_finte(240)),
      DateTime.utc(2027, 10, 15, 12),
    );

    expect(pronte, hasLength(14));
    expect(pronte.first.categoria, CategoriaMissione.halloween);
  });

  group('un guasto non lascia il foglio bianco', () {
    Future<void> restanoLeScorte(CatalogoMissioni catalogo) async {
      final pronte = await giro(catalogo, adesso);

      expect(pronte, hasLength(10));
      expect(titoli(MissionePronta.tutte), containsAll(titoli(pronte)));
    }

    test('catalogo che non risponde', () {
      return restanoLeScorte(_CatalogoRotto());
    });

    test('catalogo vuoto', () {
      return restanoLeScorte(_CatalogoFinto(const []));
    });

    test('catalogo di sole righe rifiutate', () {
      return restanoLeScorte(
        _CatalogoFinto(const [
          MissionePronta(
            titolo: 'UNA FOTO IN REGGISENO',
            consegna: 'Scritta a mano nel database.',
            categoria: CategoriaMissione.hot,
          ),
        ]),
      );
    });

    test('senza Firebase, come nelle prove', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ascolto = container.listen(
        missioniDelGiroProvider.future,
        (_, _) {},
      );

      expect(await ascolto.read(), hasLength(10));
    });
  });

  group('sulla schermata di creazione', () {
    Future<void> apri(WidgetTester tester, List<MissionePronta> pronte) async {
      // Alta abbastanza da avere la fila a schermo senza scorrere.
      tester.view.physicalSize = const Size(1200, 3000);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            missioniDelGiroProvider.overrideWith((ref) async => pronte),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const CreateChallengePage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('si vede la fila, e toccandone una si riempie il modulo', (
      tester,
    ) async {
      const pronta = MissionePronta(
        titolo: 'TOGLITI UN GUANTO COME IN GILDA',
        consegna: 'Un guanto solo, dito per dito.',
        categoria: CategoriaMissione.hot,
      );

      await apri(tester, [pronta, ..._finte(9)]);

      expect(find.text(pronta.titolo), findsOneWidget);
      expect(find.text('HOT'), findsWidgets);

      await tester.tap(find.text(pronta.titolo));
      await tester.pump();

      // Una volta sulla scheda, una nel campo del titolo.
      expect(find.text(pronta.titolo), findsNWidgets(2));
      expect(find.text(pronta.consegna), findsOneWidget);
    });

    testWidgets('scrivendo nel modulo la fila non si muove', (tester) async {
      await apri(tester, _finte(10));

      await tester.enterText(find.byType(TextFormField).first, '12');
      await tester.pump();

      expect(find.text('MISSIONE 0'), findsOneWidget);
    });
  });
}
