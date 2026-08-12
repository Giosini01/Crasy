import 'dart:async';
import 'dart:js_interop';

import 'package:crasy/core/services/location/location_exception.dart';
import 'package:crasy/core/services/location/position_sample.dart';
import 'package:web/web.dart' as web;

/// Millisecondi entro cui il browser deve rispondere.
const int _timeoutMs = 30000;

/// Quanto puo' essere vecchia una posizione gia' nota per essere accettata.
///
/// E' il punto chiave su iOS: con `maximumAge` a zero Safari deve produrre un
/// aggancio nuovo e, se non ci riesce nell'immediato, risponde
/// `POSITION_UNAVAILABLE` invece di restituire quello di poco fa. Cinque
/// minuti sono irrilevanti per una distanza in chilometri.
const int _maximumAgeMs = 300000;

Future<PositionSample> readCurrentPosition() {
  final completer = Completer<PositionSample>();

  try {
    web.window.navigator.geolocation.getCurrentPosition(
      (web.GeolocationPosition position) {
        final coordinates = position.coords;

        completer.complete(
          PositionSample(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
          ),
        );
      }.toJS,
      (web.GeolocationPositionError error) {
        completer.completeError(_describe(error.code));
      }.toJS,
      web.PositionOptions(
        // Su iOS l'alta precisione e' anche il ramo piu' affidabile: senza,
        // Safari si appoggia alla sola rete e fallisce piu' spesso.
        enableHighAccuracy: true,
        timeout: _timeoutMs,
        maximumAge: _maximumAgeMs,
      ),
    );
  } on Object {
    completer.completeError(const LocationException(LocationMessages.unknown));
  }

  return completer.future;
}

/// Codici di `GeolocationPositionError`: 1 permesso negato, 2 posizione non
/// determinabile, 3 tempo scaduto.
LocationException _describe(int code) {
  return switch (code) {
    1 => const LocationException(LocationMessages.denied),
    2 => const LocationException(LocationMessages.unavailable),
    3 => const LocationException(LocationMessages.timeout),
    _ => const LocationException(LocationMessages.unknown),
  };
}
