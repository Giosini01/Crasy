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

  /// Legge un importo scritto a mano e lo porta in centesimi.
  ///
  /// `'10,50'` fa 1050, `'500'` fa 50000. Nullo quando quello che c'e' scritto
  /// non e' un importo: chi chiama lo usa per dire "no" invece di ritrovarsi in
  /// mano uno zero che sembra un prezzo.
  ///
  /// **La virgola e il punto valgono la stessa cosa.** In Italia si scrive con
  /// la virgola, ma la tastiera numerica di iOS mette il separatore della
  /// lingua del telefono, e un telefono in inglese offre il punto: accettarne
  /// uno solo vorrebbe dire un campo che rifiuta quello che la tastiera stessa
  /// ha appena suggerito.
  ///
  /// Nessun separatore delle migliaia in ingresso, ed e' voluto: `1.250` da
  /// solo puo' valere milleduecentocinquanta o uno e venticinque, e non c'e'
  /// modo di saperlo. Qui vale **uno e venticinque** — la stessa lettura che
  /// darebbe una calcolatrice — e chi vuole milleduecentocinquanta scrive
  /// `1250`, che e' quello che uno scrive in un campo comunque.
  static int? centsFrom(String? value) {
    final text = (value ?? '').trim().replaceAll(' ', '');

    // Nove cifre di parte intera sono gia' un miliardo: il limite non e' una
    // regola di prodotto — quella e' `prizeMaxEuro` — ma un argine contro un
    // numero cosi' lungo da uscire dai numeri interi del telefono.
    final match = RegExp(r'^(\d{1,9})(?:[.,](\d{1,2}))?$').firstMatch(text);

    if (match == null) {
      return null;
    }

    final units = int.parse(match.group(1)!);

    // `'5'` dopo la virgola sono cinquanta centesimi, non cinque: si completa a
    // destra. E' l'errore che farebbe scrivere `€10,05` a chi ha scritto
    // `10,5`.
    final decimals = int.parse((match.group(2) ?? '').padRight(2, '0'));

    return units * 100 + decimals;
  }

  /// L'importo come si scrive **dentro un campo**: `88,00`, `1250,00`.
  ///
  /// Due differenze da [format], e sono tutte e due obbligatorie.
  ///
  /// **I centesimi ci sono sempre**, anche su una cifra tonda. In vetrina
  /// `€500` e' meglio di `€500,00` — e' il numero piu' grande della schermata e
  /// due zeri lo allungano per niente — ma dentro un campo che si sta
  /// compilando i due decimali dicono una cosa che serve: *qui i centesimi si
  /// possono scrivere*.
  ///
  /// **Niente punto delle migliaia**, e questa e' la parte che non si vede.
  /// [format] scriverebbe `1.250,00`, che rimesso nel campo non tornerebbe piu'
  /// indietro: [centsFrom] rifiuta il separatore delle migliaia di proposito,
  /// perche' `1.250` da solo e' ambiguo. Il campo si ritroverebbe con dentro un
  /// testo che l'app stessa non sa piu' rileggere, e il premio partirebbe a
  /// zero.
  static String plain(int cents) {
    final absolute = cents.abs();
    final segno = cents < 0 ? '-' : '';
    final decimals = absolute.remainder(100).toString().padLeft(2, '0');

    return '$segno${absolute ~/ 100},$decimals';
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
