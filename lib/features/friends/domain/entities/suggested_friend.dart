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
  });

  final String userId;
  final String username;
  final String displayName;
  final String photoUrl;

  /// Come si chiama, per chi legge: il nome vero se c'e', altrimenti il nome
  /// utente. Una riga senza niente scritto sopra non si tocca.
  String get nome => displayName.isNotEmpty ? displayName : username;
}
