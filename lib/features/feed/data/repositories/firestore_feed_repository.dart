import 'package:app_incontri/features/daily/domain/entities/daily_vibe.dart';
import 'package:app_incontri/features/feed/domain/entities/feed_item.dart';
import 'package:app_incontri/features/feed/domain/repositories/feed_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreFeedRepository implements FeedRepository {
  FirestoreFeedRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _user(String userId) =>
      _firestore.collection('users').doc(userId);

  @override
  Stream<List<FeedItem>> watchFeed(String userId, String dateKey) {
    return _user(userId)
        .collection('feed')
        .where('dateKey', isEqualTo: dateKey)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => _fromFirestore(doc.data())).toList(),
        );
  }

  @override
  Stream<Set<String>> watchDecidedUserIds(String userId) {
    return _user(userId)
        .collection('decisions')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  @override
  Future<void> recordDecision({
    required String userId,
    required String targetId,
    required bool liked,
    String? message,
  }) {
    final trimmed = message?.trim() ?? '';

    return _user(userId).collection('decisions').doc(targetId).set({
      'liked': liked,
      if (trimmed.isNotEmpty) 'message': trimmed,
      'decidedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markSeen({
    required String userId,
    required String dailyId,
  }) {
    // Fusione e non sovrascrittura: le regole permettono di toccare `seen` e
    // basta, quindi il resto della voce deve restare esattamente com'e'.
    return _user(userId)
        .collection('feed')
        .doc(dailyId)
        .set({'seen': true}, SetOptions(merge: true));
  }

  /// Interessi e affinita' arrivano denormalizzati dentro la voce di feed: il
  /// client non puo' leggere il profilo altrui, quindi e' l'unica via.
  List<String> _stringsFrom(Object? raw) {
    if (raw is! List) {
      return const [];
    }

    return [
      for (final entry in raw)
        if (entry is String) entry,
    ];
  }

  FeedItem _fromFirestore(Map<String, dynamic> data) {
    final capturedAtMillis = (data['capturedAtMillis'] as num?)?.toInt();

    return FeedItem(
      dailyId: data['dailyId'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      authorAge: (data['authorAge'] as num?)?.toInt() ?? 0,
      authorPhotoUrl: data['authorPhotoUrl'] as String? ?? '',
      authorIcebreaker: data['authorIcebreaker'] as String? ?? '',
      // Il server manda l'identificativo; la scritta con l'emoji la compone
      // l'app, cosi' cambiarla non richiede di riscrivere i feed.
      vibe: DailyVibe.chipOf(data['vibe'] as String?),
      authorInterests: _stringsFrom(data['authorInterests']),
      sharedInterests: _stringsFrom(data['sharedInterests']),
      compatibility: (data['compatibility'] as num?)?.toInt() ?? 0,
      photoUrl: data['photoUrl'] as String? ?? '',
      dateKey: data['dateKey'] as String? ?? '',
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      capturedAt: capturedAtMillis == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(capturedAtMillis),
    );
  }
}
