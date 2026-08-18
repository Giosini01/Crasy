/// Un amico: chi e', e da quando.
///
/// L'amicizia su CRASY e' **reciproca e simmetrica**: se ci siamo, ci siamo in
/// due. Non esistono seguiti e seguaci — quelli servono a chi vive di pubblico,
/// e qui non si costruisce un pubblico, si guarda cosa combinano le persone che
/// si conoscono.
class Friend {
  const Friend({required this.userId, required this.username, this.since});

  final String userId;

  /// Il nome copiato al momento dell'amicizia.
  ///
  /// E' una duplicazione voluta: l'elenco degli amici si apre spesso, e senza
  /// questo campo ogni riga costringerebbe a leggere anche il profilo di quella
  /// persona — trenta letture per una schermata sola.
  final String username;

  final DateTime? since;
}

/// Una richiesta di amicizia in attesa di risposta.
///
/// Vive **sotto chi la riceve**, non sotto chi la manda: la domanda che l'app
/// fa piu' spesso e' "ho richieste da vedere?", e cosi' e' una sola lettura
/// della propria cartella.
class FriendRequest {
  const FriendRequest({
    required this.fromUserId,
    required this.fromUsername,
    this.createdAt,
  });

  final String fromUserId;
  final String fromUsername;
  final DateTime? createdAt;
}

/// Che rapporto ho con questa persona in questo momento.
///
/// E' un solo valore e non tre booleani sparsi: il comando da mostrare — manda
/// richiesta, richiesta mandata, accetta, togli — dipende da **uno** stato, e
/// tenerlo in un enum impedisce di ritrovarsi con schermate che dicono cose
/// contraddittorie.
enum FriendshipStatus {
  /// Non ci conosciamo.
  none,

  /// Gli ho mandato una richiesta e sto aspettando.
  requestSent,

  /// Mi ha mandato una richiesta: tocca a me rispondere.
  requestReceived,

  /// Siamo amici.
  friends,

  /// Sono io.
  self,
}
