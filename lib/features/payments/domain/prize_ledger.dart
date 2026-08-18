/// I conti di un premio: chi paga quanto, e chi incassa quanto.
///
/// Sta qui e non dentro una schermata, e nemmeno solo dentro il server, per una
/// ragione sola: **i numeri che l'utente legge prima di pagare devono essere gli
/// stessi che il server addebita**. Se la schermata dicesse 507,75 e Stripe
/// prendesse 508,10, quella differenza di trentacinque centesimi varrebbe piu'
/// danni di quanto valga: e' esattamente il tipo di dettaglio su cui si perde la
/// fiducia in un'app che maneggia soldi.
///
/// Il server rifa' gli stessi conti con le stesse costanti (`functions/`), e non
/// si fida di nessun importo che arrivi dal telefono: qui si calcola per
/// **mostrare**, li' per **addebitare**.
///
/// Tutto in centesimi e tutto in interi. Un premio tenuto in virgola mobile
/// prima o poi diventa `499.99999`, ed e' il numero piu' letto dell'app.
abstract final class PrizeLedger {
  /// Quanto trattiene CRASY, in decimillesimi: 1000 = 10%.
  ///
  /// E' la percentuale con cui l'app sta in piedi, ed e' bassa di proposito.
  /// Chi lancia le prime challenge e' la persona di cui c'e' piu' bisogno, e a
  /// lui si chiede gia' la cosa piu' difficile: tirare fuori dei soldi veri per
  /// una app che non conosce.
  static const int commissionBasisPoints = 1000;

  /// La percentuale che si tiene Stripe su ogni pagamento con carta europea.
  static const int processingBasisPoints = 150;

  /// La parte fissa di Stripe, in centesimi.
  static const int processingFixedCents = 25;

  /// Quanto trattiene CRASY su un premio.
  ///
  /// Arrotondato **per difetto**, sempre. Sono centesimi, e la direzione in cui
  /// si arrotonda vale piu' del centesimo: quando il conto non torna esatto, a
  /// guadagnarci e' chi ha vinto, non chi tiene la cassa.
  static int commissionCents(int prizeCents) {
    if (prizeCents <= 0) {
      return 0;
    }

    return (prizeCents * commissionBasisPoints) ~/ 10000;
  }

  /// Quanto arriva al vincitore: il premio meno la percentuale.
  static int payoutCents(int prizeCents) {
    if (prizeCents <= 0) {
      return 0;
    }

    return prizeCents - commissionCents(prizeCents);
  }

  /// Quanto paga davvero chi lancia la challenge.
  ///
  /// Le commissioni di Stripe le paga lui, **in aggiunta** al premio: mette 500
  /// e ne paga 507,75. La ragione non e' contabile ma di prodotto — cosi' il
  /// numero grande scritto in home e' vero. Scalandole dal premio, una
  /// challenge da 500 ne pagherebbe 442, e sarebbe di nuovo un premio annunciato
  /// diverso da quello che arriva: la cosa che con l'escrow stiamo cercando di
  /// togliere.
  ///
  /// Il conto e' meno ovvio di quanto sembri, perche' Stripe prende la sua
  /// percentuale **sull'importo addebitato**, che include la commissione
  /// stessa. Aggiungere l'1,5% del premio non basterebbe: mancherebbe l'1,5%
  /// dell'1,5%. Si risolve al contrario — si cerca l'addebito il cui netto e'
  /// esattamente il premio:
  ///
  ///     addebito = (premio + parte fissa) / (1 - percentuale)
  ///
  /// Arrotondato **per eccesso**: un centesimo in meno e il netto scenderebbe
  /// sotto il premio, e a pagarlo sarebbe il vincitore.
  static int chargeCents(int prizeCents) {
    if (prizeCents <= 0) {
      return 0;
    }

    final numerator = (prizeCents + processingFixedCents) * 10000;
    final denominator = 10000 - processingBasisPoints;

    return _ceilDivide(numerator, denominator);
  }

  /// Quanto si tiene Stripe sull'addebito: la differenza fra quello che paga il
  /// creatore e il premio che resta a CRASY.
  static int processingFeeCents(int prizeCents) =>
      chargeCents(prizeCents) - prizeCents;

  static int _ceilDivide(int numerator, int denominator) {
    return (numerator + denominator - 1) ~/ denominator;
  }
}
