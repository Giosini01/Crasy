import 'package:app_incontri/features/profile/data/mappers/user_profile_mapper.dart';
import 'package:app_incontri/features/profile/domain/entities/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserProfile serializes to Firestore create map', () {
    final profile = UserProfile(
      id: 'user-1',
      name: 'Luca',
      birthDate: DateTime(1994, 3, 10),
      gender: GenderIdentity.man,
      interestedIn: InterestPreference.women,
      city: 'Milano',
      createdAt: null,
      updatedAt: null,
      onboardingCompleted: true,
    );

    final map = UserProfileMapper.toCreateMap(profile);

    expect(map['name'], 'Luca');
    expect(map['gender'], 'man');
    expect(map['interestedIn'], 'women');
    expect(map['city'], 'Milano');
    expect(map['birthDate'], isA<Timestamp>());
    expect(map['createdAt'], isA<FieldValue>());
    expect(map['updatedAt'], isA<FieldValue>());
  });

  test('UserProfile deserializes from Firestore map', () {
    final profile = UserProfileMapper.fromFirestore('user-1', {
      'name': 'Luca',
      'birthDate': Timestamp.fromDate(DateTime(1994, 3, 10)),
      'gender': 'man',
      'interestedIn': 'women',
      'city': 'Milano',
      'createdAt': Timestamp.fromDate(DateTime(2026, 8, 8)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 8, 8)),
      'onboardingCompleted': true,
    });

    expect(
      profile,
      UserProfile(
        id: 'user-1',
        name: 'Luca',
        birthDate: DateTime(1994, 3, 10),
        gender: GenderIdentity.man,
        interestedIn: InterestPreference.women,
        city: 'Milano',
        createdAt: DateTime(2026, 8, 8),
        updatedAt: DateTime(2026, 8, 8),
        onboardingCompleted: true,
      ),
    );
  });
}
