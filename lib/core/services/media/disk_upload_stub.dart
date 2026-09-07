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
