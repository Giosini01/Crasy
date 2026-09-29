/// Un commento sotto una foto in gara.
///
/// **Vive quanto la gara.** Finita quella, l'app smette di mostrarli e sotto la
/// foto restano solo le fiamme. Non e' una pulizia estetica: un commento e' una
/// cosa che si dice *mentre* si guarda una gara in corso — "questa e' assurda",
/// "ce l'hai fatta" — e riletta due settimane dopo, sotto un trofeo, e' una
/// conversazione presa da un altro momento. La foto e il numero delle fiamme
/// sono il risultato; i commenti erano il tifo.
///
/// Chi c'era li ha letti. Chi arriva dopo guarda chi ha vinto.
class EntryComment {
  const EntryComment({
    required this.id,
    required this.challengeId,
    required this.entryId,
    required this.userId,
    required this.authorName,
    required this.text,
    this.mentions = const [],
    this.createdAt,
  });

  final String id;
  final String challengeId;

  /// La partecipazione sotto cui sta. E' l'identificativo di chi l'ha mandata:
  /// una foto a testa per gara, quindi i due coincidono.
  final String entryId;

  final String userId;
  final String authorName;
  final String text;

  /// Chi e' stato nominato, con nome **e** identificativo.
  ///
  /// Il nome da solo non basterebbe. Per portare al profilo di qualcuno serve
  /// il suo identificativo, e ricavarlo dal nome vorrebbe dire una ricerca sul
  /// database a ogni `@` che compare a schermo — decine di letture per
  /// disegnare un elenco di commenti.
  ///
  /// Ed e' anche piu' onesto: un nome puo' cambiare, e un commento vecchio
  /// deve continuare a portare **alla persona che era stata nominata**, non a
  /// chi si e' preso quel nome dopo.
  final List<EntryMention> mentions;

  /// Istante dell'invio. Nullo finche' il server non ha risolto il proprio
  /// timestamp: Firestore lo scrive dopo, non al momento della chiamata.
  final DateTime? createdAt;

  /// L'identificativo di chi porta questo nome, se e' fra i nominati.
  String? userIdOf(String username) {
    for (final mention in mentions) {
      if (mention.username == username) {
        return mention.userId;
      }
    }

    return null;
  }

  /// Quanto puo' essere lungo un commento.
  ///
  /// Tre righe scarse. Sotto una foto non si scrivono lettere, e un limite
  /// basso fa piu' per la leggibilita' di qualunque impaginazione.
  static const int maxLength = 300;
}

/// Una persona nominata dentro un commento.
class EntryMention {
  const EntryMention({required this.userId, required this.username});

  final String userId;
  final String username;
}
