/// **I dati di contatto, che stanno fuori dal profilo.**
///
/// Vivono in `users/{id}/private/contatto`, dove entra solo il proprietario e
/// il server. Sono due cose sole, ma sono le due che non possono stare dove
/// stava il resto: il numero di telefono, e se con quel numero ci si vuole far
/// trovare da chi ce l'ha in rubrica.
class ContactSettings {
  const ContactSettings({this.phone = '', this.findableByPhone = true});

  final String phone;

  /// Parte acceso, ed e' una scelta che va detta invece che nascosta: spento
  /// di default, la sezione dei suggeriti non troverebbe quasi nessuno e non
  /// servirebbe a niente per nessuno. Chi non lo vuole lo spegne, e da quel
  /// momento il suo numero esce dall'indice — non viene escluso dai risultati:
  /// li' dentro non c'e' proprio piu'.
  final bool findableByPhone;
}
