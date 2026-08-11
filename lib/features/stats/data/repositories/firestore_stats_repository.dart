import 'package:app_incontri/features/stats/domain/entities/vibe_stats.dart';
import 'package:app_incontri/features/stats/domain/repositories/stats_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreStatsRepository implements StatsRepository {
  FirestoreStatsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _stats(String userId) =>
      _firestore.collection('users').doc(userId).collection('stats');

  @override
  Stream<VibeDay> watchDay(String userId, String dateKey) {
    return _stats(userId).doc(dateKey).snapshots().map((snapshot) {
      final data = snapshot.data();

      // Nessun documento vuol dire nessuno sguardo, non un errore: la prima
      // giornata di una persona nuova passa sempre di qui.
      if (data == null) {
        return VibeDay.empty;
      }

      return VibeDay(
        views: _int(data['views']),
        likes: _int(data['likes']),
        matches: _int(data['matches']),
      );
    });
  }

  @override
  Stream<VibeLifetime> watchLifetime(String userId) {
    return _stats(userId).doc('lifetime').snapshots().map((snapshot) {
      final data = snapshot.data();

      if (data == null) {
        return VibeLifetime.empty;
      }

      return VibeLifetime(
        streakDays: _int(data['streakDays']),
        streakLastDate: data['streakLastDate'] as String? ?? '',
        totalDailies: _int(data['totalDailies']),
        totalViews: _int(data['totalViews']),
        totalLikes: _int(data['totalLikes']),
        totalMatches: _int(data['totalMatches']),
      );
    });
  }

  int _int(Object? raw) => (raw as num?)?.toInt() ?? 0;
}
