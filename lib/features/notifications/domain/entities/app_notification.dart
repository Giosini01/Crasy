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

  /// Qualcuno ha dato una fiamma alla tua foto.
  fire,

  /// Qualcuno ti ha chiesto l'amicizia.
  friendRequest,

  /// Hai vinto.
  win,

  /// Qualcuno ha commentato la tua foto.
  ///
  /// Diversa dalla nomina: li' qualcuno ti **chiama** in una gara qualunque,
  /// qui qualcuno ha detto qualcosa **sotto la roba tua**. Sono due cose che
  /// capitano a persone diverse e per motivi diversi, e schiacciarle sulla
  /// stessa riga vorrebbe dire non far capire a nessuno dei due cos'e'
  /// successo.
  comment,

  /// Qualcuno ti ha nominato in un commento sotto una foto.
  ///
  /// **Senza questa notizia il tag non servirebbe a niente.** Un commento sotto
  /// la foto di una gara a cui non partecipi non lo va a leggere nessuno: chi
  /// nomina qualcuno lo fa per chiamarlo, e chiamare senza far squillare non e'
  /// chiamare.
  mention,

  /// Una gara a cui hai partecipato e' finita.
  ///
  /// Prima erano due — *sta scegliendo* e *scegli tu* — perche' il vincitore lo
  /// decideva chi aveva messo i soldi. Adesso decidono le fiamme e la gara si
  /// chiude appena finisce: resta una notizia sola, che serve a chi ha
  /// partecipato per sapere che e' il momento di andare a vedere com'e' andata.
  ended,

  /// Un tuo amico ha lanciato una missione.
  ///
  /// **La scrive il server, non l'app**, e non e' un dettaglio tecnico: per
  /// avvisare venti amici bisogna sapere chi sono e scrivere nella casella di
  /// ognuno, e il telefono di chi lancia la gara non ha — giustamente — il
  /// permesso di scrivere nelle caselle altrui. Se ce l'avesse, chiunque
  /// potrebbe riempire di notifiche chiunque.
  friendChallenge,

  /// Un tuo amico e' sceso in gara con una foto.
  friendEntry,
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

  /// Qualcuno ha scritto sotto la tua foto, o ti ha nominato.
  comments('COMMENTI'),

  /// Cosa stanno facendo i tuoi amici: gare lanciate e foto mandate.
  ///
  /// **Sta in una sezione sua, e serve che ci stia.** Le altre quattro
  /// riguardano roba tua — la tua foto, la tua gara, il tuo nome — e arrivano
  /// poche volte al giorno. Questa riguarda gli altri e arriva molte volte di
  /// piu': mescolata alle altre le sommergerebbe, e la notizia che hai vinto
  /// finirebbe sotto sei righe di gente che ha partecipato a qualcosa.
  friends('AMICI');

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
    NotificationKind.mention => '@$actorUsername ti ha nominato in un commento',
    NotificationKind.friendRequest =>
      '@$actorUsername ti ha chiesto l\'amicizia',
    NotificationKind.friendChallenge =>
      // Il premio sta nel titolo della gara quando c'e': la riga dice cosa e'
      // successo, il premio si legge aprendola.
      '@$actorUsername ha lanciato una missione',
    NotificationKind.friendEntry => '@$actorUsername e\' sceso in gara',
    NotificationKind.win => 'Hai vinto',
    NotificationKind.ended => 'La missione e\' finita: guarda chi ha vinto',
    NotificationKind.comment => '@\$actorUsername ha commentato la tua foto',
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
    NotificationKind.comment ||
    NotificationKind.mention => NotificationGroup.comments,
    NotificationKind.win || NotificationKind.ended => NotificationGroup.wins,
    NotificationKind.participation ||
    NotificationKind.friendRequest => NotificationGroup.participations,
    NotificationKind.friendChallenge ||
    NotificationKind.friendEntry => NotificationGroup.friends,
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
