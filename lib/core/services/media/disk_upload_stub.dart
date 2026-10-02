import 'package:firebase_storage/firebase_storage.dart';

/// Sul web non esistono file su disco, quindi non si carica da nessun disco.
///
/// Il selettore del browser consegna direttamente i byte: non c'e' un percorso
/// da aprire, e non c'e' niente da risparmiare — quei byte sono gia' in
/// memoria prima ancora che noi li vediamo.
const bool caricamentoDaDiscoDisponibile = false;

Future<void> caricaDalDisco(
  Reference riferimento,
  String percorso,
  SettableMetadata dati,
) => throw UnsupportedError('Sul web non ci sono file su disco.');

/// Sul web non c'e' nessun file da mettere al riparo.
Future<String> mettiAlSicuro(String origine) async => '';

/// Sul web non c'e' nessuna copia da buttare.
Future<void> buttaLaCopia(String percorso) async {}

/// Sul web non ci sono file: si va sempre di byte.
bool ilFileEBuono(String percorso) => false;

/// Sul web non c'e' nessun file da misurare: valgono i byte.
int lunghezzaDi(String percorso) => 0;

/// Sul web il file non c'e', quindi la durata non si misura: si lascia
/// passare, e il selettore del browser ha gia' fatto quel che poteva.
Future<Duration?> durataDelVideo(String percorso) async => null;
