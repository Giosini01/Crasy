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
    required this.birthDate,
    required this.createdAt,
    required this.updatedAt,
    required this.onboardingCompleted,
    this.bio = '',
    this.city = '',
    this.photoUrl,
    this.photoStoragePath,
    this.legalVersion = '',
    this.legalAcceptedAt,
    this.marketingConsent = false,
    this.profilingConsent = false,
    this.tutorialSeen = false,
    this.phone = '',
  });

  final String id;

  /// Il nome con cui si firmano le partecipazioni. Minuscolo, senza spazi:
  /// e' un'identita', non un nome anagrafico.
  final String username;

  /// Quando sei nato.
  ///
  /// Serve a una cosa sola: **tenere fuori i minorenni**. Qui girano soldi veri
  /// e si chiede alla gente di fare cose per vincerli, ed e' esattamente il tipo
  /// di spinta che a un ragazzino non va data.
  ///
  /// E' nullo solo per i profili creati prima che questo campo esistesse.
  final DateTime? birthDate;

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

  /// La versione dei testi legali che questa persona ha accettato.
  ///
  /// **Serve a poterlo dimostrare.** Il GDPR non chiede solo di raccogliere il
  /// consenso: chiede di essere in grado di provare *chi* ha acconsentito, *a
  /// che cosa* e *quando*. Un booleano "ha accettato" non prova niente il
  /// giorno in cui il testo e' cambiato tre volte.
  ///
  /// Vuota per chi si e' iscritto prima che i consensi esistessero: quelle
  /// persone ripassano dalla schermata e accettano la versione di oggi.
  final String legalVersion;
  final DateTime? legalAcceptedAt;

  /// I due consensi facoltativi. Nascono **spenti**, sempre: una casella gia'
  /// spuntata non e' un consenso, e' una distrazione sfruttata.
  final bool marketingConsent;
  final bool profilingConsent;

  /// Se ha gia' visto le quattro regole del gioco.
  ///
  /// Sta sul profilo e non sul telefono: chi cambia dispositivo o rientra dal
  /// sito non deve rifare il giro, e chi si registra da capo lo rifa'. E' una
  /// cosa che riguarda la persona, non l'apparecchio.
  final bool tutorialSeen;

  /// Il numero di telefono verificato, o vuoto.
  ///
  /// **Non serve a chiamare nessuno: serve a rendere caro un account falso.**
  /// Con dei soldi in palio e un vincitore deciso dai voti, cinque profili
  /// costruiti in cinque minuti valgono cinque voti — e la classifica che
  /// assegna il premio smette di significare qualcosa. Un'email si inventa in
  /// dieci secondi e gratis; un numero di telefono no.
  ///
  /// Non e' visibile a nessun altro utente: le regole del database lo lasciano
  /// leggere e scrivere soltanto al diretto interessato, e nell'app non compare
  /// da nessuna parte.
  final String phone;

  /// Ha verificato il numero.
  bool get phoneVerified => phone.isNotEmpty;

  /// Se ha accettato **la versione che gira adesso**.
  ///
  /// Cambiando i testi cambia la versione, e da quel momento questo torna falso
  /// per tutti: e' il modo in cui un testo nuovo viene davvero letto invece di
  /// essere pubblicato e basta.
  bool acceptedLegalVersion(String current) =>
      legalVersion.isNotEmpty && legalVersion == current;

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
    DateTime? birthDate,
    String? bio,
    String? city,
    String? photoUrl,
    String? photoStoragePath,
    String? legalVersion,
    DateTime? legalAcceptedAt,
    bool? marketingConsent,
    bool? profilingConsent,
    bool? tutorialSeen,
    String? phone,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? onboardingCompleted,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      birthDate: birthDate ?? this.birthDate,
      bio: bio ?? this.bio,
      city: city ?? this.city,
      photoUrl: photoUrl ?? this.photoUrl,
      photoStoragePath: photoStoragePath ?? this.photoStoragePath,
      legalVersion: legalVersion ?? this.legalVersion,
      legalAcceptedAt: legalAcceptedAt ?? this.legalAcceptedAt,
      marketingConsent: marketingConsent ?? this.marketingConsent,
      profilingConsent: profilingConsent ?? this.profilingConsent,
      tutorialSeen: tutorialSeen ?? this.tutorialSeen,
      phone: phone ?? this.phone,
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
        other.birthDate == birthDate &&
        other.bio == bio &&
        other.city == city &&
        other.photoUrl == photoUrl &&
        other.photoStoragePath == photoStoragePath &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.onboardingCompleted == onboardingCompleted &&
        other.phone == phone;
  }

  @override
  int get hashCode => Object.hash(
    id,
    username,
    birthDate,
    bio,
    city,
    photoUrl,
    photoStoragePath,
    createdAt,
    updatedAt,
    onboardingCompleted,
    phone,
  );
}
