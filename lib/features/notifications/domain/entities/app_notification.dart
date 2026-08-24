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

  /// Una gara a cui hai partecipato e' finita, e chi l'ha lanciata sta
  /// scegliendo.
  choosing,

  /// **Una gara tua e' finita e tocca a te scegliere.** Torna a farsi viva
  /// finche' non lo fai: vedi `notificationsProvider`.
  mustChoose,
}

/// In quale sezione della campanella finisce una notizia.
///
/// Le sezioni sono arrivate quando i tipi sono diventati sei: un elenco solo,
/// con dentro le fiamme, le gare e le amicizie mescolate in ordine di ora, non
/// si scorreva piu' — e la cosa che si stava cercando era sempre in mezzo a
/// tre che non c'entravano.
enum NotificationGroup {
  missions('MISSIONI'),
  fires('FIAMME');

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
    NotificationKind.win => 'Hai vinto',
    NotificationKind.choosing => '@$actorUsername sta scegliendo il vincitore',
    NotificationKind.mustChoose => 'Scegli chi ha vinto',
  };

  /// La sezione in cui finisce.
  ///
  /// **Le amicizie non hanno una sezione qui**, e non e' una dimenticanza: le
  /// richieste ricevute stanno gia' nella scheda Amici, con i due comandi per
  /// accettare o rifiutare. Ripeterle in campanella vuol dire farsi due elenchi
  /// della stessa cosa, e poi doverli tenere d'accordo.
  NotificationGroup get group => switch (kind) {
    NotificationKind.fire => NotificationGroup.fires,
    NotificationKind.participation ||
    NotificationKind.win ||
    NotificationKind.choosing ||
    NotificationKind.mustChoose ||
    NotificationKind.friendRequest => NotificationGroup.missions,
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
