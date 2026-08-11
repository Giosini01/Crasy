/// I numeri di una giornata: quante persone hanno guardato la tua Istantanea,
/// quanti cuori, quanti match.
///
/// Sono **privati e senza nomi**. Dicono quanti, mai chi: sapere chi ti ha
/// guardato vorrebbe dire che qualcun altro sa che tu hai guardato lui, e
/// tutta l'app e' costruita perche' non si possa.
class VibeDay {
  const VibeDay({
    required this.views,
    required this.likes,
    required this.matches,
  });

  final int views;
  final int likes;
  final int matches;

  static const empty = VibeDay(views: 0, likes: 0, matches: 0);

  bool get isEmpty => views == 0 && likes == 0 && matches == 0;
}

/// I totali di sempre, piu' la striscia di giorni consecutivi.
class VibeLifetime {
  const VibeLifetime({
    required this.streakDays,
    required this.streakLastDate,
    required this.totalDailies,
    required this.totalViews,
    required this.totalLikes,
    required this.totalMatches,
  });

  /// Giorni di fila con almeno un'Istantanea, come li ha contati il server.
  final int streakDays;

  /// Giornata dell'ultima Istantanea, in forma `yyyy-MM-dd`.
  final String streakLastDate;

  final int totalDailies;
  final int totalViews;
  final int totalLikes;
  final int totalMatches;

  static const empty = VibeLifetime(
    streakDays: 0,
    streakLastDate: '',
    totalDailies: 0,
    totalViews: 0,
    totalLikes: 0,
    totalMatches: 0,
  );

  /// La striscia **viva**, che non e' sempre quella scritta sul server.
  ///
  /// Il numero salvato racconta com'e' finita l'ultima volta: se l'ultima
  /// Istantanea e' di tre giorni fa, la striscia e' gia' rotta ma nessuno ha
  /// ancora scritto zero — il server tocca quel campo solo quando si pubblica.
  /// Il conto vero si fa quindi qui, guardando che giorno e' oggi.
  int aliveAt(String todayKey, String yesterdayKey) {
    if (streakLastDate == todayKey || streakLastDate == yesterdayKey) {
      return streakDays;
    }

    return 0;
  }
}
