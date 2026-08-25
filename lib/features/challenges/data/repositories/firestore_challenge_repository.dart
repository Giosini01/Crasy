import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crasy/features/challenges/data/mappers/challenge_mapper.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
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

          // Il filtro sul pagamento si fa qui e non nella query, e non e' una
          // pigrizia: una `where` su `prizeStatus` **salterebbe i documenti che
          // quel campo non ce l'hanno**, cioe' tutte le challenge scritte prima
          // che i pagamenti esistessero. A pagamenti spenti sparirebbero tutte
          // insieme, e la home resterebbe vuota senza un errore da nessuna
          // parte. `isPayable` sa gia' cosa fare in tutti e due i casi.
          return _challengesFrom(snapshot)
              .where(
                (challenge) =>
                    !challenge.isUpcomingAt(now) && challenge.isPayable,
              )
              .toList();
        });
  }

  @override
  Stream<List<Challenge>> watchEndedChallenges() {
    // Due limiti sullo stesso campo — finita, ma **non piu' di due giorni fa**.
    // Firestore li accetta perche' sono tutti e due su `endsAt`, e sono cio'
    // che tiene questa schermata corta: le gare piu' vecchie non si leggono
    // nemmeno, e poco dopo il server le cancella del tutto.
    final now = DateTime.now();

    return _challenges
        .where('endsAt', isLessThanOrEqualTo: Timestamp.now())
        .where(
          'endsAt',
          isGreaterThan: Timestamp.fromDate(
            now.subtract(Challenge.winnersWindow),
          ),
        )
        .orderBy('endsAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => _challengesFrom(
            snapshot,
          ).where((challenge) => challenge.isPayable).toList(),
        );
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

  /// Le partecipazioni a una challenge, dalla piu' votata.
  ///
  /// **L'ordinamento si fa in memoria, non su Firestore**, e la ragione e' una
  /// trappola che e' gia' costata una foto sparita: una query ordinata per un
  /// campo *esclude i documenti che quel campo non ce l'hanno*. Una
  /// partecipazione scritta da una versione dell'app che non salvava ancora
  /// `votes` non spariva dalla classifica — spariva dalla schermata, pur
  /// esistendo nel database.
  ///
  /// Qui si chiedono tutte le partecipazioni e si ordinano dopo. Con qualche
  /// centinaio di foto per challenge il costo e' nullo, e nessun documento puo'
  /// piu' rendersi invisibile perche' gli manca un campo.
  @override
  Stream<List<ChallengeEntry>> watchEntries(String challengeId) {
    return _entries(challengeId).limit(300).snapshots().map((snapshot) {
      final entries = [
        for (final document in snapshot.docs)
          ChallengeEntryMapper.fromFirestore(
            document.id,
            challengeId,
            document.data(),
          ),
      ];

      return entries..sort(_byVotesThenOldest);
    });
  }

  /// Piu' fiamme per prima; a parita', chi ha mandato prima.
  ///
  /// E' lo stesso criterio con cui il server proclama il vincitore: la
  /// classifica che si vede deve essere quella che poi paga.
  static int _byVotesThenOldest(ChallengeEntry a, ChallengeEntry b) {
    final byVotes = b.votes.compareTo(a.votes);

    if (byVotes != 0) {
      return byVotes;
    }

    final aTime = a.createdAt;
    final bTime = b.createdAt;

    if (aTime == null || bTime == null) {
      return 0;
    }

    return aTime.compareTo(bTime);
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
    MediaKind mediaKind = MediaKind.photo,
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

    // Il nome del file e' casuale, la cartella no.
    //
    // La cartella porta l'identificativo di chi carica, ed e' quella a
    // proteggere dalle foto altrui. Il nome casuale serve ai **ritentativi**:
    // il file sale prima che il documento venga scritto, quindi un tentativo
    // interrotto a meta' lascia un file la' — e con un nome fisso il tentativo
    // successivo si scontrerebbe con un oggetto che le regole non lasciano
    // sovrascrivere, bloccando quella persona per sempre.
    //
    // `doc().id` conia un identificativo nuovo senza scrivere niente.
    final uploadId = _entries(challengeId).doc().id;
    // **Un video si dichiara sempre `video/mp4`, anche quando arriva da un
    // iPhone che lo chiama QuickTime.**
    //
    // Sembra una bugia e non lo e'. Dentro un `.mov` di iPhone ci sono H.264 e
    // AAC: le stesse identiche cose che stanno dentro un mp4, impacchettate
    // nello stesso modo. Cambia l'etichetta sulla scatola, non la roba dentro —
    // ed e' l'etichetta a far rifiutare il file a mezzo mondo. Chrome, davanti
    // a `video/quicktime`, non prova nemmeno ad aprirlo.
    //
    // Il rischio, se un giorno arrivasse davvero un formato che il browser non
    // sa leggere: fallirebbe comunque, etichetta o no. Non si perde niente, e
    // si guadagna che i video girati con un iPhone si vedono anche su Android.
    final type = mediaKind.isVideo
        ? 'video/mp4'
        : (contentType ?? 'image/jpeg');
    final storagePath =
        'entries/$challengeId/$userId/$uploadId.${_extensionFor(type)}';
    final reference = _storage.ref(storagePath);

    // Il file sale per primo. Se l'upload fallisce non resta un documento che
    // punta a una foto inesistente, cioe' una partecipazione vuota in gara per
    // un premio.
    await reference.putData(bytes, SettableMetadata(contentType: type));

    final entry = ChallengeEntry(
      id: userId,
      challengeId: challengeId,
      challengeTitle: challenge.title,
      userId: userId,
      authorName: authorName,
      mediaUrl: await reference.getDownloadURL(),
      storagePath: storagePath,
      mediaKind: mediaKind,
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
    // Il nome del voto porta dentro la gara. Vedi `ChallengeEntry.voteKey`: le
    // partecipazioni si chiamano come il loro autore, quindi lo stesso nome
    // ricompare in ogni challenge a cui quella persona partecipa.
    final voteRef = _votes(userId).doc('${challengeId}__$entryId');
    final entryRef = _entries(challengeId).doc(entryId);

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(voteRef);

      // **Il documento del voto e' la verita', il contatore e' solo una copia.**
      //
      // Se il voto e' gia' come lo si vuole non si scrive niente: due tocchi
      // rapidi, due schermate aperte sulla stessa foto, o la stessa azione
      // rifatta dopo un errore di rete non possono contare due volte.
      if (existing.exists == voted) {
        return;
      }

      // Il contatore si legge **dentro la transazione** e si riscrive per
      // intero, invece di usare `FieldValue.increment`.
      //
      // E' la correzione di un bug che si vedeva a schermo: `increment(-1)` su
      // una partecipazione **senza il campo `votes`** non lo porta a zero, lo
      // crea a **meno uno**. Bastava una foto scritta da una versione dell'app
      // che quel campo non lo salvava ancora, un mi piace tolto, e sotto quella
      // foto compariva "-1" — un numero che non vuol dire niente, perche'
      // nessuno puo' togliere un voto che non ha dato.
      //
      // Leggendo e riscrivendo il valore, il conto non puo' scendere sotto lo
      // zero nemmeno partendo da un documento rotto: si aggiusta da solo alla
      // prima fiamma.
      final entry = await transaction.get(entryRef);
      final current = (entry.data()?['votes'] as num?)?.toInt() ?? 0;
      final next = _clampVotes(voted ? current + 1 : current - 1);

      if (voted) {
        transaction.set(voteRef, {
          'challengeId': challengeId,
          'entryId': entryId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.delete(voteRef);
      }

      // A zero, togliere una fiamma non tocca il contatore: resta zero. La
      // scrittura si salta del tutto invece di riscrivere lo stesso numero —
      // le regole accettano solo variazioni di uno, e una scrittura che non
      // cambia niente verrebbe rifiutata.
      if (next != current) {
        transaction.update(entryRef, {'votes': next});
      }
    });
  }

  @override
  Future<void> proclaimWinner({
    required String challengeId,
    required String winnerEntryId,
    required String winnerUserId,
    ChallengeEntry? winner,
    bool chosenByCreator = false,
  }) async {
    final challengeRef = _challenges.doc(challengeId);
    final batch = _firestore.batch()
      ..update(challengeRef, {
        'winnerEntryId': winnerEntryId,
        'winnerUserId': winnerUserId,
        // Chi guarda ha diritto di sapere se quel premio e' stato **assegnato**
        // o e' semplicemente scaduto in mano a chi aveva piu' fiamme.
        'chosenByCreator': chosenByCreator,
        // **La foto che ha vinto si ricopia qui dentro.**
        //
        // E' lo stesso dato che sta nella partecipazione, e la duplicazione e'
        // voluta: quarantotto ore dopo la fine le partecipazioni vengono
        // cancellate insieme alle foto, e con loro sparirebbe la prova di aver
        // vinto. Copiata qui, sopravvive — e si tiene **una foto per gara**
        // invece di quaranta.
        //
        // Si scrive nella stessa scrittura della proclamazione, non dopo: due
        // scritture separate vogliono dire che la seconda puo' non arrivare, e
        // un trofeo mancante non se ne accorge nessuno finche' non lo cerca il
        // suo proprietario, settimane dopo.
        'winnerUsername': winner?.authorName ?? '',
        'winnerMediaUrl': winner?.mediaUrl ?? '',
        'winnerMediaKind': (winner?.mediaKind ?? MediaKind.photo).name,
        'winnerVotes': winner?.votes ?? 0,
      });

    if (winnerEntryId.isNotEmpty) {
      batch.update(_entries(challengeId).doc(winnerEntryId), {
        'isWinner': true,
      });
    }

    await batch.commit();
  }

  /// L'estensione che corrisponde a un tipo di file.
  ///
  /// Serve solo a rendere leggibile il nome dentro Storage: a decidere come si
  /// apre un file e' il tipo dichiarato, non come finisce il suo nome.
  static String _extensionFor(String contentType) {
    return switch (contentType) {
      'video/webm' => 'webm',
      'video/mp4' => 'mp4',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' || 'image/heif' => 'heic',
      _ => contentType.startsWith('video/') ? 'mp4' : 'jpg',
    };
  }

  /// Le fiamme non scendono sotto zero, mai.
  static int _clampVotes(int value) => value < 0 ? 0 : value;

  @override
  Stream<Set<String>> watchVotedEntryIds(String userId) {
    return _votes(userId).snapshots().map((snapshot) {
      return {for (final document in snapshot.docs) _voteKeyOf(document)};
    });
  }

  /// Il nome del voto, ricavato dal contenuto e non dal nome del documento.
  ///
  /// I voti dati prima che la gara entrasse nel nome si chiamano ancora con il
  /// solo identificativo della partecipazione. Ricostruire la chiave dai campi
  /// — che quei documenti ce l'hanno gia' — li rende validi come i nuovi, senza
  /// doverli riscrivere e senza che nessuno perda un voto dato.
  static String _voteKeyOf(QueryDocumentSnapshot<Map<String, dynamic>> vote) {
    final data = vote.data();
    final challengeId = data['challengeId'] as String?;
    final entryId = data['entryId'] as String?;

    if (challengeId == null || entryId == null) {
      return vote.id;
    }

    return '${challengeId}__$entryId';
  }

  @override
  Stream<List<Challenge>> watchTrophiesOf(String userId) {
    // Senza `orderBy`: incrociare un filtro e un ordinamento su campi diversi
    // costringe Firestore a un indice composto, e un indice mancante non e' un
    // errore che si vede scrivendo il codice — e' una schermata vuota in mano a
    // qualcuno. Sono pochi documenti: si ordinano qui.
    return _challenges
        .where('winnerUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => _mostRecentFirst(_challengesFrom(snapshot)));
  }

  @override
  Stream<List<Challenge>> watchCommissionedBy(String userId) {
    return _challenges
        .where('createdByUserId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => _mostRecentFirst([
            for (final challenge in _challengesFrom(snapshot))
              if (challenge.hasTrophy) challenge,
          ]),
        );
  }

  /// La bacheca si legge dall'ultimo trofeo: e' quello di cui ci si ricorda.
  static List<Challenge> _mostRecentFirst(List<Challenge> challenges) {
    return challenges..sort((a, b) => b.endsAt.compareTo(a.endsAt));
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
