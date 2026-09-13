/// A che punto sta una **sfida mirata**: Giovanni sfida Mario.
///
/// Una sfida mirata e' una missione come tutte le altre — stessa collezione,
/// stessa scheda, stesso modo di partecipare — con una riga in piu' dentro:
/// **ha un destinatario solo**, e quel destinatario deve rispondere.
///
/// **E' una questione d'onore, non un contatore.** Chi accetta si impegna a
/// portarla a termine, e il fatto che l'impegno sia preso in pubblico — lo
/// vedono tutti e due, nel party — e' l'unica cosa che lo fa valere. Per
/// questo gli stati sono pochi e chiari: chi guarda deve sapere in un colpo
/// d'occhio se la palla e' sua o dell'altro.
enum DuelStatus {
  /// Lanciata, e il destinatario non ha ancora risposto.
  pending('IN ATTESA', 'Aspetta una risposta'),

  /// Ha accettato: adesso deve farla.
  accepted('ACCETTATA', 'Ha dato la parola'),

  /// Ha detto di no. Resta scritto: una sfida rifiutata non sparisce, o
  /// rifiutare non costerebbe niente.
  declined('RIFIUTATA', 'Ha detto di no'),

  /// L'ha fatta: la foto e' in gara.
  completed('COMPLETATA', 'Portata a termine');

  const DuelStatus(this.label, this.spiegazione);

  /// Come si chiama sul distintivo.
  final String label;

  /// La riga sotto, per chi non l'ha mai vista.
  final String spiegazione;

  bool get isPending => this == DuelStatus.pending;

  bool get isAccepted => this == DuelStatus.accepted;

  bool get isDeclined => this == DuelStatus.declined;

  bool get isCompleted => this == DuelStatus.completed;

  /// Se qui c'e' ancora qualcosa da fare da parte di chi l'ha ricevuta.
  bool get isOpen => isPending || isAccepted;

  /// Come si legge dal database.
  ///
  /// Il ripiego e' [pending] e conta: una sfida scritta male, o scritta da una
  /// versione dell'app che non conosceva ancora questo campo, e' comunque una
  /// sfida a cui nessuno ha risposto. Il ripiego opposto — darla per accettata
  /// — metterebbe in bocca a qualcuno una parola che non ha dato.
  static DuelStatus fromName(String? value) {
    for (final status in DuelStatus.values) {
      if (status.name == value) {
        return status;
      }
    }

    return DuelStatus.pending;
  }
}

/// Lo stato **mostrato**, che include anche quello che l'orologio decide da
/// solo.
///
/// Scaduta non e' uno stato scritto sul database, ed e' voluto: dipende da che
/// ora e', e un campo che dipende dall'ora e' un campo che qualcuno dovrebbe
/// andare a riscrivere su ogni sfida del mondo a ogni minuto. Si calcola
/// guardando la scadenza della missione, come si fa gia' per tutte le altre.
enum DuelState {
  pending('IN ATTESA'),
  accepted('ACCETTATA'),
  declined('RIFIUTATA'),
  completed('COMPLETATA'),

  /// Il tempo e' finito e non l'ha fatta.
  expired('SCADUTA');

  const DuelState(this.label);

  final String label;

  /// Come si legge sul distintivo.
  ///
  /// **Il no si sente.** Rifiutare una sfida d'onore e' l'unica mossa che non
  /// costa niente a chi la fa: senza un segno che si vede, dire di no e non
  /// aver mai ricevuto niente hanno lo stesso aspetto, e la parola data smette
  /// di valere qualcosa. `BUUU` e' quel segno — il fischio del pubblico, che e'
  /// esattamente quanto deve costare: niente di piu' di una figuraccia fra
  /// amici, ma non zero.
  String get chipLabel => this == DuelState.declined ? 'BUUU' : label;

  /// La riga di commento sotto la sfida, quando c'e' qualcosa da fischiare.
  ///
  /// Nulla dove non serve: su una sfida in corso non si commenta niente.
  String? fischio({required bool mine, required String username}) {
    return switch (this) {
      DuelState.declined =>
        mine ? 'Hai detto di no. Buuu.' : '@$username ha detto di no. Buuu.',
      DuelState.expired =>
        mine
            ? 'Tempo scaduto, non l\'hai fatta. Buuu.'
            : '@$username non l\'ha fatta in tempo. Buuu.',
      _ => null,
    };
  }
}
