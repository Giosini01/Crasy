/// Dove sono i soldi di una challenge, in questo momento.
///
/// E' il campo che regge la promessa dell'app. Senza di esso una challenge da
/// cinquecento euro e una challenge da cinquecento euro **finti** sono lo stesso
/// documento, e chi esce di casa per fare una foto assurda non ha modo di
/// distinguerle. Con dei soldi in palio la seconda truffa e' quella che chiude
/// l'app: la voce gira, e l'unica cosa che CRASY promette e' che i soldi ci
/// siano davvero.
///
/// Lo stato lo scrive **solo il server**. Il telefono puo' creare una challenge
/// solo in [unpaid], e le regole di Firestore lo impongono: se il client
/// potesse scrivere [held], scrivere "pagata" e non pagare sarebbe questione di
/// dieci righe di codice.
enum PrizeStatus {
  /// Creata, non pagata. **Non si vede da nessuna parte.**
  ///
  /// E' lo stato in cui nasce ogni challenge e in cui restano quelle il cui
  /// pagamento non e' mai andato a buon fine — la carta rifiutata, la pagina di
  /// pagamento chiusa a meta'. Non e' un errore da mostrare: e' una challenge
  /// che non e' mai esistita.
  unpaid,

  /// Pagata: i soldi sono su CRASY e ci restano fino alla fine.
  ///
  /// **Questo e' l'unico stato in cui una challenge si vede.** Chi la legge in
  /// home sa che quei soldi sono gia' stati tolti a qualcuno, e che nessuno se
  /// li puo' riprendere prima che la gara finisca.
  held,

  /// Chiusa e pagata al vincitore, meno la percentuale di CRASY.
  paidOut,

  /// Rimborsata a chi l'aveva lanciata.
  ///
  /// Succede quando non partecipa nessuno. Non c'e' nessuno a cui dare i soldi,
  /// e tenerli sarebbe rubare: tornano indietro interi.
  refunded;

  /// Se una challenge in questo stato si puo' mostrare.
  bool get isVisible => this == held || this == paidOut;

  /// Se i soldi sono ancora fermi su CRASY.
  bool get isEscrowed => this == held;

  static PrizeStatus fromName(String? value) {
    for (final status in PrizeStatus.values) {
      if (status.name == value) {
        return status;
      }
    }

    // Le challenge scritte prima che il pagamento esistesse non sono mai state
    // pagate, e vanno lette per quello che sono. Con i pagamenti accesi
    // spariscono dalla home — ed e' giusto: nessuno ha mai messo quei soldi.
    return PrizeStatus.unpaid;
  }
}

/// Se il giro dei pagamenti e' acceso.
///
/// **Adesso e' spento, e va detto invece che nascosto.** Il denaro si muove
/// dentro le Cloud Function, che richiedono il piano a consumo su Firebase, e
/// passa da Stripe, che richiede un account e una partita IVA. Finche' quelle
/// due cose non esistono, accendere questo interruttore renderebbe **invisibile
/// ogni challenge dell'app**: nascono tutte non pagate, e non c'e' niente che
/// possa pagarle.
///
/// Con l'interruttore spento CRASY si comporta come si e' sempre comportata: il
/// premio e' un patto fra chi lo mette e chi partecipa, e la schermata di
/// creazione lo dice apertamente. Acceso, il premio si paga prima e la
/// challenge si pubblica dopo.
///
///     flutter run --dart-define=CRASY_PAYMENTS=true
const bool paymentsEnabled = bool.fromEnvironment('CRASY_PAYMENTS');
