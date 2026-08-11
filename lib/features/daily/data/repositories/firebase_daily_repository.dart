import 'dart:typed_data';

import 'package:app_incontri/core/utils/app_date_utils.dart';
import 'package:app_incontri/features/daily/data/mappers/daily_mapper.dart';
import 'package:app_incontri/features/daily/domain/entities/daily.dart';
import 'package:app_incontri/features/daily/domain/entities/daily_window.dart';
import 'package:app_incontri/features/daily/domain/repositories/daily_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseDailyRepository implements DailyRepository {
  FirebaseDailyRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> _dailies(String userId) =>
      _firestore.collection('users').doc(userId).collection('dailies');

  @override
  Stream<List<Daily>> watchDailiesForDay(String userId, String dateKey) {
    return _dailies(userId)
        .where('dateKey', isEqualTo: dateKey)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) =>
                    DailyMapper.fromFirestore(document.id, userId, document.data()),
              )
              .toList(),
        );
  }

  @override
  Future<Daily> publishDaily({
    required String userId,
    required Uint8List bytes,
    required DateTime now,
    String? vibe,
  }) async {
    final dateKey = AppDateUtils.dateKey(now);
    final document = _dailies(userId).doc();
    final storagePath = 'dailies/$userId/$dateKey/${document.id}.jpg';
    final reference = _storage.ref(storagePath);

    // Il file sale per primo: se l'upload fallisce non resta un documento
    // Firestore che punta a una foto inesistente e sprecherebbe una delle tre
    // Daily della giornata.
    await reference.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final downloadUrl = await reference.getDownloadURL();
    final daily = Daily(
      id: document.id,
      userId: userId,
      storagePath: storagePath,
      dateKey: dateKey,
      slot: DailyWindow.openSlotAt(now),
      // Nasce in attesa: e' il server, dopo aver riconosciuto un volto, a
      // portarla ad "attiva" e a distribuirla.
      status: DailyStatus.draft,
      capturedAt: now,
      downloadUrl: downloadUrl,
      vibe: vibe,
    );

    await document.set(DailyMapper.toCreateMap(daily));

    return daily;
  }
}
