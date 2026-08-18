import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/data/repositories/firestore_friends_repository.dart';
import 'package:crasy/features/friends/domain/entities/friendship.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:crasy/services/firebase/firebase_bootstrap_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Il repository delle amicizie.
///
/// Nullo senza Firebase configurato, e le schermate lo sanno: gli amici sono
/// **per definizione** una cosa fra dispositivi diversi, e non c'e' modo di
/// farli funzionare in memoria come le challenge di prova. Meglio dirlo che
/// fingere.
final friendsRepositoryProvider = Provider<FirestoreFriendsRepository?>((ref) {
  if (!ref.watch(firebaseBootstrapResultProvider).isConfigured) {
    return null;
  }

  return FirestoreFriendsRepository(ref.watch(firebaseFirestoreProvider));
});

/// Il profilo di chiunque, per identificativo.
final publicProfileProvider = StreamProvider.autoDispose
    .family<UserProfile?, String>((ref, userId) {
      final repository = ref.watch(friendsRepositoryProvider);

      if (repository == null) {
        return Stream.value(null);
      }

      return repository.watchProfile(userId);
    });

/// Gli amici di qualcuno.
final friendsOfProvider = StreamProvider.autoDispose
    .family<List<Friend>, String>((ref, userId) {
      final repository = ref.watch(friendsRepositoryProvider);

      if (repository == null) {
        return Stream.value(const <Friend>[]);
      }

      return repository.watchFriends(userId);
    });

/// I miei amici.
///
/// Ascolta il repository direttamente invece di appoggiarsi a
/// `friendsOfProvider(mioId)`: passando dal `future` di quello, l'elenco si
/// sarebbe fermato al primo valore — un amico accettato mentre la schermata e'
/// aperta non sarebbe mai comparso, e non ci sarebbe stato modo di accorgersene
/// se non riaprendo l'app.
final myFriendsProvider = StreamProvider<List<Friend>>((ref) {
  final repository = ref.watch(friendsRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (repository == null || userId == null) {
    return Stream.value(const <Friend>[]);
  }

  return repository.watchFriends(userId);
});

/// Le richieste che ho ricevuto e non ho ancora deciso.
final incomingRequestsProvider = StreamProvider<List<FriendRequest>>((ref) {
  final repository = ref.watch(friendsRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (repository == null || userId == null) {
    return Stream.value(const <FriendRequest>[]);
  }

  return repository.watchIncomingRequests(userId);
});

/// Che rapporto ho con questa persona.
final friendshipStatusProvider = StreamProvider.autoDispose
    .family<FriendshipStatus, String>((ref, otherId) {
      final repository = ref.watch(friendsRepositoryProvider);
      final meId = ref.watch(currentUserIdProvider);

      if (repository == null || meId == null) {
        return Stream.value(FriendshipStatus.none);
      }

      return repository.watchStatus(meId: meId, otherId: otherId);
    });

/// Le partecipazioni di una persona, per il suo profilo pubblico.
final entriesOfProvider = StreamProvider.autoDispose
    .family<List<ChallengeEntry>, String>((ref, userId) {
      return ref.watch(challengeRepositoryProvider).watchEntriesByUser(userId);
    });

/// Quanto ha vinto una persona, in centesimi.
///
/// Si ottiene incrociando le challenge concluse con le sue partecipazioni: il
/// premio sta sulla challenge, la vittoria sulla partecipazione, e sommare
/// serve tutte e due. Copre le ultime cinquanta challenge chiuse che l'app ha
/// caricato — e' "quanto ha vinto di recente", non un estratto conto.
final prizeCentsOfProvider = Provider.autoDispose.family<int, String>((
  ref,
  userId,
) {
  final ended = ref.watch(endedChallengesProvider).valueOrNull ?? const [];
  final entries = ref.watch(entriesOfProvider(userId)).valueOrNull ?? const [];
  final byChallenge = {
    for (final entry in entries) entry.challengeId: entry.id,
  };

  var total = 0;

  for (final challenge in ended) {
    final winner = challenge.winnerEntryId;

    if (winner != null && byChallenge[challenge.id] == winner) {
      total += challenge.prizeCents;
    }
  }

  return total;
});

/// Le azioni sull'amicizia.
///
/// Stanno insieme perche' hanno tutte lo stesso preambolo — chi sono io, come
/// mi chiamo — e ripeterlo in ogni schermata sarebbe il modo piu' facile per
/// scrivere un nome sbagliato dentro l'amicizia di qualcun altro.
final friendActionsProvider = Provider<FriendActions>(FriendActions.new);

class FriendActions {
  const FriendActions(this._ref);

  final Ref _ref;

  String? get _meId => _ref.read(currentUserIdProvider);

  String get _meUsername =>
      _ref.read(currentUserProfileProvider).valueOrNull?.username ?? 'anonimo';

  FirestoreFriendsRepository? get _repository =>
      _ref.read(friendsRepositoryProvider);

  Future<void> send(String toUserId) async {
    final meId = _meId;
    final repository = _repository;

    if (meId == null || repository == null) {
      return;
    }

    await repository.sendRequest(
      fromUserId: meId,
      fromUsername: _meUsername,
      toUserId: toUserId,
    );
  }

  Future<void> cancel(String toUserId) async {
    final meId = _meId;
    final repository = _repository;

    if (meId == null || repository == null) {
      return;
    }

    await repository.cancelRequest(fromUserId: meId, toUserId: toUserId);
  }

  Future<void> accept(FriendRequest request) async {
    final meId = _meId;
    final repository = _repository;

    if (meId == null || repository == null) {
      return;
    }

    await repository.acceptRequest(
      meId: meId,
      meUsername: _meUsername,
      fromUserId: request.fromUserId,
      fromUsername: request.fromUsername,
    );
  }

  Future<void> reject(FriendRequest request) async {
    final meId = _meId;
    final repository = _repository;

    if (meId == null || repository == null) {
      return;
    }

    await repository.rejectRequest(meId: meId, fromUserId: request.fromUserId);
  }

  Future<void> remove(String otherId) async {
    final meId = _meId;
    final repository = _repository;

    if (meId == null || repository == null) {
      return;
    }

    await repository.removeFriend(meId: meId, otherId: otherId);
  }
}
