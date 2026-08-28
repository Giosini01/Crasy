import 'package:crasy/features/challenges/domain/entities/entry_moderation.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';

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
    this.moderation = EntryModeration.approved,
    this.mediaKind = MediaKind.photo,
    this.caption = '',
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

  /// Due righe scritte da chi ha mandato la foto, come sotto un'istantanea.
  ///
  /// **Si scrive una volta e non si cambia piu'**, come la foto: e' la stessa
  /// ragione: una didascalia riscritta dopo aver visto le fiamme e' cambiare la
  /// propria mossa dopo aver guardato quelle degli altri.
  ///
  /// Vuota e' il caso normale, non un errore: la maggior parte delle foto non
  /// ha niente da aggiungere, e un campo obbligatorio qui costringerebbe a
  /// scrivere qualcosa pur di mandare.
  ///
  /// Sopravvive alla gara. I commenti no — quelli spariscono alla chiusura —
  /// perche' sono una conversazione, e questa e' parte della foto.
  final String caption;

  bool get hasCaption => caption.trim().isNotEmpty;

  /// Quanto puo' essere lunga una didascalia.
  ///
  /// Corta di proposito. Sotto una foto in gara serve una battuta — dove
  /// eravamo, com'e' andata — non un racconto: la foto e' il contenuto, e una
  /// didascalia che la supera in altezza se la mangia.
  static const int captionMaxLength = 140;

  /// Istante dell'invio. Nullo finche' il server non ha risolto il proprio
  /// timestamp — Firestore lo scrive dopo, non al momento della chiamata.
  final DateTime? createdAt;

  final int votes;

  /// Come si chiama questo voto, per chi lo da'.
  ///
  /// **Non basta l'identificativo della partecipazione**, ed e' costato caro:
  /// una partecipazione si chiama come chi l'ha mandata — una foto a testa per
  /// challenge, e il nome del documento e' la regola scritta nella forma dei
  /// dati. Ma la stessa persona partecipa a **piu'** challenge, e in tutte la
  /// sua foto si chiama allo stesso modo.
  ///
  /// I voti stavano sotto quel nome soltanto. Conseguenza: bastava votare la
  /// foto di qualcuno in una gara perche' la sua foto in **un'altra** gara
  /// risultasse gia' votata — fiamma rossa senza averla toccata. E toccandola
  /// li', il conto di quella seconda gara scendeva di uno senza essere mai
  /// salito. Con dei soldi in palio, e' un voto spostato da una foto a un'altra.
  ///
  /// La gara fa parte del nome del voto. Due gare, due voti distinti.
  String get voteKey => '${challengeId}__$id';

  /// Vera per la partecipazione che ha vinto la sua challenge.
  final bool isWinner;

  /// Se e' una foto o un video. Lo decide la challenge, non chi partecipa.
  final MediaKind mediaKind;

  bool get isVideo => mediaKind.isVideo;

  /// Se la foto ha passato il controllo sui contenuti.
  final EntryModeration moderation;

  /// Se questa foto la puo' vedere [viewerId].
  ///
  /// Una foto in attesa la vede **solo chi l'ha mandata**, e con un'etichetta
  /// che lo dice: sapere che il proprio scatto e' in coda e' molto meglio che
  /// vederlo sparire senza spiegazioni. Una rifiutata non la vede nessuno.
  bool isVisibleTo(String? viewerId) {
    return switch (moderation) {
      EntryModeration.approved => true,
      EntryModeration.pending => viewerId != null && viewerId == userId,
      EntryModeration.rejected => false,
    };
  }

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
    EntryModeration? moderation,
    MediaKind? mediaKind,
    String? caption,
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
      moderation: moderation ?? this.moderation,
      mediaKind: mediaKind ?? this.mediaKind,
      caption: caption ?? this.caption,
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
        other.isWinner == isWinner &&
        other.moderation == moderation &&
        other.mediaKind == mediaKind &&
        other.caption == caption;
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
    moderation,
    mediaKind,
    caption,
  );
}
