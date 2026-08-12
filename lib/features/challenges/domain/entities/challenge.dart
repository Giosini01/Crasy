import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';

/// Una challenge: una consegna, una scadenza, dei soldi in palio.
///
/// E' l'oggetto attorno a cui gira tutto il prodotto, e ha volutamente pochi
/// campi. Le quattro cose che l'utente deve capire in due secondi — **quanto si
/// vince, cosa bisogna fare, quanto tempo resta, quanti stanno gia' giocando** —
/// sono quattro campi qui dentro, e nessuno di essi e' calcolato altrove o
/// nascosto in una mappa di metadati.
class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.brief,
    required this.prizeCents,
    required this.scope,
    required this.startsAt,
    required this.endsAt,
    this.place = '',
    this.rules = const [],
    this.coverUrl,
    this.participantsCount = 0,
    this.winnerEntryId,
  });

  final String id;

  /// Il titolo, corto e in maiuscolo nell'interfaccia: `DO SOMETHING CRAZY`.
  final String title;

  /// La consegna per esteso: cosa bisogna fare, in una frase.
  final String brief;

  /// Il premio in **centesimi**.
  ///
  /// Interi e non decimali: un premio in denaro tenuto in `double` prima o poi
  /// diventa `499.99999`, ed e' il numero piu' letto dell'app.
  final int prizeCents;

  final ChallengeScope scope;

  /// Il luogo, quando ce n'e' uno: `NAPOLI`, `MILANO`.
  final String place;

  /// Le regole, una per riga. Poche e secche.
  final List<String> rules;

  /// La foto di copertina. Puo' mancare — l'interfaccia in quel caso mostra il
  /// titolo al posto dell'immagine invece di un rettangolo muto.
  final String? coverUrl;

  final DateTime startsAt;
  final DateTime endsAt;

  final int participantsCount;

  /// La partecipazione vincente, quando la challenge e' chiusa e il vincitore
  /// e' stato proclamato. Nulla prima.
  final String? winnerEntryId;

  /// Il premio gia' scritto: `€500`.
  String get prizeLabel => AppMoney.format(prizeCents);

  /// L'etichetta dell'ambito: il luogo se c'e', altrimenti la parola di
  /// ripiego dell'ambito.
  String get scopeLabel => place.isNotEmpty ? place : scope.defaultLabel;

  bool isLiveAt(DateTime now) =>
      !now.isBefore(startsAt) && now.isBefore(endsAt);

  bool isUpcomingAt(DateTime now) => now.isBefore(startsAt);

  bool hasEndedAt(DateTime now) => !now.isBefore(endsAt);

  /// Quanto manca alla chiusura. Zero, mai negativo, a challenge conclusa.
  Duration timeLeftAt(DateTime now) {
    final remaining = endsAt.difference(now);

    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Vero per le challenge di esempio, quelle che l'app mostra quando il
  /// database e' ancora vuoto.
  ///
  /// Il segno sta nell'identificativo e non in un campo a parte perche' deve
  /// sopravvivere al passaggio da una schermata all'altra, dove viaggia solo
  /// l'id: chi riceve `demo-global-500` sa gia' che quella challenge non e' su
  /// Firestore, senza doverla ricaricare per scoprirlo.
  bool get isDemo => id.startsWith(demoIdPrefix);

  static const String demoIdPrefix = 'demo-';

  Challenge copyWith({
    String? id,
    String? title,
    String? brief,
    int? prizeCents,
    ChallengeScope? scope,
    String? place,
    List<String>? rules,
    String? coverUrl,
    DateTime? startsAt,
    DateTime? endsAt,
    int? participantsCount,
    String? winnerEntryId,
  }) {
    return Challenge(
      id: id ?? this.id,
      title: title ?? this.title,
      brief: brief ?? this.brief,
      prizeCents: prizeCents ?? this.prizeCents,
      scope: scope ?? this.scope,
      place: place ?? this.place,
      rules: rules ?? this.rules,
      coverUrl: coverUrl ?? this.coverUrl,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      participantsCount: participantsCount ?? this.participantsCount,
      winnerEntryId: winnerEntryId ?? this.winnerEntryId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Challenge &&
        other.id == id &&
        other.title == title &&
        other.brief == brief &&
        other.prizeCents == prizeCents &&
        other.scope == scope &&
        other.place == place &&
        other.coverUrl == coverUrl &&
        other.startsAt == startsAt &&
        other.endsAt == endsAt &&
        other.participantsCount == participantsCount &&
        other.winnerEntryId == winnerEntryId;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    brief,
    prizeCents,
    scope,
    place,
    coverUrl,
    startsAt,
    endsAt,
    participantsCount,
    winnerEntryId,
  );
}
