import 'package:app_incontri/features/auth/presentation/providers/auth_providers.dart';
import 'package:app_incontri/features/profile/data/repositories/firestore_user_profile_repository.dart';
import 'package:app_incontri/features/profile/domain/entities/user_profile.dart';
import 'package:app_incontri/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => FirestoreUserProfileRepository(ref.watch(firebaseFirestoreProvider)),
);

final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final authState = ref.watch(authStateProvider);
  final repository = ref.watch(userProfileRepositoryProvider);

  if (authState is! AuthenticatedAuthState) {
    return Stream.value(null);
  }

  return repository.watchCurrentUserProfile(authState.user.id);
});
