import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';

abstract final class UserProfileMapper {
  static UserProfile fromFirestore(String id, Map<String, dynamic> data) {
    return UserProfile(
      id: id,
      username: data['username'] as String? ?? '',
      birthDate: (data['birthDate'] as Timestamp?)?.toDate(),
      bio: data['bio'] as String? ?? '',
      city: data['city'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      photoStoragePath: data['photoStoragePath'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      onboardingCompleted: data['onboardingCompleted'] as bool? ?? false,
      legalVersion: data['legalVersion'] as String? ?? '',
      legalAcceptedAt: (data['legalAcceptedAt'] as Timestamp?)?.toDate(),
      marketingConsent: data['marketingConsent'] as bool? ?? false,
      profilingConsent: data['profilingConsent'] as bool? ?? false,
      tutorialSeen: data['tutorialSeen'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> toCreateMap(UserProfile profile) {
    return {
      ..._commonMap(profile),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, dynamic> toUpdateMap(UserProfile profile) {
    return {..._commonMap(profile), 'updatedAt': FieldValue.serverTimestamp()};
  }

  /// I campi che l'app scrive.
  ///
  /// La foto **non c'e'**: la scrive `uploadPhoto` da sola, subito dopo aver
  /// caricato il file. Se comparisse anche qui, salvare la biografia con in
  /// mano un profilo letto un minuto prima cancellerebbe la foto appena
  /// cambiata.
  static Map<String, dynamic> _commonMap(UserProfile profile) {
    final birthDate = profile.birthDate;

    return {
      'username': profile.username,
      if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate),
      'bio': profile.bio,
      'city': profile.city,
      'onboardingCompleted': profile.onboardingCompleted,
    };
  }
}
