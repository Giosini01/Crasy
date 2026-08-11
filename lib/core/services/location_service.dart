import 'package:app_incontri/core/services/location/location_exception.dart';
import 'package:app_incontri/core/services/location/position_reader.dart';
import 'package:app_incontri/features/profile/domain/entities/coordinates.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:app_incontri/core/services/location/location_exception.dart';

final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);

class LocationService {
  const LocationService();

  /// Legge la posizione del dispositivo e la restituisce **arrotondata**.
  ///
  /// La lettura vera la fa l'implementazione della piattaforma; qui resta solo
  /// l'arrotondamento, che e' la parte che riguarda il prodotto e non il
  /// dispositivo.
  Future<Coordinates> currentApproximateLocation() async {
    try {
      final sample = await readCurrentPosition();

      return Coordinates.approximate(
        latitude: sample.latitude,
        longitude: sample.longitude,
      );
    } on LocationException {
      rethrow;
    } on Object {
      throw const LocationException(LocationMessages.unknown);
    }
  }
}
