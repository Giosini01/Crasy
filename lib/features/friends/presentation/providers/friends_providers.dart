import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
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
/// Si somma sui suoi **trofei**, la stessa lista che riempie la bacheca appena
/// sotto: il riquadro "HA VINTO" e le figurine che gli stanno sotto devono dire
/// la stessa cosa, o una delle due sta mentendo.
///
/// **Prima passava dalle gare concluse, e per questo diceva quasi sempre zero.**
/// Quell'elenco copre una finestra di quarantotto ore e ne carica al massimo
/// cinquanta: una vittoria di tre giorni fa ne era gia' uscita, e si finiva con
/// un profilo pieno di trofei sopra un totale a zero. La query dei trofei cerca
/// per `winnerUserId`, campo che resta scritto sulla gara per sempre.
///
/// Si somma il **netto** — quello che finisce davvero in tasca — perche' e' la
/// cifra scritta su ogni singola figurina. Vedi `myPrizeCentsProvider`, che fa
/// lo stesso conto per chi sta guardando il proprio profilo.
final prizeCentsOfProvider = Provider.autoDispose.family<int, String>((
  ref,
  userId,
) {
  final trophies =
      ref.watch(trophiesOfProvider(userId)).valueOrNull ?? const <Challenge>[];

  var total = 0;

  for (final challenge in trophies) {
    total += challenge.payoutCents;
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
