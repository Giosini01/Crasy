import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crasy/features/challenges/data/mappers/challenge_mapper.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Le challenge su Firestore.
///
/// La struttura e' questa, e non e' negoziabile perche' ci poggiano sopra sia
/// le regole sia gli indici:
///
///     challenges/{challengeId}
///     challenges/{challengeId}/entries/{userId}
///     users/{userId}/votes/{entryId}
///
/// Due scelte meritano una riga. La prima: **la partecipazione ha per
/// identificativo l'utente**. Non e' un vezzo, e' la regola "una foto a testa
/// per challenge" scritta nella forma dei dati invece che in un controllo che
/// qualcuno prima o poi dimentichera' di fare — con un premio in denaro in
/// ballo, mandare venti foto per moltiplicare le proprie probabilita' e' la
/// prima cosa che verrebbe in mente a chiunque.
///
/// La seconda: **i voti stanno sotto l'utente che li ha dati**, non sotto la
/// foto votata. Cosi' "cosa ho gia' votato" e' una sola lettura di una
/// sottocollezione, mentre nell'altro verso sarebbe una query su tutto il
/// database.
class FirestoreChallengeRepository implements ChallengeRepository {
  FirestoreChallengeRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _challenges =>
      _firestore.collection('challenges');

  CollectionReference<Map<String, dynamic>> _entries(String challengeId) =>
      _challenges.doc(challengeId).collection('entries');

  CollectionReference<Map<String, dynamic>> _votes(String userId) =>
      _firestore.collection('users').doc(userId).collection('votes');

  @override
  Stream<List<Challenge>> watchLiveChallenges() {
    // Il filtro e' su `endsAt` soltanto, e l'inizio si controlla in memoria:
    // Firestore non accetta disuguaglianze su due campi diversi nella stessa
    // query, e delle due questa e' quella che taglia i documenti inutili.
    return _challenges
        .where('endsAt', isGreaterThan: Timestamp.now())
        .orderBy('endsAt')
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();

          return _challengesFrom(
            snapshot,
          ).where((challenge) => !challenge.isUpcomingAt(now)).toList();
        });
  }

  @override
  Stream<List<Challenge>> watchEndedChallenges() {
    return _challenges
        .where('endsAt', isLessThanOrEqualTo: Timestamp.now())
        .orderBy('endsAt', descending: true)
        .limit(50)
        .snapshots()
        .map(_challengesFrom);
  }

  @override
  Stream<Challenge?> watchChallenge(String challengeId) {
    return _challenges.doc(challengeId).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      return ChallengeMapper.fromFirestore(snapshot.id, data);
    });
  }

  @override
  Stream<List<ChallengeEntry>> watchEntries(String challengeId) {
    return _entries(challengeId)
        .orderBy('votes', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => [
            for (final document in snapshot.docs)
              ChallengeEntryMapper.fromFirestore(
                document.id,
                challengeId,
                document.data(),
              ),
          ],
        );
  }

  @override
  Stream<List<ChallengeEntry>> watchLatestEntries({int limit = 30}) {
    return _firestore
        .collectionGroup('entries')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_entriesFrom);
  }

  @override
  Stream<List<ChallengeEntry>> watchEntriesByUser(String userId) {
    return _firestore
        .collectionGroup('entries')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .map(_entriesFrom);
  }

  @override
  Future<Challenge> createChallenge(Challenge challenge) async {
    final document = await _challenges.add(
      ChallengeMapper.toCreateMap(challenge),
    );

    return challenge.copyWith(id: document.id);
  }

  @override
  Future<ChallengeEntry> submitEntry({
    required String challengeId,
    required String userId,
    required String authorName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final challengeRef = _challenges.doc(challengeId);
    final challengeSnapshot = await challengeRef.get();
    final challengeData = challengeSnapshot.data();

    if (!challengeSnapshot.exists || challengeData == null) {
      throw const ChallengeNotFoundException();
    }

    final challenge = ChallengeMapper.fromFirestore(
      challengeSnapshot.id,
      challengeData,
    );

    if (!challenge.isLiveAt(DateTime.now())) {
      throw const ChallengeClosedException();
    }

    final entryRef = _entries(challengeId).doc(userId);
    final storagePath = 'entries/$challengeId/$userId.jpg';
    final reference = _storage.ref(storagePath);

    // Il file sale per primo. Se l'upload fallisce non resta un documento che
    // punta a una foto inesistente, cioe' una partecipazione vuota in gara per
    // un premio.
    await reference.putData(
      bytes,
      SettableMetadata(contentType: contentType ?? 'image/jpeg'),
    );

    final entry = ChallengeEntry(
      id: userId,
      challengeId: challengeId,
      challengeTitle: challenge.title,
      userId: userId,
      authorName: authorName,
      mediaUrl: await reference.getDownloadURL(),
      storagePath: storagePath,
    );

    // **Una foto sola, e non si cambia.** Il controllo sta dentro la
    // transazione e non prima: fra una lettura e una scrittura separate ci
    // starebbe comodamente un secondo invio partito da un altro dispositivo.
    //
    // Il rifiuto e' voluto anche a challenge aperta. Poter sostituire la
    // propria foto dopo aver visto quante fiamme prende significherebbe
    // cambiare la mano dopo aver guardato le carte degli altri.
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(entryRef);

      if (existing.exists) {
        throw const AlreadyParticipatingException();
      }

      transaction.set(entryRef, ChallengeEntryMapper.toCreateMap(entry));
      transaction.update(challengeRef, {
        'participantsCount': FieldValue.increment(1),
      });
    });

    return entry;
  }

  @override
  Future<void> setVote({
    required String challengeId,
    required String entryId,
    required String userId,
    required bool voted,
  }) async {
    final voteRef = _votes(userId).doc(entryId);
    final entryRef = _entries(challengeId).doc(entryId);

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(voteRef);

      // Se il voto e' gia' come lo si vuole non si scrive niente. Senza questo
      // controllo un doppio tocco, o due schermate aperte sulla stessa foto,
      // farebbero salire il contatore due volte per un voto solo.
      if (existing.exists == voted) {
        return;
      }

      if (voted) {
        transaction.set(voteRef, {
          'challengeId': challengeId,
          'entryId': entryId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.delete(voteRef);
      }

      transaction.update(entryRef, {
        'votes': FieldValue.increment(voted ? 1 : -1),
      });
    });
  }

  @override
  Stream<Set<String>> watchVotedEntryIds(String userId) {
    return _votes(
      userId,
    ).snapshots().map((snapshot) => {for (final doc in snapshot.docs) doc.id});
  }

  List<Challenge> _challengesFrom(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return [
      for (final document in snapshot.docs)
        ChallengeMapper.fromFirestore(document.id, document.data()),
    ];
  }

  /// Le partecipazioni lette con una query sul gruppo di collezioni non sanno
  /// da sole a che challenge appartengono: l'identificativo si ricava dal
  /// genitore del documento.
  List<ChallengeEntry> _entriesFrom(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return [
      for (final document in snapshot.docs)
        ChallengeEntryMapper.fromFirestore(
          document.id,
          document.reference.parent.parent?.id ?? '',
          document.data(),
        ),
    ];
  }
}

/// La challenge a cui si sta partecipando non esiste piu'.
class ChallengeNotFoundException implements Exception {
  const ChallengeNotFoundException();

  @override
  String toString() => 'ChallengeNotFoundException';
}

/// Il tempo e' scaduto fra l'apertura della fotocamera e l'invio.
class ChallengeClosedException implements Exception {
  const ChallengeClosedException();

  @override
  String toString() => 'ChallengeClosedException';
}

/// Una foto per questa challenge era gia' stata mandata.
class AlreadyParticipatingException implements Exception {
  const AlreadyParticipatingException();

  @override
  String toString() => 'AlreadyParticipatingException';
}
