/// **Una riga dell'estratto conto: un movimento di denaro, e basta.**
///
/// ## Perche' non bastavano i movimenti del portafoglio
///
/// Il portafoglio racconta solo i soldi che passano **dentro** CRASY: i premi
/// vinti, i prelievi, le missioni pagate col saldo. Chi paga una missione con
/// la carta non ci compare — quei soldi vanno dalla carta a Stripe e non
/// toccano mai il portafoglio — e infatti undici pagamenti rimborsati in parte
/// erano visibili solo a noi, sulla dashboard di Stripe. Per chi li aveva fatti
/// non esisteva nessun posto dove leggerli.
///
/// E le gare non potevano farne le veci: annullandole si cancellano, e con loro
/// sparisce la prova di cosa era stato pagato.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.kind,
    required this.amountCents,
    this.challengeId = '',
    this.challengeTitle = '',
    this.source = '',
    this.note = '',
    this.at,
  });

  final String id;

  /// `prize`, `challengePayment`, `refund`, `withdrawal`.
  final String kind;

  /// **Dal punto di vista di chi legge**: positivo quello che entra, negativo
  /// quello che esce. E' la sola regola che tiene insieme un estratto conto
  /// fatto di movimenti scritti da cinque posti diversi.
  final int amountCents;

  final String challengeId;
  final String challengeTitle;

  /// Da dove sono passati i soldi: `card`, `wallet`, `bank`, `crasy`.
  ///
  /// Serve a dire la cosa che la gente chiede per prima — *dove sono finiti?* —
  /// e a distinguere due righe altrimenti identiche: una missione pagata con la
  /// carta e una pagata col saldo si assomigliano, e sono due fatti diversi.
  final String source;

  final String note;
  final DateTime? at;

  bool get isIn => amountCents > 0;

  /// Il titolo della riga: la gara se c'e', altrimenti cosa e' successo.
  String get label {
    if (challengeTitle.isNotEmpty) {
      return challengeTitle.toUpperCase();
    }

    return switch (kind) {
      'prize' => 'PREMIO VINTO',
      'challengePayment' => 'PREMIO MESSO IN PALIO',
      'refund' => 'RIMBORSO',
      'withdrawal' => 'PRELIEVO',
      _ => 'MOVIMENTO',
    };
  }

  /// Dove sono andati o da dove sono arrivati, in parole.
  String get dove => switch (source) {
    'card' => 'carta',
    'wallet' => 'portafoglio',
    'bank' => 'conto corrente',
    'crasy' => 'portafoglio',
    _ => '',
  };
}
