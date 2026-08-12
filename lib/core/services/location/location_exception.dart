/// Sollevata quando la posizione non si puo' ottenere.
///
/// Il [message] e' gia' scritto per l'utente: le cause sono tutte cose su cui
/// puo' intervenire, e un messaggio generico non lo aiuterebbe a capire dove.
class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => 'LocationException: $message';
}

/// Messaggi condivisi fra l'implementazione nativa e quella web, cosi' lo
/// stesso problema si racconta allo stesso modo su tutte le piattaforme.
abstract final class LocationMessages {
  static const denied = 'Accesso alla posizione negato. Concedilo e riprova.';

  static const disabled =
      'I servizi di localizzazione sono spenti. Attivali e riprova.';

  static const unavailable =
      'Il dispositivo non riesce a determinare dove sei. Se sei al chiuso '
      'spostati vicino a una finestra, oppure attiva il Wi-Fi, e riprova.';

  static const timeout =
      'La posizione ci sta mettendo troppo. Riprova fra un istante.';

  static const unknown = 'Non siamo riusciti a leggere la posizione.';
}
