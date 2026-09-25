import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/profile/data/repositories/firestore_user_profile_repository.dart';
import 'package:crasy/features/profile/domain/entities/contact_settings.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:crasy/features/profile/domain/repositories/user_profile_repository.dart';
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

/// Il numero e la preferenza su chi puo' trovarlo.
///
/// Sta separato dal profilo perche' e' in un documento che solo il
/// proprietario puo' leggere: qui c'e' sempre e solo la propria riga, mai
/// quella di qualcun altro.
final contactSettingsProvider = StreamProvider<ContactSettings>((ref) {
  final authState = ref.watch(authStateProvider);
  final repository = ref.watch(userProfileRepositoryProvider);

  if (authState is! AuthenticatedAuthState) {
    return Stream.value(const ContactSettings());
  }

  return repository.watchContactSettings(authState.user.id);
});
