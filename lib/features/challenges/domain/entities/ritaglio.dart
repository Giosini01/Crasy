/// **La cornice scelta nell'editor: quale parte della foto si vede in
/// anteprima.**
///
/// La foto si carica **intera**, com'e' stata scattata. Il ritaglio non la
/// taglia: dice soltanto quale pezzo mostrare dentro i riquadri quattro quinti
/// delle schede e delle griglie. Toccandola, la si vede tutta.
///
/// Tutto in frazioni della foto, da 0 a 1: la stessa cornice vale per
/// l'originale, per la miniatura e per qualunque misura di schermo.
class Ritaglio {
  const Ritaglio({
    required this.x,
    required this.y,
    required this.larghezza,
    required this.altezza,
  });

  /// Il bordo sinistro e quello in alto, in frazioni della foto.
  final double x;
  final double y;

  /// Quanto e' larga e alta la cornice, in frazioni della foto.
  final double larghezza;
  final double altezza;

  /// Se descrive davvero un pezzo della foto. Una cornice rotta — scritta a
  /// mano, o arrivata a meta' — si ignora e la foto si mostra come prima.
  bool get valido =>
      larghezza > 0 &&
      altezza > 0 &&
      larghezza <= 1.0001 &&
      altezza <= 1.0001 &&
      x >= -0.0001 &&
      y >= -0.0001;

  Map<String, double> toMap() => {'x': x, 'y': y, 'w': larghezza, 'h': altezza};

  /// Legge la cornice dal database, o `null` se manca o non ha senso.
  static Ritaglio? fromMap(Object? dati) {
    if (dati is! Map) {
      return null;
    }

    double? numero(Object? valore) => valore is num ? valore.toDouble() : null;

    final x = numero(dati['x']);
    final y = numero(dati['y']);
    final w = numero(dati['w']);
    final h = numero(dati['h']);

    if (x == null || y == null || w == null || h == null) {
      return null;
    }

    final ritaglio = Ritaglio(x: x, y: y, larghezza: w, altezza: h);

    return ritaglio.valido ? ritaglio : null;
  }

  @override
  bool operator ==(Object other) =>
      other is Ritaglio &&
      other.x == x &&
      other.y == y &&
      other.larghezza == larghezza &&
      other.altezza == altezza;

  @override
  int get hashCode => Object.hash(x, y, larghezza, altezza);
}
