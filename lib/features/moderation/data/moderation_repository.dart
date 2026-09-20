import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crasy/features/moderation/domain/report_reason.dart';
import 'package:crasy/features/moderation/domain/report_status.dart';

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
    String note = '',
    String reportedUsername = '',
    String mediaUrl = '',
    String challengeTitle = '',
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
      if (entryId.isEmpty) reportedUserId,
    ].join('__');

    batch.set(_reports.doc('${reporterId}__$target'), {
      'kind': kind.name,
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'reason': reason.name,
      'challengeId': challengeId,
      'entryId': entryId,
      'note': note,
      // **Quello che serve a chi la guardera', copiato dentro.**
      //
      // La dashboard deve poter mostrare la foto, il nome di chi l'ha
      // pubblicata e in che gara stava, e le tre cose non sono sempre ancora
      // li' quando qualcuno la apre: le partecipazioni vengono cancellate
      // quarantotto ore dopo la fine della gara, insieme alle foto. Una
      // segnalazione che rimanda a un documento che non c'e' piu' e' una
      // segnalazione che non si puo' piu' giudicare.
      //
      // Sono **dati di comodo**, scritti da un telefono e percio' non fidati:
      // la funzione dell'amministratore, quando la partecipazione esiste
      // ancora, legge quella e ignora questi. Servono a non restare ciechi
      // dopo, non a decidere.
      'reportedUsername': reportedUsername,
      'mediaUrl': mediaUrl,
      'challengeTitle': challengeTitle,
      'createdAt': FieldValue.serverTimestamp(),
      // **Nasce nuova, e non la muove nessun telefono.** A cambiare questo
      // campo e' solo `adminResolveReport`, che scrive con l'SDK di
      // amministrazione e non passa dalle regole. Le regole, dalla loro parte,
      // non danno a nessuno il permesso di aggiornare una segnalazione: una
      // segnalazione che si puo' ritirare e' una segnalazione che basta una
      // minaccia a far ritirare.
      'status': ReportStatus.fresh.wire,
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
