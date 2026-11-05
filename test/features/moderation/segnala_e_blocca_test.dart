import 'dart:async';

import 'package:crasy/core/theme/app_theme.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/moderation/domain/report_reason.dart';
import 'package:crasy/features/moderation/presentation/providers/moderation_providers.dart';
import 'package:crasy/features/moderation/presentation/widgets/report_sheet.dart';
import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le azioni, senza il database: si guarda cosa viene chiesto.
class _AzioniFinte implements ModerationActions {
  final segnalazioni =
      <({ReportTarget target, ReportReason motivo, String nota})>[];
  final blocchi = <ReportTarget>[];
  final sblocchi = <String>[];

  ReportOutcome esito = ReportOutcome.sent;
  Completer<void>? attesa;

  @override
  Future<ReportOutcome> report(
    ReportTarget target, {
    required ReportReason reason,
    String note = '',
  }) async {
    segnalazioni.add((target: target, motivo: reason, nota: note));
    await attesa?.future;

    return esito;
  }

  @override
  Future<bool> block(ReportTarget target) async {
    blocchi.add(target);

    return true;
  }

  @override
  Future<bool> unblock(String otherId) async {
    sblocchi.add(otherId);

    return true;
  }
}

/// Le gare e le foto, contando quante volte si riapre l'ascolto.
class _GareFinte extends Fake implements ChallengeRepository {
  final vive = StreamController<List<Challenge>>.broadcast();
  int ascolti = 0;

  @override
  Stream<List<Challenge>> watchLiveChallenges() {
    ascolti += 1;

    return vive.stream;
  }
}

const _foto = ReportTarget(
  kind: ReportTargetKind.entry,
  reportedUserId: 'mario-id',
  reportedUsername: 'mario',
  challengeId: 'gara',
  entryId: 'mario-id',
);

Challenge _gara(String id, {String autore = '', String vincitore = ''}) =>
    Challenge(
      id: id,
      title: 'Gara $id',
      brief: '',
      prizeCents: 0,
      scope: ChallengeScope.global,
      startsAt: DateTime(2026),
      endsAt: DateTime(2030),
      createdByUserId: autore,
      winnerUserId: vincitore,
    );

void main() {
  group('il menu', () {
    late _AzioniFinte azioni;
    ContentAction? fatto;

    Future<void> apri(
      WidgetTester tester, {
      ReportTarget target = _foto,
      Set<String> bloccati = const {},
    }) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      azioni = _AzioniFinte();
      fatto = null;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            moderationActionsProvider.overrideWithValue(azioni),
            blockedNowProvider.overrideWithValue(bloccati),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () async {
                    fatto = await showContentMenu(context, ref, target);
                  },
                  child: const Text('APRI'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('APRI'));
      await tester.pumpAndSettle();
    }

    testWidgets('sulla foto di un altro: Segnala e Blocca', (tester) async {
      await apri(tester);

      expect(find.text('Segnala'), findsOneWidget);
      expect(find.text('Blocca @mario'), findsOneWidget);
    });

    testWidgets('chi non si sa chi e\' si segnala ma non si blocca', (
      tester,
    ) async {
      await apri(
        tester,
        target: const ReportTarget(
          kind: ReportTargetKind.challenge,
          reportedUserId: '',
          reportedUsername: 'anonimo',
          challengeId: 'gara',
        ),
      );

      expect(find.text('Segnala'), findsOneWidget);
      expect(find.textContaining('Blocca'), findsNothing);
    });

    testWidgets('segnalare: motivo, nota, conferma', (tester) async {
      await apri(tester);
      await tester.tap(find.text('Segnala'));
      await tester.pumpAndSettle();

      // I motivi che chiede Apple, e nessuno parte finche' non si conferma.
      for (final motivo in [
        'Contenuto sessualmente esplicito',
        'Violenza',
        'Molestie o bullismo',
        'Contenuto illegale',
        'Spam o frode',
        'Altro',
      ]) {
        expect(find.text(motivo), findsOneWidget, reason: motivo);
      }

      await tester.tap(find.text('Molestie o bullismo'));
      await tester.pumpAndSettle();

      expect(azioni.segnalazioni, isEmpty);

      await tester.enterText(
        find.byType(TextField),
        '  Mi insulta da giorni  ',
      );
      await tester.tap(find.text('INVIA LA SEGNALAZIONE'));
      await tester.pumpAndSettle();

      expect(azioni.segnalazioni, hasLength(1));
      expect(azioni.segnalazioni.single.motivo, ReportReason.hate);
      expect(azioni.segnalazioni.single.nota.trim(), 'Mi insulta da giorni');
      expect(azioni.segnalazioni.single.target.entryId, 'mario-id');
      expect(fatto, ContentAction.reported);
      expect(find.textContaining('entro 24 ore'), findsOneWidget);
    });

    testWidgets('si puo\' cambiare motivo, e la nota non e\' obbligatoria', (
      tester,
    ) async {
      await apri(tester);
      await tester.tap(find.text('Segnala'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Violenza'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CAMBIA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spam o frode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('INVIA LA SEGNALAZIONE'));
      await tester.pumpAndSettle();

      expect(azioni.segnalazioni.single.motivo, ReportReason.spam);
    });

    testWidgets('due tocchi fanno una segnalazione sola', (tester) async {
      await apri(tester);
      await tester.tap(find.text('Segnala'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Violenza'));
      await tester.pumpAndSettle();

      azioni.attesa = Completer<void>();

      await tester.tap(find.text('INVIA LA SEGNALAZIONE'));
      await tester.pump();

      // Il tasto gira, e sotto il dito non c'e' piu' niente da premere.
      await tester.tap(find.byType(TextField), warnIfMissed: false);
      await tester.pump();

      azioni.attesa!.complete();
      await tester.pumpAndSettle();

      expect(azioni.segnalazioni, hasLength(1));
    });

    testWidgets('gia\' segnalata: lo dice, e non e\' un errore', (
      tester,
    ) async {
      await apri(tester);
      azioni.esito = ReportOutcome.alreadySent;
      await tester.tap(find.text('Segnala'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Violenza'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('INVIA LA SEGNALAZIONE'));
      await tester.pumpAndSettle();

      expect(find.textContaining('avevi già segnalata'), findsOneWidget);
      expect(find.textContaining('non riuscita'), findsNothing);
    });

    testWidgets('se non parte lo dice, e si riprova senza riscrivere', (
      tester,
    ) async {
      await apri(tester);
      azioni.esito = ReportOutcome.failed;
      await tester.tap(find.text('Segnala'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Violenza'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Una nota');
      await tester.tap(find.text('INVIA LA SEGNALAZIONE'));
      await tester.pumpAndSettle();

      expect(find.textContaining('non riuscita'), findsOneWidget);
      expect(find.text('Una nota'), findsOneWidget);
      expect(fatto, isNull);

      azioni.esito = ReportOutcome.sent;
      await tester.tap(find.text('INVIA LA SEGNALAZIONE'));
      await tester.pumpAndSettle();

      expect(fatto, ContentAction.reported);
    });

    testWidgets('bloccare chiede conferma', (tester) async {
      await apri(tester);
      await tester.tap(find.text('Blocca @mario'));
      await tester.pumpAndSettle();

      expect(find.text('Bloccare @mario?'), findsOneWidget);
      expect(azioni.blocchi, isEmpty);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(
        azioni.blocchi,
        isEmpty,
        reason: 'ripensandoci non succede niente',
      );
      expect(fatto, isNull);
    });

    testWidgets('confermando parte il blocco, con da dove e\' partito', (
      tester,
    ) async {
      await apri(tester);
      await tester.tap(find.text('Blocca @mario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blocca'));
      await tester.pumpAndSettle();

      expect(azioni.blocchi.single.reportedUserId, 'mario-id');
      expect(azioni.blocchi.single.kind, ReportTargetKind.entry);
      expect(fatto, ContentAction.blocked);
      expect(find.textContaining('Hai bloccato @mario'), findsOneWidget);
      // E il blocco non si e' portato dietro una segnalazione.
      expect(azioni.segnalazioni, isEmpty);
    });

    testWidgets('chi e\' gia\' bloccato si sblocca da qui', (tester) async {
      await apri(tester, bloccati: const {'mario-id'});

      expect(find.text('Blocca @mario'), findsNothing);

      await tester.tap(find.text('Sblocca @mario'));
      await tester.pumpAndSettle();

      expect(azioni.sblocchi, ['mario-id']);
    });
  });

  group('il feed', () {
    late _GareFinte gare;
    late StreamController<Set<String>> bloccati;
    late ProviderContainer container;

    setUp(() {
      gare = _GareFinte();
      bloccati = StreamController<Set<String>>.broadcast();
      container = ProviderContainer(
        overrides: [
          challengeRepositoryProvider.overrideWithValue(gare),
          currentUserIdProvider.overrideWithValue('io'),
          blockedIdsProvider.overrideWith((ref) => bloccati.stream),
        ],
      );
      addTearDown(() {
        container.dispose();
        gare.vive.close();
        bloccati.close();
      });
    });

    // Dall'elenco dei bloccati alla lista passano due giri: quello del provider che
    // lo guarda, e quello del flusso filtrato. Fra l'uno e l'altro, un tocco e basta.
    Future<void> gira() async {
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(Duration.zero);
        await container.pump();
      }
    }

    List<String> idInHome() => [
      for (final gara
          in container.read(liveChallengesProvider).valueOrNull ??
              const <Challenge>[])
        gara.id,
    ];

    test('chi blocchi sparisce subito, e l\'ascolto non si riapre', () async {
      container.listen(liveChallengesProvider, (_, _) {});
      await gira();

      gare.vive.add([
        _gara('di-mario', autore: 'mario-id'),
        _gara('di-luca', autore: 'luca-id'),
        _gara('anonima'),
      ]);
      await gira();

      expect(idInHome(), ['di-mario', 'di-luca', 'anonima']);

      bloccati.add({'mario-id'});
      await gira();

      expect(idInHome(), ['di-luca', 'anonima']);
      expect(gare.ascolti, 1);

      // Da li' in poi le gare nuove arrivano gia' filtrate.
      gare.vive.add([
        _gara('altra-di-mario', autore: 'mario-id'),
        _gara('nuova', autore: 'luca-id'),
      ]);
      await gira();

      expect(idInHome(), ['nuova']);

      // E sbloccando tornano.
      bloccati.add(const {});
      await gira();

      expect(idInHome(), ['altra-di-mario', 'nuova']);
      expect(gare.ascolti, 1);
    });

    test('il vincitore bloccato sparisce dalle gare, ma non dalle mie', () {
      final bloccato = {'mario-id'};

      expect(
        garaDaNascondere(_gara('a', vincitore: 'mario-id'), bloccato, 'io'),
        isTrue,
      );
      expect(
        garaDaNascondere(_gara('b', autore: 'mario-id'), bloccato, 'io'),
        isTrue,
      );
      expect(
        garaDaNascondere(_gara('c', autore: 'luca-id'), bloccato, 'io'),
        isFalse,
      );
      expect(
        garaDaNascondere(
          _gara('d', autore: 'io', vincitore: 'mario-id'),
          bloccato,
          'io',
        ),
        isFalse,
        reason: 'la missione e\' mia, e l\'ho pagata io',
      );
      expect(garaDaNascondere(_gara('e'), bloccato, 'io'), isFalse);
    });

    test('le foto di chi blocchi non si vedono, le altre si\'', () {
      ChallengeEntry foto(String autore) => ChallengeEntry(
        id: autore,
        challengeId: 'gara',
        userId: autore,
        authorName: autore,
        mediaUrl: 'https://esempio/$autore.jpg',
      );

      expect(
        foto('mario-id').isVisibleTo('io', blocked: {'mario-id'}),
        isFalse,
      );
      expect(foto('luca-id').isVisibleTo('io', blocked: {'mario-id'}), isTrue);
    });
  });

  test(
    'in campanella non resta quello che ha fatto chi hai bloccato',
    () async {
      final container = ProviderContainer(
        overrides: [
          storedNotificationsProvider.overrideWith(
            (ref) => Stream.value(const [
              AppNotification(
                id: 'di-mario',
                kind: NotificationKind.fire,
                actorId: 'mario-id',
                actorUsername: 'mario',
              ),
              AppNotification(
                id: 'di-luca',
                kind: NotificationKind.fire,
                actorId: 'luca-id',
                actorUsername: 'luca',
              ),
              // Quelle senza nessuno dietro restano: le scrive il server.
              AppNotification(id: 'tolta', kind: NotificationKind.removed),
            ]),
          ),
          myEntriesProvider.overrideWith((ref) => Stream.value(const [])),
          endedChallengesProvider.overrideWith((ref) => Stream.value(const [])),
          revealsSeenProvider.overrideWith(
            (ref) => Stream.value(const <String>{}),
          ),
          blockedNowProvider.overrideWithValue(const {'mario-id'}),
        ],
      );

      addTearDown(container.dispose);

      container.listen(notificationsProvider, (_, _) {});
      await container.read(storedNotificationsProvider.future);

      expect(
        container.read(notificationsProvider).map((n) => n.id),
        unorderedEquals(['di-luca', 'tolta']),
      );
    },
  );

  group('i motivi', () {
    test('i nomi non cambiano: sono scritti sul database e nelle regole', () {
      expect(ReportReason.values.map((r) => r.name).toSet(), {
        'danger',
        'sexual',
        'violence',
        'hate',
        'illegal',
        'spam',
        'minor',
        'other',
      });
      expect(ReportReason.fromName('sconosciuto'), ReportReason.other);
    });

    test('solo una foto promette di sparire a chi la segnala', () {
      expect(
        fraseDopoLaSegnalazione(ReportTargetKind.entry, ReportOutcome.sent),
        contains('non la vedi più'),
      );

      for (final kind in [ReportTargetKind.user, ReportTargetKind.challenge]) {
        expect(
          fraseDopoLaSegnalazione(kind, ReportOutcome.sent),
          isNot(contains('non la vedi')),
        );
      }
    });

    test('la foto si segnala a nome di chi l\'ha mandata', () {
      const foto = ChallengeEntry(
        id: 'autore',
        challengeId: 'gara',
        userId: 'autore',
        authorName: 'mario',
        mediaUrl: 'https://esempio/a.jpg',
        challengeTitle: 'Titolo',
      );

      final target = ReportTarget.diFoto(foto);

      expect(target.reportedUserId, target.entryId);
      expect(target.reportedUsername, 'mario');
      expect(target.challengeTitle, 'Titolo');
    });
  });
}
