import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crasy/core/services/media/disk_upload_stub.dart'
    if (dart.library.io) 'package:crasy/core/services/media/disk_upload_io.dart';
import 'package:crasy/core/services/media/photo_compressor.dart';
import 'package:crasy/features/challenges/data/mappers/challenge_mapper.dart';
import 'package:crasy/features/challenges/domain/commissioned_order.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/entry_comment.dart';
import 'package:crasy/features/challenges/domain/entities/entry_moderation.dart';
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
        // **Solo le pubbliche.** Le gare riservate agli amici non passano di
        // qui: si vedono nella scheda degli amici, e chi non e' fra i loro
        // destinatari non le puo' nemmeno leggere — lo impediscono le regole,
        // non un filtro scritto qui.
        .where('audience', arrayContains: Challenge.everyone)
        .where('endsAt', isGreaterThan: Timestamp.now())
        .orderBy('endsAt')
        // **Cinquanta, non tutte.** Senza tetto questa query legge ogni gara
        // aperta esistente, a ogni avvio, per ogni persona: con dieci utenti non
        // si nota, con duemila che ne lanciano una a testa sono duemila letture
        // per ogni apertura dell'app — il costo cresce col **quadrato** della
        // gente. L'ordine e' per scadenza crescente, quindi le cinquanta sono
        // quelle che stanno per chiudersi: esattamente quelle che si mostrano
        // per prime, e le uniche a cui si fa in tempo a partecipare.
        .limit(50)
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
        .where('audience', arrayContains: Challenge.everyone)
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
          (snapshot) => _challengesFrom(snapshot).where((challenge) {
            // **La sfida gratis resta fra i vincitori un giorno, non due.**
            //
            // Ce ne sono trecentosessantacinque all'anno, e con la finestra
            // delle altre — quarantotto ore — ce ne sarebbero sempre due in
            // cima a coprire le gare vere, quelle in cui qualcuno ha vinto dei
            // soldi. Un giorno basta: chi l'ha fatta ieri sera passa di qui la
            // mattina dopo e vede chi ha vinto.
            if (challenge.isDaily &&
                challenge.endsAt.isBefore(
                  now.subtract(const Duration(hours: 24)),
                )) {
              return false;
            }

            return challenge.isPayable;
          }).toList(),
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
  @override
  Stream<List<Challenge>> watchChallengesFor(String userId) {
    // Le gare riservate in cui **io** compaio fra i destinatari: quelle dei
    // miei amici, e le mie. Nessun'altra: il filtro e' lo stesso che usano le
    // regole per decidere se posso leggerle.
    return _challenges
        .where('audience', arrayContains: userId)
        .where('endsAt', isGreaterThan: Timestamp.now())
        .orderBy('endsAt')
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();

          return _challengesFrom(
            snapshot,
          ).where((challenge) => !challenge.isUpcomingAt(now)).toList();
        });
  }

  @override
  Stream<ChallengeEntry?> watchTopEntry(
    String challengeId, {
    bool live = false,
  }) {
    // **Cinque documenti al posto di trecento.**
    //
    // In cima a ogni scheda della home c'e' la foto che sta vincendo, ed e' una
    // foto sola. Per trovarla si leggevano **tutte** le partecipazioni della
    // gara e si ordinavano qui: con otto gare in home erano otto ascolti su
    // altrettante collezioni intere, riaperti ogni volta che una scheda usciva
    // e rientrava dallo schermo. E' la prima voce del conto delle letture.
    //
    // Chiedendo l'ordine a Firestore ne bastano cinque. Cinque e non uno perche'
    // la prima potrebbe essere in attesa di controllo o senza immagine, e in
    // vetrina non ci va: con cinque in mano la seconda scelta ce l'abbiamo gia',
    // senza una seconda domanda.
    //
    // Il campo `votes` ce l'hanno tutte — lo scrive chi manda la foto, a zero —
    // quindi ordinare per quello non taglia fuori nessuno.
    // **A gara aperta si mostra l'ultima arrivata, non la prima in
    // classifica.** Con le fiamme nascoste, una vetrina che mostra chi sta
    // vincendo sarebbe la classifica scritta in un altro modo: basterebbe
    // guardare la copertina di ogni gara per sapere come sta andando.
    //
    // L'ultima arrivata dice invece una cosa utile e innocua: **qui si sta
    // giocando adesso**.
    final query = live
        ? _entries(challengeId).orderBy('createdAt', descending: true)
        : _entries(challengeId).orderBy('votes', descending: true);

    return query.limit(5).snapshots().map((snapshot) {
      final entries = [
        for (final document in snapshot.docs)
          ChallengeEntryMapper.fromFirestore(
            document.id,
            challengeId,
            document.data(),
          ),
      ]..sort(live ? _byNewest : _byVotesThenOldest);

      for (final entry in entries) {
        if (entry.mediaUrl.isNotEmpty &&
            entry.moderation == EntryModeration.approved) {
          return entry;
        }
      }

      return null;
    });
  }

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

  /// La piu' recente per prima. Chi non ha ancora l'ora del server e' appena
  /// arrivato, quindi sta in cima: e' esattamente la foto che la vetrina deve
  /// mostrare a gara aperta.
  static int _byNewest(ChallengeEntry a, ChallengeEntry b) {
    final quando = a.createdAt;
    final altra = b.createdAt;

    if (quando == null) {
      return altra == null ? 0 : -1;
    }

    if (altra == null) {
      return 1;
    }

    return altra.compareTo(quando);
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
    String? filePath,
    MediaKind mediaKind = MediaKind.photo,
    String? contentType,
    String caption = '',
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
    //
    // **Un video sale dal disco, non dalla memoria.**
    //
    // `putData` vuole tutto il file dentro un unico blocco di memoria, e per
    // una foto stretta a trecento chilobyte va benissimo. Un video di trenta
    // secondi e' un'altra cosa: decine di megabyte, letti interi con
    // `readAsBytes`, tenuti in mano per tutto il tempo dell'anteprima e poi
    // **copiati una seconda volta** da chi li spedisce. Su un telefono che sta
    // gia' tenendo aperta la fotocamera, e' la richiesta che il sistema rifiuta
    // — e un rifiuto di memoria non e' un errore che si cattura: e' l'app che
    // sparisce, con dentro la partecipazione di qualcuno.
    //
    // `putFile` legge dal disco a pezzi: la memoria che serve non dipende piu'
    // da quanto e' lungo il video. Vale solo dove esiste un disco — sul web il
    // file non ha un percorso e si resta ai byte, che li' arrivano comunque
    // dal selettore gia' in memoria.
    final dati = SettableMetadata(contentType: type);
    final daDisco =
        caricamentoDaDiscoDisponibile &&
        filePath != null &&
        filePath.isNotEmpty;

    await (daDisco
        ? caricaDalDisco(reference, filePath, dati)
        : reference.putData(bytes, dati));

    // **La copia piccola sale insieme all'originale.**
    //
    // La fa il telefono qui, adesso, con la stessa libreria che ha appena
    // stretto la foto: nessun server, nessuna funzione, nessun ritardo che si
    // noti. Sara' lei a riempire tutti gli elenchi — dove finora si scaricavano
    // trecento chilobyte per disegnarne quaranta.
    //
    // **Se fallisce non succede niente.** La partecipazione va in gara lo
    // stesso e negli elenchi si continua a mostrare l'originale: una foto
    // pesante e' un problema di conto a fine mese, una partecipazione persa e'
    // un problema di chi l'ha mandata.
    var thumbUrl = '';

    if (!mediaKind.isVideo) {
      final small = PhotoCompressor.thumbnail(bytes);

      if (small != null) {
        try {
          final thumbRef = _storage.ref(
            'entries/$challengeId/$userId/${uploadId}_thumb.jpg',
          );

          await thumbRef.putData(
            small,
            SettableMetadata(contentType: 'image/jpeg'),
          );

          thumbUrl = await thumbRef.getDownloadURL();
        } on Exception catch (_) {
          thumbUrl = '';
        }
      }
    }

    final entry = ChallengeEntry(
      id: userId,
      challengeId: challengeId,
      challengeTitle: challenge.title,
      userId: userId,
      authorName: authorName,
      mediaUrl: await reference.getDownloadURL(),
      thumbUrl: thumbUrl,
      storagePath: storagePath,
      mediaKind: mediaKind,
      caption: caption.trim(),
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

  CollectionReference<Map<String, dynamic>> _comments(
    String challengeId,
    String entryId,
  ) => _entries(challengeId).doc(entryId).collection('comments');

  @override
  Stream<List<EntryComment>> watchComments({
    required String challengeId,
    required String entryId,
  }) {
    // L'ordine si fa in memoria, come ovunque qui dentro: una query ordinata
    // per `createdAt` **salta i documenti a cui il server non ha ancora scritto
    // l'ora**, e quello e' esattamente il commento appena mandato — che
    // sparirebbe dagli occhi di chi l'ha scritto per il mezzo secondo in cui lo
    // sta cercando.
    return _comments(challengeId, entryId).limit(200).snapshots().map((
      snapshot,
    ) {
      final comments = [
        for (final document in snapshot.docs)
          EntryCommentMapper.fromFirestore(
            document.id,
            challengeId,
            entryId,
            document.data(),
          ),
      ];

      return comments..sort(EntryCommentMapper.oldestFirst);
    });
  }

  @override
  Future<EntryComment> addComment({
    required String challengeId,
    required String entryId,
    required String userId,
    required String authorName,
    required String text,
    List<EntryMention> mentions = const [],
  }) async {
    final comment = EntryComment(
      id: '',
      challengeId: challengeId,
      entryId: entryId,
      userId: userId,
      authorName: authorName,
      text: text.trim(),
      mentions: mentions,
    );

    final document = await _comments(
      challengeId,
      entryId,
    ).add(EntryCommentMapper.toCreateMap(comment));

    return EntryComment(
      id: document.id,
      challengeId: challengeId,
      entryId: entryId,
      userId: userId,
      authorName: authorName,
      text: comment.text,
      mentions: mentions,
    );
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
  }) async {
    final challengeRef = _challenges.doc(challengeId);
    final batch = _firestore.batch()
      ..update(challengeRef, {
        'winnerEntryId': winnerEntryId,
        'winnerUserId': winnerUserId,
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
  Stream<String?> watchDailyPick(String day) {
    // Un documento per giorno, con dentro l'identificativo di una gara. Lo
    // scrive chi tiene l'app, non l'app: dalle regole nessuno lo puo' toccare.
    return _firestore.collection('daily').doc(day).snapshots().map((snapshot) {
      final scelta = snapshot.data()?['challengeId'];

      return scelta is String && scelta.isNotEmpty ? scelta : null;
    });
  }

  @override
  Stream<List<ChallengeEntry>> watchEntriesByUsers(List<String> userIds) {
    final cercati = userIds.take(30).toList();

    if (cercati.isEmpty) {
      return Stream.value(const []);
    }

    // Trenta e' il massimo che Firestore accetta in un `whereIn`. Oltre quel
    // numero di amici la riga "in gara" non compare per gli ultimi: e' una
    // perdita accettabile per una cosa di contorno, e molto meglio di trenta
    // richieste separate.
    return _firestore
        .collectionGroup('entries')
        .where('userId', whereIn: cercati)
        .limit(200)
        .snapshots()
        .map(_entriesFrom);
  }

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
  Future<void> deleteChallenge(String challengeId) {
    return _challenges.doc(challengeId).delete();
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
        .map(
          (snapshot) => _mostRecentFirst([
            for (final challenge in _challengesFrom(snapshot))
              // **La sfida del giorno non lascia figurine.**
              //
              // Il trofeo dice quanto si e' vinto, ed e' un oggetto che si
              // colleziona: nasce dal fatto che qualcuno ci ha messo dei soldi
              // e qualcun altro se li e' presi. Una gara gratis non ha niente
              // di tutto questo — si fa per giocare — e una bacheca piena di
              // figurine da zero euro toglie valore proprio a quelle vere.
              //
              // Vincerla si vede lo stesso: la gara sta fra i vincitori per un
              // giorno, con la foto e il nome di chi l'ha presa.
              if (!challenge.isDaily) challenge,
          ]),
        );
  }

  @override
  Stream<List<Challenge>> watchCommissionedBy(String userId) {
    return _challenges
        .where('createdByUserId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) =>
              commissionedOrder(_challengesFrom(snapshot), now: DateTime.now()),
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
