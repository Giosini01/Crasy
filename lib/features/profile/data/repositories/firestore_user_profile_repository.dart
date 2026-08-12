import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crasy/features/profile/data/mappers/user_profile_mapper.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:crasy/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Future<void> uploadPhoto({
    required String userId,
    required Uint8List bytes,
    String? contentType,
  }) async {
    // Percorso fisso: la foto profilo e' una sola, e sovrascriverla evita di
    // accumulare tutti i ritratti passati a ogni cambio.
    final storagePath = 'profiles/$userId/photo.jpg';
    final reference = _storage.ref(storagePath);

    await reference.putData(
      bytes,
      SettableMetadata(contentType: contentType ?? 'image/jpeg'),
    );

    await _users.doc(userId).update({
      'photoUrl': await reference.getDownloadURL(),
      'photoStoragePath': storagePath,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> createUserProfile(UserProfile profile) {
    return _users.doc(profile.id).set(UserProfileMapper.toCreateMap(profile));
  }

  @override
  Future<UserProfile?> getCurrentUserProfile(String userId) async {
    return _mapSnapshot(await _users.doc(userId).get());
  }

  @override
  Future<void> updateUserProfile(UserProfile profile) {
    return _users
        .doc(profile.id)
        .update(UserProfileMapper.toUpdateMap(profile));
  }

  @override
  Stream<UserProfile?> watchCurrentUserProfile(String userId) {
    return _users.doc(userId).snapshots().map(_mapSnapshot);
  }

  UserProfile? _mapSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return UserProfileMapper.fromFirestore(snapshot.id, data);
  }
}
