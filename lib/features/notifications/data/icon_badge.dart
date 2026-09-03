import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Il numero rosso sull'icona dell'app.
///
/// **Vuol dire "c'e' qualcosa che non hai letto", e nient'altro.** Per questo
/// va spento appena non e' piu' vero: un pallino che resta acceso su un'app che
/// si e' appena chiusa diventa un ornamento permanente, si impara a non
/// guardarlo, e il giorno in cui significa davvero qualcosa non se ne accorge
/// nessuno. Un avviso che mente una volta non lo si crede piu'.
///
/// A metterlo e' iOS, leggendo il messaggio che arriva dal server; a toglierlo
/// dobbiamo pensarci noi, e i momenti in cui farlo sono due:
///
/// - **quando l'app torna in primo piano** — se ne occupa il codice nativo, che
///   e' l'unico ad accorgersene;
/// - **quando arriva un messaggio mentre l'app e' gia' aperta** — e questo lo sa
///   solo il codice Dart, perche' l'app non torna da nessuna parte: c'e' gia'.
///   Senza questa seconda meta', il numero compare mentre uno sta guardando lo
///   schermo e non se ne va piu'.
class IconBadge {
  const IconBadge();

  static const _filo = MethodChannel('crasy/pallino');

  /// Spegne il numero. Non lancia mai: **un pallino di troppo non vale un
  /// errore**, e su tutto quello che non e' un iPhone questo filo non esiste.
  Future<void> clear() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    try {
      await _filo.invokeMethod<void>('azzera');
    } on Object catch (_) {
      // Vedi sopra.
    }
  }
}
