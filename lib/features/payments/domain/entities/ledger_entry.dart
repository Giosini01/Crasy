import 'package:crasy/core/utils/app_money.dart';

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
    this.pagatoCents = 0,
  });

  final String id;

  /// `prize`, `challengePayment`, `refund`, `withdrawal`, `tip`.
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

  /// **Quanto ha pagato davvero la carta**: il premio piu' le spese.
  ///
  /// [amountCents] su un pagamento e' solo il premio. Letta da sola, una missione
  /// da due euro diceva -2, e il suo rimborso +2,29: sembrava che i soldi
  /// fossero aumentati. Zero sulle righe scritte prima che questo campo
  /// esistesse.
  final int pagatoCents;

  bool get isIn => amountCents > 0;

  bool get _conLaCarta => kind == 'challengePayment' && source == 'card';

  /// La cifra da mostrare: quello che e' uscito davvero, quando lo si sa.
  int get cifra => _conLaCarta && pagatoCents > 0 ? -pagatoCents : amountCents;

  /// Cosa e' successo, in parole. Sulle righe vecchie con la carta dice che la
  /// cifra e' solo il premio: quanto ha pagato la carta li' non e' scritto.
  String get nota {
    if (!_conLaCarta) {
      return note;
    }

    if (pagatoCents <= 0) {
      return 'Solo il premio: la carta ha pagato anche le spese';
    }

    return '${AppMoney.format(-amountCents)} di premio più '
        '${AppMoney.format(pagatoCents + amountCents)} di spese';
  }

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
      'tip' => 'MANCIA A CRASY',
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
