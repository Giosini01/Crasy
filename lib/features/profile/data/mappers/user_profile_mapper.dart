import 'package:app_incontri/features/profile/domain/entities/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class UserProfileMapper {
  static UserProfile fromFirestore(String id, Map<String, dynamic> data) {
    return UserProfile(
      id: id,
      name: data['name'] as String? ?? '',
      birthDate: (data['birthDate'] as Timestamp).toDate(),
      gender: _genderFromValue(data['gender'] as String? ?? ''),
      interestedIn: _interestFromValue(data['interestedIn'] as String? ?? ''),
      city: data['city'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      onboardingCompleted: data['onboardingCompleted'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> toCreateMap(UserProfile profile) {
    return {
      'name': profile.name,
      'birthDate': Timestamp.fromDate(profile.birthDate),
      'gender': profile.gender.name,
      'interestedIn': profile.interestedIn.name,
      'city': profile.city,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'onboardingCompleted': profile.onboardingCompleted,
    };
  }

  static Map<String, dynamic> toUpdateMap(UserProfile profile) {
    return {
      'name': profile.name,
      'birthDate': Timestamp.fromDate(profile.birthDate),
      'gender': profile.gender.name,
      'interestedIn': profile.interestedIn.name,
      'city': profile.city,
      'updatedAt': FieldValue.serverTimestamp(),
      'onboardingCompleted': profile.onboardingCompleted,
    };
  }

  static GenderIdentity _genderFromValue(String value) {
    return GenderIdentity.values.firstWhere(
      (item) => item.name == value,
      orElse: () => GenderIdentity.other,
    );
  }

  static InterestPreference _interestFromValue(String value) {
    return InterestPreference.values.firstWhere(
      (item) => item.name == value,
      orElse: () => InterestPreference.everyone,
    );
  }
}
