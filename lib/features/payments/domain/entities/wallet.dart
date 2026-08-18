/// Il portafoglio di una persona.
///
/// **I soldi vinti non escono subito: si fermano qui.** E' una scelta che
/// conviene a chi vince, non a CRASY. Mandando un bonifico nell'istante in cui
/// la gara si chiude, servirebbe che il vincitore fosse gia' registrato con
/// documento e IBAN in quel preciso momento — cioe' quasi mai — e il premio
/// resterebbe fermo in attesa di lui.
///
/// Cosi' invece i soldi sono suoi appena vince: li vede nel profilo, si
/// sommano a quelli delle volte prima, e la registrazione la fa il giorno che
/// decide di prelevare. Una volta sola, quando ne vale la pena.
///
/// Va detto senza giri di parole, ed e' scritto anche nel profilo: **finche'
/// non li preleva, quei soldi stanno su CRASY.** Un portafoglio che non dice
/// dove sono i soldi e' la cosa piu' vicina a una truffa che si possa costruire
/// in buona fede.
class Wallet {
  const Wallet({this.balanceCents = 0, this.movements = const []});

  /// Quanto c'e' dentro, in centesimi.
  final int balanceCents;

  /// Da dove viene, dal piu' recente.
  final List<WalletMovement> movements;

  /// Sotto i dieci euro non si preleva.
  ///
  /// Non e' un limite messo per trattenere: un conto aperto su Stripe costa
  /// una piccola quota mensile, e prelevare due euro vorrebbe dire aprirlo per
  /// vedersi mangiare il prelievo. Meglio dirlo prima che dopo.
  static const int minimumWithdrawalCents = 1000;

  bool get canWithdraw => balanceCents >= minimumWithdrawalCents;

  bool get isEmpty => balanceCents <= 0 && movements.isEmpty;
}

/// Una riga del portafoglio: un premio entrato o un prelievo uscito.
class WalletMovement {
  const WalletMovement({
    required this.id,
    required this.amountCents,
    this.challengeTitle = '',
    this.createdAt,
  });

  final String id;

  /// Positivo per i premi, negativo per i prelievi.
  final int amountCents;

  final String challengeTitle;
  final DateTime? createdAt;

  bool get isPrize => amountCents > 0;

  String get label => isPrize
      ? (challengeTitle.isEmpty ? 'Premio vinto' : challengeTitle.toUpperCase())
      : 'Prelievo';
}
