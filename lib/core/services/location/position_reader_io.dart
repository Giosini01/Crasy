import 'dart:async';

import 'package:crasy/core/services/location/location_exception.dart';
import 'package:crasy/core/services/location/position_sample.dart';
import 'package:geolocator/geolocator.dart';

Future<PositionSample> readCurrentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationException(LocationMessages.disabled);
  }

  var permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw const LocationException(LocationMessages.denied);
  }

  try {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 30),
      ),
    );

    return PositionSample(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  } on TimeoutException {
    throw const LocationException(LocationMessages.timeout);
  } on PositionUpdateException {
    throw const LocationException(LocationMessages.unavailable);
  } on LocationServiceDisabledException {
    throw const LocationException(LocationMessages.disabled);
  } on PermissionDeniedException {
    throw const LocationException(LocationMessages.denied);
  }
}
