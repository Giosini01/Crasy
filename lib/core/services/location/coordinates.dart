import 'dart:math' as math;

/// Una posizione approssimata.
///
/// Le coordinate arrivano dal dispositivo ma vengono **arrotondate** prima di
/// essere usate: al centesimo di grado la precisione scende a circa un
/// chilometro, abbastanza per dire "questa challenge e' nella tua citta'" e non
/// abbastanza per risalire a un indirizzo.
///
/// Serve alle challenge locali. Nell'MVP l'ambito di una challenge e'
/// un'etichetta scelta da chi la crea (`NAPOLI`, `ITALIA`) e nessuna schermata
/// legge ancora la posizione: questo pezzo e' pronto e collaudato, ma non e'
/// ancora collegato a niente.
class Coordinates {
  const Coordinates({required this.latitude, required this.longitude});

  /// Arrotonda al centesimo di grado, cioe' a circa un chilometro.
  factory Coordinates.approximate({
    required double latitude,
    required double longitude,
  }) {
    return Coordinates(
      latitude: _roundToHundredths(latitude),
      longitude: _roundToHundredths(longitude),
    );
  }

  final double latitude;
  final double longitude;

  static const double _earthRadiusKm = 6371;

  static double _roundToHundredths(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  /// Distanza in chilometri secondo la formula dell'emisenoverso.
  ///
  /// Sulle distanze che interessano, decine di chilometri, l'errore dovuto
  /// all'approssimazione sferica e' trascurabile rispetto all'arrotondamento
  /// gia' applicato alle coordinate.
  double distanceKmTo(Coordinates other) {
    final deltaLat = _toRadians(other.latitude - latitude);
    final deltaLng = _toRadians(other.longitude - longitude);
    final lat1 = _toRadians(latitude);
    final lat2 = _toRadians(other.latitude);

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2) *
            math.cos(lat1) *
            math.cos(lat2);

    return _earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Coordinates &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'Coordinates($latitude, $longitude)';
}
