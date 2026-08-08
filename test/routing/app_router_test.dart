import 'package:app_incontri/core/constants/app_routes.dart';
import 'package:app_incontri/features/auth/presentation/controllers/mock_session_controller.dart';
import 'package:app_incontri/routing/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('landing route is auth for unauthenticated users', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(sessionLandingRouteProvider), AppRoutes.auth);
  });

  test('landing route is onboarding for authenticated users', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(mockSessionControllerProvider.notifier).setAuthenticated();

    expect(container.read(sessionLandingRouteProvider), AppRoutes.onboarding);
  });

  test('landing route is discover after onboarding completion', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(mockSessionControllerProvider.notifier).completeOnboarding();

    expect(container.read(sessionLandingRouteProvider), AppRoutes.discover);
  });
}
