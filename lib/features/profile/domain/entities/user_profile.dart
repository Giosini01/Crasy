class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.interestedIn,
    required this.city,
    required this.createdAt,
    required this.updatedAt,
    required this.onboardingCompleted,
  });

  final String id;
  final String name;
  final DateTime birthDate;
  final GenderIdentity gender;
  final InterestPreference interestedIn;
  final String city;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool onboardingCompleted;

  UserProfile copyWith({
    String? id,
    String? name,
    DateTime? birthDate,
    GenderIdentity? gender,
    InterestPreference? interestedIn,
    String? city,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? onboardingCompleted,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      interestedIn: interestedIn ?? this.interestedIn,
      city: city ?? this.city,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is UserProfile &&
        other.id == id &&
        other.name == name &&
        other.birthDate == birthDate &&
        other.gender == gender &&
        other.interestedIn == interestedIn &&
        other.city == city &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.onboardingCompleted == onboardingCompleted;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    birthDate,
    gender,
    interestedIn,
    city,
    createdAt,
    updatedAt,
    onboardingCompleted,
  );
}

enum GenderIdentity {
  woman('Donna'),
  man('Uomo'),
  nonBinary('Non binary'),
  other('Altro');

  const GenderIdentity(this.label);

  final String label;
}

enum InterestPreference {
  women('Donne'),
  men('Uomini'),
  everyone('Tutte le persone');

  const InterestPreference(this.label);

  final String label;
}
