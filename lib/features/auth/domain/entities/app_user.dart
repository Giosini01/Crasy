class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.emailVerified = false,
  });

  final String id;
  final String? email;

  /// Se l'indirizzo e' stato confermato aprendo il link che gli abbiamo
  /// mandato.
  ///
  /// Finche' e' falso l'account esiste ma **non entra**: senza un indirizzo
  /// vero non c'e' modo di far avere a nessuno il premio che ha vinto, e non
  /// c'e' modo di riconoscere chi torna dopo essere stato allontanato.
  final bool emailVerified;
}
