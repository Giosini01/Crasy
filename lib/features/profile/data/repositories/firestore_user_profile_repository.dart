import 'dart:typed_data';

import 'package:app_incontri/features/profile/data/mappers/user_profile_mapper.dart';
import 'package:app_incontri/features/profile/domain/entities/user_profile.dart';
import 'package:app_incontri/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  @override
  Future<void> uploadPhoto({
    required String userId,
    required Uint8List bytes,
    String? contentType,
  }) async {
    // Percorso fisso: la foto profilo e' una sola, e sovrascriverla evita di
    // accumulare i vecchi scatti di ogni cambio.
    final storagePath = 'profiles/$userId/photo.jpg';
    final reference = _storage.ref(storagePath);

    await reference.putData(
      bytes,
      SettableMetadata(contentType: contentType ?? 'image/jpeg'),
    );

    await _usersCollection.doc(userId).update({
      'photoUrl': await reference.getDownloadURL(),
      'photoStoragePath': storagePath,
      'photoStatus': PhotoStatus.pending.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  @override
  Future<void> createUserProfile(UserProfile profile) {
    return _usersCollection
        .doc(profile.id)
        .set(UserProfileMapper.toCreateMap(profile));
  }

  @override
  Future<UserProfile?> getCurrentUserProfile(String userId) async {
    final snapshot = await _usersCollection.doc(userId).get();

    return _mapSnapshot(snapshot);
  }

  @override
  Future<void> updateUserProfile(UserProfile profile) {
    return _usersCollection
        .doc(profile.id)
        .update(UserProfileMapper.toUpdateMap(profile));
  }

  @override
  Stream<UserProfile?> watchCurrentUserProfile(String userId) {
    return _usersCollection.doc(userId).snapshots().map(_mapSnapshot);
  }

  UserProfile? _mapSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return UserProfileMapper.fromFirestore(snapshot.id, data);
  }
}
