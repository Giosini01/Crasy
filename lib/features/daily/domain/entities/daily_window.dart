/// Le tre fasce in cui si puo' scattare l'Istantanea.
///
/// Sono **tre occasioni per un solo scatto**: mezzogiorno, meta' pomeriggio e
/// sera. Non tre scatti — uno. Le fasce dicono *quando* ci si puo' far vedere,
/// [maxPerDay] dice *quante volte*, e la risposta e' una sola.
///
/// Gli orari sono fissi e non casuali: un orario a sorpresa costringe a tenere
/// le notifiche accese e punisce chi in quel momento non puo' guardare il
/// telefono. Tre appuntamenti noti si imparano a memoria in due giorni.
abstract final class DailyWindow {
  /// Ora di inizio di ciascuna fascia, in ora locale.
  static const List<int> slotHours = [12, 15, 21];

  /// Quanto resta aperta ogni fascia.
  static const Duration slotDuration = Duration(hours: 1);

  /// **Uno al giorno.**
  ///
  /// E' la regola su cui poggia tutto il resto: se si potesse scattare finche'
  /// non viene bene, quella non sarebbe piu' un'istantanea ma la migliore di
  /// venti pose — cioe' esattamente la foto profilo che questa app non vuole.
  /// Non esiste un modo di rifarla, e non e' una svista.
  static const int maxPerDay = 1;

  /// Scavalca gli orari e tiene sempre aperto, per provare l'app fuori fascia:
  ///
  ///     flutter run --dart-define=DAILY_WINDOW_ALWAYS_OPEN=true
  ///
  /// Senza il flag vale `false`, quindi una build normale non ne risente.
  static const bool alwaysOpen = bool.fromEnvironment(
    'DAILY_WINDOW_ALWAYS_OPEN',
  );

  /// Indice della fascia aperta adesso, oppure `null` se sono tutte chiuse.
  static int? openSlotAt(DateTime now) {
    for (var index = 0; index < slotHours.length; index++) {
      final start = startOf(index, now);

      if (!now.isBefore(start) && now.isBefore(start.add(slotDuration))) {
        return index;
      }
    }

    return null;
  }

  static bool isOpenAt(DateTime now) => openSlotAt(now) != null;

  /// Inizio della fascia [index] nel giorno di [now].
  static DateTime startOf(int index, DateTime now) {
    return DateTime(now.year, now.month, now.day, slotHours[index]);
  }

  /// Fine della fascia [index] nel giorno di [now].
  static DateTime endOf(int index, DateTime now) {
    return startOf(index, now).add(slotDuration);
  }

  /// Prossima apertura: la fascia successiva di oggi, oppure la prima di
  /// domani.
  ///
  /// Il giorno dopo si ottiene incrementando il campo `day` invece di sommare
  /// 24 ore, cosi' nelle notti di cambio ora le fasce restano ancorate al loro
  /// orario di orologio.
  static DateTime nextOpening(DateTime now) {
    for (var index = 0; index < slotHours.length; index++) {
      final start = startOf(index, now);

      if (now.isBefore(start)) {
        return start;
      }
    }

    return DateTime(now.year, now.month, now.day + 1, slotHours.first);
  }

  /// Etichetta leggibile di una fascia, per esempio `12:00`.
  static String labelOf(int index) =>
      '${slotHours[index].toString().padLeft(2, '0')}:00';
}
