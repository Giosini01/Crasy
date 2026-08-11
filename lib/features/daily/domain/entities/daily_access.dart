import 'package:app_incontri/features/daily/domain/entities/daily.dart';
import 'package:app_incontri/features/daily/domain/entities/daily_window.dart';

/// Cosa puo' fare l'utente in questo momento.
///
/// Riunisce le due domande che l'interfaccia pone di continuo: "posso
/// scattare?" e "posso vedere il Per Te?". Sono indipendenti: le fasce possono
/// essere tutte chiuse e il Per Te restare aperto, perche' chi ha gia'
/// pubblicato oggi non viene richiuso fuori a fascia conclusa.
class DailyAccess {
  const DailyAccess({
    required this.boundary,
    required this.usedToday,
    required this.hasActiveDaily,
    this.openSlot,
    this.usedSlots = const {},
    this.verifying = false,
    this.justRejected = false,
  });

  factory DailyAccess.resolve({
    required DateTime now,
    required List<Daily> todayDailies,
  }) {
    // Una foto scartata dal controllo non consuma un tentativo: sarebbe una
    // punizione per un rifiuto che l'utente non ha nemmeno scelto.
    final kept = todayDailies.where((daily) => !daily.isRejected).toList();
    final openSlot = DailyWindow.openSlotAt(now);

    return DailyAccess(
      openSlot: openSlot,
      boundary: openSlot == null
          ? DailyWindow.nextOpening(now)
          : DailyWindow.endOf(openSlot, now),
      usedToday: kept.length,
      usedSlots: {
        for (final daily in kept)
          if (daily.slot != null) daily.slot!,
      },
      hasActiveDaily: kept.any((daily) => daily.isActive),
      verifying: kept.any((daily) => daily.isPending),
      justRejected: todayDailies.any((daily) => daily.isRejected),
    );
  }

  /// Fascia aperta adesso, `null` se sono tutte chiuse.
  final int? openSlot;

  /// Istante verso cui punta il countdown: la chiusura della fascia aperta,
  /// oppure l'apertura della prossima.
  final DateTime boundary;

  final int usedToday;

  /// Fasce in cui l'istantanea e' gia' stata scattata.
  final Set<int> usedSlots;

  /// L'istantanea della fascia aperta adesso e' gia' stata scattata.
  bool get usedCurrentSlot =>
      openSlot != null && usedSlots.contains(openSlot);

  final bool hasActiveDaily;

  /// C'e' una foto caricata che il server sta ancora controllando.
  final bool verifying;

  /// Almeno una foto di oggi e' stata scartata dal controllo.
  final bool justRejected;

  bool get windowOpen => openSlot != null;

  int get remaining =>
      (DailyWindow.maxPerDay - usedToday).clamp(0, DailyWindow.maxPerDay);

  bool get limitReached => remaining == 0;

  /// Si scatta se una fascia e' aperta e non e' gia' stata usata.
  ///
  /// Con il flag di prova attivo le fasce si ignorano del tutto: conta solo
  /// non aver esaurito le tre istantanee.
  bool get canCapture {
    if (DailyWindow.alwaysOpen) {
      return !limitReached;
    }

    return windowOpen && !usedCurrentSlot && !limitReached;
  }

  /// Il Per Te si apre con la prima Istantanea della giornata e resta aperto
  /// fino a mezzanotte, anche a fasce chiuse.
  bool get discoverUnlocked => hasActiveDaily;

  Duration timeToBoundary(DateTime now) {
    final remainingTime = boundary.difference(now);

    return remainingTime.isNegative ? Duration.zero : remainingTime;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is DailyAccess &&
        other.openSlot == openSlot &&
        other.boundary == boundary &&
        other.usedToday == usedToday &&
        other.usedSlots.length == usedSlots.length &&
        other.usedSlots.containsAll(usedSlots) &&
        other.hasActiveDaily == hasActiveDaily &&
        other.verifying == verifying &&
        other.justRejected == justRejected;
  }

  @override
  int get hashCode => Object.hash(
    openSlot,
    boundary,
    usedToday,
    Object.hashAllUnordered(usedSlots),
    hasActiveDaily,
    verifying,
    justRejected,
  );
}
