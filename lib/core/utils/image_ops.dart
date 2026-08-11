import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Operazioni sui pixel di una foto appena scattata.
abstract final class ImageOps {
  /// Ribalta la foto sull'asse verticale.
  ///
  /// Serve a raddrizzare i selfie. Molti telefoni salvano lo scatto della
  /// fotocamera frontale **come lo si vede nell'anteprima**, cioe' riflesso:
  /// il risultato e' una faccia con la riga dei capelli dal lato sbagliato e
  /// ogni scritta al contrario. Instagram salva l'immagine reale, ed e' quello
  /// che ci si aspetta.
  ///
  /// La correzione sta qui e non nelle impostazioni del telefono: un'app non
  /// puo' chiedere a chi la usa di andare a cambiare una preferenza di sistema
  /// perche' le sue foto vengano giuste.
  ///
  /// Torna i byte originali se l'immagine non e' decodificabile: meglio una
  /// foto forse riflessa che nessuna foto.
  static Future<Uint8List> flipHorizontally(Uint8List bytes) {
    // Su un isolato a parte: decodificare e ricodificare un JPEG da qualche
    // megapixel blocca l'interfaccia per centinaia di millisecondi.
    return compute(_flip, bytes);
  }
}

Uint8List _flip(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);

  if (decoded == null) {
    return bytes;
  }

  return img.encodeJpg(img.flipHorizontal(decoded), quality: 90);
}
