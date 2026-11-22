import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crasy/features/gioco/domain/entities/regole_del_gioco.dart';
import 'package:crasy/features/gioco/domain/entities/stato_del_gioco.dart';

/// **Il gioco visto dall'app: si legge, non si scrive.**
///
/// Tre ascolti e una chiamata. Le regole (`config/gioco`), lo stato di chi
/// guarda (`gioco/{uid}`), i premi che arrivano (`gioco/{uid}/xp`); e
/// `apriLeSfide`, che chiede al server le sfide di oggi. Nessuna scrittura:
/// punti e progressi li muove il server quando succede un fatto vero, e le
/// regole del database non lascerebbero comunque scrivere niente da qui.
class GiocoRepository {
  GiocoRepository(this._firestore, this._functions);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> _stato(String uid) =>
      _firestore.collection('gioco').doc(uid);

  Stream<RegoleDelGioco?> watchRegole() {
    return _firestore.collection('config').doc('gioco').snapshots().map((doc) {
      final dati = doc.data();

      return dati == null ? null : RegoleDelGioco.fromMap(dati);
    });
  }

  /// Lo stato di una persona. Prima del primo fatto non c'e' ancora: e' lo
  /// stato di chi parte da zero, non un errore.
  Stream<StatoDelGioco> watchStato(String uid) {
    return _stato(uid).snapshots().map((doc) {
      final dati = doc.data();

      return dati == null ? const StatoDelGioco() : StatoDelGioco.fromMap(dati);
    });
  }

  /// **I premi che arrivano mentre l'app e' aperta**, uno per uno.
  ///
  /// Quelli che c'erano gia' non si festeggiano: si aspetta la prima risposta
  /// del server — non quella della memoria del telefono, che potrebbe essere
  /// vecchia di giorni — e da li' in poi conta solo cio' che arriva di nuovo.
  /// Su due telefoni aperti insieme, la festa la fanno tutti e due.
  Stream<PremioXp> premiNuovi(String uid) async* {
    final visti = <String>{};
    var pronto = false;

    final ascolto = _stato(uid)
        .collection('xp')
        .orderBy('quando', descending: true)
        .limit(10)
        .snapshots(includeMetadataChanges: true);

    await for (final istantanea in ascolto) {
      if (!pronto) {
        visti.addAll(istantanea.docs.map((doc) => doc.id));
        pronto = !istantanea.metadata.isFromCache;

        continue;
      }

      for (final cambio in istantanea.docChanges) {
        final dati = cambio.doc.data();

        if (cambio.type == DocumentChangeType.added &&
            dati != null &&
            visti.add(cambio.doc.id)) {
          yield PremioXp.fromMap(cambio.doc.id, dati);
        }
      }
    }
  }

  /// Chiede al server le sfide di oggi. Il giorno lo decide lui: l'orologio
  /// del telefono non conta.
  Future<void> apri() async {
    await _functions.httpsCallable('apriLeSfide').call<Object?>();
  }
}
