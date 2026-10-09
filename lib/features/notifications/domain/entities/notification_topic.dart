import 'package:crasy/features/notifications/domain/entities/app_notification.dart';

/// **Un interruttore delle notifiche.**
///
/// ## Perche' otto e non venti
///
/// I tipi di notifica sono venti, e un interruttore per ognuno sarebbe un
/// pannello di controllo. Un pannello di controllo non lo configura nessuno: si
/// scorre, si chiude, e chi era infastidito finisce per spegnere tutto dalle
/// impostazioni del telefono — che e' l'unica strada da cui non si torna
/// indietro, perche' il sistema non ripropone quella domanda a chi ha gia'
/// risposto di no.
///
/// Gli argomenti invece sono otto e si leggono in un colpo d'occhio, e ognuno
/// risponde a una frase che qualcuno potrebbe dire davvero: *le fiamme non mi
/// interessano*, *i commenti si', le sfide no*.
///
/// ## Cosa non si spegne
///
/// [NotificationKind.removed] non ha un argomento, e quindi non ha un
/// interruttore. Dice che una propria foto e' stata tolta da una gara con dei
/// soldi in palio: poterla zittire vorrebbe dire poter restare dentro una gara
/// in cui non si e' piu' in corsa senza saperlo. Non e' una notizia che si
/// scegli di ricevere, e' la conseguenza di una decisione che ci riguarda.
///
/// ## Dove vive la scelta
///
/// In `users/{uid}/private/notifiche`, un documento per persona con un
/// interruttore per campo. **Nella stanza privata e non sul profilo**: il
/// profilo lo legge chiunque apra la pagina di una persona, e sapere che
/// qualcuno ha spento le fiamme non e' un'informazione che riguarda gli altri.
///
/// Il filtro lo applica **il server**, prima di mandare (vedi `vuoleSentire` in
/// `functions/index.js`). Applicarlo sul telefono vorrebbe dire una notifica
/// che arriva, squilla, e viene nascosta dopo: il telefono ha squillato
/// comunque, e la scelta non e' stata rispettata.
///
/// In campanella si continua a trovare **tutto**, anche quello che si e'
/// spento. L'interruttore dice "non farmi squillare il telefono", non "non
/// farmi sapere": una vittoria che non compare nemmeno dentro l'app perche' sei
/// mesi prima qualcuno aveva toccato un interruttore e' un errore da cui nessuno
/// si riprende da solo.
enum NotificationTopic {
  vittorie(
    'Vittorie e premi',
    'Quando vinci, quando una gara si chiude, quando tocca a te scegliere chi '
        'ha vinto.',
    {
      NotificationKind.win,
      NotificationKind.ended,
      NotificationKind.soloJudge,
      NotificationKind.pickWinner,
    },
  ),
  sfide(
    'Sfide',
    'Quando un amico ti sfida di persona, e quando risponde a una tua sfida.',
    {
      NotificationKind.duel,
      NotificationKind.duelAccepted,
      NotificationKind.duelDeclined,
      NotificationKind.duelCompleted,
      NotificationKind.duelApproved,
      NotificationKind.duelRejected,
      NotificationKind.duelNoVerdict,
      NotificationKind.partyMission,
    },
  ),
  rivali(
    'Chi prova a batterti',
    'Quando scende in gara un\'altra persona in una missione in cui ci sei '
        'anche tu.',
    {NotificationKind.rival},
  ),
  partecipazioni(
    'Chi entra nelle tue missioni',
    'Quando qualcuno manda una foto a una missione che hai lanciato tu.',
    {NotificationKind.participation},
  ),
  fiamme('Fiamme', 'Quando qualcuno mette una fiamma su una tua foto.', {
    NotificationKind.fire,
  }),
  commenti(
    'Commenti',
    'Quando scrivono sotto una tua foto, o ti nominano in un commento.',
    {NotificationKind.comment, NotificationKind.mention},
  ),
  amicizie('Chi inizia a seguirti', 'Quando una persona nuova ti segue.', {
    NotificationKind.friendRequest,
  }),
  promemoria(
    'Missioni aperte',
    'Un promemoria quando ci sono gare aperte e non stai partecipando.',
    {NotificationKind.comeback},
  );

  const NotificationTopic(this.label, this.note, this.kinds);

  final String label;

  /// La riga sotto il nome: dice **quali notifiche sparirebbero**.
  ///
  /// Serve perche' "Sfide" da solo non fa capire se dentro ci sono anche le
  /// risposte alle proprie sfide, e un interruttore di cui non si sa cosa
  /// spegne non lo tocca nessuno.
  final String note;

  final Set<NotificationKind> kinds;

  /// Sotto quale interruttore sta questo tipo, se ce n'e' uno.
  ///
  /// `null` vuol dire una notifica che non si spegne.
  static NotificationTopic? of(NotificationKind kind) {
    for (final topic in values) {
      if (topic.kinds.contains(kind)) {
        return topic;
      }
    }

    return null;
  }
}

/// Quali notifiche vuole ricevere una persona sul telefono.
///
/// **Si tiene l'elenco di quelle spente, non di quelle accese**, e la
/// differenza conta: un argomento che non c'e' scritto da nessuna parte e'
/// acceso. Cosi' un documento vuoto — cioe' quello di tutti, oggi — vuol dire
/// "manda tutto", e un argomento nuovo aggiunto domani parte accesso per tutti
/// senza bisogno di andare a riscrivere venticinque documenti.
class NotificationPrefs {
  const NotificationPrefs({this.spente = const {}});

  /// Quello che si legge da un documento che non esiste: tutto accesso.
  static const NotificationPrefs tutte = NotificationPrefs();

  final Set<NotificationTopic> spente;

  bool vuole(NotificationTopic topic) => !spente.contains(topic);

  /// Quanti argomenti sono spenti: serve alla riga che lo riassume.
  int get quanteSpente => spente.length;

  NotificationPrefs con(NotificationTopic topic, {required bool accesa}) {
    final nuove = {...spente};

    if (accesa) {
      nuove.remove(topic);
    } else {
      nuove.add(topic);
    }

    return NotificationPrefs(spente: nuove);
  }

  /// Come si scrive nel documento: **tutti** gli argomenti, uno per campo.
  ///
  /// Si scrivono anche quelli accesi, con `true`, invece di cancellare il
  /// campo: un documento che elenca tutto e' leggibile da chi ci mette gli
  /// occhi sopra per capire perche' una notifica non e' arrivata, e un
  /// documento con tre campi su otto non lo e'.
  Map<String, Object?> toMap() => {
    for (final topic in NotificationTopic.values) topic.name: vuole(topic),
  };

  static NotificationPrefs fromMap(Map<String, Object?>? dati) {
    if (dati == null) {
      return tutte;
    }

    return NotificationPrefs(
      spente: {
        for (final topic in NotificationTopic.values)
          if (dati[topic.name] == false) topic,
      },
    );
  }
}
