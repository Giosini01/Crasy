import 'package:crasy/app.dart';
import 'package:crasy/features/auth/domain/entities/app_user.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth_repository.dart';

void main() {
  const verifiedUser = AppUser(
    id: 'user-1',
    email: 'test@example.com',
    emailVerified: true,
  );

  final completeProfile = UserProfile(
    id: 'user-1',
    username: 'martina',
    birthDate: DateTime(2000, 1, 1),
    createdAt: null,
    updatedAt: null,
    onboardingCompleted: true,
  );

  /// Le schermate con il countdown tengono un timer che batte ogni secondo.
  /// Smontare l'albero alla fine lo ferma: senza, il test finisce lasciando un
  /// timer vivo e il framework lo segnala come errore.
  Future<void> tearDownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    required FakeAuthRepository authRepository,
    List<Override> overrides = const [],
  }) async {
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

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CrasyApp()),
    );
    await tester.pumpAndSettle();

    return container;
  }

  testWidgets('senza accesso non si vede niente, solo la registrazione', (
    tester,
  ) async {
    await pumpApp(tester, authRepository: FakeAuthRepository());

    // Non e' una scelta di gusto: qui girano soldi, si vota chi li vince, e si
    // entra da maggiorenni. Le foto che la gente manda sono di persone vere che
    // si mettono in gioco, e non stanno in una vetrina aperta a chiunque passi.
    // I titoli sono testo composto — parola nera piu' punto rosso — quindi non
    // sono un `Text` semplice: `findRichText` li cerca per quello che rendono.
    expect(
      find.text('CREA IL TUO\nACCOUNT.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('CHALLENGE'), findsNothing);
    expect(find.text('NESSUNA CHALLENGE APERTA'), findsNothing);

    await tearDownTree(tester);
  });

  testWidgets('con l\'email non confermata si resta fuori', (tester) async {
    await pumpApp(
      tester,
      authRepository: FakeAuthRepository(
        currentUser: const AppUser(id: 'user-1', email: 'test@example.com'),
      ),
    );

    expect(
      find.text('CONFERMA\nLA TUA EMAIL.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('HO CONFERMATO'), findsOneWidget);
    // Nemmeno qui si vedono le challenge.
    expect(find.text('NESSUNA CHALLENGE APERTA'), findsNothing);

    await tearDownTree(tester);
  });

  testWidgets(
    'con l\'email confermata ma senza profilo si va all\'onboarding',
    (tester) async {
      await pumpApp(
        tester,
        authRepository: FakeAuthRepository(currentUser: verifiedUser),
        overrides: [
          currentUserProfileProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );

      expect(
        find.text('COME TI\nCHIAMANO.', findRichText: true),
        findsOneWidget,
      );
      // L'eta' si chiede subito, non dopo: e' la porta che tiene fuori i
      // minorenni.
      expect(find.text('QUANDO SEI NATO'), findsWidgets);

      await tearDownTree(tester);
    },
  );

  testWidgets('passate tutte le porte si vedono le challenge', (tester) async {
    final container = await pumpApp(
      tester,
      authRepository: FakeAuthRepository(currentUser: verifiedUser),
      overrides: [
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(completeProfile),
        ),
      ],
    );

    expect(find.text('NESSUNA CHALLENGE APERTA'), findsOneWidget);

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
    await tester.pumpAndSettle();

    expect(find.text('€500'), findsOneWidget);
    expect(find.text('DO SOMETHING CRAZY'), findsOneWidget);
    expect(find.text('PARTECIPA'), findsOneWidget);

    await tearDownTree(tester);
  });
}
