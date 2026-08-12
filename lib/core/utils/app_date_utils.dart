abstract final class AppDateUtils {
  static const List<String> _months = [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ];

  /// Data per esteso in italiano: `10 marzo 1994`.
  static String formatItalianDate(DateTime value) {
    return '${value.day} ${_months[value.month - 1]} ${value.year}';
  }

  /// Quanto manca alla chiusura di una challenge.
  ///
  /// La forma cambia con la scala, e non per capriccio: a tre giorni dalla fine
  /// i minuti non servono a nessuno, nell'ultima ora sono l'unica cosa che
  /// conta. Mostrare sempre `03g 04h 12m 09s` sarebbe preciso e illeggibile.
  ///
  /// - oltre il giorno: `3g 4h`
  /// - oltre l'ora: `4h 32m`
  /// - sotto l'ora: `32m 09s`
  /// - a tempo scaduto: `chiusa`
  static String formatTimeLeft(Duration remaining) {
    if (remaining <= Duration.zero) {
      return 'chiusa';
    }

    if (remaining.inDays >= 1) {
      return '${remaining.inDays}g ${remaining.inHours.remainder(24)}h';
    }

    if (remaining.inHours >= 1) {
      return '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
    }

    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    return '${remaining.inMinutes}m ${seconds}s';
  }

  /// Quanto tempo fa, in forma cortissima: `ora`, `35m`, `2h`, `3g`.
  ///
  /// Sta sotto le foto del feed, dove i pixel sono pochi: "2 ore fa" non ci
  /// starebbe, e "2h" si capisce lo stesso.
  static String shortTimeAgo(DateTime moment, {DateTime? now}) {
    final elapsed = (now ?? DateTime.now()).difference(moment);

    if (elapsed.inMinutes < 1) {
      return 'ora';
    }

    if (elapsed.inMinutes < 60) {
      return '${elapsed.inMinutes}m';
    }

    if (elapsed.inHours < 24) {
      return '${elapsed.inHours}h';
    }

    return '${elapsed.inDays}g';
  }

  /// Chiave di giornata `yyyy-MM-dd` in ora locale.
  static String dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '${value.year}-$month-$day';
  }
}
