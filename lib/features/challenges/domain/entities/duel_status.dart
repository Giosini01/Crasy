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

/// Cosa ha detto chi ha lanciato la sfida, guardando la foto.
///
/// **Serve perche' una sfida mirata ha un partecipante solo.** Con una persona
/// in gara, il conteggio delle fiamme che decide tutte le altre gare qui non
/// decide niente: chiunque mandi qualcosa vince, e "qualcosa" puo' essere un
/// video nero. La sfida era "balla in mezzo a Napoli", il video e' buio, e il
/// sistema proclamerebbe un vincitore che non ha ballato.
///
/// Allora a guardarla e' chi l'ha lanciata. **E' un giudizio in buona fede, non
/// un arbitro**: non c'e' niente qui dentro che possa costringere una persona a
/// essere onesta, ed e' la stessa scommessa su cui sta in piedi tutto il resto
/// della sfida — chi accetta si impegna sulla parola, chi giudica risponde
/// della sua. Con la differenza che tutti e due sanno chi e' l'altro, e la
/// figuraccia la si fa davanti a un amico e non davanti a uno sconosciuto.
///
/// Il verdetto **chiude la sfida nel momento in cui arriva**: se Ciccio la fa e
/// va bene, non c'e' niente da aspettare fino a domani.
enum DuelVerdict {
  /// Nessuno ha ancora guardato. E' anche il ripiego di tutto quello che non
  /// si sa leggere: un verdetto che non si capisce non e' un verdetto.
  none(''),

  /// L'ha fatta, e vale. La sfida si chiude con lei che vince.
  approved('approved'),

  /// L'ha mandata, ma non e' quello che era stato chiesto.
  rejected('rejected'),

  /// Nessuno l'ha guardata in tempo, e ha deciso l'orologio: la sfida si
  /// chiude senza vincitore.
  ///
  /// **Non e' una bocciatura.** E' il silenzio di chi ha lanciato la sfida, e
  /// va scritto in un modo che si distingua da un "non vale" — perche' la
  /// colpa non e' di chi ha fatto la foto.
  expired('expired');

  const DuelVerdict(this.wire);

  /// Come si scrive sul database. Vuoto vuol dire "non c'e'", e infatti il
  /// campo sulle sfide non giudicate non esiste proprio.
  final String wire;

  bool get isGiven => this != DuelVerdict.none;

  bool get isApproved => this == DuelVerdict.approved;

  static DuelVerdict fromName(String? value) {
    if (value == null || value.isEmpty) {
      return DuelVerdict.none;
    }

    for (final verdict in DuelVerdict.values) {
      if (verdict.wire == value) {
        return verdict;
      }
    }

    return DuelVerdict.none;
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

  /// L'ha fatta, e adesso tocca a chi l'ha lanciata dire se va bene.
  ///
  /// **E' lo stato che prima non esisteva**, e la sua mancanza era il buco: la
  /// foto arrivava e la sfida era vinta, chiunque fosse quello che c'era dentro
  /// la foto.
  judging('DA GIUDICARE'),

  /// Fatta, guardata, e va bene.
  completed('VINTA'),

  /// Fatta, guardata, e non era quello che era stato chiesto.
  notValid('NON VALIDA'),

  /// Fatta, e nessuno l'ha guardata in tempo.
  noVerdict('SENZA GIUDIZIO'),

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

  /// Se qui la sfida e' finita e non c'e' piu' niente da fare.
  bool get isOver =>
      this == DuelState.completed ||
      this == DuelState.notValid ||
      this == DuelState.noVerdict ||
      this == DuelState.declined ||
      this == DuelState.expired;

  /// La riga di commento sotto la sfida, quando c'e' qualcosa da fischiare.
  ///
  /// Nulla dove non serve: su una sfida in corso non si commenta niente.
  ///
  /// [mine] vuol dire "la sfida l'ho ricevuta io", e [username] e' sempre
  /// **l'altra persona**: la stessa riga si legge dalle due parti, e dire
  /// "hai detto di no" a chi ha detto di no e "@mario ha detto di no" a chi se
  /// l'e' sentito dire e' la stessa frase vista dai due lati.
  String? fischio({required bool mine, required String username}) {
    return switch (this) {
      DuelState.declined =>
        mine ? 'Hai detto di no. Buuu.' : '@$username ha detto di no. Buuu.',
      DuelState.expired =>
        mine
            ? 'Tempo scaduto, non l\'hai fatta. Buuu.'
            : '@$username non l\'ha fatta in tempo. Buuu.',
      // **Non e' lo stesso fischio del rifiuto.** Qui la sfida l'ha fatta: il
      // no e' arrivato dopo, da chi l'ha lanciata, e va scritto come tale — o
      // sembra che sia stata lei a tirarsi indietro.
      DuelState.notValid =>
        mine
            ? 'Non e\' stata giudicata valida. Buuu.'
            : 'L\'hai giudicata non valida.',
      _ => null,
    };
  }

  /// La riga di servizio: cosa sta succedendo, e di chi e' il turno.
  ///
  /// Separata dal fischio perche' non e' una presa in giro di nessuno: dice
  /// solo chi sta aspettando cosa.
  String? nota({required bool mine, required String username}) {
    return switch (this) {
      DuelState.judging =>
        mine
            ? 'L\'hai fatta. Aspetta il giudizio di @$username.'
            : '@$username l\'ha fatta: tocca a te dire se va bene.',
      DuelState.noVerdict =>
        mine
            ? 'Nessuno l\'ha giudicata in tempo. Non e\' colpa tua.'
            : 'Non l\'hai giudicata in tempo: si e\' chiusa senza vincitore.',
      _ => null,
    };
  }
}
