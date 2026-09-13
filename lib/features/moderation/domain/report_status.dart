/// A che punto e' una segnalazione.
///
/// **Le segnalazioni non si risolvono da sole.** C'era una soglia — tre
/// segnalazioni e la foto spariva a tutti, trenta e il server la buttava fuori
/// dalla gara — e decideva al posto di una persona: tre account bastavano a
/// far sparire la foto di un rivale il giorno prima che vincesse un premio, e
/// a rimetterla dentro non ci pensava nessuno perche' nessuno sapeva che fosse
/// successo.
///
/// Adesso una segnalazione fa due cose e basta: toglie la foto **dagli occhi
/// di chi l'ha segnalata**, e la mette sul tavolo dell'amministratore. Questi
/// quattro stati sono quel tavolo — dove sta ogni cosa, e cosa e' stato
/// deciso. Chi decide e' una persona, anche davanti a una segnalazione sola.
///
/// Lo stato lo scrive **solo il server**, con l'SDK di amministrazione: le
/// regole di Firestore non lasciano a nessun telefono il permesso di
/// aggiornare una segnalazione, nemmeno la propria. Vedi `adminResolveReport`
/// in `functions/index.js`.
enum ReportStatus {
  /// Arrivata, nessuno l'ha ancora guardata.
  fresh('new', 'Nuova'),

  /// Qualcuno l'ha presa in mano e non ha ancora deciso.
  reviewing('reviewing', 'In revisione'),

  /// Guardata, e non c'era niente: la foto resta online.
  fake('fake', 'Fake segnalazione'),

  /// Guardata, e la foto e' stata tolta dalla gara.
  removed('removed', 'Foto rimossa');

  const ReportStatus(this.wire, this.label);

  /// Come si scrive sul database.
  ///
  /// Separato dal nome Dart perche' i due non coincidono: `new` e' una parola
  /// riservata in Dart e non puo' essere il nome di una costante, ma e' il
  /// valore piu' chiaro da leggere aprendo il database.
  final String wire;

  /// Come si legge nella dashboard.
  final String label;

  /// Se c'e' ancora una decisione da prendere.
  bool get isOpen => this == ReportStatus.fresh || this == ReportStatus.reviewing;

  /// Come si legge dal database.
  ///
  /// **`open` e' il valore vecchio**, quello che scrivevano tutte le
  /// segnalazioni fino a oggi: si legge come [fresh], perche' e' esattamente
  /// quello che vuol dire — arrivata e non ancora guardata. Senza questa riga
  /// le segnalazioni gia' in archivio sparirebbero dalla dashboard il giorno
  /// in cui la dashboard esiste, che e' il contrario di cio' che deve fare.
  static ReportStatus fromWire(String? value) {
    if (value == 'open' || value == null || value.isEmpty) {
      return ReportStatus.fresh;
    }

    for (final status in ReportStatus.values) {
      if (status.wire == value) {
        return status;
      }
    }

    return ReportStatus.fresh;
  }
}
