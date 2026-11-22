import 'package:crasy/core/theme/app_theme.dart';
import 'package:crasy/features/gioco/domain/entities/regole_del_gioco.dart';
import 'package:crasy/features/gioco/domain/sfide_in_vista.dart';
import 'package:crasy/features/gioco/presentation/providers/gioco_providers.dart';
import 'package:crasy/features/gioco/presentation/widgets/gioco_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Le card delle sfide si disegnano in tutti e quattro gli stati**, su un
/// telefono stretto, senza sforare.
void main() {
  SfidaInVista voce(String id, StatoSfida stato, int progresso) {
    return SfidaInVista(
      sfida: SfidaDefinita(
        id: id,
        titolo: 'Una sfida dal titolo piuttosto lungo per una card',
        descrizione: 'Manda una foto in gara, poi un\'altra ancora',
        icona: 'foto',
        metrica: 'foto',
        obiettivo: 5,
        xp: 150,
      ),
      progresso: progresso,
      stato: stato,
    );
  }

  testWidgets(
    'il livello accanto al nome, con il nome quando le regole ci sono',
    (tester) async {
      const regole = RegoleDelGioco(
        giornaliere: [],
        permanenti: [],
        livelli: [
          LivelloDefinito(numero: 1, nome: 'Novizio', xp: 0),
          LivelloDefinito(numero: 2, nome: 'Curioso', xp: 100),
          LivelloDefinito(numero: 3, nome: 'Attivo', xp: 300),
        ],
      );

      Future<void> mostra(RegoleDelGioco? quali, int livello) async {
        await tester.pumpWidget(
          ProviderScope(
            // Una scena nuova a ogni giro: le sostituzioni non si cambiano a caldo.
            key: UniqueKey(),
            overrides: [
              regoleDelGiocoProvider.overrideWith((ref) => Stream.value(quali)),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(body: LivelloBadge(livello: livello)),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mostra(regole, 3);
      expect(find.text('LIV. 3 · ATTIVO'), findsOneWidget);

      // Chi non ha mai giocato e' al primo; senza regole basta il numero.
      await mostra(null, 0);
      expect(find.text('LIVELLO 1'), findsOneWidget);
    },
  );

  testWidgets('da fare, in corso, fatta e bloccata', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const livello = LivelloAttuale(
      numero: 4,
      nome: 'Esploratore',
      xpDa: 700,
      xpA: 1500,
      progresso: 0.5,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          regoleDelGiocoProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ListView(
              children: [
                const LivelloInGrande(
                  livello: livello,
                  xp: 1100,
                  sfideCompletate: 12,
                ),
                SfidaCard(voce: voce('a', StatoSfida.daFare, 0)),
                SfidaCard(voce: voce('b', StatoSfida.inCorso, 2)),
                SfidaCard(voce: voce('c', StatoSfida.completata, 5)),
                SizedBox(
                  height: 170,
                  child: Row(
                    children: [
                      Expanded(
                        child: TraguardoMattone(
                          voce: voce('d', StatoSfida.bloccata, 1),
                        ),
                      ),
                      Expanded(
                        child: TraguardoMattone(
                          voce: voce('e', StatoSfida.completata, 5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ESPLORATORE'), findsOneWidget);
    expect(find.text('LIVELLO 4'), findsOneWidget);
    expect(find.text('400 al prossimo'), findsOneWidget);
    expect(find.text('12 sfide completate'), findsOneWidget);
    expect(find.text('+150 XP'), findsNWidgets(5));
    expect(find.text('0/5'), findsOneWidget);
    expect(find.text('2/5'), findsOneWidget);
    expect(find.text('FATTA'), findsOneWidget);
    expect(find.text('Dopo la precedente'), findsOneWidget);
    expect(find.text('Fatto'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
  });
}
