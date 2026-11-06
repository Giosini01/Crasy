class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.emailVerified = false,
    this.createdAt,
    this.lastSignInAt,
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

  /// Quando l'account e' nato.
  ///
  /// Serve a una cosa sola: sapere **da quanto** qualcuno e' fermo davanti al
  /// muro della conferma. Passata un'ora senza che l'indirizzo sia stato
  /// confermato, l'account viene buttato — cosi' quell'indirizzo torna libero e
  /// ci si puo' riprovare, invece di restare occupato per sempre da un account
  /// mai nato davvero.
  final DateTime? createdAt;

  /// **Quando e' stato fatto l'ultimo accesso con email e password**, l'ora la
  /// mette il server di Firebase.
  ///
  /// Non cambia riaprendo l'app con la sessione gia' aperta, e nemmeno quando
  /// si rinnova il token: cambia solo quando si entra di nuovo. Serve agli
  /// account che firmano i Termini a ogni accesso: vedi
  /// `UserProfile.firmaValePerLAccesso`.
  final DateTime? lastSignInAt;

  /// Da quanto esiste, a [now]. Nullo se non lo sappiamo.
  Duration? ageAt(DateTime now) {
    final nato = createdAt;

    return nato == null ? null : now.difference(nato);
  }
}
