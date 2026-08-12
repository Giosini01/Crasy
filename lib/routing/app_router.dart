import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/features/auth/presentation/pages/auth_page.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/presentation/pages/challenge_detail_page.dart';
import 'package:crasy/features/challenges/presentation/pages/create_challenge_page.dart';
import 'package:crasy/features/challenges/presentation/pages/participate_page.dart';
import 'package:crasy/features/home/presentation/pages/home_page.dart';
import 'package:crasy/features/home/presentation/pages/splash_page.dart';
import 'package:crasy/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Dove deve stare la sessione in questo momento.
///
/// Non e' la rotta corrente: e' la rotta **minima** che lo stato della sessione
/// impone. Chi ha fatto l'accesso ed e' passato dall'onboarding puo' stare dove
/// vuole, e questo provider risponde [AppRoutes.challenges] per dire
/// "nessun vincolo, la home e' li'".
final sessionLandingRouteProvider = Provider<String>((ref) {
  final authState = ref.watch(authStateProvider);

  if (authState is LoadingAuthState) {
    return AppRoutes.splash;
  }

  // Senza accesso non si viene rimbalzati sulla registrazione: si atterra sulle
  // challenge. E' la prima cosa che CRASY deve mostrare di se'.
  if (authState is UnauthenticatedAuthState || authState is ErrorAuthState) {
    return AppRoutes.challenges;
  }

  if (authState is AuthenticatedAuthState) {
    final profileState = ref.watch(currentUserProfileProvider);

    return profileState.when(
      loading: () => AppRoutes.splash,
      // Un profilo che non si riesce a leggere viene trattato come un profilo
      // che non c'e': l'onboarding e' l'unica schermata che sa ricrearlo.
      error: (_, _) => AppRoutes.onboarding,
      data: (profile) {
        if (profile == null || !profile.onboardingCompleted) {
          return AppRoutes.onboarding;
        }

        return AppRoutes.challenges;
      },
    );
  }

  return AppRoutes.splash;
});

/// Rotta senza animazione di ingresso.
///
/// Le quattro schede sono rotte distinte, quindi go_router le tratterebbe come
/// pagine da impilare e le farebbe entrare da destra. Cambiare scheda deve
/// sembrare cambiare vista, non aprire una pagina nuova.
GoRoute _tabRoute(String path, Widget child) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) =>
        NoTransitionPage<void>(key: state.pageKey, child: child),
  );
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final landing = ref.watch(sessionLandingRouteProvider);
  final signedIn = ref.watch(authStateProvider) is AuthenticatedAuthState;

  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      _tabRoute(AppRoutes.splash, const SplashPage()),
      _tabRoute(AppRoutes.auth, const AuthPage()),
      _tabRoute(AppRoutes.onboarding, const OnboardingPage()),
      for (final tab in AppRoutes.tabs) _tabRoute(tab, HomePage(location: tab)),
      GoRoute(
        path: AppRoutes.challengeDetail,
        builder: (context, state) =>
            ChallengeDetailPage(challengeId: state.pathParameters['id'] ?? ''),
        routes: [
          GoRoute(
            path: 'partecipa',
            builder: (context, state) =>
                ParticipatePage(challengeId: state.pathParameters['id'] ?? ''),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.create,
        builder: (context, state) => const CreateChallengePage(),
      ),
    ],
    redirect: (context, state) {
      final location = state.matchedLocation;

      // Finche' non si sa chi c'e' dall'altra parte non si mostra niente:
      // mandare qualcuno sulle challenge per poi rimbalzarlo sull'onboarding un
      // istante dopo e' peggio di mezzo secondo di attesa.
      if (landing == AppRoutes.splash) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      if (landing == AppRoutes.onboarding) {
        return location == AppRoutes.onboarding ? null : AppRoutes.onboarding;
      }

      // Da qui in giu' la sessione e' a posto: lo splash e l'onboarding non
      // hanno piu' niente da dire, e chi ha gia' fatto l'accesso non deve
      // ritrovarsi sulla registrazione.
      if (location == AppRoutes.splash || location == AppRoutes.onboarding) {
        return AppRoutes.challenges;
      }

      if (location == AppRoutes.auth) {
        return signedIn ? AppRoutes.challenges : null;
      }

      // L'ospite guarda, ma non lascia tracce: partecipare, votare e avere un
      // profilo passano tutti dalla registrazione.
      if (!signedIn && !AppRoutes.guestAllowed.contains(location)) {
        return AppRoutes.auth;
      }

      return null;
    },
  );
});
