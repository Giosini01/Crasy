import 'dart:async';

import 'package:crasy/app.dart';
import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/legal/legal_documents.dart';
import 'package:crasy/core/widgets/opening_curtain.dart';
import 'package:crasy/features/auth/domain/entities/app_user.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/legal/presentation/controllers/consent_controller.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:crasy/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:crasy/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';

/// Il registro dei consensi, senza il database.
class _RegistroFinto extends Fake implements UserProfileRepository {
  final firme =
      <({String userId, String version, bool marketing, String origine})>[];

  Object? guasto;

  /// Se c'e', la scrittura aspetta qui: serve a guardare cosa succede intanto.
  Completer<void>? attesa;

  @override
  Future<void> saveConsent({
    required String userId,
    required String version,
    required bool marketing,
    String origine = 'dentro-l-app',
  }) async {
    await attesa?.future;

    if (guasto case final errore?) {
      throw errore;
    }

    firme.add((
      userId: userId,
      version: version,
      marketing: marketing,
      origine: origine,
    ));
  }
}

/// **I Termini si accettano una volta sola, quando ci si registra, prima di entrare**
/// (Apple, linea guida 1.2).
///
/// I due difetti che queste prove tengono chiusi. Prima i documenti si accettavano
/// solo dopo la registrazione, in fondo a quattro schermate. E per un giorno si sono
/// richiesti a ogni accesso: chi li aveva gia' accettati doveva rifare le spunte ogni
/// volta che rientrava.
void main() {
  const persona = AppUser(
    id: 'persona-1',
    email: 'test@esempio.it',
    emailVerified: true,
  );

  UserProfile profilo({String versione = ''}) => UserProfile(
    id: persona.id,
    username: 'martina',
    birthDate: DateTime(2000),
    createdAt: null,
    updatedAt: null,
    onboardingCompleted: true,
    phoneVerified: true,
    contactsPromptSeen: true,
    tutorialSeen: true,
    legalVersion: versione,
  );

  group('registrarsi', () {
    Future<ProviderContainer> apri(WidgetTester tester) async {
      // Tutto a schermo: qui si prova cosa si puo' fare, non come si scorre.
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final accesso = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(accesso),
          openingCurtainProvider.overrideWithValue(false),
        ],
      );

      addTearDown(() {
        accesso.dispose();
        container.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CrasyApp(),
        ),
      );
      await tester.pumpAndSettle();

      return container;
    }

    Future<void> spunta(WidgetTester tester, LegalConsent consenso) async {
      await tester.tap(find.text(consenso.label));
      await tester.pump(const Duration(milliseconds: 200));
    }

    Finder accetto() => find.text('ACCETTO E CONTINUO');

    Future<void> toccaRegistrati(WidgetTester tester) async {
      await tester.tap(find.text('REGISTRATI'));
      await tester.pumpAndSettle();
    }

    testWidgets('chi entra non vede i Termini: si apre sull\'accesso', (
      tester,
    ) async {
      await apri(tester);

      expect(find.text('BENTORNATO.', findRichText: true), findsOneWidget);
      expect(find.text('ENTRA'), findsOneWidget);
      expect(accetto(), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('il modulo di registrazione si apre solo dopo i Termini', (
      tester,
    ) async {
      final container = await apri(tester);

      await toccaRegistrati(tester);

      expect(accetto(), findsOneWidget);
      expect(find.text('CREA ACCOUNT'), findsNothing);
      expect(container.read(pendingConsentProvider), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('senza tutte e quattro le spunte non si passa', (tester) async {
      final container = await apri(tester);

      await toccaRegistrati(tester);
      await tester.tap(accetto());
      await tester.pumpAndSettle();

      expect(find.textContaining('servono le prime quattro'), findsOneWidget);
      expect(container.read(pendingConsentProvider), isNull);

      // Tre su quattro non bastano, e nemmeno la facoltativa.
      for (final consenso in LegalConsent.mandatory.take(3)) {
        await spunta(tester, consenso);
      }

      await spunta(tester, LegalConsent.marketing);
      await tester.tap(accetto());
      await tester.pumpAndSettle();

      expect(container.read(pendingConsentProvider), isNull);
      expect(find.text('CREA ACCOUNT'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('i documenti si leggono prima di accettare', (tester) async {
      await apri(tester);
      await toccaRegistrati(tester);

      await tester.tap(find.text('LEGGI: TERMINI E CONDIZIONI'));
      await tester.pumpAndSettle();

      expect(find.textContaining('TOLLERANZA ZERO'), findsOneWidget);

      await tester.tap(find.text('Chiudi'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('LEGGI: INFORMATIVA PRIVACY'));
      await tester.pumpAndSettle();

      expect(find.textContaining('NESSUN TRACCIAMENTO'), findsOneWidget);

      await tester.tap(find.text('Chiudi'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('accettando si arriva al modulo, e non si richiedono piu\'', (
      tester,
    ) async {
      final container = await apri(tester);

      await toccaRegistrati(tester);

      for (final consenso in LegalConsent.mandatory) {
        await spunta(tester, consenso);
      }

      await tester.tap(accetto());
      await tester.pumpAndSettle();

      expect(find.text('CREA ACCOUNT'), findsOneWidget);
      expect(accetto(), findsNothing);

      final firma = container.read(pendingConsentProvider);

      expect(firma?.version, LegalTexts.version);
      expect(firma?.marketing, isFalse, reason: 'nasce spento');

      // Tornando all'accesso e ripassando, non si rifanno le spunte.
      await tester.tap(find.text('ENTRA').last);
      await tester.pumpAndSettle();
      await toccaRegistrati(tester);

      expect(accetto(), findsNothing);
      expect(find.text('CREA ACCOUNT'), findsOneWidget);

      // E da qui si rileggono.
      await tester.tap(find.text('TERMINI'));
      await tester.pumpAndSettle();

      expect(find.textContaining('TOLLERANZA ZERO'), findsOneWidget);

      await tester.tap(find.text('Chiudi'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('tornando indietro dai Termini non ci si registra', (
      tester,
    ) async {
      final container = await apri(tester);

      await toccaRegistrati(tester);
      await tester.tap(find.text('TORNA INDIETRO'));
      await tester.pumpAndSettle();

      expect(find.text('BENTORNATO.', findRichText: true), findsOneWidget);
      expect(find.text('CREA ACCOUNT'), findsNothing);
      expect(container.read(pendingConsentProvider), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('la firma', () {
    late FakeAuthRepository accesso;
    late _RegistroFinto registro;

    ProviderContainer contenitore({UserProfile? letto}) {
      accesso = FakeAuthRepository();
      registro = _RegistroFinto();

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(accesso),
          userProfileRepositoryProvider.overrideWithValue(registro),
          currentUserProfileProvider.overrideWith((ref) => Stream.value(letto)),
        ],
      );

      addTearDown(() {
        accesso.dispose();
        container.dispose();
      });

      // Come in `CrasyApp`: resta accesa per tutta la vita dell'app.
      container.listen(consentSyncProvider, (_, _) {});

      return container;
    }

    Future<void> gira(ProviderContainer container) async {
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      await container.pump();
    }

    const firmaData = PendingConsent(version: '1.6', marketing: true);

    test(
      'si scrive sul server appena esiste l\'account, e si consuma',
      () async {
        final container = contenitore();

        container.read(pendingConsentProvider.notifier).state = firmaData;
        accesso.entra(persona);
        await gira(container);

        expect(registro.firme, hasLength(1));
        expect(registro.firme.single.userId, persona.id);
        expect(registro.firme.single.version, '1.6');
        expect(registro.firme.single.marketing, isTrue);
        expect(registro.firme.single.origine, 'prima-della-registrazione');
        expect(container.read(pendingConsentProvider), isNull);
      },
    );

    test('**una volta sola**: chi esce e rientra non la rifa\'', () async {
      final container = contenitore(
        letto: profilo(versione: LegalTexts.version),
      );

      accesso.entra(persona);
      await container.read(currentUserProfileProvider.future);
      await gira(container);

      expect(container.read(sessionLandingRouteProvider), AppRoutes.challenges);

      await accesso.signOut();
      await gira(container);

      // Fuori si torna all'accesso, non ai Termini.
      expect(container.read(sessionLandingRouteProvider), AppRoutes.auth);

      accesso.entra(persona);
      await gira(container);

      expect(container.read(sessionLandingRouteProvider), AppRoutes.challenges);
      expect(registro.firme, isEmpty, reason: 'nessuna firma in piu\'');
    });

    test(
      'un account senza firma non entra: un vecchio accesso non vale',
      () async {
        final container = contenitore(letto: profilo());

        accesso.entra(persona);
        await container.read(currentUserProfileProvider.future);
        await gira(container);

        expect(container.read(sessionLandingRouteProvider), AppRoutes.consents);
      },
    );

    test('nemmeno chi aveva firmato una versione vecchia', () async {
      final container = contenitore(letto: profilo(versione: '1.5'));

      accesso.entra(persona);
      await container.read(currentUserProfileProvider.future);
      await gira(container);

      expect(container.read(sessionLandingRouteProvider), AppRoutes.consents);
    });

    test('la firma di uno non vale per chi si registra dopo', () async {
      // Sta in memoria e si consuma: a registrarne una seconda serve una spunta nuova.
      final container = contenitore();

      container.read(pendingConsentProvider.notifier).state = firmaData;
      accesso.entra(persona);
      await gira(container);
      await accesso.signOut();
      await gira(container);

      expect(container.read(pendingConsentProvider), isNull);

      accesso.entra(
        const AppUser(id: 'altra', email: 'a@b.it', emailVerified: true),
      );
      await gira(container);

      expect(registro.firme, hasLength(1));
    });

    test('se non arriva al server, la schermata la richiede', () async {
      final container = contenitore(letto: profilo(versione: '1.5'));

      registro.guasto = StateError('rete giu');
      container.read(pendingConsentProvider.notifier).state = firmaData;
      accesso.entra(persona);
      await container.read(currentUserProfileProvider.future);
      await gira(container);

      expect(registro.firme, isEmpty);
      expect(container.read(pendingConsentProvider), isNull);
      expect(container.read(sessionLandingRouteProvider), AppRoutes.consents);
    });

    test('mentre arriva al server, i consensi non lampeggiano', () async {
      final container = contenitore(letto: profilo(versione: '1.5'));

      registro.attesa = Completer<void>();
      addTearDown(registro.attesa!.complete);

      container.read(pendingConsentProvider.notifier).state = firmaData;
      accesso.entra(persona);
      await container.read(currentUserProfileProvider.future);
      await gira(container);

      expect(container.read(sessionLandingRouteProvider), AppRoutes.splash);
    });
  });

  group('i testi', () {
    test('i Termini dicono cosa chiede Apple', () {
      final testo = LegalTexts.terms.body.replaceAll(RegExp(r'\s+'), ' ');

      for (final frase in [
        'TOLLERANZA ZERO',
        'offensivi',
        'illegali',
        'sessualmente espliciti',
        'violenti',
        'molestare',
        'minacciare',
        'discriminare',
        'uso improprio della piattaforma',
        'rimuovere i contenuti',
        'sospeso o eliminato',
        'segnalare',
        'bloccare',
        'entro 24 ore',
      ]) {
        expect(testo, contains(frase), reason: frase);
      }
    });

    test('alzare i testi vuol dire richiedere il consenso', () {
      expect(LegalTexts.version, '1.6');
      expect(profilo(versione: '1.5').acceptedLegalVersion('1.6'), isFalse);
      expect(profilo(versione: '1.6').acceptedLegalVersion('1.6'), isTrue);
    });

    test('resta una scelta sola facoltativa, e non parla di pubblicita\'', () {
      expect(LegalConsent.optional, [LegalConsent.marketing]);
      expect(LegalConsent.mandatory, hasLength(4));

      for (final consenso in LegalConsent.values) {
        expect(
          consenso.explanation.toLowerCase(),
          isNot(contains('pubblicit')),
        );
        expect(consenso.explanation.toLowerCase(), isNot(contains('gusti')));
      }
    });

    test(
      'chi riceve foto e testi per il controllo automatico e\' scritto chiaro',
      () {
        // La 5.1.2(i) chiede di dire quando i dati vanno a un'intelligenza artificiale
        // di terzi, e di averne il permesso: sta nella spunta, non solo nel documento.
        final spunta = LegalConsent.content.explanation;

        expect(spunta, contains('OpenAI'));
        expect(spunta, contains('Google'));
      },
    );
  });
}
