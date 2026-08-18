import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
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
      prizeStatus: PrizeStatus.fromName(data['prizeStatus'] as String?),
    );
  }

  static Map<String, dynamic> toCreateMap(Challenge challenge) {
    return {
      'title': challenge.title,
      'brief': challenge.brief,
      'prizeCents': challenge.prizeCents,
      'scope': challenge.scope.name,
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
      votes: (data['votes'] as num?)?.toInt() ?? 0,
      isWinner: data['isWinner'] as bool? ?? false,
      moderation: EntryModeration.fromName(data['moderation'] as String?),
      mediaKind: MediaKind.fromName(data['mediaKind'] as String?),
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
