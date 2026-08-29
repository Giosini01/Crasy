import 'package:crasy/app.dart';
import 'package:crasy/core/widgets/opening_curtain.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_repository.dart';

/// Rifarsi la password.
///
/// Prima non si poteva: chi la dimenticava restava fuori per sempre, e non
/// c'era niente che nemmeno noi potessimo fare dall'altra parte.
void main() {
  late FakeAuthRepository authRepository;

  Future<void> apri(WidgetTester tester) async {
    authRepository = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        // Il sipario dell'apertura non si alza nelle prove: coprirebbe
        // lo schermo per due secondi e i tocchi finirebbero su di lui.
        openingCurtainProvider.overrideWithValue(false),
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
  }

  Future<void> chiudi(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('il collegamento c\'e\' su chi entra, non su chi si registra', (
    tester,
  ) async {
    await apri(tester);

    expect(find.text('PASSWORD DIMENTICATA'), findsOneWidget);

    // Passando alla registrazione sparisce: una password da recuperare, per
    // chi l'account non ce l'ha ancora, non esiste.
    await tester.tap(find.text('REGISTRATI'));
    await tester.pumpAndSettle();

    expect(find.text('PASSWORD DIMENTICATA'), findsNothing);

    await chiudi(tester);
  });

  testWidgets('senza email scritta chiede l\'email', (tester) async {
    await apri(tester);

    await tester.tap(find.text('PASSWORD DIMENTICATA'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Scrivi qui sopra la tua email'),
      findsOneWidget,
    );
    expect(authRepository.passwordResets, isEmpty);

    await chiudi(tester);
  });

  testWidgets('con l\'email scritta il messaggio parte', (tester) async {
    await apri(tester);

    await tester.enterText(find.byType(TextFormField).first, 'ciao@esempio.it');
    await tester.tap(find.text('PASSWORD DIMENTICATA'));
    await tester.pumpAndSettle();

    expect(authRepository.passwordResets, ['ciao@esempio.it']);

    // **La frase non dice se quell'account esiste.** Dirlo regalerebbe a
    // chiunque un modo di scoprire chi sta su CRASY.
    expect(find.textContaining('Se esiste un account'), findsOneWidget);

    await chiudi(tester);
  });

  testWidgets('la password non serve per poterla dimenticare', (tester) async {
    await apri(tester);

    // Il campo della password resta vuoto: chi non se la ricorda ha quel campo
    // vuoto per definizione, e il modulo non deve pretenderlo.
    await tester.enterText(find.byType(TextFormField).first, 'ciao@esempio.it');
    await tester.tap(find.text('PASSWORD DIMENTICATA'));
    await tester.pumpAndSettle();

    expect(authRepository.passwordResets, hasLength(1));

    await chiudi(tester);
  });
}
