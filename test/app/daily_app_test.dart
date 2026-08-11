import 'dart:async';

import 'package:app_incontri/app.dart';
import 'package:app_incontri/features/auth/domain/entities/app_user.dart';
import 'package:app_incontri/features/auth/domain/repositories/auth_repository.dart';
import 'package:app_incontri/features/auth/presentation/providers/auth_providers.dart';
import 'package:app_incontri/features/daily/domain/entities/daily_access.dart';
import 'package:app_incontri/features/daily/presentation/providers/daily_providers.dart';
import 'package:app_incontri/features/feed/presentation/providers/feed_providers.dart';
import 'package:app_incontri/features/profile/domain/entities/user_profile.dart';
import 'package:app_incontri/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final completedProfile = UserProfile(
    id: 'user-1',
    name: 'Luca',
    birthDate: DateTime(1994, 3, 10),
    gender: GenderIdentity.man,
    interestedIn: InterestPreference.women,
    createdAt: DateTime(2026, 8, 8),
    updatedAt: DateTime(2026, 8, 8),
    onboardingCompleted: true,
  );

  // Lo stato di accesso si inietta a mano: dipendesse dall'orologio, l'esito
  // dei test cambierebbe a seconda dell'ora in cui li si lancia.
  final windowOpenNoDaily = DailyAccess(
    openSlot: 0,
    boundary: DateTime(2026, 8, 9, 22),
    usedToday: 0,
    hasActiveDaily: false,
  );

  final dailyPublished = DailyAccess(
    openSlot: 0,
    boundary: DateTime(2026, 8, 9, 22),
    usedToday: 1,
    hasActiveDaily: true,
  );

  testWidgets('RawsyApp renders auth flow for unauthenticated users', (
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
      UncontrolledProviderScope(container: container, child: const RawsyApp()),
    );

    await tester.pumpAndSettle();

    // Il logotipo e' un'immagine, non una scritta: si cerca per etichetta.
    expect(find.bySemanticsLabel('Rawsy'), findsOneWidget);
    expect(
      find.textContaining('Entra e scopri chi c\'e oggi.'),
      findsOneWidget,
    );
  });

  testWidgets('discover stays locked until the first Daily of the day', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository(
      currentUser: const AppUser(id: 'user-1', email: 'test@example.com'),
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(completedProfile),
        ),
        dailyAccessProvider.overrideWithValue(windowOpenNoDaily),
        // Senza nessuno in anteprima il Per Te mostra la spiegazione, non
        // l'assaggio: e' il caso che questo test vuole coprire.
        todayFeedProvider.overrideWith((ref) => Stream.value(const [])),
        decidedUserIdsProvider.overrideWith(
          (ref) => Stream.value(const <String>{}),
        ),
      ],
    );
    addTearDown(() async {
      authRepository.dispose();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const RawsyApp()),
    );

    await tester.pumpAndSettle();

    expect(find.text('Prima tocca a te.'), findsOneWidget);
    expect(find.text('Scatta la tua Istantanea'), findsOneWidget);
    expect(
      find.textContaining('Qui vedrai soltanto chi e presente oggi'),
      findsNothing,
    );
  });

  testWidgets('discover opens once a Daily is published', (tester) async {
    final authRepository = _FakeAuthRepository(
      currentUser: const AppUser(id: 'user-1', email: 'test@example.com'),
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(completedProfile),
        ),
        dailyAccessProvider.overrideWithValue(dailyPublished),
        todayFeedProvider.overrideWith((ref) => Stream.value(const [])),
        decidedUserIdsProvider.overrideWith(
          (ref) => Stream.value(const <String>{}),
        ),
      ],
    );
    addTearDown(() async {
      authRepository.dispose();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const RawsyApp()),
    );

    await tester.pumpAndSettle();

    expect(find.text('Prima tocca a te.'), findsNothing);
    expect(find.text('Ancora nessuno, per oggi.'), findsOneWidget);
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




