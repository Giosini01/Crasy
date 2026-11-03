import 'package:cloud_functions/cloud_functions.dart';
import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/core/theme/app_theme.dart';
import 'package:crasy/features/auth/domain/entities/app_user.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/data/repositories/firestore_challenge_repository.dart';
import 'package:crasy/features/challenges/data/repositories/sample_challenge_repository.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/proposta_missione.dart';
import 'package:crasy/features/challenges/presentation/pages/create_challenge_page.dart';
import 'package:crasy/features/challenges/presentation/pages/missione_approvata_page.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/domain/entities/friendship.dart';
import 'package:crasy/features/friends/presentation/pages/launch_duel_page.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fake_auth_repository.dart';

/// Il server, com'e' visto dal modulo: risponde quello che decide la prova.
class _Server extends SampleChallengeRepository {
  _Server(this.esito);

  final Object esito;
  int chiamate = 0;

  @override
  Future<Challenge> createChallenge(Challenge challenge) async {
    chiamate += 1;

    throw esito;
  }
}

class _Risultato extends Fake
    implements HttpsCallableResult<Map<Object?, Object?>> {
  _Risultato(this.data);

  @override
  final Map<Object?, Object?> data;
}

class _Funzione extends Fake implements HttpsCallable {
  _Funzione(this.quale, this.finte);

  final String quale;
  final _Finte finte;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    finte.chiamate.add((quale, parameters));

    final errore = finte.errore;

    if (errore != null) {
      throw errore;
    }

    return _Risultato(finte.risposta) as HttpsCallableResult<T>;
  }
}

class _Finte extends Fake implements FirebaseFunctions {
  _Finte({this.risposta = const {}, this.errore});

  final Map<Object?, Object?> risposta;
  final Object? errore;
  final chiamate = <(String, dynamic)>[];

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _Funzione(name, this);
}

class _RifiutoDelServer extends FirebaseFunctionsException {
  _RifiutoDelServer(String code, String message)
    : super(code: code, message: message);
}

/// Una pila di due pagine: una sotto, e quella che si prova sopra.
Widget _app(Widget pagina, List<Override> overrides) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/pagina'),
            child: const Text('CASA'),
          ),
        ),
      ),
      GoRoute(path: '/pagina', builder: (context, state) => pagina),
      GoRoute(
        path: '/missione/:id',
        builder: (context, state) =>
            Text('PAGAMENTO ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/challenge/:id',
        builder: (context, state) => Text('GARA ${state.pathParameters['id']}'),
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

/// Il modulo e' lungo: su uno schermo alto il tasto si tocca senza scorrere.
void _schermoAlto(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  const utente = AppUser(
    id: 'io',
    email: 'io@example.com',
    emailVerified: true,
  );

  group('il modulo di una missione', () {
    Future<_Server> compila(WidgetTester tester, Object esito) async {
      _schermoAlto(tester);

      final server = _Server(esito);
      final auth = FakeAuthRepository(currentUser: utente);

      addTearDown(auth.dispose);

      await tester.pumpWidget(
        _app(const CreateChallengePage(), [
          authRepositoryProvider.overrideWithValue(auth),
          challengeRepositoryProvider.overrideWithValue(server),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('CASA'));
      await tester.pumpAndSettle();

      final campi = find.byType(TextFormField);

      await tester.enterText(campi.at(0), '5');
      await tester.enterText(campi.at(1), 'Foto fuori al balcone');
      await tester.enterText(campi.at(2), 'Una foto, adesso.');
      await tester.pump();

      await tester.tap(find.text('LANCIA LA CHALLENGE'));
      await tester.pumpAndSettle();

      return server;
    }

    testWidgets('in controllo: lo dice, e il modulo se ne va', (tester) async {
      final server = await compila(tester, const MissioneInControllo('p1'));

      expect(server.chiamate, 1);
      expect(
        find.text('Ti avvisiamo appena c’è una risposta.'),
        findsOneWidget,
      );

      await tester.tap(find.text('HO CAPITO'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateChallengePage), findsNothing);
      expect(find.text('CASA'), findsOneWidget);
    });

    testWidgets('fermata alle parole: la frase del server, e si riscrive', (
      tester,
    ) async {
      await compila(
        tester,
        const MissioneBloccata('Questa missione chiede un reato.'),
      );

      expect(find.text('Questa missione chiede un reato.'), findsOneWidget);
      expect(find.byType(CreateChallengePage), findsOneWidget);
      expect(
        find.text('Ti avvisiamo appena c’è una risposta.'),
        findsNothing,
      );
    });

    testWidgets('gia\' approvata: si va dritti a pagare', (tester) async {
      await compila(tester, const MissioneDaPagare('p9'));

      expect(find.text('PAGAMENTO p9'), findsOneWidget);
      expect(find.byType(CreateChallengePage), findsNothing);
    });

    testWidgets(
      'troppe proposte: si legge la frase del server, non un guasto',
      (tester) async {
        await compila(
          tester,
          _RifiutoDelServer(
            'resource-exhausted',
            'Hai proposto troppe missioni per oggi. Riprova domani.',
          ),
        );

        expect(
          find.text('Hai proposto troppe missioni per oggi. Riprova domani.'),
          findsOneWidget,
        );
      },
    );
  });

  group('il modulo di una sfida', () {
    Future<_Server> apri(WidgetTester tester, Object esito) async {
      _schermoAlto(tester);

      final server = _Server(esito);
      final auth = FakeAuthRepository(currentUser: utente);

      addTearDown(auth.dispose);

      await tester.pumpWidget(
        _app(const LaunchDuelPage(friendId: 'amico'), [
          authRepositoryProvider.overrideWithValue(auth),
          challengeRepositoryProvider.overrideWithValue(server),
          myFriendsProvider.overrideWith(
            (ref) => Stream.value(const [
              Friend(userId: 'amico', username: 'luigi'),
            ]),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('CASA'));
      await tester.pumpAndSettle();

      return server;
    }

    Future<void> scrivi(WidgetTester tester, {String riga = ''}) async {
      final campi = find.byType(TextFormField);

      await tester.enterText(campi.at(0), 'Una sfida');
      await tester.enterText(campi.at(1), 'Fai una foto.');
      await tester.enterText(campi.at(2), riga);
      await tester.pump();

      await tester.tap(find.text('LANCIA LA SFIDA'));
      await tester.pumpAndSettle();
    }

    testWidgets('la riga per l\'amico non passa senza che la guardi nessuno', (
      tester,
    ) async {
      final server = await apri(tester, const MissioneInControllo('p1'));

      await scrivi(tester, riga: '4MM4ZZ4T1');

      expect(server.chiamate, 0, reason: 'non doveva nemmeno partire');
      expect(find.textContaining('farsi del male'), findsOneWidget);
    });

    testWidgets('in controllo: lo dice, e all\'amico non arriva niente', (
      tester,
    ) async {
      final server = await apri(tester, const MissioneInControllo('p1'));

      await scrivi(tester, riga: 'Vediamo se ce la fai.');

      expect(server.chiamate, 1);
      expect(
        find.text('Ti avvisiamo appena c’è una risposta.'),
        findsOneWidget,
      );

      await tester.tap(find.text('HO CAPITO'));
      await tester.pumpAndSettle();

      expect(find.byType(LaunchDuelPage), findsNothing);
    });

    testWidgets('fermata alle parole: resta nel modulo', (tester) async {
      await apri(tester, const MissioneBloccata('Non si può.'));

      await scrivi(tester);

      expect(find.text('Non si può.'), findsOneWidget);
      expect(find.byType(LaunchDuelPage), findsOneWidget);
    });
  });

  group('la pagina di una missione approvata', () {
    Future<_Finte> apri(
      WidgetTester tester,
      _Finte finte, {
      int premio = 500,
    }) async {
      _schermoAlto(tester);

      await tester.pumpWidget(
        _app(const MissioneApprovataPage(propostaId: 'p1'), [
          firebaseFunctionsProvider.overrideWithValue(finte),
          propostaMissioneProvider('p1').overrideWith(
            (ref) async => PropostaMissione(
              id: 'p1',
              stato: 'approvata',
              title: 'Foto',
              brief: 'Una foto',
              prizeCents: premio,
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('CASA'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('LANCIA LA MISSIONE'));
      await tester.pumpAndSettle();

      return finte;
    }

    testWidgets('il tasto chiede al server la gara, e la apre', (tester) async {
      final finte = await apri(
        tester,
        _Finte(risposta: {'challengeId': 'gara-1'}),
      );

      expect(finte.chiamate.single.$1, 'lanciaMissioneApprovata');
      expect(finte.chiamate.single.$2, {'propostaId': 'p1'});
      expect(find.text('GARA gara-1'), findsOneWidget);
    });

    testWidgets('gia\' pagata: si va alla gara', (tester) async {
      await apri(
        tester,
        _Finte(risposta: {'challengeId': 'gara-1', 'giaPagata': true}),
      );

      expect(find.text('GARA gara-1'), findsOneWidget);
    });

    testWidgets('un rifiuto del server si legge, e si resta qui', (
      tester,
    ) async {
      await apri(
        tester,
        _Finte(
          errore: _RifiutoDelServer(
            'failed-precondition',
            'Questa missione non è approvata.',
          ),
        ),
      );

      expect(find.text('Questa missione non è approvata.'), findsOneWidget);
      expect(find.byType(MissioneApprovataPage), findsOneWidget);
      // Il velo si spegne: il tasto si puo' toccare di nuovo.
      expect(find.text('LANCIA LA MISSIONE'), findsOneWidget);
    });

    testWidgets('una risposta senza gara non apre una pagina vuota', (
      tester,
    ) async {
      await apri(tester, _Finte());

      expect(find.byType(MissioneApprovataPage), findsOneWidget);
      expect(find.textContaining('Non siamo riusciti'), findsOneWidget);
    });
  });
}
