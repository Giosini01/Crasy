import 'package:app_incontri/app.dart';
import 'package:app_incontri/features/auth/presentation/controllers/mock_session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DailyApp renders splash content on startup', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DailyApp()));

    expect(find.text('Daily'), findsOneWidget);
    expect(
      find.textContaining('Una presenza nuova ogni giorno'),
      findsOneWidget,
    );
  });

  testWidgets('DailyApp can start from an authenticated session', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(mockSessionControllerProvider.notifier).completeOnboarding();

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
