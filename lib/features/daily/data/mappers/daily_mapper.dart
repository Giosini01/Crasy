import 'package:app_incontri/features/daily/domain/entities/daily.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class DailyMapper {
  static Daily fromFirestore(
    String id,
    String userId,
    Map<String, dynamic> data,
  ) {
    return Daily(
      id: id,
      userId: userId,
      storagePath: data['storagePath'] as String? ?? '',
      dateKey: data['dateKey'] as String? ?? '',
      status: _statusFromValue(data['status'] as String? ?? ''),
      slot: (data['slot'] as num?)?.toInt(),
      capturedAt: (data['capturedAt'] as Timestamp?)?.toDate(),
      downloadUrl: data['downloadUrl'] as String?,
      vibe: data['vibe'] as String?,
    );
  }

  static Map<String, dynamic> toCreateMap(Daily daily) {
    return {
      'storagePath': daily.storagePath,
      'dateKey': daily.dateKey,
      'status': daily.status.name,
      'slot': daily.slot,
      'downloadUrl': daily.downloadUrl,
      'vibe': daily.vibe,
      'capturedAt': FieldValue.serverTimestamp(),
    };
  }

  static DailyStatus _statusFromValue(String value) {
    return DailyStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => DailyStatus.draft,
    );
  }
}
