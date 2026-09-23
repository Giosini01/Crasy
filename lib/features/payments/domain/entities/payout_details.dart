/// **Chi sei e dove ti mandiamo i soldi.**
///
/// Si chiedono solo a chi preleva, e solo quando preleva. Non alla
/// registrazione: chiedere un codice fiscale a qualcuno che si e' appena
/// iscritto per fare una foto assurda e' il modo piu' rapido di farlo
/// scappare, e per giunta a nessuno serve finche' non ha vinto niente.
///
/// **Non ci sono foto di documenti qui dentro**, ed e' voluto. Verificare
/// un'identita' e' un lavoro che per legge tocca a chi manda il denaro — Stripe
/// — e custodire le carte d'identita' di centinaia di persone e' una
/// responsabilita' che non si prende chi puo' evitarla. Questi dati servono a
/// riempire quella pagina una volta sola, e a sapere a chi stiamo mandando dei
/// soldi.
class PayoutDetails {
  const PayoutDetails({
    this.firstName = '',
    this.lastName = '',
    this.fiscalCode = '',
    this.iban = '',
    this.birthDate,
  });

  final String firstName;
  final String lastName;

  /// Il codice fiscale, sempre in maiuscolo e senza spazi.
  final String fiscalCode;

  /// L'IBAN, sempre in maiuscolo e senza spazi.
  final String iban;

  final DateTime? birthDate;

  /// Se c'e' tutto quello che serve per far partire un prelievo.
  bool get isComplete =>
      PayoutValidators.name(firstName) == null &&
      PayoutValidators.name(lastName) == null &&
      PayoutValidators.fiscalCode(fiscalCode) == null &&
      PayoutValidators.iban(iban) == null &&
      PayoutValidators.birthDate(birthDate) == null;

  /// Le ultime quattro cifre, per far riconoscere il conto senza mostrarlo
  /// tutto. Su una schermata che qualcuno puo' guardare da sopra la spalla,
  /// un IBAN intero e' piu' di quanto serva.
  String get ibanTail =>
      iban.length < 4 ? iban : '···· ${iban.substring(iban.length - 4)}';

  PayoutDetails copyWith({
    String? firstName,
    String? lastName,
    String? fiscalCode,
    String? iban,
    DateTime? birthDate,
  }) {
    return PayoutDetails(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fiscalCode: fiscalCode ?? this.fiscalCode,
      iban: iban ?? this.iban,
      birthDate: birthDate ?? this.birthDate,
    );
  }
}

/// I controlli sui dati del prelievo.
///
/// **Controllare qui non e' zelo: e' l'unico punto in cui un errore si puo'
/// ancora correggere.** Un IBAN sbagliato mandato avanti diventa un bonifico
/// partito verso un conto che non esiste, o peggio verso quello di un altro, e
/// da li' in poi non si torna indietro con un tasto. Una cifra storta la si
/// scopre adesso, mentre chi l'ha scritta ce l'ha ancora sotto gli occhi, o non
/// la si scopre piu'.
abstract final class PayoutValidators {
  /// Nome e cognome: si controlla solo che ci siano e non siano una lettera.
  ///
  /// Niente elenchi di caratteri ammessi: i cognomi del mondo contengono
  /// apostrofi, accenti, trattini e spazi, e un controllo troppo stretto qui
  /// rifiuta delle persone vere per fare bella figura con le finte.
  static String? name(String? value) {
    final pulito = (value ?? '').trim();

    if (pulito.length < 2) {
      return 'Scrivilo per intero.';
    }

    if (pulito.length > 60) {
      return 'Troppo lungo.';
    }

    return null;
  }

  /// **L'IBAN, con la sua prova del nove.**
  ///
  /// Non si guarda solo la forma: dentro un IBAN ci sono due cifre di
  /// controllo, e con quelle si verifica tutto il resto. E' il motivo per cui
  /// una sola cifra sbagliata — la svista piu' comune quando si ricopia da un
  /// telefono all'altro — viene rifiutata qui invece di diventare un bonifico
  /// perso.
  ///
  /// Il conto e' quello standard: si spostano i primi quattro caratteri in
  /// fondo, le lettere diventano numeri (A vale 10, B 11, e cosi' via), e il
  /// numero enorme che ne esce deve dare **resto 1** diviso 97.
  static String? iban(String? value) {
    final pulito = normalize(value);

    if (pulito.isEmpty) {
      return 'Serve l\'IBAN del conto su cui vuoi i soldi.';
    }

    if (!RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]{10,30}$').hasMatch(pulito)) {
      return 'Questo IBAN non è scritto bene.';
    }

    // Un IBAN italiano ha esattamente ventisette caratteri. Vale la pena dirlo
    // a parte: chi sbaglia la lunghezza quasi sempre ne ha dimenticato uno, e
    // "manca qualcosa" e' un consiglio migliore di "non e' valido".
    if (pulito.startsWith('IT') && pulito.length != 27) {
      return 'Un IBAN italiano ha 27 caratteri, questo ne ha '
          '${pulito.length}.';
    }

    if (!_resto1(pulito)) {
      return 'Questo IBAN non esiste: ricontrolla le cifre.';
    }

    return null;
  }

  /// **Il codice fiscale, con la sua lettera finale.**
  ///
  /// Anche qui c'e' una cifra di controllo — l'ultima lettera — calcolata da
  /// tutte le altre quindici. Verificarla scarta i codici inventati e la
  /// maggior parte degli errori di battitura, e costa quindici righe.
  static String? fiscalCode(String? value) {
    final pulito = normalize(value);

    if (pulito.isEmpty) {
      return 'Serve il codice fiscale.';
    }

    if (!RegExp(
      r'^[A-Z]{6}[0-9LMNPQRSTUV]{2}[ABCDEHLMPRST][0-9LMNPQRSTUV]{2}'
      r'[A-Z][0-9LMNPQRSTUV]{3}[A-Z]$',
    ).hasMatch(pulito)) {
      return 'Questo codice fiscale non è scritto bene.';
    }

    if (pulito[15] != _controlloFiscale(pulito)) {
      return 'Questo codice fiscale non torna: ricontrollalo.';
    }

    return null;
  }

  /// La data di nascita: maggiorenni, e nati in un secolo plausibile.
  ///
  /// **I minorenni non prendono soldi**, e non e' una scelta di prodotto: un
  /// contratto con un minore non sta in piedi, e nessuno manda un bonifico a
  /// chi non puo' firmarlo.
  static String? birthDate(DateTime? value, {DateTime? now}) {
    if (value == null) {
      return 'Serve la data di nascita.';
    }

    final oggi = now ?? DateTime.now();
    final maggiorenneDal = DateTime(value.year + 18, value.month, value.day);

    if (maggiorenneDal.isAfter(oggi)) {
      return 'Per incassare bisogna essere maggiorenni.';
    }

    if (oggi.year - value.year > 120) {
      return 'Ricontrolla la data.';
    }

    return null;
  }

  /// Maiuscolo, senza spazi: e' cosi' che questi codici si scrivono, e
  /// accettarli comunque scritti evita di respingere chi li ha copiati con uno
  /// spazio in mezzo.
  static String normalize(String? value) =>
      (value ?? '').replaceAll(RegExp(r'\s'), '').toUpperCase();

  /// La prova del nove dell'IBAN. Il numero e' piu' lungo di quanto un intero
  /// possa contenere, quindi si divide per pezzi tenendo il resto: e' la
  /// divisione in colonna, quella delle elementari.
  static bool _resto1(String iban) {
    final spostato = iban.substring(4) + iban.substring(0, 4);
    var resto = 0;

    for (final carattere in spostato.split('')) {
      final codice = carattere.codeUnitAt(0);
      final pezzo = codice >= 65 && codice <= 90
          ? '${codice - 55}' // A = 10 … Z = 35
          : carattere;

      for (final cifra in pezzo.split('')) {
        resto = (resto * 10 + int.parse(cifra)) % 97;
      }
    }

    return resto == 1;
  }

  /// I valori delle lettere in posizione dispari e pari, come da tabella
  /// ministeriale. Non c'e' una regola dietro: sono due elenchi, e vanno
  /// scritti.
  static const _dispari = {
    '0': 1, '1': 0, '2': 5, '3': 7, '4': 9, '5': 13, '6': 15, '7': 17,
    '8': 19, '9': 21, 'A': 1, 'B': 0, 'C': 5, 'D': 7, 'E': 9, 'F': 13,
    'G': 15, 'H': 17, 'I': 19, 'J': 21, 'K': 2, 'L': 4, 'M': 18, 'N': 20,
    'O': 11, 'P': 3, 'Q': 6, 'R': 8, 'S': 12, 'T': 14, 'U': 16, 'V': 10,
    'W': 22, 'X': 25, 'Y': 24, 'Z': 23,
  };

  static const _pari = {
    '0': 0, '1': 1, '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8,
    '9': 9, 'A': 0, 'B': 1, 'C': 2, 'D': 3, 'E': 4, 'F': 5, 'G': 6, 'H': 7,
    'I': 8, 'J': 9, 'K': 10, 'L': 11, 'M': 12, 'N': 13, 'O': 14, 'P': 15,
    'Q': 16, 'R': 17, 'S': 18, 'T': 19, 'U': 20, 'V': 21, 'W': 22, 'X': 23,
    'Y': 24, 'Z': 25,
  };

  static String _controlloFiscale(String codice) {
    var somma = 0;

    for (var i = 0; i < 15; i++) {
      final carattere = codice[i];

      // Le posizioni si contano da uno: la prima lettera e' dispari.
      somma += (i % 2 == 0 ? _dispari[carattere] : _pari[carattere]) ?? 0;
    }

    return String.fromCharCode(65 + somma % 26);
  }
}
