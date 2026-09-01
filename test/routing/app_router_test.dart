import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/legal/legal_documents.dart';
import 'package:crasy/features/auth/domain/entities/app_user.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:crasy/routing/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth_repository.dart';

void main() {
  const user = AppUser(
    id: 'user-1',
    email: 'test@example.com',
    emailVerified: true,
  );

  ProviderContainer containerWith(
    FakeAuthRepository authRepository, {
    List<Override> overrides = const [],
  }) {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        ...overrides,
      ],
    );

    addTearDown(() {
      authRepository.dispose();
      container.dispose();
    });

    return container;
  }

  test('chi non ha fatto l\'accesso resta sulla registrazione', () async {
    final container = containerWith(FakeAuthRepository());

    await container.pump();

    expect(container.read(sessionLandingRouteProvider), AppRoutes.auth);
  });

  test('con l\'email non confermata si resta al muro della verifica', () async {
    // Senza un indirizzo vero non c'e' modo di far avere a nessuno il premio
    // che ha vinto: la conferma non e' un formalismo.
    final container = containerWith(
      FakeAuthRepository(
        currentUser: const AppUser(id: 'user-1', email: 'test@example.com'),
      ),
    );

    await container.pump();

    expect(container.read(sessionLandingRouteProvider), AppRoutes.verifyEmail);
  });

  test('un profilo senza data di nascita torna all\'onboarding', () async {
    // Chi si era registrato prima che l'eta' venisse chiesta non puo' restare
    // dentro senza averla dichiarata: e' l'unica cosa che tiene fuori i
    // minorenni.
    final container = containerWith(
      FakeAuthRepository(currentUser: user),
      overrides: [
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(
            const UserProfile(
              id: 'user-1',
              username: 'martina',
              birthDate: null,
              createdAt: null,
              updatedAt: null,
              onboardingCompleted: true,
              // Il muro del telefono viene prima: senza questo, la prova si
              // fermerebbe li' e non verificherebbe piu' i consensi.
              phone: '+393330000000',
            ),
          ),
        ),
      ],
    );

    await container.read(currentUserProfileProvider.future);
    await container.pump();

    expect(container.read(sessionLandingRouteProvider), AppRoutes.onboarding);
  });

  test('senza profilo si passa dall\'onboarding', () async {
    final container = containerWith(
      FakeAuthRepository(currentUser: user),
      overrides: [
        currentUserProfileProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );

    await container.read(currentUserProfileProvider.future);
    await container.pump();

    expect(container.read(sessionLandingRouteProvider), AppRoutes.onboarding);
  });

  test('un onboarding lasciato a meta\' riporta all\'onboarding', () async {
    final container = containerWith(
      FakeAuthRepository(currentUser: user),
      overrides: [
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(
            UserProfile(
              id: 'user-1',
              username: 'martina',
              birthDate: DateTime(2000, 1, 1),
              createdAt: null,
              updatedAt: null,
              onboardingCompleted: false,
            ),
          ),
        ),
      ],
    );

    await container.read(currentUserProfileProvider.future);
    await container.pump();

    expect(container.read(sessionLandingRouteProvider), AppRoutes.onboarding);
  });

  test('con l\'onboarding fatto si atterra sulle challenge', () async {
    final container = containerWith(
      FakeAuthRepository(currentUser: user),
      overrides: [
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(
            UserProfile(
              id: 'user-1',
              username: 'martina',
              birthDate: DateTime(2000, 1, 1),
              createdAt: null,
              updatedAt: null,
              onboardingCompleted: true,
              legalVersion: LegalTexts.version,
              legalAcceptedAt: DateTime(2026),
              tutorialSeen: true,
              phone: '+393330000000',
            ),
          ),
        ),
      ],
    );

    await container.read(currentUserProfileProvider.future);
    await container.pump();

    expect(container.read(sessionLandingRouteProvider), AppRoutes.challenges);
  });

  test('senza numero verificato si passa dalla verifica del telefono', () async {
    final container = containerWith(
      FakeAuthRepository(currentUser: user),
      overrides: [
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(
            UserProfile(
              id: 'user-1',
              username: 'martina',
              birthDate: DateTime(2000, 1, 1),
              createdAt: null,
              updatedAt: null,
              onboardingCompleted: true,
              legalVersion: LegalTexts.version,
              legalAcceptedAt: DateTime(2026),
              tutorialSeen: true,
            ),
          ),
        ),
      ],
    );

    await container.read(currentUserProfileProvider.future);
    await container.pump();

    // **Prima dei consensi**, non dopo: e' un requisito di identita'. A
    // decidere chi vince sono i voti, e sulle gare girano dei soldi: finche'
    // iscriversi costa un indirizzo email, cinque profili valgono cinque voti.
    expect(container.read(sessionLandingRouteProvider), AppRoutes.verifyPhone);
  });

  test('senza sessione completa non si guarda niente', () {
    // Non e' una scelta di prodotto ma una conseguenza di cosa e' CRASY: qui
    // girano soldi, si vota chi li vince, e si entra da maggiorenni. Nessuna
    // delle tre regge se chi guarda non ha un nome e un indirizzo confermato.
    expect(AppRoutes.openToEveryone, contains(AppRoutes.auth));
    expect(AppRoutes.openToEveryone, isNot(contains(AppRoutes.challenges)));
    expect(AppRoutes.openToEveryone, isNot(contains(AppRoutes.winners)));
    expect(AppRoutes.openToEveryone, isNot(contains(AppRoutes.profile)));
  });

  test('senza i consensi non si entra', () async {
    // **Un profilo a posto in tutto tranne i consensi resta fuori.** E' la
    // differenza fra avere un'informativa e averla fatta leggere: senza questa
    // porta, il testo esisterebbe e non l'avrebbe visto nessuno.
    final container = containerWith(
      FakeAuthRepository(currentUser: user),
      overrides: [
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(
            UserProfile(
              id: 'user-1',
              username: 'martina',
              birthDate: DateTime(2000, 1, 1),
              createdAt: null,
              updatedAt: null,
              onboardingCompleted: true,
              // Il muro del telefono viene prima: senza questo, la prova si
              // fermerebbe li' e non verificherebbe piu' i consensi.
              phone: '+393330000000',
            ),
          ),
        ),
      ],
    );

    await container.read(currentUserProfileProvider.future);
    await container.pump();

    expect(container.read(sessionLandingRouteProvider), AppRoutes.consents);
  });

  test('una versione vecchia non basta', () async {
    // Cambiando i testi cambia la versione, e chi aveva accettato quella di
    // prima **ripassa dalla porta**. E' il meccanismo che rende vera la frase
    // "ti verra' chiesto di prenderne visione".
    final container = containerWith(
      FakeAuthRepository(currentUser: user),
      overrides: [
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(
            UserProfile(
              id: 'user-1',
              username: 'martina',
              birthDate: DateTime(2000, 1, 1),
              createdAt: null,
              updatedAt: null,
              onboardingCompleted: true,
              legalVersion: 'una-versione-di-due-anni-fa',
              legalAcceptedAt: DateTime(2024),
              phone: '+393330000000',
            ),
          ),
        ),
      ],
    );

    await container.read(currentUserProfileProvider.future);
    await container.pump();

    expect(container.read(sessionLandingRouteProvider), AppRoutes.consents);
  });

  test('il giro di presentazione si fa prima di entrare', () async {
    // **Le quattro regole prima dell'elenco delle gare.** Senza, la prima
    // schermata e' una lista e nessuno ha detto quante fiamme si hanno: si
    // scopre sbagliando, e sbagliare qui costa una partecipazione che torna
    // solo domani.
    final container = containerWith(
      FakeAuthRepository(currentUser: user),
      overrides: [
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(
            UserProfile(
              id: 'user-1',
              username: 'martina',
              birthDate: DateTime(2000, 1, 1),
              createdAt: null,
              updatedAt: null,
              onboardingCompleted: true,
              legalVersion: LegalTexts.version,
              legalAcceptedAt: DateTime(2026),
              phone: '+393330000000',
            ),
          ),
        ),
      ],
    );

    await container.read(currentUserProfileProvider.future);
    await container.pump();

    expect(container.read(sessionLandingRouteProvider), AppRoutes.tutorial);
  });
}
