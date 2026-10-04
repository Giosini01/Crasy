import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crasy/features/friends/domain/entities/friendship.dart';
import 'package:crasy/features/profile/data/mappers/user_profile_mapper.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';

/// Le amicizie su Firestore.
///
///     users/{userId}                          il profilo, leggibile da tutti
///     users/{userId}/friends/{friendId}       gli amici, due righe per coppia
///     users/{userId}/friendRequests/{fromId}  chi mi segue e io non ancora
///     users/{userId}/following/{otherId}      chi seguo io
///
/// ## Seguire, e diventare amici
///
/// **Si segue da soli, si diventa amici in due.** Seguire qualcuno scrive due
/// cose: la riga in `following` sotto di me — serve a vedere dove gareggia — e
/// la "richiesta" nella sua cartella, che per lui vuol dire *ti segue* e gli fa
/// arrivare l'avviso. Se ricambia, nascono le due righe di `friends` e da li'
/// si puo' sfidare: e' la stessa amicizia di prima, a cui si arriva seguendosi
/// a vicenda.
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

  CollectionReference<Map<String, dynamic>> _following(String userId) =>
      _users.doc(userId).collection('following');

  /// Chi seguo. Gli amici ci sono anche loro, se si sono seguiti da quando
  /// esiste questa cartella: per le amicizie di prima vale `friends`.
  Stream<List<Friend>> watchFollowing(String userId) {
    return _following(userId).limit(300).snapshots().map((snapshot) {
      return [
        for (final document in snapshot.docs)
          Friend(
            userId: document.id,
            username: document.data()['username'] as String? ?? '',
            since: (document.data()['since'] as Timestamp?)?.toDate(),
          ),
      ];
    });
  }

  /// **Chi seguo e quando ho guardato i follower**, dal mio profilo.
  ///
  /// Chi seguo sta anche qui, in un elenco dentro il mio documento, e non solo
  /// nella cartella `following`: il mio documento lo posso scrivere con le
  /// regole di sempre, e seguire qualcuno deve funzionare anche prima che le
  /// regole nuove siano pubblicate. Era il motivo per cui chi seguiva senza
  /// essere ricambiato non vedeva niente.
  Stream<
    ({
      List<String> seguiti,
      DateTime? followersSeenAt,
      int? followersCount,
      int? followingCount,
    })
  >
  watchOwnFollow(String userId) {
    return _users.doc(userId).snapshots().map((snapshot) {
      final data = snapshot.data() ?? const <String, dynamic>{};
      final seguiti = [
        for (final id in (data['seguiti'] as List<dynamic>? ?? const []))
          if (id is String && id.isNotEmpty) id,
      ];

      // Mentre l'ora del server non e' ancora tornata vale adesso: letta come
      // nulla, riaccenderebbe il pallino su tutti per un istante.
      var visti = (data['followersSeenAt'] as Timestamp?)?.toDate();

      if (visti == null &&
          snapshot.metadata.hasPendingWrites &&
          data.containsKey('followersSeenAt')) {
        visti = DateTime.now();
      }

      return (
        seguiti: seguiti,
        followersSeenAt: visti,
        // I contatori li tiene il server: con mille follower contarli qui
        // vorrebbe dire leggerne mille a ogni apertura del profilo.
        followersCount: (data['followersCount'] as num?)?.toInt(),
        followingCount: (data['followingCount'] as num?)?.toInt(),
      );
    });
  }

  /// **Una pagina di chi mi segue senza che io ricambi**, dalla piu' recente.
  ///
  /// A pagine e non tutti insieme: con mille follower l'elenco si legge
  /// trenta alla volta, mentre si scorre, invece di mille righe ogni volta
  /// che si apre la schermata.
  Future<({List<FriendRequest> righe, DocumentSnapshot<Object?>? ultimo})>
  pageIncoming(
    String userId, {
    DocumentSnapshot<Object?>? dopo,
    int quanti = 30,
  }) async {
    var query = _requests(
      userId,
    ).orderBy('createdAt', descending: true).limit(quanti);

    if (dopo != null) {
      query = query.startAfterDocument(dopo);
    }

    final pagina = await query.get();

    return (
      righe: [
        for (final document in pagina.docs)
          FriendRequest(
            fromUserId: document.id,
            fromUsername: document.data()['fromUsername'] as String? ?? '',
            createdAt: (document.data()['createdAt'] as Timestamp?)?.toDate(),
          ),
      ],
      ultimo: pagina.docs.isEmpty ? null : pagina.docs.last,
    );
  }

  /// **Una pagina di amici**, dai piu' recenti. Come [pageIncoming].
  Future<({List<Friend> righe, DocumentSnapshot<Object?>? ultimo})> pageFriends(
    String userId, {
    DocumentSnapshot<Object?>? dopo,
    int quanti = 30,
  }) async {
    var query = _friends(
      userId,
    ).orderBy('since', descending: true).limit(quanti);

    if (dopo != null) {
      query = query.startAfterDocument(dopo);
    }

    final pagina = await query.get();

    return (
      righe: [
        for (final document in pagina.docs)
          Friend(
            userId: document.id,
            username: document.data()['username'] as String? ?? '',
            since: (document.data()['since'] as Timestamp?)?.toDate(),
          ),
      ],
      ultimo: pagina.docs.isEmpty ? null : pagina.docs.last,
    );
  }

  /// Aggiunge [otherId] a chi seguo, nel mio documento. Non lancia.
  Future<void> addSeguito({
    required String meId,
    required String otherId,
  }) async {
    try {
      await _users.doc(meId).set({
        'seguiti': FieldValue.arrayUnion([otherId]),
      }, SetOptions(merge: true));
    } on FirebaseException catch (_) {
      // Resta la riga in `following`, se le regole la lasciano scrivere.
    }
  }

  /// Toglie [otherId] da chi seguo, nel mio documento. Non lancia.
  Future<void> removeSeguito({
    required String meId,
    required String otherId,
  }) async {
    try {
      await _users.doc(meId).set({
        'seguiti': FieldValue.arrayRemove([otherId]),
      }, SetOptions(merge: true));
    } on FirebaseException catch (_) {
      // Vedi sopra.
    }
  }

  /// Segna che ho guardato chi mi segue: il pallino rosso si spegne.
  Future<void> markFollowersSeen(String userId) async {
    try {
      await _users.doc(userId).set({
        'followersSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (_) {
      // Il pallino resta acceso fino alla prossima volta. Pazienza.
    }
  }

  /// Scrive che [meId] segue [otherId].
  ///
  /// **Non lancia.** La cartella `following` ha regole sue: se non sono ancora
  /// state pubblicate la scrittura viene rifiutata, e seguire deve funzionare
  /// lo stesso — la richiesta, cioe' l'avviso e il bottone, e' gia' partita.
  Future<void> markFollowing({
    required String meId,
    required String otherId,
    required String otherUsername,
  }) async {
    try {
      await _following(meId).doc(otherId).set({
        'username': otherUsername,
        'since': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (_) {
      // Vedi sopra.
    }
  }

  /// Toglie che [followerId] segue [otherId]. Non lancia, come [markFollowing].
  Future<void> unmarkFollowing({
    required String followerId,
    required String otherId,
  }) async {
    try {
      await _following(followerId).doc(otherId).delete();
    } on FirebaseException catch (_) {
      // Vedi sopra.
    }
  }

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
