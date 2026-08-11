import 'package:app_incontri/features/profile/domain/entities/coordinates.dart';
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
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      onboardingCompleted: data['onboardingCompleted'] as bool? ?? false,
      icebreaker: data['icebreaker'] as String? ?? '',
      interests: _interestsFrom(data['interests']),
      photoUrl: data['photoUrl'] as String?,
      photoStoragePath: data['photoStoragePath'] as String?,
      photoStatus:
          _enumFrom(
            PhotoStatus.values,
            data['photoStatus'] as String?,
            PhotoStatus.none,
          ) ??
          PhotoStatus.none,
      coordinates: _coordinatesFrom(data),
    );
  }

  /// Gli interessi arrivano come elenco di identificativi.
  static List<String> _interestsFrom(Object? raw) {
    if (raw is! List) {
      return const [];
    }

    return [
      for (final entry in raw)
        if (entry is String) entry,
    ];
  }

  /// Un valore sconosciuto vale come non risposto: un dato scritto da una
  /// versione futura non deve far fallire la lettura di tutto il profilo.
  static T? _enumFrom<T extends Enum>(
    List<T> values,
    String? raw,
    T? fallback,
  ) {
    if (raw == null) {
      return fallback;
    }

    for (final value in values) {
      if (value.name == raw) {
        return value;
      }
    }

    return fallback;
  }

  static Map<String, dynamic> _photoMap(UserProfile profile) {
    return {
      'photoUrl': profile.photoUrl,
      'photoStoragePath': profile.photoStoragePath,
      'photoStatus': profile.photoStatus.name,
    };
  }

  /// Latitudine e longitudine stanno come campi separati e non dentro un
  /// `GeoPoint`: cosi' la Cloud Function che costruisce i feed le legge come
  /// normali numeri, senza dover conoscere i tipi di Firestore.
  static Coordinates? _coordinatesFrom(Map<String, dynamic> data) {
    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();

    if (latitude == null || longitude == null) {
      return null;
    }

    return Coordinates(latitude: latitude, longitude: longitude);
  }

  static Map<String, dynamic> toCreateMap(UserProfile profile) {
    return {
      'name': profile.name,
      'birthDate': Timestamp.fromDate(profile.birthDate),
      'gender': profile.gender.name,
      'interestedIn': profile.interestedIn.name,
      'icebreaker': profile.icebreaker,
      'interests': profile.interests,
      ..._photoMap(profile),
      ..._coordinatesMap(profile),
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
      'icebreaker': profile.icebreaker,
      'interests': profile.interests,
      ..._photoMap(profile),
      ..._coordinatesMap(profile),
      'updatedAt': FieldValue.serverTimestamp(),
      'onboardingCompleted': profile.onboardingCompleted,
    };
  }

  static Map<String, dynamic> _coordinatesMap(UserProfile profile) {
    final coordinates = profile.coordinates;

    if (coordinates == null) {
      return const {};
    }

    return {
      'latitude': coordinates.latitude,
      'longitude': coordinates.longitude,
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

