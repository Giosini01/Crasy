import 'package:app_incontri/core/services/firebase/firebase_providers.dart';
import 'package:app_incontri/features/auth/presentation/providers/auth_providers.dart';
import 'package:app_incontri/features/profile/data/repositories/firestore_user_profile_repository.dart';
import 'package:app_incontri/features/profile/domain/entities/user_profile.dart';
import 'package:app_incontri/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => FirestoreUserProfileRepository(
    ref.watch(firebaseFirestoreProvider),
    ref.watch(firebaseStorageProvider),
  ),
);

final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final authState = ref.watch(authStateProvider);
  final repository = ref.watch(userProfileRepositoryProvider);

  if (authState is! AuthenticatedAuthState) {
    return Stream.value(null);
  }

  return repository.watchCurrentUserProfile(authState.user.id);
});


