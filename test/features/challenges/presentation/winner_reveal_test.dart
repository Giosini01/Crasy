import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
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
/// Le prove qui sotto sono le cose che devono succedere in ordine: prima i
/// tamburi **e nient'altro**, poi la proclamazione **senza tamburi**, poi il
/// congedo. Piu' quella che conta di piu': che **si possa saltare**.
///
/// ## Perche' il rullo si prova per quello che NON mostra
///
/// Durante i tamburi non deve esserci niente del finale: non il nome, non la
/// frase, non il premio. E' l'unica cosa che rende la rivelazione una
/// rivelazione, ed e' anche l'errore piu' facile da introdurre senza
/// accorgersene — basta spostare una scritta fuori da un `if`.
///
/// ## Perche' le scritte grosse si cercano in coppia
///
/// La frase e' bianca con il contorno rosso, e in Flutter una scritta sa essere
/// piena **oppure** contornata, mai tutte e due: sono due `Text` sovrapposti,
/// il tratto sotto e il pieno sopra. Percio' `findsNWidgets(2)`, e non e' una
/// stranezza da tollerare — e' la prova che il contorno c'e' ancora.
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

  final vincitrice = ChallengeEntry(
    id: 'e1',
    challengeId: 'g1',
    challengeTitle: gara.title,
    userId: 'anna',
    authorName: 'anna',
    // Vuoto di proposito: qui si prova il tempo, non le immagini, e una foto
    // vera vorrebbe dire una richiesta di rete dentro una prova.
    mediaUrl: '',
  );

  Future<void> apri(WidgetTester tester, {required bool mine}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WinnerReveal(
          challenge: gara,
          winner: vincitrice,
          mine: mine,
        ),
      ),
    );
  }

  Widget conIlTasto() => MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () => WinnerReveal.show(
          context,
          challenge: gara,
          winner: vincitrice,
          mine: true,
        ),
        child: const Text('apri'),
      ),
    ),
  );

  testWidgets('prima i tamburi, e nientaltro', (tester) async {
    await apri(tester, mine: false);

    expect(find.byKey(WinnerReveal.chiaveDeiTamburi), findsOneWidget);

    // Niente del finale deve essere gia' a schermo: ne' chi ha vinto, ne' che
    // qualcuno ha vinto, ne' quanto.
    expect(find.text('@anna'), findsNothing);
    expect(find.text('HA VINTO'), findsNothing);
    expect(find.text('HAI VINTO'), findsNothing);
    expect(find.text('€50'), findsNothing);

    // L'animazione e' ancora in corso: senza questo, la prova finisce con un
    // timer vivo e il messaggio d'errore non nomina la causa.
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('poi la foto, e i tamburi spariscono', (tester) async {
    await apri(tester, mine: false);

    // Oltre lo scoppio, che sta a poco piu' di un terzo dei cinque secondi.
    await tester.pump(const Duration(milliseconds: 2200));

    expect(find.byKey(WinnerReveal.chiaveDeiTamburi), findsNothing);
    expect(find.text('HA VINTO'), findsNWidgets(2));
    // Il nome e il premio no: quelli sono scritte normali, una sola ciascuna.
    expect(find.text('@anna'), findsOneWidget);
    expect(find.text('€50'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('al vincitore lo dice in faccia', (tester) async {
    await apri(tester, mine: true);
    await tester.pump(const Duration(milliseconds: 2200));

    expect(find.text('HAI VINTO'), findsNWidgets(2));

    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('se ha vinto un video non si apre nessun lettore', (tester) async {
    // **Era uno schermo nero.** Un lettore video dentro un'animazione da cinque
    // secondi non fa in tempo ad aprirsi: restava un rettangolo nero per tutta
    // la durata, e il momento piu' importante dell'app diventava un buco.
    //
    // Adesso il riquadro non c'e' proprio, e la notizia sta nel nome.
    await tester.pumpWidget(
      MaterialApp(
        home: WinnerReveal(
          challenge: gara,
          winner: ChallengeEntry(
            id: 'e9',
            challengeId: 'g1',
            challengeTitle: gara.title,
            userId: 'anna',
            authorName: 'anna',
            mediaUrl: 'https://esempio/qualcosa.mp4',
            mediaKind: MediaKind.video,
          ),
          mine: false,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 2200));

    expect(find.byType(MediaFrame), findsNothing);
    // Il nome invece c'e', ed e' l'unica cosa rimasta.
    expect(find.text('@anna'), findsOneWidget);
    expect(find.text('HA VINTO'), findsNWidgets(2));

    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('si chiude da sola, e non resta li a vita', (tester) async {
    await tester.pumpWidget(conIlTasto());

    await tester.tap(find.text('apri'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(WinnerReveal.chiaveDeiTamburi), findsOneWidget);

    // Passati i cinque secondi se ne va da sola.
    await tester.pumpAndSettle(const Duration(seconds: 7));

    expect(find.byKey(WinnerReveal.chiaveDeiTamburi), findsNothing);
    expect(find.text('HAI VINTO'), findsNothing);
    expect(find.text('apri'), findsOneWidget);
  });

  testWidgets('un tocco la salta', (tester) async {
    await tester.pumpWidget(conIlTasto());

    await tester.tap(find.text('apri'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(WinnerReveal.chiaveDeiTamburi), findsOneWidget);

    // A meta' rullo, un tocco **in un punto qualunque**: e' proprio quello che
    // deve funzionare, non un tasto da centrare. Si tocca un angolo vuoto.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byKey(WinnerReveal.chiaveDeiTamburi), findsNothing);
    expect(find.text('apri'), findsOneWidget);
  });
}
