import 'package:app_incontri/core/constants/app_routes.dart';
import 'package:app_incontri/features/auth/presentation/pages/auth_page.dart';
import 'package:app_incontri/features/auth/presentation/providers/auth_providers.dart';
import 'package:app_incontri/features/home/presentation/pages/home_page.dart';
import 'package:app_incontri/features/home/presentation/pages/splash_page.dart';
import 'package:app_incontri/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:app_incontri/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final sessionLandingRouteProvider = Provider<String>((ref) {
  final authState = ref.watch(authStateProvider);

  if (authState is LoadingAuthState) {
    return AppRoutes.splash;
  }

  if (authState is UnauthenticatedAuthState || authState is ErrorAuthState) {
    return AppRoutes.auth;
  }

  if (authState is AuthenticatedAuthState) {
    final profileState = ref.watch(currentUserProfileProvider);

    return profileState.when(
      loading: () => AppRoutes.splash,
      error: (_, _) => AppRoutes.onboarding,
      data: (profile) {
        if (profile == null || !profile.onboardingCompleted) {
          return AppRoutes.onboarding;
        }

        return AppRoutes.discover;
      },
    );
  }

  return AppRoutes.splash;
});

final goRouterProvider = Provider<GoRouter>((ref) {
  final targetRoute = ref.watch(sessionLandingRouteProvider);

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
      final homeLocations = <String>{
        AppRoutes.discover,
        AppRoutes.camera,
        AppRoutes.matches,
        AppRoutes.profile,
      };

      if (targetRoute == AppRoutes.splash) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      if (targetRoute == AppRoutes.auth) {
        return location == AppRoutes.auth ? null : AppRoutes.auth;
      }

      if (targetRoute == AppRoutes.onboarding) {
        return location == AppRoutes.onboarding ? null : AppRoutes.onboarding;
      }

      if (targetRoute == AppRoutes.discover) {
        return homeLocations.contains(location) ? null : AppRoutes.discover;
      }

      return null;
    },
  );
});
