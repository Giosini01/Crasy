import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/features/auth/presentation/pages/auth_page.dart';
import 'package:crasy/features/auth/presentation/pages/verify_email_page.dart';
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
/// Sono quattro porte in fila, e si passano in quest'ordine: **accesso**, poi
/// **email confermata**, poi **profilo con data di nascita**, poi l'app. Ognuna
/// esiste per un motivo che ha a che fare con i soldi in palio: senza un
/// account non si sa chi vince, senza un indirizzo vero non si sa dove
/// mandarlo, e senza sapere quanti anni ha non si dovrebbe chiedere a nessuno
/// di uscire a fare qualcosa per vincerlo.
final sessionLandingRouteProvider = Provider<String>((ref) {
  final authState = ref.watch(authStateProvider);

  if (authState is LoadingAuthState) {
    return AppRoutes.splash;
  }

  if (authState is! AuthenticatedAuthState) {
    return AppRoutes.auth;
  }

  if (!authState.user.emailVerified) {
    return AppRoutes.verifyEmail;
  }

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

      // Chi si e' registrato prima che la data di nascita esistesse ripassa
      // dall'onboarding: l'eta' non e' un campo che si possa lasciare vuoto.
      if (profile.birthDate == null) {
        return AppRoutes.onboarding;
      }

      return AppRoutes.challenges;
    },
  );
});

/// Rotta senza animazione di ingresso.
///
/// Le schede sono rotte distinte, quindi go_router le tratterebbe come pagine
/// da impilare e le farebbe entrare da destra. Cambiare scheda deve sembrare
/// cambiare vista, non aprire una pagina nuova.
GoRoute _tabRoute(String path, Widget child) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) =>
        NoTransitionPage<void>(key: state.pageKey, child: child),
  );
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final landing = ref.watch(sessionLandingRouteProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      _tabRoute(AppRoutes.splash, const SplashPage()),
      _tabRoute(AppRoutes.auth, const AuthPage()),
      _tabRoute(AppRoutes.verifyEmail, const VerifyEmailPage()),
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

      // Finche' una porta non e' passata, quella porta e' l'unico posto in cui
      // si puo' stare. Il controllo e' scritto una volta sola e vale per tutte:
      // splash, accesso, conferma dell'email e onboarding si comportano allo
      // stesso modo, e non c'e' modo di aggirarne una scrivendo un indirizzo a
      // mano.
      const gates = {
        AppRoutes.splash,
        AppRoutes.auth,
        AppRoutes.verifyEmail,
        AppRoutes.onboarding,
      };

      if (gates.contains(landing)) {
        return location == landing ? null : landing;
      }

      // Da qui in giu' la sessione e' completa: le schermate d'ingresso non
      // hanno piu' niente da dire.
      if (gates.contains(location)) {
        return AppRoutes.challenges;
      }

      return null;
    },
  );
});
