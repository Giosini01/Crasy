abstract final class AppRoutes {
  static const splash = '/';
  static const auth = '/auth';

  /// Il muro della conferma dell'email: si sta qui finche' non e' confermata.
  static const verifyEmail = '/verifica-email';

  /// Il muro del numero di telefono: **un account per persona**.
  static const verifyPhone = '/verifica-telefono';

  static const onboarding = '/onboarding';

  /// Dove porta il link dentro un nostro messaggio.
  ///
  /// **E' l'unica rotta che non chiede niente a nessuno.** Ci si arriva dal
  /// browser, con in mano un codice e nessuna sessione: fermare chi arriva qui
  /// davanti al muro della conferma vorrebbe dire lasciarcelo per sempre,
  /// perche' il codice che apre quel muro e' proprio quello che non gli
  /// abbiamo lasciato consegnare.
  static const emailAction = '/conferma';

  /// **Dove atterra un link condiviso da dentro CRASY.**
  ///
  /// `https://crasyapp.com/foto?g=<gara>&f=<foto>`: e' l'indirizzo che si manda
  /// su WhatsApp, e sul telefono lo apre l'app invece del browser — come fa
  /// TikTok. Chi l'app non ce l'ha resta sul sito, che quella foto la mostra
  /// lo stesso e offre gli store.
  ///
  /// **E' l'unico indirizzo di crasyapp.com che appartiene all'app.** La
  /// vetrina, l'informativa e il resto restano un sito: sta scritto nei due
  /// file di associazione, non qui.
  static const sharedEntry = '/foto';

  /// I consensi: cosa accetti prima di entrare.
  static const consents = '/consensi';

  /// Le quattro regole del gioco, una volta sola.
  static const tutorial = '/come-funziona';

  // --- Le tre schede ---------------------------------------------------------

  /// La home: le challenge aperte.
  static const challenges = '/challenges';

  /// Gli amici: le richieste da decidere e chi hai gia'.
  static const friends = '/amici';

  /// Cosa stanno combinando: le loro missioni, le loro foto in gara.
  static const friendsActivity = '/amici/attivita';

  /// I vincitori delle challenge concluse.
  static const winners = '/winners';

  static const profile = '/profile';

  // --- Le pagine che si aprono sopra le schede ------------------------------

  static const challengeDetail = '/challenge/:id';

  /// La campanella: cosa hanno fatto gli altri.
  static const notifications = '/notifiche';

  /// La lente: si cerca una challenge o una persona.
  ///
  /// E' una scheda in fondo, non una pagina che si apre: sta fra gli amici e i
  /// vincitori, che e' il posto in cui il pollice la cerca senza guardare.
  static const search = '/cerca';
  static const userProfile = '/utente/:id';
  static const participate = '/challenge/:id/partecipa';
  static const create = '/crea';

  /// Il modulo per una missione riservata agli amici.
  ///
  /// **E' una rotta sua e non un parametro**, perche' e' una schermata diversa:
  /// il premio si sceglie fra gratis e almeno un euro, e il campo di gara non
  /// si sceglie affatto.
  static const createForFriends = '/crea/amici';

  static String challengeDetailOf(String id) => '/challenge/$id';

  static String userProfileOf(String id) => '/utente/$id';

  static String participateOf(String id) => '/challenge/$id/partecipa';

  /// Le schede in fondo, nell'ordine in cui compaiono.
  /// Le schede in fondo.
  ///
  /// Al secondo posto ci sono di nuovo gli amici, ma **non e' l'elenco che
  /// c'era prima**: e' quello che stanno facendo. La differenza e' tutta li'.
  /// Un elenco di nomi si guarda ogni tanto e non merita un posto nella barra;
  /// le gare che hanno lanciato e le foto con cui sono in gara adesso cambiano
  /// ogni giorno, e sono il motivo per riaprire l'app.
  ///
  /// L'elenco vero — le richieste da accettare, chi hai gia' — sta dietro
  /// [friends], che si apre da qui e dal numero sul profilo.
  static const tabs = <String>[
    challenges,
    friendsActivity,
    search,
    winners,
    profile,
  ];

  /// Le sole schermate raggiungibili senza una sessione completa.
  ///
  /// **Non si guarda niente senza aver fatto l'accesso.** Non e' una scelta di
  /// prodotto ma una conseguenza di cosa e' CRASY: qui girano soldi veri, si
  /// vota chi li vince, e si entra da maggiorenni. Nessuna di queste tre cose
  /// regge se chi guarda non ha un nome e un indirizzo confermato.
  ///
  /// Le foto che la gente manda sono di persone vere che si mettono in gioco:
  /// non stanno in una vetrina aperta a chiunque passi.
  static const openToEveryone = <String>{splash, auth};
}
