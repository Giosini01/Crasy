/// Una persona che hai in rubrica e che sta gia' su CRASY.
///
/// Quello che **non** c'e' dentro e' voluto: nessun numero di telefono. Serve
/// a mostrare una faccia e un nome, e il numero — che pure e' il motivo per
/// cui questa persona e' comparsa — non deve viaggiare indietro dal server
/// accoppiato a un profilo.
class SuggestedFriend {
  const SuggestedFriend({
    required this.userId,
    required this.username,
    this.displayName = '',
    this.photoUrl = '',
    this.stato = SuggestedStato.nuovo,
  });

  final String userId;
  final String username;
  final String displayName;
  final String photoUrl;

  /// **Che rapporto c'e' gia' con questa persona.**
  ///
  /// Chi era gia' amico prima veniva tolto dall'elenco, e con due contatti su
  /// CRASY di cui uno gia' amico la schermata diceva "nessuno": sembrava che
  /// la ricerca non avesse funzionato. Si mostrano tutti, e questo campo dice
  /// al tasto cosa scrivere.
  final SuggestedStato stato;

  /// Come si chiama, per chi legge: il nome vero se c'e', altrimenti il nome
  /// utente. Una riga senza niente scritto sopra non si tocca.
  String get nome => displayName.isNotEmpty ? displayName : username;
}

/// Come si sta con una persona trovata in rubrica.
enum SuggestedStato {
  /// Non vi siete mai chiesti niente.
  nuovo,

  /// Gli hai gia' chiesto l'amicizia e sta aspettando.
  inviata,

  /// Te l'ha chiesta lui, e la risposta manca.
  tiHaChiesto,

  /// Siete gia' amici.
  amico;

  static SuggestedStato leggi(String? scritto) {
    return switch (scritto) {
      'amico' => SuggestedStato.amico,
      'inviata' => SuggestedStato.inviata,
      'ti-ha-chiesto' => SuggestedStato.tiHaChiesto,
      // Una parola che non conosciamo vale come "nuovo": il caso peggiore e'
      // offrire di chiedere l'amicizia a chi ce l'ha gia', e il server la
      // seconda richiesta la ignora. Il contrario — nascondere il tasto a chi
      // poteva usarlo — non si recupera.
      _ => SuggestedStato.nuovo,
    };
  }
}
