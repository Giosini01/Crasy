abstract final class AppDateUtils {
  static int calculateAge(DateTime birthDate, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final birth = _dateOnly(birthDate);

    var age = today.year - birth.year;
    final hasHadBirthday =
        today.month > birth.month ||
        (today.month == birth.month && today.day >= birth.day);

    if (!hasHadBirthday) {
      age--;
    }

    return age;
  }

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
  ///
  /// Scritta a mano invece di passare da `MaterialLocalizations`: qui serve
  /// una sola lingua, e i nomi dei mesi in un elenco sono piu' facili da
  /// leggere e da verificare di una dipendenza sulla localizzazione.
  static String formatItalianDate(DateTime value) {
    return '${value.day} ${_months[value.month - 1]} ${value.year}';
  }

  /// Quanto tempo fa, in forma cortissima: `ora`, `35m`, `2h`.
  ///
  /// Sta su una targhetta sopra la foto, dove ci sono pochi pixel: "2 ore fa"
  /// non ci starebbe, e "2h" si capisce lo stesso.
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

  /// Quanto manca, in forma cortissima: `17h`, `42m`, `ora`.
  ///
  /// L'opposto di [shortTimeAgo], e serve allo stesso scopo: dire quanto vive
  /// ancora una foto senza occupare una riga intera. Sopra l'ora si contano le
  /// ore, sotto i minuti — chi legge "17h" non ha bisogno dei secondi.
  static String shortTimeLeft(DateTime moment, {DateTime? now}) {
    final left = moment.difference(now ?? DateTime.now());

    if (left.isNegative || left == Duration.zero) {
      return 'ora';
    }

    if (left.inHours >= 1) {
      return '${left.inHours}h';
    }

    return '${left.inMinutes.clamp(1, 59)}m';
  }

  /// Chiave di giornata `yyyy-MM-dd` in ora locale.
  ///
  /// E' la stessa stringa che finisce su Firestore, quindi il "giorno" delle
  /// Daily coincide sempre con quello dell'orologio dell'utente.
  static String dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '${value.year}-$month-$day';
  }

  /// Countdown in stile orologio: `02:14:31` sopra l'ora, `14:31` sotto.
  ///
  /// Le due cifre fisse evitano che il numero cambi larghezza a ogni secondo,
  /// e la forma a orologio si legge senza doverla interpretare.
  static String formatCountdown(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours >= 1) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }

    return '$minutes:$seconds';
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
