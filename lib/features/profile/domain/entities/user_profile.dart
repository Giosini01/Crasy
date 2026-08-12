/// Chi sei su CRASY.
///
/// Il profilo e' cortissimo, e la brevita' e' il punto. Qui non si viene per
/// essere guardati: si viene per partecipare. Un nome con cui firmare le
/// proprie foto, una riga per dire chi sei, la citta' — e nient'altro.
///
/// Quello che un profilo vale non sta in questi campi: sta nelle foto che ha
/// mandato e nelle challenge che ha vinto, che si contano dalle partecipazioni
/// e non si scrivono qui. Un contatore di vittorie salvato sul profilo e' un
/// numero che prima o poi non torna con la realta'.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.createdAt,
    required this.updatedAt,
    required this.onboardingCompleted,
    this.bio = '',
    this.city = '',
    this.photoUrl,
    this.photoStoragePath,
  });

  final String id;

  /// Il nome con cui si firmano le partecipazioni. Minuscolo, senza spazi:
  /// e' un'identita', non un nome anagrafico.
  final String username;

  /// Una riga, non una biografia.
  final String bio;

  /// La citta'. Serve a riconoscere le challenge locali che ti riguardano.
  final String city;

  final String? photoUrl;

  /// Percorso su Storage: serve per sovrascrivere la foto senza accumulare i
  /// vecchi file a ogni cambio.
  final String? photoStoragePath;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool onboardingCompleted;

  bool get hasPhoto => (photoUrl ?? '').isNotEmpty;

  bool get hasBio => bio.trim().isNotEmpty;

  /// Le iniziali per l'avatar quando non c'e' una foto.
  ///
  /// Il taglio a due caratteri e' sicuro perche' il nome utente e' validato:
  /// solo lettere, cifre, punto e trattino basso. Su un campo libero questo
  /// `substring` spezzerebbe a meta' un'emoji.
  String get initials {
    final trimmed = username.trim();

    if (trimmed.isEmpty) {
      return '?';
    }

    return (trimmed.length <= 2 ? trimmed : trimmed.substring(0, 2))
        .toUpperCase();
  }

  UserProfile copyWith({
    String? id,
    String? username,
    String? bio,
    String? city,
    String? photoUrl,
    String? photoStoragePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? onboardingCompleted,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      city: city ?? this.city,
      photoUrl: photoUrl ?? this.photoUrl,
      photoStoragePath: photoStoragePath ?? this.photoStoragePath,
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
        other.username == username &&
        other.bio == bio &&
        other.city == city &&
        other.photoUrl == photoUrl &&
        other.photoStoragePath == photoStoragePath &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.onboardingCompleted == onboardingCompleted;
  }

  @override
  int get hashCode => Object.hash(
    id,
    username,
    bio,
    city,
    photoUrl,
    photoStoragePath,
    createdAt,
    updatedAt,
    onboardingCompleted,
  );
}
