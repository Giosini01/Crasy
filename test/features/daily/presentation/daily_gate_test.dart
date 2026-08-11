import 'dart:async';

import 'package:app_incontri/core/theme/app_theme.dart';
import 'package:app_incontri/features/auth/domain/entities/app_user.dart';
import 'package:app_incontri/features/auth/presentation/providers/auth_providers.dart';
import 'package:app_incontri/features/camera/presentation/pages/camera_page.dart';
import 'package:app_incontri/features/daily/domain/entities/daily_access.dart';
import 'package:app_incontri/features/daily/domain/entities/daily_vibe.dart';
import 'package:app_incontri/features/daily/presentation/providers/daily_providers.dart';
import 'package:app_incontri/features/discover/presentation/pages/discover_page.dart';
import 'package:app_incontri/features/feed/domain/entities/feed_item.dart';
import 'package:app_incontri/features/feed/domain/repositories/feed_repository.dart';
import 'package:app_incontri/features/feed/presentation/providers/feed_providers.dart';
import 'package:app_incontri/features/stats/domain/entities/vibe_stats.dart';
import 'package:app_incontri/features/stats/presentation/providers/stats_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_network_images.dart';

void main() {
  useFakeNetworkImages();

  Widget host(
    Widget child,
    DailyAccess access,
    ThemeData theme, {
    List<FeedItem> feed = const [],
  }) {
    return ProviderScope(
      overrides: [
        dailyAccessProvider.overrideWithValue(access),
        todayFeedProvider.overrideWith((ref) => Stream.value(feed)),
        decidedUserIdsProvider.overrideWith(
          (ref) => Stream.value(const <String>{}),
        ),
        // Guardare una scheda segna l'Istantanea come vista, e per farlo
        // serve un archivio: senza questa riga il widget cerca Firestore, che
        // in un test non esiste.
        authStateProvider.overrideWith(_StubAuthState.new),
        feedRepositoryProvider.overrideWithValue(_RecordingFeedRepository(feed)),
        // Stessa ragione per i numeri della giornata: la schermata di chi ha
        // gia' pubblicato li mostra, e vanno da qualche parte.
        todayVibeProvider.overrideWith((ref) => Stream.value(VibeDay.empty)),
        lifetimeVibeProvider.overrideWith(
          (ref) => Stream.value(VibeLifetime.empty),
        ),
      ],
      child: MaterialApp(theme: theme, home: child),
    );
  }

  // Il logotipo in cima e' anch'esso un'Image: si cerca quella che punta a
  // una foto di rete, cioe' l'Istantanea.
  final photoFinder = find.byWidgetPredicate(
    (widget) => widget is Image && widget.image is NetworkImage,
  );

  FeedItem feedItem({
    required String author,
    required String name,
    required int age,
    required double distanceKm,
    String dailyId = 'daily-1',
    String photoUrl = 'https://example.com/a.jpg',
    String icebreaker = '',
    List<String> interests = const [],
    List<String> shared = const [],
    int compatibility = 0,
    DateTime? capturedAt,
    String vibe = '',
  }) {
    return FeedItem(
      vibe: DailyVibe.chipOf(vibe),
      dailyId: dailyId,
      authorId: author,
      authorName: name,
      authorAge: age,
      authorPhotoUrl: '',
      authorIcebreaker: icebreaker,
      authorInterests: interests,
      sharedInterests: shared,
      compatibility: compatibility,
      photoUrl: photoUrl,
      dateKey: '2026-08-09',
      distanceKm: distanceKm,
      capturedAt: capturedAt ?? DateTime(2026, 8, 9, 20),
    );
  }

  final windowOpen = DailyAccess(
    openSlot: 0,
    boundary: DateTime.now().add(const Duration(hours: 1)),
    usedToday: 0,
    hasActiveDaily: false,
  );

  final windowClosed = DailyAccess(
    openSlot: null,
    boundary: DateTime.now().add(const Duration(hours: 5)),
    usedToday: 0,
    hasActiveDaily: false,
  );

  final limitReached = DailyAccess(
    openSlot: 0,
    boundary: DateTime.now().add(const Duration(minutes: 40)),
    usedToday: 3,
    hasActiveDaily: true,
  );

  final unlocked = DailyAccess(
    openSlot: null,
    boundary: DateTime.now().add(const Duration(hours: 5)),
    usedToday: 1,
    hasActiveDaily: true,
  );

  // L'app ha un solo tema: la mappa resta perche' e' il gancio da riaprire se
  // un giorno tornera' una seconda variante.
  final themes = {'light': AppTheme.light()};

  for (final theme in themes.entries) {
    testWidgets('discover locked, window open (${theme.key})', (tester) async {
      await tester.pumpWidget(
        host(const DiscoverPage(), windowOpen, theme.value),
      );
      await tester.pump();

      expect(find.text('Prima tocca a te.'), findsOneWidget);
      expect(find.text('Scatta la tua Istantanea'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('discover locked, window closed (${theme.key})', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const DiscoverPage(), windowClosed, theme.value),
      );
      await tester.pump();

      expect(find.text('Prima tocca a te.'), findsOneWidget);
      expect(find.text('Prossima istantanea tra'), findsOneWidget);
      expect(find.textContaining('12:00, 15:00, 21:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('discover unlocked but feed empty (${theme.key})', (
      tester,
    ) async {
      await tester.pumpWidget(host(const DiscoverPage(), unlocked, theme.value));
      await tester.pump();

      expect(find.text('Ancora nessuno, per oggi.'), findsOneWidget);
      expect(find.text('Prima tocca a te.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('deck opens on the nearest person (${theme.key})', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const DiscoverPage(),
          unlocked,
          theme.value,
          feed: [
            feedItem(author: 'u2', name: 'Marco', age: 27, distanceKm: 33.4),
            feedItem(
              author: 'u3',
              name: 'Sara',
              age: 24,
              distanceKm: 0.4,
              icebreaker: 'Chiedimi del mio ultimo viaggio',
              interests: const ['libri', 'musica'],
              shared: const ['libri'],
              compatibility: 40,
            ),
          ],
        ),
      );
      await tester.pump();

      // Una persona alla volta, la piu' vicina per prima.
      expect(find.text('Sara, 24'), findsOneWidget);
      expect(find.text('Marco, 27'), findsNothing);

      // Sotto il chilometro lo zero arrotondato sembrerebbe un errore.
      // Distanza e interessi in comune stanno sulla stessa riga.
      expect(find.textContaining('meno di 1 km'), findsOneWidget);
      expect(find.textContaining('Libri'), findsOneWidget);

      // Sulla foto compare l'"Oggi...": e' l'esca.
      expect(find.text('Chiedimi del mio ultimo viaggio'), findsOneWidget);

      // Nessuna percentuale di affinita': le persone non si presentano con un
      // punteggio addosso.
      expect(find.textContaining('% affini'), findsNothing);
    });

    testWidgets('camera closed window (${theme.key})', (tester) async {
      await tester.pumpWidget(
        host(const CameraPage(), windowClosed, theme.value),
      );
      await tester.pump();

      expect(find.text('Non e ancora il momento.'), findsOneWidget);
      expect(find.textContaining('12:00'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('camera limit reached (${theme.key})', (tester) async {
      await tester.pumpWidget(
        host(const CameraPage(), limitReached, theme.value),
      );
      await tester.pump();

      // Con un'Istantanea gia' attiva la pagina non dice "hai finito": mostra
      // la giornata pubblicata e i suoi numeri, che sono il motivo per cui si
      // torna qui.
      expect(find.text('Sei online.'), findsOneWidget);
      expect(find.text('Vai al Feed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tapping the card walks through a person Daily by Daily', (
    tester,
  ) async {
    const older = 'https://example.com/older.jpg';
    const newer = 'https://example.com/newer.jpg';

    await tester.pumpWidget(
      host(
        const DiscoverPage(),
        unlocked,
        AppTheme.light(),
        feed: [
          feedItem(
            author: 'u2',
            name: 'Marco',
            age: 27,
            distanceKm: 3,
            dailyId: 'd-old',
            photoUrl: older,
            capturedAt: DateTime(2026, 8, 9, 19, 30),
          ),
          feedItem(
            author: 'u2',
            name: 'Marco',
            age: 27,
            distanceKm: 3,
            dailyId: 'd-new',
            photoUrl: newer,
            capturedAt: DateTime(2026, 8, 9, 21),
          ),
        ],
      ),
    );
    await tester.pump();

    String shownUrl() {
      final image = tester.widget<Image>(photoFinder);

      return (image.image as NetworkImage).url;
    }

    // Le due Daily della stessa persona formano una scheda sola, aperta
    // sull'ultima.
    expect(find.text('Marco, 27'), findsOneWidget);
    expect(shownUrl(), newer);

    final card = tester.getRect(photoFinder);

    // Meta' sinistra: si va indietro nel tempo.
    await tester.tapAt(Offset(card.left + card.width * 0.25, card.center.dy));
    await tester.pump();
    expect(shownUrl(), older);

    // Meta' destra: si torna verso l'ultima.
    await tester.tapAt(Offset(card.left + card.width * 0.75, card.center.dy));
    await tester.pump();
    expect(shownUrl(), newer);
  });

  testWidgets('arrows and segment bars also move between Istantanee', (
    tester,
  ) async {
    const older = 'https://example.com/older.jpg';
    const newer = 'https://example.com/newer.jpg';

    await tester.pumpWidget(
      host(
        const DiscoverPage(),
        unlocked,
        AppTheme.light(),
        feed: [
          feedItem(
            author: 'u2',
            name: 'Marco',
            age: 27,
            distanceKm: 3,
            dailyId: 'd-old',
            photoUrl: older,
            capturedAt: DateTime(2026, 8, 9, 19, 30),
          ),
          feedItem(
            author: 'u2',
            name: 'Marco',
            age: 27,
            distanceKm: 3,
            dailyId: 'd-new',
            photoUrl: newer,
            capturedAt: DateTime(2026, 8, 9, 21),
          ),
        ],
      ),
    );
    await tester.pump();

    String shownUrl() {
      final image = tester.widget<Image>(photoFinder);

      return (image.image as NetworkImage).url;
    }

    expect(shownUrl(), newer);

    // La freccia e' un tasto, non un disegno: prima stava sotto un
    // `IgnorePointer` e premerla non faceva niente.
    await tester.tap(find.bySemanticsLabel('Istantanea precedente'));
    await tester.pump();
    expect(shownUrl(), older);

    await tester.tap(find.bySemanticsLabel('Istantanea successiva'));
    await tester.pump();
    expect(shownUrl(), newer);

    // Anche le barrette portano alla loro istantanea: la prima a sinistra e'
    // la piu' vecchia.
    final bars = tester.getRect(find.byType(AnimatedContainer).first);
    await tester.tapAt(bars.center);
    await tester.pump();
    expect(shownUrl(), older);
  });

  testWidgets('the heart records a like and the cross records a pass', (
    tester,
  ) async {
    final repository = _RecordingFeedRepository([
      feedItem(author: 'u2', name: 'Marco', age: 27, distanceKm: 3),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyAccessProvider.overrideWithValue(unlocked),
          feedRepositoryProvider.overrideWithValue(repository),
          authStateProvider.overrideWith(_StubAuthState.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DiscoverPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Mi piace'));
    // La scelta si registra a volo finito: la scheda esce di lato per prima.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.decisions, [('u2', true)]);
  });

  testWidgets('camera survives the plugin being unavailable', (tester) async {
    await tester.pumpWidget(
      host(const CameraPage(), windowOpen, AppTheme.light()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Senza plugin `availableCameras` fallisce: deve comparire lo stato di
    // errore, non un'eccezione non gestita.
    expect(tester.takeException(), isNull);
    expect(find.byType(CameraPage), findsOneWidget);
  });

  testWidgets('the cross records a pass', (tester) async {
    final repository = _RecordingFeedRepository([
      feedItem(author: 'u2', name: 'Marco', age: 27, distanceKm: 3),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyAccessProvider.overrideWithValue(unlocked),
          feedRepositoryProvider.overrideWithValue(repository),
          authStateProvider.overrideWith(_StubAuthState.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DiscoverPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Passa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.decisions, [('u2', false)]);

    // Chi e' stato valutato esce dal mazzo senza aspettare il server.
    await tester.pump();
    expect(find.text('Marco, 27'), findsNothing);
  });

  testWidgets('the deck leads with affinity, not with distance', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const DiscoverPage(),
        unlocked,
        AppTheme.light(),
        feed: [
          feedItem(
            author: 'u2',
            name: 'Marco',
            age: 27,
            distanceKm: 1,
            compatibility: 10,
          ),
          feedItem(
            author: 'u3',
            name: 'Sara',
            age: 24,
            distanceKm: 40,
            compatibility: 80,
          ),
        ],
      ),
    );
    await tester.pump();

    // Chi ha piu' interessi in comune passa davanti anche se abita lontano.
    expect(find.text('Sara, 24'), findsOneWidget);
    expect(find.text('Marco, 27'), findsNothing);
  });

  testWidgets('passing the free peek veils the next person with a notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const DiscoverPage(),
        windowOpen,
        AppTheme.light(),
        feed: [
          feedItem(author: 'u2', name: 'Marco', age: 27, distanceKm: 3),
          feedItem(author: 'u3', name: 'Sara', age: 24, distanceKm: 6),
        ],
      ),
    );
    await tester.pump();

    // La prima persona si vede in chiaro: e' l'assaggio.
    expect(find.text('Marco, 27'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.tap(find.bySemanticsLabel('Passa'));
    await tester.pump();

    // La seconda resta leggibile ma velata, con l'avviso sulla scheda.
    expect(find.text('Sara, 24'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('Qualcuno si e gia fatto vedere.'), findsOneWidget);
  });

  testWidgets('once published there is no way to shoot again', (tester) async {
    // Una gia' online e una fascia diversa aperta: e' il caso in cui prima
    // compariva il tasto per rifarla. Non deve piu' esistere.
    final published = DailyAccess(
      openSlot: 1,
      boundary: DateTime.now().add(const Duration(hours: 1)),
      usedToday: 1,
      usedSlots: const {0},
      hasActiveDaily: true,
    );

    // La regola vale gia' a monte: una foto chiude la giornata.
    expect(published.canCapture, isFalse);

    await tester.pumpWidget(
      host(const CameraPage(), published, AppTheme.light()),
    );
    await tester.pump();

    expect(find.text('Sei online.'), findsOneWidget);
    expect(find.text('Vai al Feed'), findsOneWidget);
    expect(find.textContaining('Fanne un altra'), findsNothing);
  });

  testWidgets('swiping right likes and swiping left passes', (tester) async {
    Future<_RecordingFeedRepository> swipe(double dx) async {
      final repository = _RecordingFeedRepository([
        feedItem(author: 'u2', name: 'Marco', age: 27, distanceKm: 3),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyAccessProvider.overrideWithValue(unlocked),
            feedRepositoryProvider.overrideWithValue(repository),
            authStateProvider.overrideWith(_StubAuthState.new),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const DiscoverPage(),
          ),
        ),
      );
      await tester.pump();

      await tester.drag(photoFinder, Offset(dx, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      return repository;
    }

    // Destra il cuore: e' il verso che chi arriva da altre app ha nelle mani,
    // e uno scarto per sbaglio qui non si annulla.
    expect((await swipe(300)).decisions, [('u2', true)]);
    expect((await swipe(-300)).decisions, [('u2', false)]);
  });

  testWidgets('a small drag brings the card back, deciding nothing', (
    tester,
  ) async {
    final repository = _RecordingFeedRepository([
      feedItem(author: 'u2', name: 'Marco', age: 27, distanceKm: 3),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyAccessProvider.overrideWithValue(unlocked),
          feedRepositoryProvider.overrideWithValue(repository),
          authStateProvider.overrideWith(_StubAuthState.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DiscoverPage(),
        ),
      ),
    );
    await tester.pump();

    // Un dito che scivola non e' una scelta: sotto la soglia si torna al
    // centro senza registrare niente.
    await tester.drag(photoFinder, const Offset(40, 0), touchSlopX: 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.decisions, isEmpty);
    expect(find.text('Marco, 27'), findsOneWidget);
  });

  testWidgets('a like can carry a message', (tester) async {
    final repository = _RecordingFeedRepository([
      feedItem(author: 'u2', name: 'Marco', age: 27, distanceKm: 3),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyAccessProvider.overrideWithValue(unlocked),
          feedRepositoryProvider.overrideWithValue(repository),
          authStateProvider.overrideWith(_StubAuthState.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DiscoverPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Mi piace, con un messaggio'));
    // Non `pumpAndSettle`: il campo ha il cursore che lampeggia, quindi non
    // arriva mai un fotogramma di quiete. Si aspetta l'apertura del foglio.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField), 'Anche io adoro la montagna');
    await tester.tap(find.text('Invia con il cuore'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Un cuore normale, con la riga attaccata: la decisione resta una sola.
    expect(repository.decisions, [('u2', true)]);
    expect(repository.messages.single, 'Anche io adoro la montagna');
  });

  testWidgets('the vibe of the moment rides on the card', (tester) async {
    await tester.pumpWidget(
      host(
        const DiscoverPage(),
        unlocked,
        AppTheme.light(),
        feed: [
          feedItem(
            author: 'u2',
            name: 'Marco',
            age: 27,
            distanceKm: 3,
            icebreaker: 'Oggi mi trovi sul divano',
            vibe: 'relax',
          ),
        ],
      ),
    );
    await tester.pump();

    // Il server manda l'identificativo, l'app compone la scritta: se un giorno
    // l'etichetta cambia nome, i feed gia' scritti non vanno toccati.
    expect(find.text('☕ Relax'), findsOneWidget);
    expect(find.text('Oggi mi trovi sul divano'), findsOneWidget);
  });

  testWidgets('locked discover fits a short viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host(const DiscoverPage(), windowClosed, AppTheme.light()),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

/// Sessione autenticata fissa: il mazzo ha bisogno di sapere chi sta guardando
/// per registrare la decisione.
class _StubAuthState extends AuthStateNotifier {
  @override
  AuthState build() {
    return const AuthenticatedAuthState(
      AppUser(id: 'me', email: 'me@example.com'),
    );
  }
}

/// Registra le decisioni e le rimanda indietro come farebbe Firestore, cosi'
/// si verifica anche che la persona valutata sparisca dal mazzo.
class _RecordingFeedRepository implements FeedRepository {
  _RecordingFeedRepository(this._items);

  final List<FeedItem> _items;
  final List<(String, bool)> decisions = [];

  /// La riga allegata a ciascuna decisione, `null` quando non ce n'era una.
  final List<String?> messages = [];

  /// Le Istantanee segnate come guardate, per verificare che lo sguardo si
  /// conti una volta sola.
  final List<String> seen = [];

  final _decided = StreamController<Set<String>>.broadcast();

  @override
  Stream<List<FeedItem>> watchFeed(String userId, String dateKey) {
    return Stream.value(_items);
  }

  @override
  Stream<Set<String>> watchDecidedUserIds(String userId) async* {
    yield const <String>{};
    yield* _decided.stream;
  }

  @override
  Future<void> recordDecision({
    required String userId,
    required String targetId,
    required bool liked,
    String? message,
  }) async {
    messages.add(message);
    decisions.add((targetId, liked));
    _decided.add(decisions.map((decision) => decision.$1).toSet());
  }

  @override
  Future<void> markSeen({
    required String userId,
    required String dailyId,
  }) async {
    seen.add(dailyId);
  }
}



