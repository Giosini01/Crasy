import 'package:app_incontri/core/constants/app_routes.dart';
import 'package:app_incontri/features/auth/presentation/controllers/mock_session_controller.dart';
import 'package:app_incontri/features/auth/presentation/pages/auth_page.dart';
import 'package:app_incontri/features/home/presentation/pages/home_page.dart';
import 'package:app_incontri/features/home/presentation/pages/splash_page.dart';
import 'package:app_incontri/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final sessionLandingRouteProvider = Provider<String>((ref) {
  final session = ref.watch(mockSessionControllerProvider);

  if (!session.isAuthenticated) {
    return AppRoutes.auth;
  }

  if (!session.isOnboardingComplete) {
    return AppRoutes.onboarding;
  }

  return AppRoutes.discover;
});

final goRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(mockSessionControllerProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.discover,
        builder: (context, state) =>
            const HomePage(location: AppRoutes.discover),
      ),
      GoRoute(
        path: AppRoutes.camera,
        builder: (context, state) => const HomePage(location: AppRoutes.camera),
      ),
      GoRoute(
        path: AppRoutes.matches,
        builder: (context, state) =>
            const HomePage(location: AppRoutes.matches),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) =>
            const HomePage(location: AppRoutes.profile),
      ),
    ],
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isAuthenticated = session.isAuthenticated;
      final isOnboardingComplete = session.isOnboardingComplete;
      final isInAuthFlow =
          location == AppRoutes.auth || location == AppRoutes.splash;

      if (!isAuthenticated && !isInAuthFlow) {
        return AppRoutes.auth;
      }

      if (isAuthenticated &&
          !isOnboardingComplete &&
          location != AppRoutes.onboarding &&
          location != AppRoutes.splash) {
        return AppRoutes.onboarding;
      }

      if (isAuthenticated &&
          isOnboardingComplete &&
          (location == AppRoutes.auth || location == AppRoutes.onboarding)) {
        return AppRoutes.discover;
      }

      return null;
    },
  );
});
