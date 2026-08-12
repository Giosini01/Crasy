/// Una partecipazione: la foto che qualcuno ha mandato per una challenge.
class ChallengeEntry {
  const ChallengeEntry({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.authorName,
    required this.mediaUrl,
    this.storagePath = '',
    this.challengeTitle = '',
    this.createdAt,
    this.votes = 0,
    this.isWinner = false,
  });

  final String id;
  final String challengeId;

  /// Il titolo della challenge, copiato qui dentro.
  ///
  /// E' una duplicazione voluta: nel feed si vedono le partecipazioni a
  /// challenge diverse, e senza questo campo ogni riga costringerebbe a leggere
  /// anche il documento della sua challenge — decine di letture per una
  /// schermata sola.
  final String challengeTitle;

  final String userId;
  final String authorName;

  /// La foto. E' il contenuto, quindi non e' facoltativa: una partecipazione
  /// senza immagine non esiste.
  final String mediaUrl;

  final String storagePath;

  /// Istante dell'invio. Nullo finche' il server non ha risolto il proprio
  /// timestamp — Firestore lo scrive dopo, non al momento della chiamata.
  final DateTime? createdAt;

  final int votes;

  /// Vera per la partecipazione che ha vinto la sua challenge.
  final bool isWinner;

  ChallengeEntry copyWith({
    String? id,
    String? challengeId,
    String? challengeTitle,
    String? userId,
    String? authorName,
    String? mediaUrl,
    String? storagePath,
    DateTime? createdAt,
    int? votes,
    bool? isWinner,
  }) {
    return ChallengeEntry(
      id: id ?? this.id,
      challengeId: challengeId ?? this.challengeId,
      challengeTitle: challengeTitle ?? this.challengeTitle,
      userId: userId ?? this.userId,
      authorName: authorName ?? this.authorName,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      storagePath: storagePath ?? this.storagePath,
      createdAt: createdAt ?? this.createdAt,
      votes: votes ?? this.votes,
      isWinner: isWinner ?? this.isWinner,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ChallengeEntry &&
        other.id == id &&
        other.challengeId == challengeId &&
        other.challengeTitle == challengeTitle &&
        other.userId == userId &&
        other.authorName == authorName &&
        other.mediaUrl == mediaUrl &&
        other.storagePath == storagePath &&
        other.createdAt == createdAt &&
        other.votes == votes &&
        other.isWinner == isWinner;
  }

  @override
  int get hashCode => Object.hash(
    id,
    challengeId,
    challengeTitle,
    userId,
    authorName,
    mediaUrl,
    storagePath,
    createdAt,
    votes,
    isWinner,
  );
}
