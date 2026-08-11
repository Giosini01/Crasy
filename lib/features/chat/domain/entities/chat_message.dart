/// Un messaggio scambiato dopo il match.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String senderId;
  final String text;

  /// Nullo per il breve istante fra l'invio e la risposta del server, che e'
  /// quello che assegna l'orario vero.
  final DateTime? sentAt;

  bool sentBy(String userId) => senderId == userId;

  /// L'indirizzo della conversazione fra due persone.
  ///
  /// I due identificativi in ordine alfabetico, uniti da `_`: e' una regola
  /// che le due parti applicano da sole e ottengono lo stesso risultato, senza
  /// doverselo comunicare. Gli identificativi di Firebase non contengono `_`,
  /// quindi la separazione e' sempre univoca — ed e' su questo che si appoggia
  /// anche il permesso di scrittura.
  static String chatIdOf(String a, String b) {
    final pair = [a, b]..sort();

    return pair.join('_');
  }
}
