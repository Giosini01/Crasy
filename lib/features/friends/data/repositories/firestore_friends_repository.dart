import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crasy/features/friends/domain/entities/friendship.dart';
import 'package:crasy/features/profile/data/mappers/user_profile_mapper.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';

/// Le amicizie su Firestore.
///
///     users/{userId}                          il profilo, leggibile da tutti
///     users/{userId}/friends/{friendId}       gli amici, due righe per coppia
///     users/{userId}/friendRequests/{fromId}  le richieste ricevute
///
/// **Un'amicizia sono due documenti**, uno per parte, e non uno solo con dentro
/// due nomi. Sembra una duplicazione ed e' la scelta che tiene in piedi tutto:
/// "chi sono i miei amici" diventa la lettura di una sola cartella, la mia,
/// invece di una ricerca su tutto il database di ogni documento che mi nomina.
///
/// Il prezzo e' che accettare scrive in due posti e va fatto insieme. Il vantaggio
/// e' che ogni lettura successiva — cioe' quasi tutto — costa una query sola.
class FirestoreFriendsRepository {
  FirestoreFriendsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> _friends(String userId) =>
      _users.doc(userId).collection('friends');

  CollectionReference<Map<String, dynamic>> _requests(String userId) =>
      _users.doc(userId).collection('friendRequests');

  /// Il profilo di chiunque. Emette `null` se non esiste.
  Stream<UserProfile?> watchProfile(String userId) {
    return _users.doc(userId).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      return UserProfileMapper.fromFirestore(snapshot.id, data);
    });
  }

  /// Le persone il cui nome comincia per [query].
  ///
  /// **Per prefisso, non "che contiene"**, ed e' un limite dichiarato invece
  /// che nascosto: Firestore non sa cercare dentro una parola, e l'unico modo
  /// di fingere che lo sappia — scaricare tutti i profili e filtrarli sul
  /// telefono — e' una ricerca che funziona finche' gli iscritti sono cento e
  /// smette di funzionare esattamente quando comincia a servire.
  ///
  /// Il nome e' gia' scritto minuscolo sul profilo, quindi qui basta abbassare
  /// quello che e' stato digitato: una ricerca che non trova `Marco` perche' e'
  /// stato scritto con la maiuscola sarebbe una ricerca rotta.
  ///
  /// Il carattere finale (``) e' il piu' alto che Firestore sappia
  /// ordinare: sta dopo qualunque cosa possa seguire il prefisso, ed e' cio'
  /// che chiude l'intervallo su "tutto quello che comincia cosi'".
  Future<List<UserProfile>> searchProfiles(
    String query, {
    int limit = 20,
  }) async {
    final needle = query.trim().toLowerCase();

    if (needle.isEmpty) {
      return const [];
    }

    final snapshot = await _users
        .orderBy('username')
        .startAt([needle])
        .endAt(['$needle'])
        .limit(limit)
        .get();

    return [
      for (final document in snapshot.docs)
        UserProfileMapper.fromFirestore(document.id, document.data()),
    ];
  }

  Stream<List<Friend>> watchFriends(String userId) {
    return _friends(userId).limit(300).snapshots().map((snapshot) {
      final friends = [
        for (final document in snapshot.docs)
          Friend(
            userId: document.id,
            username: document.data()['username'] as String? ?? '',
            since: (document.data()['since'] as Timestamp?)?.toDate(),
          ),
      ];

      // L'ordine si fa qui e non nella query: una query ordinata per un campo
      // salta i documenti che quel campo non ce l'hanno, e un amico non deve
      // sparire dall'elenco per una data mancante.
      return friends..sort((a, b) => a.username.compareTo(b.username));
    });
  }

  Stream<List<FriendRequest>> watchIncomingRequests(String userId) {
    return _requests(userId).limit(100).snapshots().map((snapshot) {
      return [
        for (final document in snapshot.docs)
          FriendRequest(
            fromUserId: document.id,
            fromUsername: document.data()['fromUsername'] as String? ?? '',
            createdAt: (document.data()['createdAt'] as Timestamp?)?.toDate(),
          ),
      ];
    });
  }

  /// Che rapporto c'e' fra [meId] e [otherId], in tempo reale.
  ///
  /// Tre letture di documenti singoli, non tre query: sono tutte e tre per
  /// identificativo esatto, quindi costano quanto una riga.
  Stream<FriendshipStatus> watchStatus({
    required String meId,
    required String otherId,
  }) {
    if (meId == otherId) {
      return Stream.value(FriendshipStatus.self);
    }

    final areFriends = _friends(meId).doc(otherId).snapshots();
    final iSent = _requests(otherId).doc(meId).snapshots();
    final iReceived = _requests(meId).doc(otherId).snapshots();

    return areFriends.asyncExpand((friend) {
      if (friend.exists) {
        return Stream.value(FriendshipStatus.friends);
      }

      return iReceived.asyncExpand((received) {
        if (received.exists) {
          return Stream.value(FriendshipStatus.requestReceived);
        }

        return iSent.map(
          (sent) => sent.exists
              ? FriendshipStatus.requestSent
              : FriendshipStatus.none,
        );
      });
    });
  }

  /// Manda la richiesta. Il nome viaggia con essa: chi la riceve deve sapere
  /// **chi** e' senza dover leggere un altro documento.
  Future<void> sendRequest({
    required String fromUserId,
    required String fromUsername,
    required String toUserId,
  }) {
    return _requests(toUserId).doc(fromUserId).set({
      'fromUsername': fromUsername,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelRequest({
    required String fromUserId,
    required String toUserId,
  }) {
    return _requests(toUserId).doc(fromUserId).delete();
  }

  /// Accetta: nascono le due righe dell'amicizia e la richiesta sparisce.
  ///
  /// Le tre scritture vanno **insieme**, in un lotto: un'amicizia scritta da una
  /// parte sola e' il tipo di stato che poi nessuno sa piu' come rimettere a
  /// posto — uno vede l'altro fra i suoi amici e l'altro no.
  Future<void> acceptRequest({
    required String meId,
    required String meUsername,
    required String fromUserId,
    required String fromUsername,
  }) {
    final batch = _firestore.batch()
      ..set(_friends(meId).doc(fromUserId), {
        'username': fromUsername,
        'since': FieldValue.serverTimestamp(),
      })
      ..set(_friends(fromUserId).doc(meId), {
        'username': meUsername,
        'since': FieldValue.serverTimestamp(),
      })
      ..delete(_requests(meId).doc(fromUserId));

    return batch.commit();
  }

  Future<void> rejectRequest({
    required String meId,
    required String fromUserId,
  }) {
    return _requests(meId).doc(fromUserId).delete();
  }

  /// Toglie l'amicizia da tutte e due le parti.
  Future<void> removeFriend({required String meId, required String otherId}) {
    final batch = _firestore.batch()
      ..delete(_friends(meId).doc(otherId))
      ..delete(_friends(otherId).doc(meId));

    return batch.commit();
  }
}
