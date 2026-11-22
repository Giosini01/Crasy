import 'dart:convert';
import 'dart:io';

import 'package:crasy/core/theme/app_theme.dart';
import 'package:crasy/features/gioco/domain/entities/regole_del_gioco.dart';
import 'package:crasy/features/gioco/domain/entities/stato_del_gioco.dart';
import 'package:crasy/features/gioco/presentation/pages/sfide_page.dart';
import 'package:crasy/features/gioco/presentation/providers/gioco_providers.dart';
import 'package:crasy/features/gioco/presentation/widgets/gioco_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Su Android non si rompe niente.** Gli schermi Android piu' comuni, dal
/// piccolo al grande, con il testo normale e con quello ingrandito fino al
/// massimo che l'app lascia passare (+25%, vedi `CrasyApp`): la schermata
/// delle sfide e la parte alta del profilo devono stare dentro, senza righe
/// che sbordano.
void main() {
  final regole = RegoleDelGioco.fromMap(
    jsonDecode(File('functions/dati/gioco.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  // Una giornata piena: sfide a meta', traguardi fatti, in corso e bloccati.
  final stato = StatoDelGioco.fromMap({
    'xp': 1240,
    'livello': 4,
    'sfideCompletate': 23,
    'contatori': {'foto': 34, 'fiammeDate': 100, 'vittorie': 3, 'amici': 4},
    'completate': {'primi_scatti': 1, 'socializzatore': 1, 'prima_vittoria': 1},
    'giorno': '2026-12-02',
    'oggi': {
      'scelte': ['doppietta', 'social', 'popolare_oggi', 'chiacchierone'],
      'contatori': {'foto': 1, 'fiammeDate': 5},
      'completate': {'social': 1},
    },
  });

  const schermi = {
    'piccolo 320x568': Size(320, 568),
    'medio 360x780': Size(360, 780),
    'Pixel 393x851': Size(393, 851),
    'grande 412x915': Size(412, 915),
  };

  Widget scena(Widget figlio, double testo) => ProviderScope(
    overrides: [
      giocoRepositoryProvider.overrideWithValue(null),
      apriLeSfideProvider.overrideWith((ref) async {}),
      regoleDelGiocoProvider.overrideWith((ref) => Stream.value(regole)),
      statoDelGiocoProvider.overrideWith((ref) => Stream.value(stato)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(testo)),
        child: child!,
      ),
      home: figlio,
    ),
  );

  for (final MapEntry(key: nome, value: misura) in schermi.entries) {
    for (final testo in [1.0, 1.25]) {
      testWidgets('Android $nome, testo x$testo', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        tester.view.devicePixelRatio = 2.75;
        tester.view.physicalSize = misura * 2.75;
        addTearDown(tester.view.reset);

        // La schermata delle sfide, scorsa fino in fondo.
        await tester.pumpWidget(scena(const SfidePage(), testo));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // La parte alta del profilo: anello, badge e serie, riga delle sfide.
        await tester.pumpWidget(
          scena(
            Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: AnelloDelLivello(
                      livello: 4,
                      xp: 1240,
                      diametro: 92,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [LivelloBadge(livello: 4)],
                  ),
                  const SizedBox(height: 12),
                  const LivelloCard(),
                ],
              ),
            ),
            testo,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('LIV. 4 · ESPLORATORE'), findsOneWidget);

        debugDefaultTargetPlatformOverride = null;
      });
    }
  }
}
