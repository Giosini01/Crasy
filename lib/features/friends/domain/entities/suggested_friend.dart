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
    this.numero = '',
    this.nomeInRubrica = '',
  });

  final String userId;
  final String username;
  final String displayName;
  final String photoUrl;

  /// **Come l'hai salvato tu in rubrica.**
  ///
  /// E' il nome che serve per riconoscere qualcuno, e mancava: la riga mostrava
  /// il nome del profilo CRASY, che spesso non e' quello con cui quella persona
  /// e' in testa a chi guarda. In rubrica c'e' `Zia Carla`; su CRASY c'e'
  /// `carlotta_92`. Chi scorre l'elenco cerca la zia, e non la trovava — pur
  /// avendola davanti.
  ///
  /// Il nome era **gia' sul telefono**: lo si legge per scrivere "Invita Marco"
  /// nell'altra meta' della schermata, e per chi stava su CRASY veniva buttato
  /// via a meta' strada. Non arriva dal server e non ci torna: resta su questo
  /// telefono, come il numero accanto a cui sta.
  final String nomeInRubrica;

  /// **Che rapporto c'e' gia' con questa persona.**
  ///
  /// Chi era gia' amico prima veniva tolto dall'elenco, e con due contatti su
  /// CRASY di cui uno gia' amico la schermata diceva "nessuno": sembrava che
  /// la ricerca non avesse funzionato. Si mostrano tutti, e questo campo dice
  /// al tasto cosa scrivere.
  final SuggestedStato stato;

  /// Il numero con cui l'abbiamo trovato fra i contatti.
  ///
  /// Serve a una cosa sola: togliere quella riga dall'elenco di chi resta da
  /// invitare. E' un numero che il telefono aveva gia' in rubrica — nessuno gli
  /// sta dicendo niente di nuovo — e non si mostra da nessuna parte.
  final String numero;

  /// Come si chiama, per chi legge.
  ///
  /// **Prima di tutto il nome della rubrica**, perche' e' l'unico che chi guarda
  /// ha scelto lui: fra `Zia Carla` e `Carlotta R.` non vince il piu' completo,
  /// vince quello che si riconosce a colpo d'occhio. Poi il nome del profilo, e
  /// per ultimo il nome utente — una riga senza niente scritto sopra non si
  /// tocca.
  String get nome {
    if (nomeInRubrica.isNotEmpty) {
      return nomeInRubrica;
    }

    return displayName.isNotEmpty ? displayName : username;
  }

  /// Se sotto il nome c'e' qualcosa da scrivere, e cosa.
  ///
  /// Sotto `Zia Carla` va `@carlotta_92`: senza, non si sa chi si sta per
  /// seguire su CRASY, e il nome della rubrica da solo non e' verificabile da
  /// nessuna parte. Vuoto quando la riga **e' gia'** il nome utente, perche'
  /// scriverlo due volte non aggiunge niente.
  String get sottoNome => nome == username ? '' : '@$username';
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
