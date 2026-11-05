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

  @override
  Future<void> saveConsent({
    required String userId,
    required String version,
    required bool marketing,
    String origine = 'dentro-l-app',
  }) async {
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

/// **I Termini prima di registrarsi o di entrare** (Apple, linea guida 1.2).
///
/// Il difetto che queste prove tengono chiuso: i documenti si accettavano solo dopo
/// la registrazione, in fondo a quattro schermate. Chi rientrava non li vedeva mai.
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

  group('la schermata', () {
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

    testWidgets('si apre sui Termini: non si arriva all\'accesso', (
      tester,
    ) async {
      final container = await apri(tester);

      expect(accetto(), findsOneWidget);
      expect(find.text('EMAIL'), findsNothing);
      expect(find.text('BENTORNATO.', findRichText: true), findsNothing);

      // E nemmeno scrivendo un indirizzo a mano.
      for (final dove in [AppRoutes.auth, AppRoutes.challenges]) {
        container.read(goRouterProvider).go(dove);
        await tester.pumpAndSettle();

        expect(accetto(), findsOneWidget, reason: dove);
        expect(find.text('EMAIL'), findsNothing, reason: dove);
      }

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('senza tutte e quattro le spunte non si passa', (tester) async {
      final container = await apri(tester);

      await tester.tap(accetto());
      await tester.pumpAndSettle();

      expect(find.textContaining('servono le prime quattro'), findsOneWidget);
      expect(container.read(pendingConsentProvider), isNull);

      // Tre su quattro non bastano, qualunque sia quella che manca.
      for (final consenso in LegalConsent.mandatory.take(3)) {
        await spunta(tester, consenso);
      }

      await tester.tap(accetto());
      await tester.pumpAndSettle();

      expect(container.read(pendingConsentProvider), isNull);
      expect(find.text('EMAIL'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('i Termini e l\'informativa si leggono prima di accettare', (
      tester,
    ) async {
      await apri(tester);

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

    testWidgets('accettando si arriva all\'accesso, e si rileggono da li\'', (
      tester,
    ) async {
      final container = await apri(tester);

      for (final consenso in LegalConsent.mandatory) {
        await spunta(tester, consenso);
      }

      await tester.tap(accetto());
      await tester.pumpAndSettle();

      expect(find.text('BENTORNATO.', findRichText: true), findsOneWidget);
      expect(find.text('REGISTRATI'), findsOneWidget);

      final firma = container.read(pendingConsentProvider);

      expect(firma?.version, LegalTexts.version);
      expect(firma?.marketing, isFalse, reason: 'nasce spento');

      await tester.tap(find.text('TERMINI'));
      await tester.pumpAndSettle();

      expect(find.textContaining('TOLLERANZA ZERO'), findsOneWidget);

      await tester.tap(find.text('Chiudi'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('senza le obbligatorie, la facoltativa non apre la porta', (
      tester,
    ) async {
      final container = await apri(tester);

      await spunta(tester, LegalConsent.marketing);
      await tester.tap(accetto());
      await tester.pumpAndSettle();

      expect(container.read(pendingConsentProvider), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('la firma', () {
    late FakeAuthRepository accesso;
    late _RegistroFinto registro;

    ProviderContainer contenitore({
      UserProfile? profiloLetto,
      bool conProfilo = false,
    }) {
      accesso = FakeAuthRepository();
      registro = _RegistroFinto();

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(accesso),
          userProfileRepositoryProvider.overrideWithValue(registro),
          currentUserProfileProvider.overrideWith(
            (ref) => Stream.value(conProfilo ? profiloLetto : null),
          ),
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

    const firmaData = PendingConsent(version: '1.6', marketing: true);

    test(
      'si scrive sul server appena esiste un account, e si consuma',
      () async {
        final container = contenitore();

        container.read(pendingConsentProvider.notifier).state = firmaData;
        accesso.entra(persona);
        await container.pump();
        await Future<void>.delayed(Duration.zero);
        await container.pump();

        expect(registro.firme, hasLength(1));
        expect(registro.firme.single.userId, persona.id);
        expect(registro.firme.single.version, '1.6');
        expect(registro.firme.single.marketing, isTrue);
        expect(registro.firme.single.origine, 'prima-dell-accesso');
        expect(container.read(pendingConsentProvider), isNull);
      },
    );

    test(
      '**chi esce deve riaccettare**: non vale l\'accesso di prima',
      () async {
        final container = contenitore();

        container.read(pendingConsentProvider.notifier).state = firmaData;
        accesso.entra(persona);
        await container.pump();
        await Future<void>.delayed(Duration.zero);
        await container.pump();

        await accesso.signOut();
        await container.pump();

        expect(container.read(sessionLandingRouteProvider), AppRoutes.consents);
      },
    );

    test('la firma non vale per chi entra dopo sullo stesso telefono', () async {
      // Sta in memoria e si consuma: a registrarne una seconda serve una spunta nuova.
      final container = contenitore();

      container.read(pendingConsentProvider.notifier).state = firmaData;
      accesso.entra(persona);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      await accesso.signOut();
      await container.pump();

      accesso.entra(
        const AppUser(id: 'altra', email: 'a@b.it', emailVerified: true),
      );
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      await container.pump();

      expect(registro.firme, hasLength(1));
    });

    test('se non arriva al server, la schermata la richiede', () async {
      final container = contenitore(
        conProfilo: true,
        profiloLetto: profilo(versione: '1.5'),
      );

      registro.guasto = StateError('rete giu');
      container.read(pendingConsentProvider.notifier).state = firmaData;
      accesso.entra(persona);
      await container.read(currentUserProfileProvider.future);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      await container.pump();

      expect(registro.firme, isEmpty);
      expect(container.read(pendingConsentProvider), isNull);
      expect(container.read(sessionLandingRouteProvider), AppRoutes.consents);
    });

    test('mentre arriva al server, i consensi non lampeggiano', () async {
      final container = contenitore(
        conProfilo: true,
        profiloLetto: profilo(versione: '1.5'),
      );

      // Si entra con la firma ancora in viaggio: la scrittura non e' finita.
      accesso.currentUser = persona;
      container.invalidate(authStateProvider);
      container.read(pendingConsentProvider.notifier).state = firmaData;
      await container.read(currentUserProfileProvider.future);
      await container.pump();

      expect(container.read(sessionLandingRouteProvider), AppRoutes.splash);
    });
  });

  group('i testi', () {
    test('i Termini dicono cosa chiede Apple', () {
      final testo = LegalTexts.terms.body;

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
        expect(
          testo.replaceAll(RegExp(r'\s+'), ' '),
          contains(frase),
          reason: frase,
        );
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
