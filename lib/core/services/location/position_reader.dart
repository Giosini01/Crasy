/// Lettura della posizione, con l'implementazione della piattaforma corrente.
///
/// Su web si parla direttamente con l'API del browser invece di passare da
/// `geolocator`: il suo wrapper web converte il timeout in microsecondi e
/// forza `maximumAge` a zero, e su iOS quest'ultima cosa fa fallire la lettura
/// con "posizione non disponibile" ogni volta che il sistema non ha un
/// aggancio fresco da restituire.
library;

export 'package:crasy/core/services/location/position_reader_stub.dart'
    if (dart.library.js_interop) 'package:crasy/core/services/location/position_reader_web.dart'
    if (dart.library.io) 'package:crasy/core/services/location/position_reader_io.dart';
export 'package:crasy/core/services/location/position_sample.dart';
