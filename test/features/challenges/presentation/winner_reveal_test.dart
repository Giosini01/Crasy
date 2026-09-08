import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/presentation/widgets/winner_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Il rullo di tamburi, provato secondo per secondo.
///
/// **Un'animazione a tempo si rompe in silenzio.** Non lancia niente, non
/// colora niente di rosso: semplicemente resta ferma su un fotogramma, o salta
/// il finale, o non si chiude piu' — e chi la guarda pensa che l'app si sia
/// piantata proprio nel momento in cui doveva dire che aveva vinto dei soldi.
///
/// Le prove qui sotto sono le tre cose che devono succedere in ordine: prima la
/// domanda, poi la risposta, poi il congedo. Piu' quella che conta di piu': che
/// **si possa saltare**.
///
/// ## Perche' le scritte grosse si cercano in coppia
///
/// La frase in cima e' bianca con il contorno rosso, e in Flutter una scritta
/// sa essere piena **oppure** contornata, mai tutte e due: sono due `Text`
/// sovrapposti, il tratto sotto e il pieno sopra. Percio' `findsNWidgets(2)`,
/// e non e' una stranezza da tollerare — e' la prova che il contorno c'e'
/// ancora. Se qualcuno lo togliesse, questi numeri lo direbbero subito.
void main() {
  final gara = Challenge(
    id: 'g1',
    title: 'LA COSA PIU BRUTTA CHE HAI IN CASA',
    brief: 'Cercala bene.',
    prizeCents: 5000,
    scope: ChallengeScope.global,
    createdByUsername: 'frankk',
    createdByUserId: 'u-padrone',
    startsAt: DateTime(2026, 1, 1, 10),
    endsAt: DateTime(2026, 1, 1, 12),
  );

  ChallengeEntry foto(String id, String chi) => ChallengeEntry(
    id: id,
    challengeId: 'g1',
    challengeTitle: gara.title,
    userId: chi,
    authorName: chi,
    // Vuoto di proposito: qui si prova il tempo, non le immagini, e una foto
    // vera vorrebbe dire una richiesta di rete dentro una prova.
    mediaUrl: '',
  );

  Future<void> apri(WidgetTester tester, {required bool mine}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WinnerReveal(
          challenge: gara,
          entries: [foto('e1', 'anna'), foto('e2', 'bea')],
          winner: foto('e1', 'anna'),
          mine: mine,
        ),
      ),
    );
  }

  testWidgets('prima chiede, e non dice chi ha vinto', (tester) async {
    await apri(tester, mine: false);

    expect(find.text('CHI VINCE?'), findsNWidgets(2));
    // Il nome del vincitore non deve stare da nessuna parte finche' il rullo
    // gira: comparirebbe sotto la foto un istante prima della rivelazione.
    expect(find.text('@anna'), findsNothing);
    expect(find.text('HA VINTO'), findsNothing);

    // L'animazione e' ancora in corso: senza questo, la prova finisce con un
    // timer vivo e il messaggio d'errore non nomina la causa.
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('poi risponde, con il nome e il premio', (tester) async {
    await apri(tester, mine: false);

    // Oltre lo scoppio, che sta a poco piu' di un terzo dei cinque secondi.
    await tester.pump(const Duration(milliseconds: 2200));

    expect(find.text('HA VINTO'), findsNWidgets(2));
    // Il nome e il premio no: quelli sono scritte normali, una sola ciascuna.
    expect(find.text('@anna'), findsOneWidget);
    expect(find.text('€50'), findsOneWidget);
    expect(find.text('CHI VINCE?'), findsNothing);

    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('al vincitore lo dice in faccia', (tester) async {
    await apri(tester, mine: true);
    await tester.pump(const Duration(milliseconds: 2200));

    expect(find.text('HAI VINTO'), findsNWidgets(2));

    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('si chiude da sola, e non resta li a vita', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => WinnerReveal.show(
              context,
              challenge: gara,
              entries: [foto('e1', 'anna')],
              winner: foto('e1', 'anna'),
              mine: true,
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('apri'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('HAI VINTO'), findsNothing);
    expect(find.text('CHI VINCE?'), findsNWidgets(2));

    // Passati i cinque secondi se ne va da sola.
    await tester.pumpAndSettle(const Duration(seconds: 7));

    expect(find.text('CHI VINCE?'), findsNothing);
    expect(find.text('HAI VINTO'), findsNothing);
    expect(find.text('apri'), findsOneWidget);
  });

  testWidgets('un tocco la salta', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => WinnerReveal.show(
              context,
              challenge: gara,
              entries: [foto('e1', 'anna')],
              winner: foto('e1', 'anna'),
              mine: true,
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('apri'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('CHI VINCE?'), findsNWidgets(2));

    // A meta' rullo, un tocco **in un punto qualunque**: e' proprio quello che
    // deve funzionare, non un tasto da centrare. Si tocca un angolo vuoto,
    // lontano da qualsiasi scritta.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('CHI VINCE?'), findsNothing);
    expect(find.text('apri'), findsOneWidget);
  });
}
