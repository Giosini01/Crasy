/// Un'Istantanea altrui, gia' selezionata per chi la guarda.
///
/// Tutti i dati dell'autore sono **denormalizzati** qui dentro: il client non
/// puo' leggere i profili degli altri, e non deve poterlo fare. E' il server a
/// decidere che cosa finisce in questo documento, quindi l'app non ha modo di
/// vedere piu' di quanto le spetta.
class FeedItem {
  const FeedItem({
    required this.dailyId,
    required this.authorId,
    required this.authorName,
    required this.authorAge,
    required this.authorPhotoUrl,
    required this.authorIcebreaker,
    required this.vibe,
    required this.authorInterests,
    required this.sharedInterests,
    required this.compatibility,
    required this.photoUrl,
    required this.dateKey,
    required this.distanceKm,
    required this.capturedAt,
  });

  final String dailyId;
  final String authorId;
  final String authorName;
  final int authorAge;
  /// Foto profilo dell'autore, vuota se non ne ha una verificata.
  final String authorPhotoUrl;

  /// La riga da cui far partire il primo messaggio: l'"Oggi..." di chi ha
  /// pubblicato.
  final String authorIcebreaker;

  /// L'etichetta del momento, gia' pronta da mostrare (`☕ Relax`). Vuota se
  /// non ne e' stata scelta una.
  final String vibe;

  final List<String> authorInterests;

  /// Interessi condivisi con chi guarda, calcolati dal server.
  final List<String> sharedInterests;

  /// Percentuale di affinita', gia' calcolata: il client non puo' leggere gli
  /// interessi di chi guarda e di chi e' guardato nello stesso momento.
  final int compatibility;

  /// L'Istantanea vera e propria.
  final String photoUrl;
  final String dateKey;

  /// Distanza calcolata dal server al momento della pubblicazione.
  final double distanceKm;

  /// Istante dello scatto: ordina le Daily di una stessa persona.
  final DateTime capturedAt;

  /// Distanza arrotondata da mostrare: sotto il chilometro diventa "meno di
  /// 1 km" invece di uno zero che sembrerebbe un errore.
  String get distanceLabel {
    if (distanceKm < 1) {
      return 'meno di 1 km';
    }

    return '${distanceKm.round()} km';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is FeedItem &&
        other.dailyId == dailyId &&
        other.authorId == authorId &&
        other.authorName == authorName &&
        other.authorAge == authorAge &&
        other.photoUrl == photoUrl &&
        other.dateKey == dateKey &&
        other.distanceKm == distanceKm &&
        other.capturedAt == capturedAt;
  }

  @override
  int get hashCode => Object.hash(
    dailyId,
    authorId,
    authorName,
    authorAge,
    authorIcebreaker,
    compatibility,
    photoUrl,
    dateKey,
    distanceKm,
    capturedAt,
  );
}
