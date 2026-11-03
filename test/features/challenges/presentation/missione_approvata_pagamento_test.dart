import 'package:cloud_functions/cloud_functions.dart';
import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/core/theme/app_theme.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/features/challenges/domain/entities/proposta_missione.dart';
import 'package:crasy/features/challenges/presentation/pages/missione_approvata_page.dart';
import 'package:crasy/features/payments/data/payments_service.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';
import 'package:crasy/features/payments/domain/entities/saldo_spendibile.dart';
import 'package:crasy/features/payments/domain/prize_ledger.dart';
import 'package:crasy/features/payments/presentation/providers/payments_providers.dart';
import 'package:crasy/features/payments/presentation/widgets/riepilogo_premio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Risultato extends Fake
    implements HttpsCallableResult<Map<Object?, Object?>> {
  @override
  Map<Object?, Object?> get data => const {'challengeId': 'gara-1'};
}

class _Funzione extends Fake implements HttpsCallable {
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async =>
      _Risultato() as HttpsCallableResult<T>;
}

class _Finte extends Fake implements FirebaseFunctions {
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _Funzione();
}

/// Stripe e il portafoglio, come li vede la pagina.
class _Cassa extends Fake implements PaymentsService {
  _Cassa({
    this.conLaCarta = true,
    this.dalPortafoglio = true,
    this.saldoBasso = false,
    this.inArrivo = false,
    this.consensoMancante = false,
    this.guasto,
    this.spendibile,
  });

  final bool conLaCarta;
  final bool dalPortafoglio;
  final bool saldoBasso;
  final bool inArrivo;
  final bool consensoMancante;
  final Object? guasto;
  final SaldoSpendibile? spendibile;

  final pagateConLaCarta = <String>[];
  final pagateDalPortafoglio = <String>[];

  @override
  Future<SaldoSpendibile?> saldoSpendibile() async => spendibile;

  @override
  Future<bool> payChallenge(
    String challengeId, {
    void Function(String passo)? passo,
    String? returnRoute,
  }) async {
    if (guasto case final errore?) {
      throw errore;
    }

    pagateConLaCarta.add(challengeId);

    return conLaCarta;
  }

  @override
  Future<({bool pagata, bool saldoBasso, bool inArrivo, bool consensoMancante})>
  payChallengeFromWallet(String challengeId) async {
    pagateDalPortafoglio.add(challengeId);

    return (
      pagata: dalPortafoglio,
      saldoBasso: saldoBasso,
      inArrivo: inArrivo,
      consensoMancante: consensoMancante,
    );
  }
}

/// **I soldi di una missione approvata.**
///
/// Queste prove girano solo a pagamenti accesi, perche' l'interruttore e' deciso
/// quando si compila l'app:
///
///     flutter test --dart-define=CRASY_PAYMENTS=true test/features/challenges/presentation/missione_approvata_pagamento_test.dart
void main() {
  const premio = 500;

  Future<void> apri(WidgetTester tester, _Cassa cassa, {int saldo = 0}) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

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
        GoRoute(
          path: '/pagina',
          builder: (context, state) =>
              const MissioneApprovataPage(propostaId: 'p1'),
        ),
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
          firebaseFunctionsProvider.overrideWithValue(_Finte()),
          paymentsServiceProvider.overrideWithValue(cassa),
          walletBalanceProvider.overrideWithValue(saldo),
          propostaMissioneProvider('p1').overrideWith(
            (ref) async => const PropostaMissione(
              id: 'p1',
              stato: 'approvata',
              title: 'Foto',
              brief: 'Una foto',
              prizeCents: premio,
            ),
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

  group('il riepilogo', () {
    Future<void> mostra(WidgetTester tester, {required int saldo}) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [walletBalanceProvider.overrideWithValue(saldo)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: RiepilogoPremio(cents: premio),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('dice la cifra esatta, la stessa del foglio di Stripe', (
      tester,
    ) async {
      await mostra(tester, saldo: 0);

      expect(find.text('Paghi ora'), findsOneWidget);
      expect(
        find.text(AppMoney.format(PrizeLedger.chargeCents(premio))),
        findsOneWidget,
      );
      expect(find.text('Oppure dal portafoglio'), findsNothing);
    });

    testWidgets('il portafoglio si dice solo se basta', (tester) async {
      await mostra(tester, saldo: premio);

      expect(find.text('Oppure dal portafoglio'), findsOneWidget);
    });
  });

  group('il pagamento', skip: !paymentsEnabled, () {
    testWidgets('il saldo non ancora spendibile si dice prima di scegliere', (
      tester,
    ) async {
      final cassa = _Cassa(
        spendibile: SaldoSpendibile(
          spendibileCents: 10,
          inArrivoCents: premio - 10,
          inArrivoEntro: DateTime(2026, 11, 5),
        ),
      );

      await apri(tester, cassa, saldo: premio);

      // Gia' nel riepilogo: niente "oppure dal portafoglio".
      expect(find.text('Oppure dal portafoglio'), findsNothing);
      expect(find.textContaining('entro il 5 novembre'), findsOneWidget);

      await tester.tap(find.text('PAGA E LANCIA'));
      await tester.pumpAndSettle();

      // Nel foglio c'e', spento e con il motivo: toccarlo non paga niente.
      await tester.tap(find.text('Dal portafoglio · non ancora'));
      await tester.pumpAndSettle();
      expect(cassa.pagateDalPortafoglio, isEmpty);
      expect(find.text('Dal portafoglio · non ancora'), findsOneWidget);

      await tester.tap(
        find.text(
          'Con la carta · ${AppMoney.format(PrizeLedger.chargeCents(premio))}',
        ),
      );
      await tester.pumpAndSettle();

      expect(cassa.pagateConLaCarta, ['gara-1']);
      expect(cassa.pagateDalPortafoglio, isEmpty);
    });

    testWidgets('se quello che si puo spendere basta, resta tutto come prima', (
      tester,
    ) async {
      final cassa = _Cassa(
        spendibile: const SaldoSpendibile(
          spendibileCents: premio,
          inArrivoCents: 90,
        ),
      );

      await apri(tester, cassa, saldo: premio + 90);
      await tester.tap(find.text('PAGA E LANCIA'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.text('Dal portafoglio · ${AppMoney.format(premio)}'),
      );
      await tester.pumpAndSettle();

      expect(cassa.pagateDalPortafoglio, ['gara-1']);
    });

    testWidgets('senza saldo si va alla carta, e poi alla gara', (
      tester,
    ) async {
      final cassa = _Cassa();

      await apri(tester, cassa);

      expect(find.text('Paghi ora'), findsOneWidget);

      await tester.tap(find.text('PAGA E LANCIA'));
      await tester.pumpAndSettle();

      expect(cassa.pagateConLaCarta, ['gara-1']);
      expect(cassa.pagateDalPortafoglio, isEmpty);
      expect(find.text('GARA gara-1'), findsOneWidget);
    });

    testWidgets('col saldo si chiede, e dal portafoglio costa il premio', (
      tester,
    ) async {
      final cassa = _Cassa();

      await apri(tester, cassa, saldo: premio);
      await tester.tap(find.text('PAGA E LANCIA'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.text('Dal portafoglio · ${AppMoney.format(premio)}'),
      );
      await tester.pumpAndSettle();

      expect(cassa.pagateDalPortafoglio, ['gara-1']);
      expect(cassa.pagateConLaCarta, isEmpty);
      expect(find.text('GARA gara-1'), findsOneWidget);
    });

    testWidgets('col saldo si puo\' scegliere comunque la carta', (
      tester,
    ) async {
      final cassa = _Cassa();

      await apri(tester, cassa, saldo: premio);
      await tester.tap(find.text('PAGA E LANCIA'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.text(
          'Con la carta · ${AppMoney.format(PrizeLedger.chargeCents(premio))}',
        ),
      );
      await tester.pumpAndSettle();

      expect(cassa.pagateConLaCarta, ['gara-1']);
      expect(cassa.pagateDalPortafoglio, isEmpty);
    });

    testWidgets('chiuso il foglio senza scegliere non parte niente', (
      tester,
    ) async {
      final cassa = _Cassa();

      await apri(tester, cassa, saldo: premio);
      await tester.tap(find.text('PAGA E LANCIA'));
      await tester.pumpAndSettle();

      // Il foglio ha due volte la stessa parola, a sinistra e a destra.
      await tester.tap(find.text('Annulla').first);
      await tester.pumpAndSettle();

      expect(cassa.pagateConLaCarta, isEmpty);
      expect(cassa.pagateDalPortafoglio, isEmpty);
      expect(find.byType(MissioneApprovataPage), findsOneWidget);
      // Il velo si e' spento: il tasto si puo' toccare di nuovo.
      expect(find.text('PAGA E LANCIA'), findsOneWidget);
    });

    testWidgets('la carta chiusa a meta\': si dice, e si puo\' riprovare', (
      tester,
    ) async {
      await apri(tester, _Cassa(conLaCarta: false));
      await tester.tap(find.text('PAGA E LANCIA'));
      await tester.pumpAndSettle();

      expect(find.textContaining('non è stato pagato'), findsOneWidget);
      expect(find.byType(MissioneApprovataPage), findsOneWidget);
      expect(find.text('PAGA E LANCIA'), findsOneWidget);
    });

    testWidgets('un guasto del pagamento si dice, non si inghiotte', (
      tester,
    ) async {
      await apri(tester, _Cassa(guasto: Exception('Stripe non risponde')));
      await tester.tap(find.text('PAGA E LANCIA'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Stripe non risponde'), findsOneWidget);
      expect(find.byType(MissioneApprovataPage), findsOneWidget);
    });

    testWidgets('i premi ancora in arrivo si dicono', (tester) async {
      await apri(
        tester,
        _Cassa(dalPortafoglio: false, inArrivo: true),
        saldo: premio,
      );
      await tester.tap(find.text('PAGA E LANCIA'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Dal portafoglio · ${AppMoney.format(premio)}'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ancora in arrivo'), findsOneWidget);
    });

    testWidgets('senza il permesso sul conto Stripe si dice dove darlo', (
      tester,
    ) async {
      await apri(
        tester,
        _Cassa(dalPortafoglio: false, consensoMancante: true),
        saldo: premio,
      );
      await tester.tap(find.text('PAGA E LANCIA'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Dal portafoglio · ${AppMoney.format(premio)}'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('serve il tuo permesso'), findsOneWidget);
    });

    testWidgets('il portafoglio che non basta piu\' lo dice', (tester) async {
      await apri(
        tester,
        _Cassa(dalPortafoglio: false, saldoBasso: true),
        saldo: premio,
      );
      await tester.tap(find.text('PAGA E LANCIA'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Dal portafoglio · ${AppMoney.format(premio)}'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('non basta più'), findsOneWidget);
      expect(find.byType(MissioneApprovataPage), findsOneWidget);
    });
  });
}
