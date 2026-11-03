import 'package:cloud_functions/cloud_functions.dart';
import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/core/theme/app_theme.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/features/challenges/data/repositories/firestore_challenge_repository.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_source.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/challenges/presentation/widgets/esito_missione.dart';
import 'package:crasy/features/challenges/presentation/widgets/modifica_missione.dart';
import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';
import 'package:crasy/features/payments/domain/prize_ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _mostra(WidgetTester tester, Widget figlio) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: figlio),
    ),
  );
}

class _Risultato extends Fake implements HttpsCallableResult<Object?> {
  @override
  Object? get data => const {'ok': true};
}

class _Funzione extends Fake implements HttpsCallable {
  _Funzione(this.finte);

  final _Finte finte;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    finte.mandato = parameters as Map<String, Object?>;

    final errore = finte.errore;

    if (errore != null) {
      throw errore;
    }

    return _Risultato() as HttpsCallableResult<T>;
  }
}

class _Finte extends Fake implements FirebaseFunctions {
  Map<String, Object?>? mandato;
  String? nome;
  Object? errore;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    nome = name;

    return _Funzione(this);
  }
}

void main() {
  group('la risposta del server', () {
    test('una missione da controllare con un premio si paga adesso', () {
      expect(
        () => FirestoreChallengeRepository.idDellaGara(const {
          'stato': 'daPagareInRevisione',
          'propostaId': 'p1',
          'challengeId': 'g1',
        }),
        throwsA(
          isA<MissioneDaPagareInRevisione>()
              .having((e) => e.propostaId, 'proposta', 'p1')
              .having((e) => e.challengeId, 'gara', 'g1'),
        ),
      );
    });

    test('in revisione non si vede da nessuna parte', () {
      expect(PrizeStatus.fromName('inRevisione'), PrizeStatus.inRevisione);
      expect(PrizeStatus.inRevisione.isVisible, isFalse);
      expect(PrizeStatus.inRevisione.isEscrowed, isFalse);
    });
  });

  group('cosa si legge prima di pagare', () {
    testWidgets('tutto quello che succede ai soldi, con le cifre', (
      tester,
    ) async {
      const premio = 200;

      await _mostra(
        tester,
        const AvvisoPrimaDellaRevisione(premioCents: premio),
      );

      final pagato = PrizeLedger.chargeCents(premio);
      final commissioni = PrizeLedger.processingFeeCents(premio);

      expect(find.textContaining(AppMoney.format(pagato)), findsOneWidget);
      expect(
        find.textContaining(
          'i soldi tornano indietro: sulla carta '
          '${AppMoney.format(pagato - commissioni)}',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('tranne le commissioni di Stripe'),
        findsOneWidget,
      );
      expect(find.textContaining(AppMoney.format(commissioni)), findsOneWidget);
      expect(find.textContaining('Se entro 48 ore'), findsOneWidget);
      expect(find.textContaining('resta in pausa'), findsOneWidget);
      expect(find.textContaining('5-10 giorni'), findsOneWidget);
    });

    testWidgets('si conferma, o non parte niente', (tester) async {
      bool? risposta;

      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  risposta = await chiediConfermaRevisione(
                    context,
                    premioCents: 200,
                  );
                },
                child: const Text('APRI'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('APRI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Non adesso'));
      await tester.pumpAndSettle();
      expect(risposta, isFalse);

      await tester.tap(find.text('APRI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PAGA E MANDALA IN REVISIONE'));
      await tester.pumpAndSettle();
      expect(risposta, isTrue);
    });
  });

  group('cosa si legge dopo', () {
    testWidgets('appena pagato: in pausa, e cosa torna', (tester) async {
      await _mostra(tester, const AvvisoInRevisione());

      expect(find.textContaining('in pausa'), findsOneWidget);
      expect(find.textContaining('entro 48 ore'), findsOneWidget);
      expect(find.textContaining('tornano indietro'), findsOneWidget);
    });

    testWidgets('un no con i soldi gia pagati dice quanto torna', (
      tester,
    ) async {
      await _mostra(
        tester,
        const AvvisoRifiutata(
          titolo: 'Foto',
          motivo: 'Mette in pericolo chi la fa',
          rimborsoCents: 205,
          rimborsoDove: 'carta',
        ),
      );

      expect(find.text('Non hai pagato niente.'), findsNothing);
      expect(
        find.textContaining('Ti abbiamo rimborsato €2,05'),
        findsOneWidget,
      );
      expect(find.textContaining('commissioni di Stripe'), findsOneWidget);
    });

    testWidgets('un no senza soldi di mezzo resta com era', (tester) async {
      await _mostra(tester, const AvvisoRifiutata(titolo: '', motivo: ''));

      expect(find.text('Non hai pagato niente.'), findsOneWidget);
    });

    testWidgets('dal portafoglio torna nel portafoglio', (tester) async {
      await _mostra(
        tester,
        const AvvisoNonCaricata(
          titolo: 'Foto',
          rimborsoCents: 200,
          rimborsoDove: 'portafoglio',
        ),
      );

      expect(find.textContaining('nel portafoglio'), findsOneWidget);
      expect(find.textContaining('commissioni'), findsNothing);
    });

    testWidgets('48 ore senza risposta: poche parole', (tester) async {
      await _mostra(tester, const AvvisoNonCaricata(titolo: 'Foto'));

      expect(find.byType(AvvisoNonCaricata), findsOneWidget);
      expect(find.textContaining('rimborsato'), findsNothing);
    });

    test('la campanella dice quanto torna', () {
      const rifiutata = AppNotification(
        id: 'a',
        kind: NotificationKind.missionRejected,
        rimborsoCents: 205,
      );
      const scaduta = AppNotification(
        id: 'b',
        kind: NotificationKind.missionExpired,
        rimborsoCents: 205,
      );
      const scadutaGratis = AppNotification(
        id: 'c',
        kind: NotificationKind.missionExpired,
      );

      expect(rifiutata.message, contains('€2,05'));
      expect(
        scaduta.message,
        'La tua missione non è stata caricata: ti tornano €2,05',
      );
      expect(scadutaGratis.message, 'La tua missione non è stata caricata');
      expect(scaduta.group, NotificationGroup.participations);
    });
  });

  group('modificare una missione', () {
    Challenge missione() => Challenge(
      id: 'g1',
      title: 'Foto',
      brief: 'Una foto',
      prizeCents: 200,
      scope: ChallengeScope.global,
      createdByUsername: 'io',
      createdByUserId: 'io',
      startsAt: DateTime(2026, 11, 3, 10),
      endsAt: DateTime(2026, 11, 3, 11),
      maxParticipants: 15,
    );

    Future<_Finte> apri(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final finte = _Finte();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [firebaseFunctionsProvider.overrideWithValue(finte)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => mostraModificaMissione(context, missione()),
                  child: const Text('APRI'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('APRI'));
      await tester.pumpAndSettle();

      return finte;
    }

    testWidgets('manda solo quello che e cambiato', (tester) async {
      final finte = await apri(tester);

      await tester.tap(find.text(ChallengeSource.archive.label));
      await tester.tap(find.text('10'));
      await tester.pump();
      await tester.tap(find.text('SALVA'));
      await tester.pumpAndSettle();

      expect(finte.nome, 'modificaMissione');
      expect(finte.mandato, {
        'challengeId': 'g1',
        'source': 'archive',
        'maxParticipants': 10,
      });
      expect(find.text('Modificata.'), findsOneWidget);
    });

    testWidgets('senza cambiare niente non chiede niente', (tester) async {
      final finte = await apri(tester);

      await tester.tap(find.text('SALVA'));
      await tester.pumpAndSettle();

      expect(finte.mandato, isNull);
      expect(find.byType(ModificaMissione), findsNothing);
    });

    testWidgets('titolo e premio non si toccano, e la durata si', (
      tester,
    ) async {
      final finte = await apri(tester);

      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text(MediaKind.video.label));
      await tester.tap(find.text('2 ORE'));
      await tester.pump();
      await tester.tap(find.text('SALVA'));
      await tester.pumpAndSettle();

      expect(finte.mandato, {
        'challengeId': 'g1',
        'mediaKind': 'video',
        'minutes': 120,
      });
    });

    testWidgets('se il server dice di no si legge il perche', (tester) async {
      final finte = await apri(tester);

      finte.errore = FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'Qualcuno ha già partecipato: non si può più modificare.',
      );

      await tester.tap(find.text('10'));
      await tester.pump();
      await tester.tap(find.text('SALVA'));
      await tester.pumpAndSettle();

      expect(
        find.text('Qualcuno ha già partecipato: non si può più modificare.'),
        findsOneWidget,
      );
      expect(find.byType(ModificaMissione), findsOneWidget);
    });
  });
}
