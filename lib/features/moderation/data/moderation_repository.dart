import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crasy/features/moderation/domain/report_reason.dart';

/// Segnalazioni e blocchi.
///
/// **Due cose diverse che sembrano una sola.** Segnalare vuol dire "questa roba
/// non dovrebbe stare qui" e riguarda tutti; bloccare vuol dire "io questa
/// persona non la voglio vedere" e riguarda solo chi blocca. Una non sostituisce
/// l'altra: chi ha appena letto un insulto vuole tutte e due, e se gliene dai
/// una sola se ne va con la sensazione di non aver risolto niente.
class ModerationRepository {
  ModerationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// Quante segnalazioni diverse servono per far sparire una cosa a tutti.
  ///
  /// **Tre, e non una.** Con una sola, due account falsi bastano a far sparire
  /// la foto di un rivale il giorno prima che vinca un premio — e con dei soldi
  /// in palio quello smette di essere un caso di scuola. Con tre, chi vuole
  /// censurare qualcuno deve costruire tre identita' diverse, e nel frattempo
  /// chi segnala per davvero non vede piu' niente lo stesso, subito, perche' la
  /// propria segnalazione nasconde il contenuto **a chi l'ha fatta** a
  /// prescindere dagli altri.
  static const int reportsToHide = 3;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('reports');

  CollectionReference<Map<String, dynamic>> _blocked(String userId) =>
      _firestore.collection('users').doc(userId).collection('blocked');

  /// Manda una segnalazione.
  ///
  /// Scrive in due posti dentro la stessa scrittura: la segnalazione vera —
  /// quella che leggiamo noi — e un segno sul contenuto segnalato, che serve
  /// all'app per farlo sparire senza dover interrogare le segnalazioni di
  /// nessun altro.
  Future<void> report({
    required ReportTargetKind kind,
    required String reporterId,
    required String reportedUserId,
    required ReportReason reason,
    String challengeId = '',
    String entryId = '',
    String commentId = '',
    String note = '',
  }) async {
    final batch = _firestore.batch();

    // L'identificativo mette insieme chi segnala e cosa: **la stessa persona
    // non puo' segnalare due volte la stessa cosa**, e non perche' glielo
    // impedisca un controllo, ma perche' la seconda segnalazione riscrive la
    // prima. Senza, tre tocchi nervosi dello stesso dito farebbero sparire una
    // foto a tutti.
    final target = [
      kind.name,
      if (challengeId.isNotEmpty) challengeId,
      if (entryId.isNotEmpty) entryId,
      if (commentId.isNotEmpty) commentId,
      if (entryId.isEmpty && commentId.isEmpty) reportedUserId,
    ].join('__');

    batch.set(_reports.doc('${reporterId}__$target'), {
      'kind': kind.name,
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'reason': reason.name,
      'challengeId': challengeId,
      'entryId': entryId,
      'commentId': commentId,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });

    // Il segno sul contenuto. Sta dentro la partecipazione e non fuori perche'
    // l'app le partecipazioni le legge gia' tutte: contare le segnalazioni
    // altrove vorrebbe dire una lettura in piu' per ogni foto di ogni
    // schermata.
    if (kind == ReportTargetKind.entry &&
        challengeId.isNotEmpty &&
        entryId.isNotEmpty) {
      batch.set(
        _firestore
            .collection('challenges')
            .doc(challengeId)
            .collection('entries')
            .doc(entryId),
        {
          'reporters': FieldValue.arrayUnion([reporterId]),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  /// Non voglio piu' vedere questa persona.
  Future<void> block({required String userId, required String otherId}) {
    return _blocked(
      userId,
    ).doc(otherId).set({'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> unblock({required String userId, required String otherId}) {
    return _blocked(userId).doc(otherId).delete();
  }

  /// Chi ho bloccato.
  ///
  /// Un ascolto solo per tutta la sessione: e' un elenco corto, cambia quasi
  /// mai, e serve a **ogni** schermata che mostra roba scritta da altri.
  Stream<Set<String>> watchBlocked(String userId) {
    return _blocked(userId).snapshots().map(
      (snapshot) => {for (final document in snapshot.docs) document.id},
    );
  }
}
