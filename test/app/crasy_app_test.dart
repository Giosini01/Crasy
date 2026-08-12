import 'package:crasy/app.dart';
import 'package:crasy/features/auth/domain/entities/app_user.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth_repository.dart';

void main() {
  /// Le schermate con il countdown tengono un timer che batte ogni secondo.
  /// Smontare l'albero alla fine lo ferma: senza, il test finisce lasciando un
  /// timer vivo e il framework lo segnala come errore.
  Future<void> tearDownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('senza accesso si aprono direttamente le challenge', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
    );
    addTearDown(() {
      authRepository.dispose();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CrasyApp()),
    );
    await tester.pumpAndSettle();

    // Senza Firebase configurato non c'e' nessuna challenge, e non e' un
    // errore: l'app nasce vuota e si riempie quando qualcuno ne lancia una.
    expect(find.text('NESSUNA CHALLENGE APERTA'), findsOneWidget);

    // Nessuna traccia della vecchia app di incontri.
    expect(find.text('Match'), findsNothing);
    expect(find.text('Istantanea'), findsNothing);

    await tearDownTree(tester);
  });

  testWidgets('una challenge lanciata compare in home con premio e tempo', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
    );
    addTearDown(() {
      authRepository.dispose();
      container.dispose();
    });

    final now = DateTime.now();
    await container
        .read(sampleChallengeRepositoryProvider)
        .createChallenge(
          Challenge(
            id: '',
            title: 'Do something crazy',
            brief: 'Fai la foto piu\' assurda che riesci.',
            prizeCents: 50000,
            scope: ChallengeScope.global,
            createdByUsername: 'crasy',
            startsAt: now.subtract(const Duration(hours: 1)),
            endsAt: now.add(const Duration(hours: 4)),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CrasyApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('€500'), findsOneWidget);
    expect(find.text('DO SOMETHING CRAZY'), findsOneWidget);
    expect(find.text('GLOBAL'), findsOneWidget);
    expect(find.textContaining('0 partecipanti'), findsOneWidget);
    expect(find.text('Lanciata da @crasy'), findsOneWidget);
    expect(find.text('PARTECIPA'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('chi ha l\'accesso ma non il profilo finisce sull\'onboarding', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository(
      currentUser: const AppUser(id: 'user-1', email: 'test@example.com'),
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        currentUserProfileProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    addTearDown(() {
      authRepository.dispose();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CrasyApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('COME TI\nCHIAMANO'), findsOneWidget);
    expect(find.text('ENTRA IN CRASY'), findsOneWidget);

    await tearDownTree(tester);
  });
}
