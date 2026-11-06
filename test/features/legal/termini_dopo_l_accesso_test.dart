import 'dart:async';

import 'package:crasy/app.dart';
import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/legal/legal_documents.dart';
import 'package:crasy/core/utils/provider_cache.dart';
import 'package:crasy/core/widgets/opening_curtain.dart';
import 'package:crasy/features/auth/domain/entities/app_user.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/profile/data/mappers/user_profile_mapper.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:crasy/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:crasy/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';

/// Il profilo, senza il database: si legge come lo legge l'app, un istante dopo
/// essersi messi in ascolto.
class _ProfiliFinti extends Fake implements UserProfileRepository {
  _ProfiliFinti(this.profilo);

  final UserProfile profilo;

  /// Quante volte l'app si e' rimessa in ascolto del profilo.
  int ascolti = 0;

  final firme = <String>[];

  @override
  Stream<UserProfile?> watchCurrentUserProfile(String userId) async* {
    ascolti += 1;

    yield profilo;
  }

  @override
  Future<void> saveConsent({
    required String userId,
    required String version,
    required bool marketing,
    String origine = 'dentro-l-app',
  }) async {
    firme.add(version);
  }
}

/// **I Termini, per chi ha gia' un account e non li ha ancora accettati.**
///
/// Il difetto che queste prove tengono chiuso: subito dopo l'accesso Firebase
/// rimanda l'utente tre o quattro volte (il rinnovo del token, la ricarica dei
/// dati). A ogni giro il profilo ripartiva da capo, l'app passava un istante dal
/// caricamento e la schermata dei Termini rinasceva vuota: le spunte sparivano e
/// il testo aperto con "Leggi" si chiudeva da solo. Il revisore di Apple spuntava,
/// premeva "Accetto" e si sentiva dire che mancavano le spunte.
void main() {
  const persona = AppUser(
    id: 'persona-1',
    email: 'test@esempio.it',
    emailVerified: true,
  );

  final senzaFirma = UserProfile(
    id: persona.id,
    username: 'appreview',
    birthDate: DateTime(1996),
    createdAt: null,
    updatedAt: null,
    onboardingCompleted: true,
    phoneVerified: true,
    contactsPromptSeen: true,
    permissionsSeen: true,
    tutorialSeen: true,
  );

  Future<({FakeAuthRepository accesso, _ProfiliFinti profili})> apri(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final accesso = FakeAuthRepository(currentUser: persona);
    final profili = _ProfiliFinti(senzaFirma);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(accesso),
        userProfileRepositoryProvider.overrideWithValue(profili),
        openingCurtainProvider.overrideWithValue(false),
        providerCacheProvider.overrideWithValue(Duration.zero),
        todayKeyProvider.overrideWith((ref) => Stream.value('2026-11-06')),
      ],
    );

    addTearDown(() {
      accesso.dispose();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CrasyApp()),
    );
    await tester.pumpAndSettle();

    return (accesso: accesso, profili: profili);
  }

  Future<void> spunta(WidgetTester tester, LegalConsent consenso) async {
    await tester.tap(find.text(consenso.label));
    await tester.pump(const Duration(milliseconds: 200));
  }

  Finder accetto() => find.text('ACCETTO E CONTINUO');

  /// Firebase che rimanda la stessa persona, come fa da solo dopo l'accesso.
  Future<void> rinnovaIlToken(
    WidgetTester tester,
    FakeAuthRepository accesso,
  ) async {
    for (var volta = 0; volta < 3; volta++) {
      accesso.entra(persona);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('le spunte restano quando Firebase rimanda l\'utente', (
    tester,
  ) async {
    final (:accesso, :profili) = await apri(tester);

    expect(accetto(), findsOneWidget);

    await spunta(tester, LegalConsent.mandatory.elementAt(0));
    await spunta(tester, LegalConsent.mandatory.elementAt(1));
    await rinnovaIlToken(tester, accesso);
    await spunta(tester, LegalConsent.mandatory.elementAt(2));
    await spunta(tester, LegalConsent.mandatory.elementAt(3));

    await tester.tap(accetto());
    await tester.pumpAndSettle();

    expect(find.textContaining('servono le prime quattro'), findsNothing);
    expect(profili.firme, [LegalTexts.version]);
    expect(profili.ascolti, 1, reason: 'il profilo non riparte da capo');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('il testo aperto con "Leggi" non si chiude da solo', (
    tester,
  ) async {
    final (:accesso, profili: _) = await apri(tester);

    await tester.tap(find.text('LEGGI: TERMINI E CONDIZIONI'));
    await tester.pumpAndSettle();

    expect(find.textContaining('TOLLERANZA ZERO'), findsOneWidget);

    await rinnovaIlToken(tester, accesso);

    expect(find.textContaining('TOLLERANZA ZERO'), findsOneWidget);

    await tester.tap(find.text('Chiudi'));
    await tester.pumpAndSettle();

    expect(accetto(), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
  group("l'account della revisione di Apple", () {
    final firmataAlle = DateTime.utc(2026, 11, 6, 10);

    /// Dove porta l'app chi ha fatto l'accesso a [accesso], con [profilo].
    Future<String> doveVa(UserProfile profilo, {DateTime? accesso}) async {
      final auth = FakeAuthRepository(
        currentUser: AppUser(
          id: persona.id,
          email: persona.email,
          emailVerified: true,
          lastSignInAt: accesso,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          currentUserProfileProvider.overrideWith(
            (ref) => Stream.value(profilo),
          ),
        ],
      );

      addTearDown(() {
        auth.dispose();
        container.dispose();
      });

      await container.read(currentUserProfileProvider.future);
      await container.pump();

      return container.read(sessionLandingRouteProvider);
    }

    final revisore = senzaFirma.copyWith(
      legalVersion: LegalTexts.version,
      legalAcceptedAt: firmataAlle,
      firmaAOgniAccesso: true,
    );

    test(
      'a ogni accesso nuovo rivede i Termini, anche se li aveva firmati',
      () async {
        final dove = await doveVa(
          revisore,
          accesso: firmataAlle.add(const Duration(hours: 2)),
        );

        expect(dove, AppRoutes.consents);
      },
    );

    test("riaprendo l'app, dopo averli firmati, non li rivede", () async {
      // L'accesso e' quello di prima della firma: e' la stessa sessione.
      final dove = await doveVa(
        revisore,
        accesso: firmataAlle.subtract(const Duration(minutes: 1)),
      );

      expect(dove, AppRoutes.challenges);
    });

    test('mentre la firma arriva al server, resta sui Termini', () async {
      final inViaggio = UserProfile(
        id: persona.id,
        username: 'appreview',
        birthDate: DateTime(1996),
        createdAt: null,
        updatedAt: null,
        onboardingCompleted: true,
        phoneVerified: true,
        contactsPromptSeen: true,
        permissionsSeen: true,
        tutorialSeen: true,
        legalVersion: LegalTexts.version,
        firmaAOgniAccesso: true,
      );

      expect(await doveVa(inViaggio, accesso: firmataAlle), AppRoutes.consents);
    });

    test('per tutti gli altri i Termini restano una volta sola', () async {
      final qualcuno = revisore.copyWith(firmaAOgniAccesso: false);

      expect(
        await doveVa(
          qualcuno,
          accesso: firmataAlle.add(const Duration(days: 30)),
        ),
        AppRoutes.challenges,
      );
      expect(
        await doveVa(
          senzaFirma.copyWith(legalVersion: LegalTexts.version),
          accesso: firmataAlle,
        ),
        AppRoutes.challenges,
        reason: "una firma vecchia, senza ora, vale per chi non e' il revisore",
      );
    });

    test('il segno si legge dal database', () {
      expect(
        UserProfileMapper.fromFirestore('x', {
          'firmaAOgniAccesso': true,
        }).firmaAOgniAccesso,
        isTrue,
      );
      expect(
        UserProfileMapper.fromFirestore('x', const {}).firmaAOgniAccesso,
        isFalse,
      );
    });
  });
}
