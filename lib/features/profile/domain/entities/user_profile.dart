import 'package:app_incontri/features/profile/domain/entities/coordinates.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.interestedIn,
    required this.createdAt,
    required this.updatedAt,
    required this.onboardingCompleted,
    this.icebreaker = '',
    this.interests = const [],
    this.photoUrl,
    this.photoStoragePath,
    this.photoStatus = PhotoStatus.none,
    this.coordinates,
  });

  final String id;
  final String name;
  final DateTime birthDate;
  final GenderIdentity gender;
  final InterestPreference interestedIn;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool onboardingCompleted;

  /// Una riga per rompere il ghiaccio: non una biografia, ma l'appiglio da
  /// cui far partire il primo messaggio.
  final String icebreaker;

  bool get hasIcebreaker => icebreaker.trim().isNotEmpty;

  /// Identificativi degli interessi scelti. Su di essi si calcola l'affinita'.
  final List<String> interests;

  /// Foto profilo permanente, distinta dall'Istantanea del giorno.
  final String? photoUrl;

  /// Percorso su Storage, serve al server per verificarla.
  final String? photoStoragePath;

  final PhotoStatus photoStatus;

  /// Vera solo quando la foto e' stata verificata: finche' e' in controllo
  /// non si mostra a nessuno.
  bool get hasPhoto => photoStatus == PhotoStatus.active && photoUrl != null;

  /// Posizione approssimata. Nulla per i profili creati prima che il feed
  /// esistesse: senza di essa il profilo non entra in nessun feed.
  final Coordinates? coordinates;

  bool get hasLocation => coordinates != null;

  /// Vero se questo profilo e [other] si cercano a vicenda.
  ///
  /// La compatibilita' e' **reciproca**: non basta che a me piaccia il suo
  /// genere, deve valere anche il contrario. Due uomini che cercano entrambi
  /// uomini si vedono; un uomo che cerca donne e una donna che cerca donne no.
  bool isCompatibleWith(UserProfile other) {
    return interestedIn.covers(other.gender) &&
        other.interestedIn.covers(gender);
  }

  UserProfile copyWith({
    String? id,
    String? name,
    DateTime? birthDate,
    GenderIdentity? gender,
    InterestPreference? interestedIn,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? onboardingCompleted,
    String? icebreaker,
    List<String>? interests,
    String? photoUrl,
    String? photoStoragePath,
    PhotoStatus? photoStatus,
    Coordinates? coordinates,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      interestedIn: interestedIn ?? this.interestedIn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      icebreaker: icebreaker ?? this.icebreaker,
      interests: interests ?? this.interests,
      photoUrl: photoUrl ?? this.photoUrl,
      photoStoragePath: photoStoragePath ?? this.photoStoragePath,
      photoStatus: photoStatus ?? this.photoStatus,
      coordinates: coordinates ?? this.coordinates,
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
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.onboardingCompleted == onboardingCompleted &&
        other.icebreaker == icebreaker &&
        _sameInterests(other.interests) &&
        other.photoUrl == photoUrl &&
        other.photoStoragePath == photoStoragePath &&
        other.photoStatus == photoStatus &&
        other.coordinates == coordinates;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    birthDate,
    gender,
    interestedIn,
    createdAt,
    updatedAt,
    onboardingCompleted,
    icebreaker,
    Object.hashAllUnordered(interests),
    photoUrl,
    photoStatus,
    coordinates,
  );

  /// L'ordine degli interessi non conta: e' un insieme, non un elenco.
  bool _sameInterests(List<String> other) {
    return other.length == interests.length &&
        other.toSet().containsAll(interests);
  }
}

/// Stato della foto profilo.
///
/// Come per l'Istantanea, una foto appena caricata non e' ancora visibile:
/// passa prima dal controllo del server, che verifica ci sia un volto.
enum PhotoStatus {
  /// Nessuna foto caricata.
  none,

  /// Caricata, in attesa del controllo.
  pending,

  /// Verificata e visibile.
  active,

  /// Scartata perche' non ritraeva una persona.
  rejected,
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

  /// Vero se questa preferenza comprende [gender].
  ///
  /// Chi cerca "tutte le persone" comprende ogni identita'. Chi cerca donne o
  /// uomini non comprende `nonBinary` e `other`: e' una semplificazione da
  /// rivedere, ma meglio essere espliciti che far finta che il problema non
  /// esista incastrandole d'ufficio da una parte.
  bool covers(GenderIdentity gender) {
    return switch (this) {
      InterestPreference.everyone => true,
      InterestPreference.women => gender == GenderIdentity.woman,
      InterestPreference.men => gender == GenderIdentity.man,
    };
  }
}
