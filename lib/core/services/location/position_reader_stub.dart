import 'package:app_incontri/core/services/location/location_exception.dart';
import 'package:app_incontri/core/services/location/position_sample.dart';

/// Piattaforme senza ne' `dart:io` ne' `dart:js_interop`: non esistono fra i
/// bersagli dell'app, ma il compilatore vuole comunque un ramo.
Future<PositionSample> readCurrentPosition() {
  throw const LocationException(LocationMessages.unknown);
}
