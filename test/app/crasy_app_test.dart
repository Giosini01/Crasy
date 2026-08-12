import 'package:crasy/app.dart';
import 'package:crasy/features/auth/domain/entities/app_user.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
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

    // Senza Firebase configurato l'app gira sulle challenge di esempio: e' il
    // caso che vede chiunque apra il progetto appena clonato.
    //
    // La prima della lista e' quella che scade prima, non quella dal premio
    // piu' alto: e' l'ordinamento che conta per chi deve decidere se fa in
    // tempo a partecipare.
    expect(find.text('€100'), findsOneWidget);
    expect(find.text('LUNGOMARE'), findsOneWidget);
    expect(find.text('PARTECIPA'), findsWidgets);

    // Nessuna traccia della vecchia app di incontri.
    expect(find.text('Match'), findsNothing);
    expect(find.text('Istantanea'), findsNothing);

    await tearDownTree(tester);
  });

  testWidgets('il premio e il tempo restano leggibili nella riga di servizio', (
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

    expect(find.textContaining('31 partecipanti'), findsOneWidget);
    expect(find.text('NAPOLI'), findsOneWidget);

    // Scorrendo si arriva alla challenge dal premio piu' alto.
    await tester.scrollUntilVisible(find.text('€500'), 400);
    await tester.pumpAndSettle();

    expect(find.text('DO SOMETHING CRAZY'), findsOneWidget);
    expect(find.textContaining('243 partecipanti'), findsOneWidget);

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
