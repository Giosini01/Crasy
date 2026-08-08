import 'dart:async';

import 'package:app_incontri/app.dart';
import 'package:app_incontri/features/auth/domain/entities/app_user.dart';
import 'package:app_incontri/features/auth/domain/repositories/auth_repository.dart';
import 'package:app_incontri/features/auth/presentation/providers/auth_providers.dart';
import 'package:app_incontri/features/profile/domain/entities/user_profile.dart';
import 'package:app_incontri/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DailyApp renders auth flow for unauthenticated users', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
    );
    addTearDown(() async {
      authRepository.dispose();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DailyApp()),
    );

    await tester.pumpAndSettle();

    expect(find.text('Daily'), findsOneWidget);
    expect(
      find.textContaining('Entra e scopri chi c\'e oggi.'),
      findsOneWidget,
    );
  });

  testWidgets('DailyApp renders discover flow for completed users', (
    tester,
  ) async {
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
              birthDate: DateTime(1994, 3, 10),
              gender: GenderIdentity.man,
              interestedIn: InterestPreference.women,
              city: 'Milano',
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

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DailyApp()),
    );

    await tester.pumpAndSettle();

    expect(
      find.textContaining('Qui vedrai soltanto chi e presente oggi'),
      findsOneWidget,
    );
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
