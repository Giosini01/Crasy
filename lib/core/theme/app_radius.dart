/// I raggi degli angoli.
///
/// Piccoli. Un angolo molto tondo e' *amichevole*, e CRASY non vuole essere
/// amichevole: vuole essere netta. Le foto e i comandi prendono [md], che a
/// occhio si legge quasi come uno spigolo vivo ma toglie la durezza del taglio
/// perfetto.
///
/// [pill] esiste per una cosa sola — gli avatar — e non va usato per i bottoni:
/// una pillola rossa a tutta larghezza e' il bottone di un'altra app.
abstract final class AppRadius {
  static const double xs = 2;
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;

  /// Le foto, e solo quelle.
  ///
  /// **Molto piu' tondo del resto, ed e' voluto.** I comandi restano quasi
  /// squadrati perche' devono sembrare netti; una foto no — e' un oggetto che
  /// si guarda, e l'angolo molto tondo e' quello che la fa sembrare una cosa
  /// posata li' invece che un riquadro ritagliato nella pagina. E' anche la
  /// curva su cui corre la didascalia: con un angolo vivo la scritta girerebbe
  /// uno spigolo, che e' un'altra cosa e non e' bella.
  static const double media = 20;

  /// Solo per cio' che e' davvero circolare.
  static const double pill = 999;
}
