/// Gli indirizzi usa-e-getta, e perche' qui danno fastidio piu' che altrove.
///
/// Su un'app qualunque un indirizzo temporaneo e' una scocciatura: un utente in
/// meno da ricontattare. **Qui e' il modo piu' semplice di rubare.** Le
/// challenge le decidono le fiamme, una per persona, e "una persona" per CRASY
/// vuol dire un account. Chi si fa cinque caselle in due minuti su uno di
/// questi siti si fa cinque account, e con cinque account si vota cinque volte
/// la propria foto: non e' un trucco da smanettoni, e' la prima cosa che
/// verrebbe in mente a chiunque veda dei soldi in palio.
///
/// ## Cosa ferma davvero, e cosa no
///
/// **Il muro dell'email confermata copre gia' meta' del problema**: un indirizzo
/// su un dominio che non esiste non riceve niente, quindi nessuno lo conferma e
/// nessuno entra. Quello che passa e' l'altra meta' — le caselle temporanee che
/// funzionano davvero, ricevono la posta e si buttano dopo dieci minuti. E'
/// contro quelle che serve questo elenco.
///
/// **E' una prima porta, non un muro.** Un elenco di domini ferma chi apre il
/// primo sito che trova su Google, non chi ne cerca uno che qui dentro non c'e'.
/// Il muro vero e' una funzione di blocco lato server — Firebase la chiama
/// *blocking function* — che rifiuta la registrazione prima ancora che
/// l'account nasca, e richiede il piano a consumo. Finche' non c'e', **questa
/// difesa vive solo dentro l'app**: chi chiama direttamente l'API di Firebase
/// la scavalca. E' esattamente la stessa struttura a strati che ha la
/// moderazione dei testi, e va detta invece che nascosta.
///
/// ## Cosa non si blocca, di proposito
///
/// - **I relay di Apple** (`privaterelay.appleid.com`). Sono indirizzi veri, di
///   persone vere, e il giorno in cui si aggiungera' l'accesso con Apple —
///   che Apple *impone* di accettare — bloccarli chiuderebbe la porta in faccia
///   a chi entra dalla strada che Apple ci obbliga a offrire.
/// - **Gli alias con il piu'** (`nome+crasy@gmail.com`). Sono un buco vero e
///   piu' largo di questo elenco: la stessa persona se ne fa quanti ne vuole,
///   e per Firebase sono indirizzi diversi. Chiuderlo non e' una lista di
///   domini, e' tenere da qualche parte l'indirizzo **ridotto alla sua forma
///   canonica** e impedire che si ripeta. E' un lavoro a se', e va fatto.
abstract final class EmailPolicy {
  /// Il messaggio che legge chi ci prova.
  ///
  /// Dice **cosa** non va e **cosa fare**, e non chiama nessuno furbo: la
  /// maggior parte di chi ci finisce sopra sta solo usando la casella che usa
  /// per tutto, senza secondi fini.
  static const String message =
      'Serve un indirizzo email vero: qui si vincono soldi, e senza un '
      'contatto stabile non c\'e\' modo di farteli avere.';

  /// I domini che non si accettano in registrazione.
  ///
  /// Sono i piu' diffusi, non tutti: elenchi completi ne esistono da
  /// cinquantamila voci, pesano un megabyte e invecchiano in un mese. Questi
  /// coprono la stragrande maggioranza di chi apre il primo sito che trova.
  static const Set<String> _disposable = {
    // I grandi classici, quelli che escono cercando "email temporanea".
    '10minutemail.com', '10minutemail.net', '10minutemail.org',
    'temp-mail.org', 'tempmail.com', 'tempmail.dev', 'tempmailo.com',
    'tempail.com', 'tempinbox.com', 'tempr.email', 'minuteinbox.com',
    'throwawaymail.com', 'trashmail.com', 'trashmail.de', 'trashmail.net',
    'yopmail.com', 'yopmail.fr', 'yopmail.net',
    'mailinator.com', 'mailinator.net', 'mailnesia.com', 'maildrop.cc',
    'dispostable.com', 'fakeinbox.com', 'mailcatch.com', 'mailsac.com',
    'getnada.com', 'nada.email', 'mohmal.com', 'moakt.com',
    'emailondeck.com', 'harakirimail.com', 'mailpoof.com', 'luxusmail.org',
    'discard.email', 'incognitomail.com', 'jetable.org', 'spambog.com',
    'spamgourmet.com', 'mytemp.email', 'mail.tm', 'tmail.ws',
    '1secmail.com', '1secmail.net', '1secmail.org',
    'wegwerfmail.de', 'mailde.de',

    // La famiglia Guerrilla: stesso servizio, molti nomi.
    'guerrillamail.com', 'guerrillamail.net', 'guerrillamail.org',
    'guerrillamail.biz', 'guerrillamail.de', 'guerrillamailblock.com',
    'sharklasers.com', 'grr.la', 'pokemail.net', 'spam4.me',

    // Gli alias infiniti. Non sono usa-e-getta in senso stretto — sono servizi
    // seri, usati da gente seria — ma fanno la stessa identica cosa: un
    // indirizzo nuovo a ogni registrazione, senza limite. Con dei premi in
    // denaro, "senza limite" e' il problema.
    'anonaddy.com', 'anonaddy.me', 'addy.io',
    'simplelogin.com', 'simplelogin.io', 'slmail.me',
    '33mail.com', 'burnermail.io', 'duck.com',
  };

  /// Il dominio di un indirizzo, in minuscolo. Vuoto se non e' un indirizzo.
  static String _domainOf(String email) {
    final at = email.trim().toLowerCase().lastIndexOf('@');

    if (at < 0) {
      return '';
    }

    return email.trim().toLowerCase().substring(at + 1);
  }

  /// Se l'indirizzo viene da un servizio usa-e-getta conosciuto.
  ///
  /// Guarda anche i **sottodomini**: `qualcosa.mailinator.com` e' lo stesso
  /// servizio, e quei siti ne offrono a manciate proprio per aggirare gli
  /// elenchi fatti sul nome esatto.
  static bool isDisposable(String? email) {
    final domain = _domainOf(email ?? '');

    if (domain.isEmpty) {
      return false;
    }

    if (_disposable.contains(domain)) {
      return true;
    }

    for (final blocked in _disposable) {
      if (domain.endsWith('.$blocked')) {
        return true;
      }
    }

    return false;
  }

  /// Il messaggio da mostrare, o `null` se l'indirizzo va bene.
  static String? validate(String? email) =>
      isDisposable(email) ? message : null;
}
