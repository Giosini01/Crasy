/// Il portafoglio di una persona.
///
/// **I premi vinti stanno su un conto Stripe a nome suo, non su CRASY.** Il
/// conto si collega una volta, prima della prima gara con dei soldi; da li' in
/// poi ogni premio ci va appena la gara si chiude, e si preleva verso la banca
/// da dieci euro in su — o si usa per lanciare una missione.
///
/// Una parte puo' essere ancora su CRASY, in custodia: premi vinti prima di
/// collegare il conto, o in viaggio verso il conto. E' scritto nel portafoglio
/// dove sono, perche' un portafoglio che non dice dove sono i soldi e' la cosa
/// piu' vicina a una truffa che si possa costruire in buona fede.
class Wallet {
  const Wallet({
    this.balanceCents = 0,
    this.suStripeCents = 0,
    this.withdrawingCents = 0,
    this.movements = const [],
  });

  /// Quanto c'e' dentro, in centesimi: tutto, ovunque stia.
  final int balanceCents;

  /// **Di cui sul conto Stripe a nome suo.** Il resto e' ancora su CRASY, in
  /// custodia, e ci passa appena il conto e' collegato. Serve solo a dire dove
  /// sono i soldi: per chi li guarda sono gli stessi.
  final int suStripeCents;

  /// Quanto e' ancora su CRASY.
  int get inCustodiaCents => balanceCents - suStripeCents;

  /// Quanto e' gia' stato chiesto e sta arrivando sul conto.
  ///
  /// **E' uscito dal saldo ma non e' ancora arrivato**, ed e' giusto che si
  /// veda: chi ha chiesto un prelievo e trova il portafoglio a zero, senza una
  /// riga che glielo spieghi, pensa che i suoi soldi siano spariti. E' anche
  /// la riga che impedisce di chiedere due volte gli stessi soldi.
  final int withdrawingCents;

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
    this.kind = '',
    this.challengeTitle = '',
    this.createdAt,
  });

  final String id;

  /// Che movimento e': `prize`, `withdrawal`, `challengePayment`.
  ///
  /// **Serve perche' i negativi non sono piu' una cosa sola.** Finche' l'unico
  /// modo di far scendere il saldo era prelevare, bastava il segno: meno vuol
  /// dire prelievo. Da quando si puo' pagare una missione col portafoglio i
  /// negativi sono due, e il segno non li distingue piu' — ogni missione pagata
  /// compariva nell'elenco come "Prelievo", cioe' come soldi andati sul conto
  /// quando invece erano rimasti qui dentro.
  ///
  /// Vuoto sulle righe scritte prima che questo campo esistesse: li' si torna a
  /// decidere con il segno, che per quelle e' ancora giusto.
  final String kind;

  /// Positivo per i premi, negativo per i prelievi.
  final int amountCents;

  final String challengeTitle;
  final DateTime? createdAt;

  bool get isPrize => amountCents > 0;

  /// Se questa riga e' una missione pagata col portafoglio.
  bool get isChallengePayment => kind == 'challengePayment';

  /// Se e' un premio tornato indietro: gara annullata, o nessun partecipante.
  bool get isRefund => kind == 'refund';

  String get label {
    if (isPrize) {
      // **Un rimborso e' positivo come un premio, ma non e' una vittoria.**
      // Senza questa riga una gara annullata comparirebbe nel portafoglio
      // scritta uguale a una vinta, e la bacheca direbbe una cosa falsa.
      if (isRefund) {
        return challengeTitle.isEmpty
            ? 'Premio restituito'
            : challengeTitle.toUpperCase();
      }

      return challengeTitle.isEmpty
          ? 'Premio vinto'
          : challengeTitle.toUpperCase();
    }

    if (isChallengePayment) {
      // Il titolo della missione, come per i premi: chi guarda il portafoglio
      // cerca **per quale gara** sono usciti quei soldi, non la parola
      // "pagamento". La riga sotto dira' che e' un premio messo in palio.
      return challengeTitle.isEmpty
          ? 'Premio messo in palio'
          : challengeTitle.toUpperCase();
    }

    return 'Prelievo';
  }

  /// La riga piccola sotto il titolo, dove serve a distinguere.
  ///
  /// Sui premi vinti non c'e': il titolo in maiuscolo e il segno piu' dicono
  /// gia' tutto. Su una missione pagata serve, perche' senza si legge come una
  /// gara vinta con l'importo negativo — che non vuol dire niente.
  String get note {
    if (isChallengePayment) {
      return 'Premio messo in palio';
    }

    if (isRefund) {
      return "Rimborso: la gara è stata annullata";
    }

    return '';
  }
}
