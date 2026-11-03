import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/core/utils/app_money.dart';

/// **Quanto si puo' spendere adesso, che non e' per forza quanto si ha.**
///
/// Un premio pagato dalla carta di qualcun altro arriva subito sul conto Stripe
/// di chi ha vinto, ma "in arrivo": Stripe lo rende spendibile solo dopo aver
/// incassato quel pagamento. Il saldo del portafoglio lo conta gia', ed e'
/// giusto, perche' quei soldi sono suoi. Per pagare una missione pero' serve
/// quello che c'e' adesso: scrivere "esce subito" guardando solo il totale
/// voleva dire farsi dire di no un attimo dopo.
class SaldoSpendibile {
  const SaldoSpendibile({
    required this.spendibileCents,
    required this.inArrivoCents,
    this.inArrivoEntro,
  });

  final int spendibileCents;
  final int inArrivoCents;

  /// Entro quando e' spendibile tutto. Lo dice Stripe, quando lo dice.
  final DateTime? inArrivoEntro;

  bool basta(int premioCents) => spendibileCents >= premioCents;

  /// `entro il 5 novembre`, o `fra qualche giorno` se Stripe non l'ha detto.
  String get quando => switch (inArrivoEntro) {
    final data? => 'entro il ${AppDateUtils.formatDayMonth(data)}',
    null => 'fra qualche giorno',
  };

  /// Perche' il portafoglio non basta ancora, in una frase.
  String spiegaA(int saldoCents) {
    final saldo = AppMoney.format(saldoCents);

    return inArrivoCents > 0
        ? 'Hai $saldo, ma ${AppMoney.format(inArrivoCents)} sono ancora in '
              'arrivo: Stripe li rende spendibili $quando.'
        : 'Hai $saldo, ma adesso puoi spenderne '
              '${AppMoney.format(spendibileCents)}.';
  }
}
