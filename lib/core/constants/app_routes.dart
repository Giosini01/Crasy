abstract final class AppRoutes {
  static const splash = '/';
  static const auth = '/auth';

  /// Il muro della conferma dell'email: si sta qui finche' non e' confermata.
  static const verifyEmail = '/verifica-email';

  static const onboarding = '/onboarding';

  // --- Le tre schede ---------------------------------------------------------

  /// La home: le challenge aperte.
  static const challenges = '/challenges';

  /// Gli amici: le richieste da decidere e chi hai gia'.
  static const friends = '/amici';

  /// I vincitori delle challenge concluse.
  static const winners = '/winners';

  static const profile = '/profile';

  // --- Le pagine che si aprono sopra le schede ------------------------------

  static const challengeDetail = '/challenge/:id';
  static const userProfile = '/utente/:id';
  static const participate = '/challenge/:id/partecipa';
  static const create = '/crea';

  static String challengeDetailOf(String id) => '/challenge/$id';

  static String userProfileOf(String id) => '/utente/$id';

  static String participateOf(String id) => '/challenge/$id/partecipa';

  /// Le schede in fondo, nell'ordine in cui compaiono.
  static const tabs = <String>[challenges, friends, winners, profile];

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
