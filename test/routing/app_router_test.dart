import 'dart:async';

import 'package:app_incontri/core/constants/app_routes.dart';
import 'package:app_incontri/features/auth/domain/entities/app_user.dart';
import 'package:app_incontri/features/auth/domain/repositories/auth_repository.dart';
import 'package:app_incontri/features/auth/presentation/providers/auth_providers.dart';
import 'package:app_incontri/features/profile/domain/entities/user_profile.dart';
import 'package:app_incontri/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:app_incontri/routing/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unauthenticated users land on auth', () async {
    final authRepository = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
    );
    addTearDown(() async {
      authRepository.dispose();
      container.dispose();
    });

    await container.pump();

    expect(container.read(sessionLandingRouteProvider), AppRoutes.auth);
  });

  test('authenticated users without profile land on onboarding', () async {
    final authRepository = _FakeAuthRepository(
      currentUser: const AppUser(id: 'user-1', email: 'test@example.com'),
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        currentUserProfileProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    addTearDown(() async {
      authRepository.dispose();
      container.dispose();
    });

    await container.read(currentUserProfileProvider.future);
    await container.pump();

    expect(container.read(sessionLandingRouteProvider), AppRoutes.onboarding);
  });

  test('authenticated users with completed onboarding land on home', () async {
    final authRepository = _FakeAuthRepository(
      currentUser: const AppUser(id: 'user-1', email: 'test@example.com'),
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(
            UserProfile(
              id: 'user-1',
              name: 'Luca',
              birthDate: DateTime(1996, 8, 8),
              gender: GenderIdentity.man,
              interestedIn: InterestPreference.women,
              createdAt: DateTime(2026, 8, 8),
              updatedAt: DateTime(2026, 8, 8),
              onboardingCompleted: true,
            ),
          ),
        ),
      ],
    );
    addTearDown(() async {
      authRepository.dispose();
      container.dispose();
    });

    await container.read(currentUserProfileProvider.future);
    await container.pump();

    expect(container.read(sessionLandingRouteProvider), AppRoutes.discover);
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.currentUser});

  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();

  @override
  AppUser? currentUser;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield currentUser;
    yield* _controller.stream;
  }

  void dispose() {
    _controller.close();
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
    _controller.add(null);
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }
}

