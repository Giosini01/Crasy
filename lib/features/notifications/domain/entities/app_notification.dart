/// Cosa e' successo, e chi l'ha fatto.
///
/// Le notifiche di CRASY sono **quattro**, e ognuna corrisponde a un momento in
/// cui qualcun altro ha fatto qualcosa che ti riguarda. Non ce ne sono di
/// automatiche — nessun "hai una nuova challenge da provare", nessun "e' da tre
/// giorni che non partecipi": quelle non sono notizie, sono richiami, e un'app
/// che li manda si spegne dalle impostazioni del telefono nel giro di una
/// settimana.
enum NotificationKind {
  /// Qualcuno ha mandato una foto alla challenge che hai lanciato.
  participation,

  /// **Un amico ti ha sfidato di persona.**
  ///
  /// E' l'unica notizia dell'app che chiede una risposta: le altre raccontano
  /// una cosa che e' successa, questa mette qualcuno ad aspettare. Senza,
  /// una sfida mirata non servirebbe a niente — chi la riceve non saprebbe
  /// nemmeno di essere stato chiamato in causa, e la sfida scadrebbe da sola
  /// dentro una scheda che nessuno ha motivo di aprire.
  duel,

  /// Ha accettato la sfida che gli hai lanciato.
  duelAccepted,

  /// Ha rifiutato la sfida che gli hai lanciato.
  duelDeclined,

  /// L'ha portata a termine: la foto e' in gara.
  duelCompleted,

  /// **Ha guardato la tua foto e ha detto che vale.** La sfida e' vinta.
  ///
  /// Su una sfida mirata non c'e' nessun conteggio di fiamme che chiuda la
  /// partita: a chiuderla e' una persona, e questa e' la notizia che lo dice a
  /// chi ha fatto il lavoro.
  duelApproved,

  /// Ha guardato la foto e ha detto che non e' quello che aveva chiesto.
  duelRejected,

  /// **Nessuno ha guardato la foto in tempo, e la sfida si e' chiusa cosi'.**
  ///
  /// La scrive il server, non un telefono, ed e' l'unica delle sfide che non
  /// ha un attore: non e' successo niente, e' proprio questo il punto. Senza,
  /// chi ha fatto la sfida vedrebbe la propria foto sparire dentro una gara
  /// chiusa senza vincitore e l'unica spiegazione possibile sarebbe che l'app
  /// se la sia mangiata.
  duelNoVerdict,

  /// **Un amico ha lanciato una missione per il gruppo.**
  ///
  /// E' l'unica notizia "c'e' una missione nuova" che resta, e la differenza
  /// con quelle tolte e' chi la riceve: gli annunci per ogni gara pubblica
  /// andavano a tutti — decine di telefoni che squillano per gare che non
  /// riguardano nessuno, finche' qualcuno spegne le notifiche e le spegne
  /// tutte. Questa va **solo ai destinatari di quella missione**, che sono gli
  /// amici di chi l'ha lanciata: la riguarda per definizione, ed e' privata.
  ///
  /// Senza, una missione di party non la vedeva nessuno: vive solo dentro la
  /// scheda Party, che non ha nessun motivo di essere aperta se non si sa che
  /// c'e' qualcosa dentro.
  partyMission,

  /// Qualcuno ha dato una fiamma alla tua foto.
  fire,

  /// Qualcuno ti ha chiesto l'amicizia.
  friendRequest,

  /// Hai vinto.
  win,

  /// Una gara a cui hai partecipato e' finita.
  ///
  /// Prima erano due — *sta scegliendo* e *scegli tu* — perche' il vincitore lo
  /// decideva chi aveva messo i soldi. Adesso decidono le fiamme e la gara si
  /// chiude appena finisce: resta una notizia sola, che serve a chi ha
  /// partecipato per sapere che e' il momento di andare a vedere com'e' andata.
  ended,

  /// Un richiamo per chi non si fa vedere da qualche giorno.
  ///
  /// **E' l'unica che non nasce da un fatto.** Tutte le altre raccontano
  /// qualcosa che e' successo a chi le riceve; questa la manda il server perche'
  /// fa comodo a noi. Per questo va spesa con parsimonia — e per questo esiste
  /// come tipo a se': mescolata alle altre non si distinguerebbe, e la prima
  /// cosa che si vorra' fare il giorno in cui da' fastidio e' poterla spegnere
  /// da sola.
  comeback,

  /// **La tua foto e' stata tolta dalla gara.**
  ///
  /// Prima non lo diceva nessuno: la foto spariva dalla griglia e basta. Chi
  /// l'aveva mandata restava dentro una gara con dei soldi in palio senza piu'
  /// esserci, e se ne accorgeva solo tornando a guardare — o non se ne
  /// accorgeva affatto, e continuava ad aspettare un risultato che non poteva
  /// arrivare.
  ///
  /// **Non dice chi l'ha segnalata, e non lo dira' mai.** Le segnalazioni sono
  /// anonime per costruzione: dirlo trasformerebbe una moderazione in una lite
  /// fra due persone, e la prossima segnalazione non la manderebbe piu'
  /// nessuno.
  removed,
}

/// In quale sezione della campanella finisce una notizia.
///
/// Le sezioni sono arrivate quando i tipi sono diventati sei: un elenco solo,
/// con dentro le fiamme, le gare e le amicizie mescolate in ordine di ora, non
/// si scorreva piu' — e la cosa che si stava cercando era sempre in mezzo a
/// tre che non c'entravano.
enum NotificationGroup {
  /// Hai vinto, o una gara a cui eri dentro si e' chiusa.
  wins('VITTORIE'),

  /// Qualcuno ha dato una fiamma alla tua foto.
  fires('LIKE'),

  /// Qualcuno e' entrato in una gara che hai lanciato tu.
  participations('PARTECIPAZIONI'),

  /// Le sfide mirate: quelle che ti hanno lanciato, e le risposte alle tue.
  ///
  /// **Una sezione sua, e non mescolata alle partecipazioni.** Una
  /// partecipazione e' una cosa da guardare; una sfida ricevuta e' una cosa a
  /// cui rispondere, e finisce in fondo all'elenco insieme a venti fiamme
  /// esattamente il giorno in cui serviva vederla.
  duels('SFIDE');

  const NotificationGroup(this.label);

  final String label;
}

/// Una riga della campanella.
///
/// Ne esistono di due specie, e la differenza non si vede a schermo ma conta:
///
/// - **scritte**: partecipazioni e fiamme. Le scrive chi le provoca, dentro le
///   notifiche di chi le riceve, perche' non c'e' modo di ricavarle dopo — chi
///   ha votato la tua foto e' un'informazione che nessuno puo' leggere, nemmeno
///   tu, ed e' voluto;
/// - **ricavate**: richieste di amicizia e vittorie. Non le scrive nessuno: si
///   leggono dai dati che gia' esistono. Una notifica scritta sarebbe una copia
///   che puo' andare fuori sincrono con la cosa che racconta.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    this.actorId = '',
    this.actorUsername = '',
    this.challengeId = '',
    this.challengeTitle = '',
    this.createdAt,
  });

  final String id;
  final NotificationKind kind;

  /// Chi l'ha provocata. Vuoto per le vittorie: non le provoca nessuno.
  final String actorId;
  final String actorUsername;

  /// La gara di cui si parla, per sapere dove portare chi tocca la riga.
  final String challengeId;
  final String challengeTitle;

  final DateTime? createdAt;

  /// Se e' arrivata dopo l'ultima volta che si e' aperta la campanella.
  ///
  /// Una notifica senza data conta come **non letta**: nel dubbio si fa vedere,
  /// che e' l'errore meno grave dei due.
  bool isUnreadSince(DateTime? seenAt) {
    if (seenAt == null || createdAt == null) {
      return true;
    }

    return createdAt!.isAfter(seenAt);
  }

  /// Cosa c'e' scritto nella riga.
  ///
  /// Il testo lo compone l'entita' e non la schermata: e' la stessa frase in
  /// tutti i posti in cui compare, e cambiarla vuol dire cambiarla una volta.
  String get message => switch (kind) {
    NotificationKind.participation =>
      '@$actorUsername ha partecipato alla tua challenge',
    NotificationKind.fire => '@$actorUsername ha dato una fiamma alla tua foto',
    NotificationKind.friendRequest =>
      '@$actorUsername ti ha chiesto l\'amicizia',
    NotificationKind.comeback => 'Ci sono missioni nuove che ti aspettano',
    NotificationKind.duel => '@$actorUsername ti ha sfidato',
    NotificationKind.duelAccepted =>
      '@$actorUsername ha accettato la tua sfida',
    NotificationKind.duelDeclined =>
      '@$actorUsername ha rifiutato la tua sfida',
    NotificationKind.duelCompleted =>
      '@$actorUsername ha portato a termine la tua sfida',
    NotificationKind.duelApproved =>
      '@$actorUsername dice che ce l\'hai fatta: sfida vinta',
    NotificationKind.duelRejected =>
      '@$actorUsername non ha giudicato valida la tua sfida',
    NotificationKind.duelNoVerdict =>
      'Nessuno ha giudicato la tua sfida in tempo',
    NotificationKind.partyMission =>
      '@$actorUsername ha lanciato una missione per il party',
    NotificationKind.win => 'Hai vinto',
    NotificationKind.ended => 'La missione è finita: guarda chi ha vinto',
    NotificationKind.removed => 'La tua foto è stata tolta dalla gara',
  };

  /// La sezione in cui finisce.
  ///
  /// **Le amicizie non hanno una sezione qui**, e non e' una dimenticanza: le
  /// richieste ricevute stanno gia' nella scheda Amici, con i due comandi per
  /// accettare o rifiutare. Ripeterle in campanella vuol dire farsi due elenchi
  /// della stessa cosa, e poi doverli tenere d'accordo.
  /// In quale delle quattro finisce.
  ///
  /// **La gara finita sta con le vittorie**, e non e' una forzatura: quella
  /// notizia serve a una cosa sola — andare a vedere chi ha vinto — quindi
  /// arriva dove uno andrebbe a cercarla.
  ///
  /// Le richieste di amicizia non hanno una sezione loro perche' **non
  /// compaiono qui**: stanno nella scheda Amici, con i due comandi per
  /// accettare o rifiutare. Il ramo resta perche' il tipo esiste ancora, non
  /// perche' ci arrivi qualcosa.
  NotificationGroup get group => switch (kind) {
    NotificationKind.fire => NotificationGroup.fires,
    NotificationKind.duel ||
    NotificationKind.duelAccepted ||
    NotificationKind.duelDeclined ||
    NotificationKind.duelCompleted ||
    NotificationKind.duelApproved ||
    NotificationKind.duelRejected ||
    NotificationKind.duelNoVerdict ||
    NotificationKind.partyMission => NotificationGroup.duels,
    NotificationKind.win ||
    NotificationKind.ended ||
    NotificationKind.comeback => NotificationGroup.wins,
    NotificationKind.participation ||
    NotificationKind.friendRequest ||
    // **Sta con le partecipazioni, non con le vittorie.** E' la propria
    // partecipazione che non c'e' piu': trovarla sotto l'insegna VITTORIE
    // sarebbe la cosa piu' stonata della campanella.
    NotificationKind.removed => NotificationGroup.participations,
  };

  static NotificationKind kindFromName(String? value) {
    for (final kind in NotificationKind.values) {
      if (kind.name == value) {
        return kind;
      }
    }

    return NotificationKind.fire;
  }
}
