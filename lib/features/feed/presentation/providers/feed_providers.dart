import 'package:app_incontri/core/services/firebase/firebase_providers.dart';
import 'package:app_incontri/features/auth/presentation/providers/auth_providers.dart';
import 'package:app_incontri/features/daily/presentation/providers/daily_providers.dart';
import 'package:app_incontri/features/feed/data/repositories/firestore_feed_repository.dart';
import 'package:app_incontri/features/feed/domain/entities/feed_item.dart';
import 'package:app_incontri/features/feed/domain/entities/feed_person.dart';
import 'package:app_incontri/features/feed/domain/repositories/feed_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FirestoreFeedRepository(ref.watch(firebaseFirestoreProvider)),
);

final todayFeedProvider = StreamProvider<List<FeedItem>>((ref) {
  final authState = ref.watch(authStateProvider);

  if (authState is! AuthenticatedAuthState) {
    return Stream.value(const <FeedItem>[]);
  }

  return ref
      .watch(feedRepositoryProvider)
      .watchFeed(authState.user.id, ref.watch(todayKeyProvider));
});

final decidedUserIdsProvider = StreamProvider<Set<String>>((ref) {
  final authState = ref.watch(authStateProvider);

  if (authState is! AuthenticatedAuthState) {
    return Stream.value(const <String>{});
  }

  return ref
      .watch(feedRepositoryProvider)
      .watchDecidedUserIds(authState.user.id);
});

/// Segna le Istantanee man mano che compaiono davvero sullo schermo.
///
/// Tiene in memoria quelle gia' segnate: sfogliare avanti e indietro dentro la
/// stessa scheda e' un solo sguardo, non dieci, e chi ha pubblicato non deve
/// vedere il proprio contatore salire per un dito che va e viene.
class FeedSeenController {
  FeedSeenController(this._ref);

  final Ref _ref;
  final Set<String> _marked = {};

  void mark(String dailyId) {
    final authState = _ref.read(authStateProvider);

    if (authState is! AuthenticatedAuthState || !_marked.add(dailyId)) {
      return;
    }

    // Senza `await` e senza mostrare errori: e' un conteggio, non un'azione
    // dell'utente. Se fallisce, il numero sara' leggermente piu' basso —
    // molto meglio di un avviso per una cosa che non ha chiesto.
    _ref
        .read(feedRepositoryProvider)
        .markSeen(userId: authState.user.id, dailyId: dailyId)
        .ignore();
  }
}

final feedSeenControllerProvider = Provider<FeedSeenController>(
  FeedSeenController.new,
);

/// Il mazzo da sfogliare: una scheda per persona, gia' senza chi e' stato
/// valutato.
///
/// Il filtro sta qui e non nella query perche' la decisione e' un fatto
/// locale a chi guarda: appena tocca il cuore la persona sparisce, senza
/// aspettare che il server riscriva il feed.
final feedPeopleProvider = Provider<AsyncValue<List<FeedPerson>>>((ref) {
  final feed = ref.watch(todayFeedProvider);
  final decided = ref.watch(decidedUserIdsProvider).valueOrNull ?? const <String>{};

  return feed.whenData((items) {
    final pending = items
        .where((item) => !decided.contains(item.authorId))
        .toList();

    return _ordered(FeedPerson.group(pending));
  });
});

/// L'ordine del mazzo: prima chi ha piu' interessi in comune, e a parita' di
/// affinita' chi abita piu' vicino.
///
/// E' l'unico ordine possibile, senza schede da scegliere: chi apre il Feed
/// vuole vedere gente, non decidere come guardarla.
List<FeedPerson> _ordered(List<FeedPerson> people) {
  return [...people]..sort((a, b) {
    final byCompatibility = b.compatibility.compareTo(a.compatibility);

    return byCompatibility != 0
        ? byCompatibility
        : a.distanceKm.compareTo(b.distanceKm);
  });
}


