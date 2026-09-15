import 'package:cloud_firestore/cloud_firestore.dart';

/// Le proclamazioni che una persona ha gia' guardato.
///
///     users/{userId}/revealsSeen/{challengeId}
///
/// **Un rullo di tamburi si vede una volta.** Rifarlo a ogni apertura della
/// missione lo trasformerebbe da momento in intralcio, e coprirebbe la
/// classifica proprio a chi era tornato per guardarla con calma.
///
/// Sta sul database e non sul telefono perche' deve valere per **la persona**,
/// non per l'apparecchio: chi ha visto vincere dal telefono non deve rivedere
/// lo stesso rullo aprendo l'app da un'altra parte.
///
/// I documenti sono vuoti: conta che esistano, e il loro nome e' la gara.
class RevealSeenStore {
  const RevealSeenStore(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String userId, String challengeId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('revealsSeen')
          .doc(challengeId);

  /// Se questa persona ha gia' visto proclamare questa gara.
  ///
  /// **In caso di dubbio dice di si'.** Se la lettura non riesce — rete assente,
  /// permessi — la scelta e' fra non mostrare un'animazione e mostrarla a
  /// qualcuno che l'ha gia' vista, magari sopra la classifica che stava
  /// leggendo. La prima si perde, la seconda da' fastidio.
  Future<bool> seen({required String userId, required String challengeId}) async {
    if (userId.isEmpty || challengeId.isEmpty) {
      return true;
    }

    try {
      final snapshot = await _doc(userId, challengeId).get();

      return snapshot.exists;
    } on Object catch (_) {
      return true;
    }
  }

  /// Quali proclamazioni ha gia' visto, mentre cambiano.
  ///
  /// **Serve alla campanella, e serve a non rovinare la sorpresa.** La riga
  /// *hai vinto* si ricava dalla partecipazione, quindi comparirebbe **prima**
  /// che qualcuno abbia aperto la missione: uno tocca la notifica *e' finita*,
  /// passa dalla campanella e legge il finale li', e il rullo di tamburi arriva
  /// a raccontare una cosa gia' saputa. Finche' non l'ha vista, quella riga non
  /// c'e'.
  /// **Solo le gare che interessano**, non tutta la collezione.
  ///
  /// Serviva a rispondere a una domanda sola — *di queste gare che ho vinto,
  /// quali ho gia' visto proclamare?* — e per rispondere leggeva **ogni
  /// documento** della collezione, a ogni avvio dell'app. Quella collezione non
  /// la svuota nessuno: cresce per sempre, e la domanda invece riguarda sempre
  /// pochissime gare, perche' le vittorie sono poche.
  ///
  /// **Un `limit()` qui sarebbe stato sbagliato**, e vale la pena dirlo: senza
  /// un ordinamento Firestore non promette *quali* documenti restituisce. Se
  /// fosse rimasto fuori proprio quello della gara che serve, l'app crederebbe
  /// che il rullo non e' stato visto e mostrerebbe la riga *hai vinto* in
  /// anticipo — cioe' lo spoiler che tutto questo esiste per evitare.
  ///
  /// Si chiedono invece **per nome**, che e' la domanda esatta. Trenta per
  /// volta e' il tetto di Firestore su `whereIn`, e trenta vittorie da
  /// guardare insieme non le ha nessuno: oltre quelle, le piu' vecchie si danno
  /// per viste — il rullo di una gara di sei mesi fa non lo aspetta nessuno.
  Stream<Set<String>> watchSeen(String userId, List<String> challengeIds) {
    final cercate = challengeIds.take(30).toList();

    if (userId.isEmpty || cercate.isEmpty) {
      return Stream.value(const <String>{});
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('revealsSeen')
        .where(FieldPath.documentId, whereIn: cercate)
        .snapshots()
        .map((snapshot) => {for (final doc in snapshot.docs) doc.id});
  }

  /// Segna che l'ha vista.
  ///
  /// **Si chiama quando il rullo comincia, non quando finisce.** Chi chiude
  /// l'app a meta' l'ha visto abbastanza da sapere com'e' andata; segnandolo
  /// alla fine, un'uscita a meta' lo farebbe ripartire da capo alla riapertura,
  /// e cosi' ogni volta.
  Future<void> markSeen({
    required String userId,
    required String challengeId,
  }) async {
    if (userId.isEmpty || challengeId.isEmpty) {
      return;
    }

    try {
      await _doc(userId, challengeId).set({
        'seenAt': FieldValue.serverTimestamp(),
      });
    } on Object catch (_) {
      // Se non si riesce a scrivere, il rullo si rivedra' una volta di troppo.
      // E' il tipo di guasto che non merita di far fallire niente.
    }
  }
}
