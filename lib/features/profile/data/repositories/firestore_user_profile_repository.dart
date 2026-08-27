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

  @override
  Future<void> saveConsent({
    required String userId,
    required String version,
    required bool marketing,
    required bool profiling,
  }) {
    final user = _users.doc(userId);

    // Le due scritture partono insieme: o si registrano tutte e due, o
    // nessuna. Un profilo che dice "accettato" senza la riga corrispondente nel
    // registro e' peggio di nessuna delle due — sembra a posto e non lo e'.
    final batch = _firestore.batch()
      ..update(user, {
        'legalVersion': version,
        'legalAcceptedAt': FieldValue.serverTimestamp(),
        'marketingConsent': marketing,
        'profilingConsent': profiling,
        'updatedAt': FieldValue.serverTimestamp(),
      })
      // Documento nuovo a ogni volta, mai lo stesso riscritto: revocare un
      // consenso **non cancella** quello dato prima. Il registro deve poter
      // rispondere anche a "cosa aveva accettato in quel momento", non solo a
      // "cosa accetta adesso".
      ..set(user.collection('consents').doc(), {
        'version': version,
        'marketing': marketing,
        'profiling': profiling,
        'at': FieldValue.serverTimestamp(),
      });

    return batch.commit();
  }

  UserProfile? _mapSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return UserProfileMapper.fromFirestore(snapshot.id, data);
  }
}
