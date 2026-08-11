import 'package:app_incontri/features/matches/domain/entities/match_person.dart';
import 'package:app_incontri/features/matches/domain/repositories/matches_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreMatchesRepository implements MatchesRepository {
  FirestoreMatchesRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<MatchPerson>> watchMatches(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('matches')
        .snapshots()
        .map((snapshot) {
          final matches = snapshot.docs
              .map((doc) => _fromFirestore(doc.id, doc.data()))
              .toList();

          // Il piu' recente in cima: un match nuovo e' la notizia, e cercarlo
          // in fondo a un elenco sarebbe assurdo.
          matches.sort((a, b) {
            final first = a.matchedAt;
            final second = b.matchedAt;

            if (first == null || second == null) {
              return 0;
            }

            return second.compareTo(first);
          });

          return matches;
        });
  }

  MatchPerson _fromFirestore(String id, Map<String, dynamic> data) {
    return MatchPerson(
      userId: data['userId'] as String? ?? id,
      name: data['name'] as String? ?? '',
      age: (data['age'] as num?)?.toInt() ?? 0,
      photoUrl: data['photoUrl'] as String? ?? '',
      icebreaker: data['icebreaker'] as String? ?? '',
      vibe: data['vibe'] as String? ?? '',
      interests: [
        for (final entry in (data['interests'] as List<dynamic>? ?? const []))
          if (entry is String) entry,
      ],
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      message: data['message'] as String? ?? '',
      myMessage: data['myMessage'] as String? ?? '',
      photoCapturedAt: (data['photoCapturedAt'] as Timestamp?)?.toDate(),
      profilePhotoUrl: data['profilePhotoUrl'] as String? ?? '',
      matchedAt: (data['matchedAt'] as Timestamp?)?.toDate(),
    );
  }
}
