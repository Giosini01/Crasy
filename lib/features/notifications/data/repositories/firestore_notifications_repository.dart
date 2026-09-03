import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crasy/features/notifications/domain/entities/app_notification.dart';

/// Le notifiche su Firestore.
///
///     users/{userId}/notifications/{id}
///
/// **Le scrive chi le provoca, non chi le riceve.** Sembra strano e non c'e'
/// alternativa: senza un server acceso — le Cloud Function richiedono il piano
/// a pagamento — nessun altro puo' accorgersi che hai dato una fiamma. Chi la
/// da' e' l'unico che lo sa nel momento in cui succede.
///
/// Le regole di Firestore reggono l'abuso che questo apre: si puo' scrivere
/// solo dichiarando **il proprio** identificativo come autore, non si puo'
/// scrivere a se' stessi, e non si puo' toccare una notifica gia' scritta.
///
/// ## L'identificativo che si ripete
///
/// Il nome del documento non e' casuale: e' `fiamma_{foto}_{chiVota}`. Due
/// persone diverse, due documenti; **la stessa persona sulla stessa foto, lo
/// stesso documento**. Chi toglie e rimette una fiamma venti volte non produce
/// venti notifiche: produce venti tentativi di riscrivere lo stesso documento,
/// e le regole li rifiutano tutti tranne il primo.
///
/// E' la difesa piu' economica che esista contro il fastidio, e non costa
/// nemmeno una lettura: e' il nome del documento a impedirlo.
class FirestoreNotificationsRepository {
  FirestoreNotificationsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _inbox(String userId) =>
      _firestore.collection('users').doc(userId).collection('notifications');

  /// Le ultime notifiche ricevute, dalla piu' recente.
  ///
  /// L'ordinamento si fa in memoria e non nella query: una `orderBy` **salta i
  /// documenti che quel campo non ce l'hanno**, e una notifica scritta un
  /// istante prima che il server le assegnasse l'ora sparirebbe dall'elenco
  /// invece di comparire in cima.
  Stream<List<AppNotification>> watch(String userId) {
    return _inbox(userId).limit(60).snapshots().map((snapshot) {
      final items = [
        for (final document in snapshot.docs)
          _from(document.id, document.data()),
      ];

      items.sort((a, b) {
        final at = a.createdAt;
        final bt = b.createdAt;

        if (at == null && bt == null) {
          return 0;
        }

        // Quelle senza data vanno in cima: sono appena state scritte e l'ora
        // del server non e' ancora tornata indietro.
        if (at == null) {
          return -1;
        }

        if (bt == null) {
          return 1;
        }

        return bt.compareTo(at);
      });

      return items;
    });
  }

  /// Quando si e' aperta la campanella l'ultima volta.
  Stream<DateTime?> watchSeenAt(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map(
          (snapshot) =>
              (snapshot.data()?['notificationsSeenAt'] as Timestamp?)?.toDate(),
        );
  }

  /// Segna tutto come visto.
  ///
  /// Un campo solo sul profilo, invece di un "letta" su ogni notifica: aprire
  /// la campanella diventa **una scrittura** invece di trenta, e il conto delle
  /// non lette e' una data da confrontare invece che una collezione da contare.
  Future<void> markSeen(String userId) {
    return _firestore.collection('users').doc(userId).set({
      'notificationsSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Avvisa qualcuno che hai fatto qualcosa.
  ///
  /// Non lancia mai. Una notifica che non si riesce a scrivere **non deve
  /// rovinare l'azione che l'ha provocata**: se il rifiuto della notifica
  /// facesse fallire la fiamma, un dettaglio di contorno diventerebbe la cosa
  /// che rompe la funzione principale dell'app.
  ///
  /// Il rifiuto piu' comune, poi, e' quello giusto: e' il documento che esiste
  /// gia' perche' quella notifica e' stata mandata la prima volta.
  Future<void> push({
    required String toUserId,
    required String id,
    required NotificationKind kind,
    required String actorId,
    required String actorUsername,
    String challengeId = '',
    String challengeTitle = '',
  }) async {
    if (toUserId.isEmpty || toUserId == actorId) {
      return;
    }

    try {
      await _inbox(toUserId).doc(id).set({
        'kind': kind.name,
        'actorId': actorId,
        'actorUsername': actorUsername,
        'challengeId': challengeId,
        'challengeTitle': challengeTitle,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (_) {
      // Gia' mandata, o non consentita. In tutti e due i casi non c'e' niente
      // da fare e niente da dire a nessuno.
    }
  }

  /// Toglie una notifica che avevamo mandato noi.
  ///
  /// **Serve quando la cosa che l'aveva provocata non c'e' piu'.** Una fiamma
  /// tolta lascerebbe in campanella la notizia di un mi piace che non esiste:
  /// chi la legge apre la propria foto e va a cercare una fiamma che non
  /// trovera'. Un avviso che racconta una cosa falsa e' peggio di nessun
  /// avviso — dopo due volte non lo si guarda piu'.
  ///
  /// Come [push], non lancia: se la cancellazione non riesce resta una riga di
  /// troppo in campanella, che e' molto meno grave di una fiamma che non si
  /// riesce a togliere perche' e' fallito un dettaglio di contorno.
  Future<void> remove({required String toUserId, required String id}) async {
    if (toUserId.isEmpty) {
      return;
    }

    try {
      await _inbox(toUserId).doc(id).delete();
    } on FirebaseException catch (_) {
      // Vedi sopra.
    }
  }

  /// Il nome del documento di una fiamma. Stessa persona, stessa foto, stesso
  /// nome: la notifica esiste una volta sola.
  static String fireId({required String voteKey, required String actorId}) =>
      'fiamma_${voteKey}_$actorId';

  /// Il nome del documento di una nomina dentro un commento.
  ///
  /// Ci sono la gara, chi nomina e chi e' nominato — non **quale** commento.
  /// Cosi' chi ti nomina dieci volte nella stessa gara ti fa squillare la
  /// campanella una volta: le regole accettano una notifica sola per nome di
  /// documento, e le altre nove vengono scartate senza far niente.
  static String mentionId({
    required String challengeId,
    required String actorId,
    required String toUserId,
  }) => 'nomina_${challengeId}_${actorId}_$toUserId';

  /// Il nome del documento di un commento sotto una foto.
  ///
  /// Ci sono la foto e chi ha scritto — non **quale** commento. Cosi' una
  /// conversazione di venti righe fra due persone fa squillare la campanella
  /// una volta: le regole accettano una notifica sola per nome di documento, e
  /// le altre diciannove vengono scartate senza fare niente.
  static String commentId({
    required String challengeId,
    required String entryId,
    required String actorId,
  }) => 'commento_${challengeId}_${entryId}_$actorId';

  /// Il nome del documento di una partecipazione.
  static String participationId({
    required String challengeId,
    required String actorId,
  }) => 'gara_${challengeId}_$actorId';

  AppNotification _from(String id, Map<String, dynamic> data) {
    return AppNotification(
      id: id,
      kind: AppNotification.kindFromName(data['kind'] as String?),
      actorId: data['actorId'] as String? ?? '',
      actorUsername: data['actorUsername'] as String? ?? '',
      challengeId: data['challengeId'] as String? ?? '',
      challengeTitle: data['challengeTitle'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
