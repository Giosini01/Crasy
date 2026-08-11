import 'package:app_incontri/features/feed/domain/entities/feed_item.dart';
import 'package:app_incontri/features/profile/domain/entities/profile_interests.dart';

/// Una persona nel feed, con le sue Daily di oggi raccolte in un mazzo solo.
///
/// Il feed arriva dal server come un documento per foto; qui diventa un
/// documento per persona, perche' e' la persona che si sceglie o si scarta,
/// non la singola foto.
class FeedPerson {
  const FeedPerson({
    required this.userId,
    required this.name,
    required this.age,
    required this.photoUrl,
    required this.icebreaker,
    required this.vibe,
    required this.interests,
    required this.sharedInterests,
    required this.compatibility,
    required this.distanceKm,
    required this.dailies,
  });

  final String userId;
  final String name;
  final int age;

  /// Foto profilo, vuota se non ne ha una verificata.
  final String photoUrl;

  /// La riga da cui far partire il primo messaggio.
  final String icebreaker;

  /// L'etichetta del momento dell'Istantanea piu' recente.
  final String vibe;

  final List<String> interests;

  /// Interessi in comune con chi guarda.
  final List<String> sharedInterests;

  /// Percentuale di affinita', calcolata dal server.
  final int compatibility;

  final double distanceKm;

  bool get hasPhoto => photoUrl.isNotEmpty;

  bool get hasIcebreaker => icebreaker.trim().isNotEmpty;

  bool get hasVibe => vibe.isNotEmpty;

  /// Gli interessi in comune, detti per nome.
  ///
  /// Al posto della percentuale di affinita', che e' stata tolta: un numero
  /// non dice da dove partire, "Musica · Montagna" si'. Oltre i due si conta,
  /// perche' una riga lunga sopra una foto non si legge.
  String get sharedInterestsLabel {
    if (sharedInterests.isEmpty) {
      return '';
    }

    if (sharedInterests.length <= 2) {
      return sharedInterests.map(ProfileInterests.labelOf).join(' · ');
    }

    return '${sharedInterests.length} interessi in comune';
  }

  /// Dalla piu' recente alla piu' vecchia: la scheda si apre sull'ultima, e
  /// toccando a sinistra si va indietro nel tempo.
  final List<FeedItem> dailies;

  String get distanceLabel => dailies.first.distanceLabel;

  /// L'Istantanea piu' recente: e' quella che si apre e quella che decide da
  /// quanto una persona e' "in giro".
  DateTime get latestCapturedAt => dailies.first.capturedAt;

  /// Raggruppa le voci per autore e ordina le persone dalla piu' vicina.
  static List<FeedPerson> group(List<FeedItem> items) {
    final byAuthor = <String, List<FeedItem>>{};

    for (final item in items) {
      byAuthor.putIfAbsent(item.authorId, () => []).add(item);
    }

    final people = byAuthor.values.map((dailies) {
      final sorted = [...dailies]
        ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      final first = sorted.first;

      return FeedPerson(
        userId: first.authorId,
        name: first.authorName,
        age: first.authorAge,
        photoUrl: first.authorPhotoUrl,
        icebreaker: first.authorIcebreaker,
        vibe: first.vibe,
        interests: first.authorInterests,
        sharedInterests: first.sharedInterests,
        compatibility: first.compatibility,
        distanceKm: first.distanceKm,
        dailies: sorted,
      );
    }).toList();

    people.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return people;
  }
}
