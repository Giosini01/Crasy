import 'package:app_incontri/features/daily/domain/entities/daily_vibe.dart';

/// Una persona con cui il cuore e' stato reciproco.
///
/// Come per il feed, tutto e' **denormalizzato**: il client non puo' leggere
/// il profilo altrui nemmeno dopo un match, quindi qui dentro c'e' esattamente
/// cio' che il server ha deciso di far vedere, e niente di piu'.
class MatchPerson {
  const MatchPerson({
    required this.userId,
    required this.name,
    required this.age,
    required this.photoUrl,
    required this.icebreaker,
    required this.vibe,
    required this.interests,
    required this.distanceKm,
    required this.message,
    required this.myMessage,
    required this.photoCapturedAt,
    required this.profilePhotoUrl,
    required this.matchedAt,
  });

  final String userId;
  final String name;
  final int age;

  /// L'Istantanea che aveva quando e' nato il match.
  ///
  /// Dopo un giorno quella foto non esiste piu' e questo indirizzo non porta
  /// a niente: e' voluto, la foto dura un giorno anche quando e' diventata un
  /// match. La schermata ripiega sull'iniziale del nome.
  final String photoUrl;

  /// L'"Oggi..." di quel momento.
  final String icebreaker;

  /// Identificativo dell'etichetta del momento.
  final String vibe;

  final List<String> interests;

  final double distanceKm;

  /// La riga che questa persona aveva allegato al proprio cuore.
  ///
  /// Arriva **solo ora**: finche' il cuore non e' stato ricambiato era chiusa
  /// dentro la sua decisione, che nessuno poteva leggere.
  final String message;

  /// La riga che **io** avevo allegato al mio cuore, rimandata indietro dal
  /// server. Serve a far vedere le due frasi una sotto l'altra: la
  /// conversazione e' gia' cominciata prima che ci fosse una chat.
  final String myMessage;

  /// Quando e' stata scattata l'Istantanea qui sopra.
  final DateTime? photoCapturedAt;

  /// La foto profilo, che non scade: e' il ripiego quando l'Istantanea e'
  /// sparita.
  final String profilePhotoUrl;

  final DateTime? matchedAt;

  /// Quando questa Istantanea smette di esistere.
  DateTime? get photoExpiresAt =>
      photoCapturedAt?.add(const Duration(hours: 24));

  /// Vero quando l'Istantanea e' passata.
  ///
  /// **Il match resta**: a sparire e' la foto, non la persona. Da qui in poi
  /// la scheda mostra la foto profilo e lo dice, invece di lasciare un buco
  /// che sembrerebbe un guasto.
  bool expiredAt(DateTime now) {
    final expiry = photoExpiresAt;

    return expiry == null || !now.isBefore(expiry);
  }

  /// La foto da mostrare adesso: l'Istantanea se e' ancora viva, altrimenti
  /// quella del profilo.
  String photoAt(DateTime now) {
    if (!expiredAt(now) && photoUrl.isNotEmpty) {
      return photoUrl;
    }

    return profilePhotoUrl;
  }

  bool get hasPhoto => photoUrl.isNotEmpty;

  bool get hasMessage => message.trim().isNotEmpty;

  bool get hasMyMessage => myMessage.trim().isNotEmpty;

  /// Quanti interessi si hanno in comune con [mine].
  ///
  /// Si conta **qui e non sul server** perche' e' l'unico calcolo che il
  /// client puo' fare da solo: gli interessi dell'altra persona arrivano nel
  /// documento del match, i propri sono gia' in memoria. Niente percentuali —
  /// un numero di cose concrete dice da dove partire, un punteggio no.
  String sharedLabelWith(List<String> mine) {
    if (interests.isEmpty || mine.isEmpty) {
      return '';
    }

    final owned = mine.toSet();
    final shared = interests.where(owned.contains).length;

    if (shared == 0) {
      return '';
    }

    return shared == 1 ? '1 interesse in comune' : '$shared interessi in comune';
  }

  /// Distanza arrotondata, come nel feed.
  String get distanceLabel {
    if (distanceKm < 1) {
      return 'meno di 1 km';
    }

    return '${distanceKm.round()} km';
  }

  bool get hasIcebreaker => icebreaker.trim().isNotEmpty;

  String get vibeChip => DailyVibe.chipOf(vibe);

  /// Da dove partire per scrivere.
  ///
  /// Non e' un testo generato: e' il **suggerimento di un appiglio**, preso da
  /// quello che la persona ha gia' detto di se'. Prima l'"Oggi...", che e' la
  /// cosa piu' fresca; poi cosa stava facendo; e in ultimo un interesse in
  /// comune. Se non c'e' niente di tutto questo, non si inventa nulla.
  String? get conversationHint {
    // Se ha scritto qualcosa, il punto di partenza e' quello e basta: non si
    // suggerisce un appiglio a chi ne ha gia' offerto uno.
    if (hasMessage) {
      return null;
    }

    if (hasIcebreaker) {
      return 'Ha scritto: "${icebreaker.trim()}". Parti da li.';
    }

    final chip = vibeChip;

    if (chip.isNotEmpty) {
      return 'Oggi era in modalita $chip. Chiediglielo.';
    }

    if (interests.isNotEmpty) {
      return 'Avete ${interests.first} in comune.';
    }

    return null;
  }
}
