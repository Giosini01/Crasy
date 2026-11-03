import 'package:crasy/core/theme/app_theme.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/features/auth/domain/entities/app_user.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/data/repositories/firestore_challenge_repository.dart';
import 'package:crasy/features/challenges/data/repositories/sample_challenge_repository.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/presentation/pages/create_challenge_page.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/esito_missione.dart';
import 'package:crasy/features/friends/domain/entities/friendship.dart';
import 'package:crasy/features/friends/presentation/pages/launch_duel_page.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/payments/data/payments_service.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';
import 'package:crasy/features/payments/domain/entities/saldo_spendibile.dart';
import 'package:crasy/features/payments/domain/prize_ledger.dart';
import 'package:crasy/features/payments/presentation/providers/payments_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fake_auth_repository.dart';

/// Il server dice che la deve guardare una persona.
class _Server extends SampleChallengeRepository {
  int chiamate = 0;

  @override
  Future<Challenge> createChallenge(Challenge challenge) async {
    chiamate += 1;

    throw const MissioneDaPagareInRevisione('p1', 'g1');
  }
}

class _Cassa extends Fake implements PaymentsService {
  _Cassa({this.conLaCarta = true});

  final bool conLaCarta;
  final pagateConLaCarta = <String>[];
  final pagateDalPortafoglio = <String>[];
  String? ritorno;

  @override
  Future<SaldoSpendibile?> saldoSpendibile() async => null;

  @override
  Future<bool> payChallenge(
    String challengeId, {
    void Function(String passo)? passo,
    String? returnRoute,
  }) async {
    pagateConLaCarta.add(challengeId);
    ritorno = returnRoute;

    return conLaCarta;
  }

  @override
  Future<({bool pagata, bool saldoBasso, bool inArrivo, bool consensoMancante})>
  payChallengeFromWallet(String challengeId) async {
    pagateDalPortafoglio.add(challengeId);

    return (
      pagata: true,
      saldoBasso: false,
      inArrivo: false,
      consensoMancante: false,
    );
  }
}

/// **Una missione da controllare: si paga, resta in pausa, e si dice tutto prima.**
///
/// Queste prove girano solo a pagamenti accesi:
///
///     flutter test --dart-define=CRASY_PAYMENTS=true test/features/challenges/presentation/lancio_in_revisione_pagamento_test.dart
void main() {
  const utente = AppUser(
    id: 'io',
    email: 'io@example.com',
    emailVerified: true,
  );

  Future<void> monta(
    WidgetTester tester,
    Widget pagina,
    _Server server,
    _Cassa cassa, {
    int saldo = 0,
  }) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = FakeAuthRepository(currentUser: utente);

    addTearDown(auth.dispose);

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
          path: '/challenge/:id',
          builder: (context, state) =>
              Text('GARA ${state.pathParameters['id']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          challengeRepositoryProvider.overrideWithValue(server),
          paymentsServiceProvider.overrideWithValue(cassa),
          walletBalanceProvider.overrideWithValue(saldo),
          myFriendsProvider.overrideWith(
            (ref) => Stream.value(const [
              Friend(userId: 'amico', username: 'luigi'),
            ]),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('CASA'));
    await tester.pumpAndSettle();
  }

  Future<void> lancia(WidgetTester tester) async {
    final campi = find.byType(TextFormField);

    await tester.enterText(campi.at(0), '5');
    await tester.enterText(campi.at(1), 'Foto fuori al balcone');
    await tester.enterText(campi.at(2), 'Una foto, adesso.');
    await tester.pump();

    await tester.tap(find.text('LANCIA LA CHALLENGE'));
    await tester.pumpAndSettle();
  }

  group('il modulo di una missione', () {
    testWidgets('prima di pagare si legge cosa succede ai soldi', (
      tester,
    ) async {
      final cassa = _Cassa();

      await monta(tester, const CreateChallengePage(), _Server(), cassa);
      await lancia(tester);

      expect(find.byType(AvvisoPrimaDellaRevisione), findsOneWidget);
      expect(find.textContaining('tornano indietro'), findsOneWidget);
      expect(cassa.pagateConLaCarta, isEmpty);
    }, skip: !paymentsEnabled);

    testWidgets('senza confermare non parte niente, e si resta sul modulo', (
      tester,
    ) async {
      final server = _Server();
      final cassa = _Cassa();

      await monta(tester, const CreateChallengePage(), server, cassa);
      await lancia(tester);

      await tester.tap(find.text('Non adesso'));
      await tester.pumpAndSettle();

      expect(cassa.pagateConLaCarta, isEmpty);
      expect(find.byType(CreateChallengePage), findsOneWidget);
      expect(find.textContaining('finché non la paghi'), findsOneWidget);

      // Riprovando non se ne scrive un'altra, e si legge di nuovo tutto.
      await tester.tap(find.text('PAGA IL PREMIO'));
      await tester.pumpAndSettle();

      expect(server.chiamate, 1);
      expect(find.byType(AvvisoPrimaDellaRevisione), findsOneWidget);
    }, skip: !paymentsEnabled);

    testWidgets('pagata con la carta: non si apre, e si dice che e in revisione', (
      tester,
    ) async {
      final cassa = _Cassa();

      await monta(tester, const CreateChallengePage(), _Server(), cassa);
      await lancia(tester);

      await tester.tap(find.text('PAGA E MANDALA IN REVISIONE'));
      await tester.pumpAndSettle();

      expect(cassa.pagateConLaCarta, ['g1']);
      expect(cassa.ritorno, '/missione-in-revisione');
      expect(find.byType(AvvisoInRevisione), findsOneWidget);
      expect(find.textContaining('GARA'), findsNothing);

      await tester.tap(find.text('HO CAPITO'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateChallengePage), findsNothing);
      expect(find.text('CASA'), findsOneWidget);
    }, skip: !paymentsEnabled);

    testWidgets('pagata dal portafoglio: uguale, senza aprire la gara', (
      tester,
    ) async {
      final cassa = _Cassa();

      await monta(
        tester,
        const CreateChallengePage(),
        _Server(),
        cassa,
        saldo: 1000,
      );
      await lancia(tester);

      await tester.tap(find.text('PAGA E MANDALA IN REVISIONE'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.text('Dal portafoglio · ${AppMoney.format(500)}'),
      );
      await tester.pumpAndSettle();

      expect(cassa.pagateDalPortafoglio, ['g1']);
      expect(find.byType(AvvisoInRevisione), findsOneWidget);
      expect(find.textContaining('GARA'), findsNothing);
    }, skip: !paymentsEnabled);

    testWidgets('una carta che non va: si puo riprovare', (tester) async {
      final cassa = _Cassa(conLaCarta: false);

      await monta(tester, const CreateChallengePage(), _Server(), cassa);
      await lancia(tester);

      await tester.tap(find.text('PAGA E MANDALA IN REVISIONE'));
      await tester.pumpAndSettle();

      expect(find.byType(AvvisoInRevisione), findsNothing);
      expect(find.byType(CreateChallengePage), findsOneWidget);
      expect(find.text('PAGA IL PREMIO'), findsOneWidget);
    }, skip: !paymentsEnabled);
  });

  group('il modulo di una sfida', () {
    Future<void> lanciaLaSfida(WidgetTester tester) async {
      await tester.tap(find.text('CON PREMIO'));
      await tester.pumpAndSettle();

      final campi = find.byType(TextFormField);

      await tester.enterText(campi.at(0), 'Una sfida');
      await tester.enterText(campi.at(1), 'Fai una foto.');
      await tester.enterText(campi.at(3), '2');
      await tester.pump();

      await tester.tap(find.text('LANCIA LA SFIDA'));
      await tester.pumpAndSettle();
    }

    testWidgets('si paga, e all amico non arriva niente finche non e accettata', (
      tester,
    ) async {
      final cassa = _Cassa();

      await monta(
        tester,
        const LaunchDuelPage(friendId: 'amico'),
        _Server(),
        cassa,
      );

      await lanciaLaSfida(tester);

      expect(find.byType(AvvisoPrimaDellaRevisione), findsOneWidget);

      await tester.tap(find.text('PAGA E MANDALA IN REVISIONE'));
      await tester.pumpAndSettle();

      expect(cassa.pagateConLaCarta, ['g1']);
      expect(cassa.ritorno, '/missione-in-revisione');
      expect(find.byType(AvvisoInRevisione), findsOneWidget);
      expect(find.textContaining('GARA'), findsNothing);

      await tester.tap(find.text('HO CAPITO'));
      await tester.pumpAndSettle();

      expect(find.byType(LaunchDuelPage), findsNothing);
    }, skip: !paymentsEnabled);
  });

  test('il conto del foglio e quello del modulo sono lo stesso', () {
    expect(PrizeLedger.chargeCents(200), 234);
    expect(PrizeLedger.processingFeeCents(200), 29);
  });
}
