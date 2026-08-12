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
  const user = AppUser(id: 'user-1', email: 'test@example.com');

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

  test('chi non ha fatto l\'accesso atterra sulle challenge', () async {
    final container = containerWith(FakeAuthRepository());

    await container.pump();

    expect(container.read(sessionLandingRouteProvider), AppRoutes.challenges);
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
            const UserProfile(
              id: 'user-1',
              username: 'martina',
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
            const UserProfile(
              id: 'user-1',
              username: 'martina',
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

  test('le sezioni aperte agli ospiti non comprendono il profilo', () {
    expect(AppRoutes.guestAllowed, contains(AppRoutes.challenges));
    expect(AppRoutes.guestAllowed, contains(AppRoutes.winners));
    expect(AppRoutes.guestAllowed, isNot(contains(AppRoutes.profile)));
    expect(AppRoutes.guestAllowed, isNot(contains(AppRoutes.create)));
  });
}
