import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/entities/entry_comment.dart';
import 'package:crasy/features/challenges/domain/entities/entry_moderation.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';

abstract final class ChallengeMapper {
  static Challenge fromFirestore(String id, Map<String, dynamic> data) {
    return Challenge(
      id: id,
      title: data['title'] as String? ?? '',
      brief: data['brief'] as String? ?? '',
      prizeCents: (data['prizeCents'] as num?)?.toInt() ?? 0,
      scope: ChallengeScope.fromName(data['scope'] as String?),
      place: data['place'] as String? ?? '',
      rules: _stringList(data['rules']),
      mediaKind: MediaKind.fromName(data['mediaKind'] as String?),
      createdByUsername: data['createdByUsername'] as String? ?? '',
      createdByUserId: data['createdByUserId'] as String? ?? '',
      // Le date sono obbligatorie per il prodotto ma non per il documento: un
      // record scritto a mano male non deve far cadere l'intera schermata.
      // Senza inizio e fine la challenge risulta chiusa, che e' lo stato piu'
      // innocuo in cui possa finire.
      startsAt: _dateOr(data['startsAt'], _epoch),
      endsAt: _dateOr(data['endsAt'], _epoch),
      participantsCount: (data['participantsCount'] as num?)?.toInt() ?? 0,
      winnerEntryId: data['winnerEntryId'] as String?,
      winnerUserId: data['winnerUserId'] as String? ?? '',
      winnerUsername: data['winnerUsername'] as String? ?? '',
      winnerMediaUrl: data['winnerMediaUrl'] as String? ?? '',
      winnerMediaKind: MediaKind.fromName(data['winnerMediaKind'] as String?),
      winnerVotes: (data['winnerVotes'] as num?)?.toInt() ?? 0,
      prizeStatus: PrizeStatus.fromName(data['prizeStatus'] as String?),
      // La sfida del giorno di CRASY si riconosce da qui. Il campo lo scrive
      // solo chi tiene l'app, con l'SDK di amministrazione: dalle regole una
      // gara con questo dentro non la puo' creare nessuno.
      isDaily: (data['kind'] as String?) == 'daily',
      audience: _stringList(data['audience']),
    );
  }

  static Map<String, dynamic> toCreateMap(Challenge challenge) {
    return {
      'title': challenge.title,
      'brief': challenge.brief,
      'prizeCents': challenge.prizeCents,
      'scope': challenge.scope.name,
      // **Chi la puo' vedere viaggia con la gara.** Ogni query filtra su questo
      // campo, e una query che filtra su un campo salta i documenti che non ce
      // l'hanno: una gara scritta senza `audience` non comparirebbe da nessuna
      // parte, nemmeno a chi l'ha lanciata.
      'audience': challenge.audience,
      'place': challenge.place,
      'rules': challenge.rules,
      'mediaKind': challenge.mediaKind.name,
      'createdByUsername': challenge.createdByUsername,
      'createdByUserId': challenge.createdByUserId,
      'startsAt': Timestamp.fromDate(challenge.startsAt),
      'endsAt': Timestamp.fromDate(challenge.endsAt),
      'participantsCount': challenge.participantsCount,
      'winnerEntryId': challenge.winnerEntryId,
      // **Nasce sempre non pagata, qualunque cosa dica chi la crea.**
      //
      // Non si scrive `challenge.prizeStatus` di proposito: se il valore
      // arrivasse da chi chiama, pubblicare una challenge senza pagarla
      // sarebbe questione di una riga. A muoverlo e' solo il server, quando
      // Stripe conferma che i soldi sono arrivati. Le regole di Firestore
      // impongono la stessa cosa dall'altra parte.
      'prizeStatus': PrizeStatus.unpaid.name,
      'createdAt': FieldValue.serverTimestamp(),
      // **Nasce esplicitamente non ripulita, e il `null` scritto serve.**
      //
      // Lo spazzino cerca le gare da svuotare con `purgedAt == null`, e per
      // Firestore un campo che non c'e' non corrisponde a nessun confronto —
      // nemmeno a quello con `null`. Senza questa riga la gara non verrebbe
      // trovata mai, e le sue foto resterebbero in magazzino per sempre.
      'purgedAt': null,
    };
  }

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  static DateTime _dateOr(Object? raw, DateTime fallback) {
    return raw is Timestamp ? raw.toDate() : fallback;
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) {
      return const [];
    }

    return [
      for (final entry in raw)
        if (entry is String) entry,
    ];
  }
}

abstract final class ChallengeEntryMapper {
  /// Le fiamme non vanno sotto zero, qualunque cosa dica il documento.
  static int _atLeastZero(int value) => value < 0 ? 0 : value;

  static ChallengeEntry fromFirestore(
    String id,
    String challengeId,
    Map<String, dynamic> data,
  ) {
    return ChallengeEntry(
      id: id,
      challengeId: challengeId,
      challengeTitle: data['challengeTitle'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      mediaUrl: data['mediaUrl'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      // Mai sotto zero, qualunque cosa dica il documento.
      //
      // Una fiamma negativa non vuol dire niente — nessuno puo' togliere un
      // voto che non ha dato — quindi se sul database ce n'e' una, e' un dato
      // rotto. Rotto o no, a schermo non ci finisce: si legge zero e la gara
      // continua. Un "-1" sotto la foto di qualcuno e' il tipo di dettaglio che
      // fa perdere fiducia a tutta l'app, non solo a quel numero.
      votes: _atLeastZero((data['votes'] as num?)?.toInt() ?? 0),
      isWinner: data['isWinner'] as bool? ?? false,
      moderation: EntryModeration.fromName(data['moderation'] as String?),
      mediaKind: MediaKind.fromName(data['mediaKind'] as String?),
      // Le partecipazioni scritte prima che la didascalia esistesse non ce
      // l'hanno, ed e' giusto che si leggano come foto senza didascalia invece
      // che come dati rotti.
      caption: data['caption'] as String? ?? '',
    );
  }

  /// La mappa con cui nasce una partecipazione.
  ///
  /// I voti partono da zero e **il campo deve esserci**. Ometterlo sembrava
  /// piu' pulito — tanto chi legge tratta l'assenza come zero — ma le regole di
  /// Firestore no: la condizione che protegge il contatore confronta il valore
  /// nuovo con `resource.data.votes`, e su un documento dove quel campo non
  /// esiste la valutazione fallisce e il voto viene respinto. Una partecipazione
  /// nata senza `votes` e' una partecipazione che non puo' riceverne.
  static Map<String, dynamic> toCreateMap(ChallengeEntry entry) {
    return {
      'challengeId': entry.challengeId,
      'challengeTitle': entry.challengeTitle,
      'userId': entry.userId,
      'authorName': entry.authorName,
      'mediaUrl': entry.mediaUrl,
      'storagePath': entry.storagePath,
      'mediaKind': entry.mediaKind.name,
      // La didascalia si scrive alla nascita e non si tocca piu': le regole non
      // danno all'autore nessun permesso di aggiornamento sulla propria
      // partecipazione, e questa riga ci va sotto come la foto.
      'caption': entry.caption,
      'votes': 0,
      // Con il controllo acceso la foto nasce in attesa e la vede solo chi
      // l'ha mandata, finche' il server non l'ha guardata. Spento, nasce
      // ammessa: un'attesa che nessuno scioglie sarebbe una foto persa.
      'moderation': photoModerationEnabled
          ? EntryModeration.pending.name
          : EntryModeration.approved.name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Un commento fra il documento su Firestore e l'oggetto in memoria.
abstract final class EntryCommentMapper {
  static EntryComment fromFirestore(
    String id,
    String challengeId,
    String entryId,
    Map<String, dynamic> data,
  ) {
    // I nominati arrivano come elenco di mappe. Un documento scritto male —
    // una stringa al posto di una mappa, un campo mancante — non deve far
    // sparire il commento: si salta quella nomina e il testo si legge lo
    // stesso. Un commento che non compare e' molto peggio di un nome che non
    // porta da nessuna parte.
    final grezze = data['mentions'];
    final mentions = <EntryMention>[];

    if (grezze is List) {
      for (final voce in grezze) {
        if (voce is! Map) {
          continue;
        }

        final userId = voce['userId'];
        final username = voce['username'];

        if (userId is String &&
            username is String &&
            userId.isNotEmpty &&
            username.isNotEmpty) {
          mentions.add(EntryMention(userId: userId, username: username));
        }
      }
    }

    return EntryComment(
      id: id,
      challengeId: challengeId,
      entryId: entryId,
      userId: data['userId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      mentions: mentions,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, dynamic> toCreateMap(EntryComment comment) {
    return {
      'userId': comment.userId,
      'authorName': comment.authorName,
      'text': comment.text,
      'mentions': [
        for (final mention in comment.mentions)
          {'userId': mention.userId, 'username': mention.username},
      ],
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Dal piu' vecchio: sotto una foto si legge una conversazione, e una
  /// conversazione si legge nell'ordine in cui e' avvenuta.
  ///
  /// Chi non ha ancora l'ora del server va **in fondo**, non all'inizio: e' il
  /// commento appena mandato, cioe' l'ultimo arrivato. Metterlo in cima lo
  /// farebbe saltare in testa per mezzo secondo e poi ridiscendere.
  static int oldestFirst(EntryComment a, EntryComment b) {
    final at = a.createdAt;
    final bt = b.createdAt;

    if (at == null && bt == null) {
      return 0;
    }

    if (at == null) {
      return 1;
    }

    if (bt == null) {
      return -1;
    }

    return at.compareTo(bt);
  }
}
