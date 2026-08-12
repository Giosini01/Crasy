/// Il denaro in palio, scritto come va scritto.
abstract final class AppMoney {
  /// Formatta un importo in centesimi: `€500`, `€1.250`, `€99,50`.
  ///
  /// Gli importi tondi perdono i decimali, e non e' un dettaglio estetico: il
  /// premio e' il numero piu' grande della schermata, e `€500,00` occupa un
  /// terzo di spazio in piu' di `€500` per dire la stessa identica cosa.
  ///
  /// Le migliaia prendono il punto e i decimali la virgola, come si scrive in
  /// italiano. La separazione e' fatta a mano invece che con `intl`: e' una
  /// riga di codice, e non vale una dipendenza in piu'.
  static String format(int cents, {String symbol = '€'}) {
    final negative = cents < 0;
    final absolute = cents.abs();
    final units = absolute ~/ 100;
    final decimals = absolute.remainder(100);
    final buffer = StringBuffer();

    if (negative) {
      buffer.write('-');
    }

    buffer
      ..write(symbol)
      ..write(_grouped(units));

    if (decimals != 0) {
      buffer
        ..write(',')
        ..write(decimals.toString().padLeft(2, '0'));
    }

    return buffer.toString();
  }

  /// Inserisce il punto ogni tre cifre partendo da destra.
  static String _grouped(int units) {
    final digits = units.toString();
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index).remainder(3) == 0) {
        buffer.write('.');
      }

      buffer.write(digits[index]);
    }

    return buffer.toString();
  }
}
