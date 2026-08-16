import 'package:crasy/core/constants/app_routes.dart';
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
            ),
          ),
        ),
      ],
    );

    await container.read(currentUserProfileProvider.future);
    await container.pump();

    expect(container.read(sessionLandingRouteProvider), AppRoutes.challenges);
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
}
