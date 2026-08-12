abstract final class AppRoutes {
  static const splash = '/';
  static const auth = '/auth';
  static const onboarding = '/onboarding';

  // --- Le quattro schede ----------------------------------------------------

  /// La home: le challenge aperte.
  static const challenges = '/challenges';

  /// Il feed: cosa hanno mandato gli altri.
  static const feed = '/feed';

  /// I vincitori delle challenge concluse.
  static const winners = '/winners';

  static const profile = '/profile';

  // --- Le pagine che si aprono sopra le schede ------------------------------

  static const challengeDetail = '/challenge/:id';
  static const participate = '/challenge/:id/partecipa';
  static const create = '/crea';

  static String challengeDetailOf(String id) => '/challenge/$id';

  static String participateOf(String id) => '/challenge/$id/partecipa';

  /// Le quattro schede in fondo, nell'ordine in cui compaiono.
  static const tabs = <String>[challenges, feed, winners, profile];

  /// Le sezioni che si possono guardare senza aver fatto l'accesso.
  ///
  /// Le challenge e il feed sono aperti a tutti di proposito: chi apre CRASY
  /// per la prima volta deve **vedere** cosa c'e' in palio prima che gli venga
  /// chiesto qualcosa. La registrazione arriva al primo gesto che lascia una
  /// traccia — partecipare, votare, avere un profilo.
  static const guestAllowed = <String>{challenges, feed, winners};
}
