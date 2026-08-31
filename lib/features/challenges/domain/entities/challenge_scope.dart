/// Dove vive una challenge.
///
/// Non e' un filtro e non e' una categoria: e' **con chi si compete**. Una
/// challenge globale mette in gara tutti, una locale solo chi e' in quella
/// citta' — e siccome il premio e' lo stesso, il campo di gara e' una delle
/// prime cose che uno vuole sapere.
enum ChallengeScope {
  global('GLOBAL'),
  country('ITALIA'),

  /// Legata a una citta' o a un luogo. L'etichetta vera arriva dalla challenge
  /// (`NAPOLI`, `MILANO`), questa e' solo la parola di ripiego.
  local('LOCALE'),

  /// **Solo per i tuoi amici.** Non e' un filtro sulla home: e' una gara che
  /// chi non ti conosce **non vede proprio**, perche' le regole del database
  /// non gliela lasciano leggere. Chi la puo' vedere sta scritto dentro la gara
  /// stessa, nel campo `audience`.
  ///
  /// E' l'unico ambito in cui il premio puo' essere zero: fra amici la sfida
  /// vale gia' per conto suo, e chiedere un euro per lanciarla vorrebbe dire
  /// mettere un casello davanti alla cosa piu' naturale che si fa qui dentro.
  friends('SOLO AMICI'),

  /// Su invito. Non ancora aperta nell'MVP, ma il valore esiste gia' perche' i
  /// documenti che lo portano possano essere letti senza rompere nulla.
  private('PRIVATA');

  const ChallengeScope(this.defaultLabel);

  /// Come si chiama questo ambito quando la challenge non dice altro.
  final String defaultLabel;

  static ChallengeScope fromName(String? value) {
    for (final scope in ChallengeScope.values) {
      if (scope.name == value) {
        return scope;
      }
    }

    return ChallengeScope.global;
  }
}
