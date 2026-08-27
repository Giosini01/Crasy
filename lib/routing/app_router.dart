import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/legal/legal_documents.dart';
import 'package:crasy/core/routing/swipe_back_page.dart';
import 'package:crasy/features/auth/presentation/pages/auth_page.dart';
import 'package:crasy/features/auth/presentation/pages/verify_email_page.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/presentation/pages/challenge_detail_page.dart';
import 'package:crasy/features/challenges/presentation/pages/create_challenge_page.dart';
import 'package:crasy/features/challenges/presentation/pages/participate_page.dart';
import 'package:crasy/features/home/presentation/pages/home_page.dart';
import 'package:crasy/features/home/presentation/pages/splash_page.dart';
import 'package:crasy/features/legal/presentation/pages/consent_page.dart';
import 'package:crasy/features/notifications/presentation/pages/notifications_page.dart';
import 'package:crasy/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:crasy/features/profile/presentation/pages/public_profile_page.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Dove deve stare la sessione in questo momento.
///
/// Sono cinque porte in fila, e si passano in quest'ordine: **accesso**, poi
/// **email confermata**, poi **profilo con data di nascita**, poi **i
/// consensi**, poi l'app. Ognuna esiste per un motivo che ha a che fare con i
/// soldi in palio: senza un account non si sa chi vince, senza un indirizzo
/// vero non si sa dove mandarlo, e senza sapere quanti anni ha non si dovrebbe
/// chiedere a nessuno di uscire a fare qualcosa per vincerlo.
///
/// **L'ultima e' una porta che si riapre.** Le altre quattro si passano una
/// volta sola; questa torna a chiudersi ogni volta che i testi legali cambiano
/// versione, perche' un'informativa nuova che nessuno ha mai visto non vale
/// niente. E' il meccanismo che rende vera la frase "ti verra' chiesto di
/// prenderne visione" invece che una promessa scritta in un documento.
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

      // Chi non ha mai accettato, e chi aveva accettato una versione che nel
      // frattempo e' stata sostituita.
      if (!profile.acceptedLegalVersion(LegalTexts.version)) {
        return AppRoutes.consents;
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
GoRoute _tabRoute(String path, Widget child, {LocalKey? key}) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) =>
        NoTransitionPage<void>(key: key ?? state.pageKey, child: child),
  );
}

/// La chiave dell'impalcatura con le quattro schede.
///
/// **E' la stessa per tutte e quattro**, ed e' cio' che rende possibile passare
/// da una scheda all'altra con il dito. Con una chiave per rotta — cioe' quello
/// che viene naturale — ogni cambio di scheda butta via l'impalcatura e ne
/// costruisce un'altra: non c'e' niente che resti in piedi abbastanza da poter
/// scorrere, e ogni scheda ricomincia da capo anche solo per averla sfiorata.
///
/// Con una chiave sola l'impalcatura resta la stessa e cambia solo quale scheda
/// sta mostrando, che e' esattamente cio' che succede quando si scorre.
const _homeShellKey = ValueKey<String>('impalcatura-schede');

/// Dove stava andando chi e' stato fermato all'ingresso.
///
/// **E' il pezzo che fa funzionare i link condivisi.** Qualcuno riceve il link
/// di una foto, lo apre, non ha un account: senza questo, dopo essersi
/// registrato atterrerebbe sulla home e la foto per cui e' venuto sarebbe da
/// ritrovare. Con questo, finita la registrazione si apre esattamente quella.
///
/// Sta in una variabile e non in un provider perche' il reindirizzamento di
/// go_router non e' il posto in cui si aggiorna lo stato dell'app: qui si
/// annota una cosa e la si consuma subito dopo.
String? _destinationBeforeLogin;

/// Una pagina che si apre sopra le schede.
///
/// **Si chiude tirandola via col dito dal bordo sinistro**, come su un
/// telefono, e su tutte le piattaforme — il gesto sta dentro `CupertinoPage`,
/// non nel tema. E' il gesto che tutti conoscono, non chiede niente a schermo,
/// e lascia l'intestazione vuota: la freccia in alto resta per chi la cerca,
/// ma non e' piu' l'unico modo di tornare indietro.
GoRoute _pushedRoute(
  String path,
  Widget Function(GoRouterState state) child, {
  List<RouteBase> routes = const [],
  bool swipeAnywhere = true,
}) {
  return GoRoute(
    path: path,
    // **Due modi di tornare indietro col dito, e si vedono tutti e due.**
    //
    // `SwipeBackPage` fa muovere la pagina sotto il dito da qualunque punto la
    // si prenda; `CupertinoPage` fa la stessa cosa ma solo dai venti punti
    // all'estrema sinistra. Il secondo resta dove c'e' qualcosa da perdere —
    // una foto appena scattata, una challenge scritta a meta' — perche' un
    // gesto largo quanto lo schermo la butterebbe via per un dito storto.
    pageBuilder: (context, state) => swipeAnywhere
        ? SwipeBackPage<void>(key: state.pageKey, child: child(state))
        : CupertinoPage<void>(key: state.pageKey, child: child(state)),
    routes: routes,
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
      _tabRoute(AppRoutes.consents, const ConsentPage()),
      for (final tab in AppRoutes.tabs)
        _tabRoute(tab, HomePage(location: tab), key: _homeShellKey),
      _pushedRoute(
        AppRoutes.challengeDetail,
        (state) =>
            ChallengeDetailPage(challengeId: state.pathParameters['id'] ?? ''),
        routes: [
          _pushedRoute(
            'partecipa',
            (state) =>
                ParticipatePage(challengeId: state.pathParameters['id'] ?? ''),
            swipeAnywhere: false,
          ),
        ],
      ),
      _pushedRoute(
        AppRoutes.notifications,
        (state) => const NotificationsPage(),
      ),
      _pushedRoute(
        AppRoutes.userProfile,
        (state) => PublicProfilePage(userId: state.pathParameters['id'] ?? ''),
      ),
      _pushedRoute(
        AppRoutes.create,
        (state) => const CreateChallengePage(),
        swipeAnywhere: false,
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
        AppRoutes.consents,
      };

      if (gates.contains(landing)) {
        // Si annota dove stava andando, con tutto quello che si porta dietro:
        // `?foto=` e' proprio la parte che conta, ed e' nella query.
        if (!gates.contains(location)) {
          _destinationBeforeLogin = state.uri.toString();
        }

        return location == landing ? null : landing;
      }

      // Da qui in giu' la sessione e' completa: le schermate d'ingresso non
      // hanno piu' niente da dire.
      if (gates.contains(location)) {
        final wanted = _destinationBeforeLogin;
        _destinationBeforeLogin = null;

        return wanted ?? AppRoutes.challenges;
      }

      return null;
    },
  );
});
