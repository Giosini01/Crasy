/// Le distanze.
///
/// I valori grandi ci sono e vanno usati: in CRASY lo spazio vuoto e' un
/// elemento del progetto, non quello che avanza. Fra una challenge e la
/// successiva ci va [section], non [md] — se due challenge si toccano
/// diventano un elenco, e un elenco non si guarda, si scorre.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Il respiro fra due blocchi che non c'entrano niente l'uno con l'altro.
  static const double section = 72;

  /// Il margine laterale delle schermate. Uno solo, uguale ovunque: e' cio'
  /// che tiene in colonna il premio, il titolo, la foto e il comando.
  static const double page = 24;
}
