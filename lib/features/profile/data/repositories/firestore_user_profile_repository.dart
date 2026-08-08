import 'package:app_incontri/features/profile/data/mappers/user_profile_mapper.dart';
import 'package:app_incontri/features/profile/domain/entities/user_profile.dart';
import 'package:app_incontri/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository(this._firestore);

  final FirebaseFirestore _firestore;

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
