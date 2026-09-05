import 'dart:async';

import 'package:crasy/app.dart';
import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/legal/legal_documents.dart';
import 'package:crasy/core/utils/provider_cache.dart';
import 'package:crasy/core/widgets/opening_curtain.dart';
import 'package:crasy/features/auth/domain/entities/app_user.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:crasy/routing/app_router.dart';
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
    // La quinta porta: senza la versione accettata si resta fermi ai consensi.
    legalVersion: LegalTexts.version,
    legalAcceptedAt: DateTime(2026),
    tutorialSeen: true,
    // La porta del numero: senza, si resta fermi alla verifica del telefono.
    phone: '+393330000000',
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
        // Il sipario dell'apertura non si alza nelle prove: coprirebbe
        // lo schermo per due secondi e i tocchi finirebbero su di lui.
        openingCurtainProvider.overrideWithValue(false),
        providerCacheProvider.overrideWithValue(Duration.zero),
        // Il giorno e' fisso: quello vero si porta dietro una sveglia puntata
        // sulla mezzanotte, e una prova non deve dipendere da che ore sono.
        todayKeyProvider.overrideWith((ref) => Stream.value('2026-08-30')),
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
    //
    // Si apre sull'accesso: chi torna e' la maggioranza schiacciante, e chi e'
    // nuovo ha il suo bottone rosso subito sotto.
    expect(find.text('BENTORNATO.', findRichText: true), findsOneWidget);
    expect(find.text('REGISTRATI'), findsOneWidget);
    expect(find.text('CHALLENGE'), findsNothing);
    expect(find.text('NESSUNA CHALLENGE APERTA'), findsNothing);

    await tearDownTree(tester);
  });

  testWidgets('il tocco su una notifica aspetta che la sessione sia in piedi', (
    tester,
  ) async {
    // **E' il difetto che faceva sembrare le notifiche sconnesse.**
    //
    // Toccandone una ad app chiusa, l'app parte e per qualche istante non sa
    // ancora chi sei: in quel momento ogni indirizzo viene dirottato al muro
    // che tocca passare. Il salto verso la campanella partiva li' dentro e
    // veniva sbattuto via insieme agli altri — e si finiva ogni volta in un
    // posto diverso, a seconda di quanto ci metteva la rete.
    final profilo = StreamController<UserProfile?>();
    addTearDown(profilo.close);

    await pumpApp(
      tester,
      authRepository: FakeAuthRepository(currentUser: verifiedUser),
      overrides: [
        currentUserProfileProvider.overrideWith((ref) => profilo.stream),
        pushTapsProvider.overrideWith(
          (ref) => Stream.value((
            scheda: AppRoutes.challenges,
            apri: AppRoutes.notifications,
            evidenzia: null,
            daFermo: true,
            quando: 1,
          )),
        ),
      ],
    );

    // Sessione non ancora completa: il tocco non deve portare da nessuna parte.
    profilo.add(null);
    await tester.pumpAndSettle();

    expect(find.text('Notifiche'), findsNothing);

    // Sessione completa: adesso il tocco messo da parte si consuma.
    profilo.add(completeProfile);
    await tester.pumpAndSettle();

    expect(find.text('Notifiche'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('il link del messaggio passa anche senza sessione', (
    tester,
  ) async {
    // **E' la prova che il muro non si mangia il link.** Chi clicca la
    // conferma dell'indirizzo arriva dal browser senza niente in mano: se la
    // porta d'ingresso lo dirotta come dirotta tutti gli altri, il codice che
    // aprirebbe quella porta se ne va insieme all'indirizzo da cui lo stiamo
    // portando via, e resta chiuso fuori per sempre — con l'unica via
    // d'uscita di farsi rimandare il messaggio e ricascarci uguale.
    final container = await pumpApp(
      tester,
      authRepository: FakeAuthRepository(),
    );

    container
        .read(goRouterProvider)
        .go('${AppRoutes.emailAction}?mode=verifyEmail&oobCode=abc123');
    await tester.pumpAndSettle();

    expect(find.text('TUTTO\nA POSTO.', findRichText: true), findsOneWidget);
    expect(find.text('BENTORNATO.', findRichText: true), findsNothing);

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

    // `textContaining` e non `text`: il titolo di una sezione vuota adesso
    // finisce con il punto rosso del marchio, quindi il testo per esteso e'
    // "NESSUNA CHALLENGE APERTA." — cercarlo esatto lo mancherebbe per un
    // carattere.
    expect(find.textContaining('NESSUNA CHALLENGE APERTA'), findsOneWidget);

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

  testWidgets('le schede si cambiano anche col dito', (tester) async {
    final container = await pumpApp(
      tester,
      authRepository: FakeAuthRepository(currentUser: verifiedUser),
      overrides: [
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(completeProfile),
        ),
      ],
    );

    String where() => container
        .read(goRouterProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;

    expect(where(), AppRoutes.challenges);

    // Il dito va verso sinistra e la scheda successiva entra da destra, come su
    // qualunque app con delle schede in fondo.
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();

    // Al secondo posto ci sono gli amici, ma non l'elenco dei nomi: quello che
    // stanno facendo. L'elenco si apre da li' dentro e dal profilo.
    expect(where(), AppRoutes.friendsActivity);

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(where(), AppRoutes.search);

    // E si torna indietro dall'altra parte.
    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(where(), AppRoutes.friendsActivity);

    // Toccando l'icona in fondo si arriva allo stesso posto: le due strade
    // devono raccontare la stessa storia, altrimenti l'indirizzo e la schermata
    // finiscono disallineati.
    await tester.tap(find.text('PROFILO'));
    await tester.pumpAndSettle();

    expect(where(), AppRoutes.profile);

    await tearDownTree(tester);
  });
}
