import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Rimpicciolisce una foto prima che parta.
///
/// **E' la cosa che tiene in piedi i conti dello spazio.** Una foto da un
/// telefono recente pesa fra i tre e gli otto megabyte; la stessa foto, larga
/// milleseicento punti e salvata all'ottantadue per cento, ne pesa fra i due e i
/// quattro decimi. E' **dieci volte meno**, e sullo schermo di un telefono non
/// si vede la differenza: quella foto verra' guardata dentro un riquadro largo
/// quattrocento punti.
///
/// Su telefono `image_picker` sa gia' ridimensionare da solo, e questo passaggio
/// non trova quasi niente da fare. Su web quei parametri **li ignora** — e' un
/// limite noto della piattaforma — e finora ogni foto saliva com'era uscita
/// dalla fotocamera. Siccome oggi CRASY vive sul web, era la strada da cui
/// arrivava tutto.
///
/// Non e' un filtro di qualita': e' il taglio di quello che nessuno vedra' mai.
abstract final class PhotoCompressor {
  /// Il lato lungo massimo, in punti.
  ///
  /// Milleseicento e' abbondante per uno schermo da telefono anche a tre volte
  /// la densita', e lascia margine per ingrandire con due dita a schermo intero.
  static const int maxSide = 1600;

  /// Quanto si stringe. Ottantadue e' il punto in cui i file crollano e gli
  /// occhi non se ne accorgono; sotto, sulle tinte piatte cominciano a
  /// comparire i quadretti.
  static const int quality = 82;

  /// Sotto questa misura non si tocca niente.
  ///
  /// Ricomprimere una foto gia' piccola la peggiora e basta: ogni passaggio in
  /// JPEG butta via qualcosa, e qui non ci sarebbe niente da guadagnare.
  static const int leaveAloneBelowBytes = 400 * 1024;

  /// Torna la foto rimpicciolita, o **gli stessi byte** se non c'e' niente da
  /// fare o se qualcosa va storto.
  ///
  /// Non lancia mai, ed e' voluto: un formato che il decodificatore non conosce
  /// — un HEIC di iPhone, per dirne uno — non deve far fallire la
  /// partecipazione. Nel dubbio sale l'originale: pesante, ma in gara.
  static Uint8List shrink(Uint8List bytes) {
    if (bytes.lengthInBytes <= leaveAloneBelowBytes) {
      return bytes;
    }

    try {
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        return bytes;
      }

      final longest = decoded.width > decoded.height
          ? decoded.width
          : decoded.height;

      final resized = longest <= maxSide
          ? decoded
          : img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? maxSide : null,
              height: decoded.height > decoded.width ? maxSide : null,
              interpolation: img.Interpolation.average,
            );

      final encoded = img.encodeJpg(resized, quality: quality);

      // Se il giro non ha guadagnato niente si tiene l'originale. Capita con le
      // foto gia' compresse bene, e riscriverle sarebbe solo un altro passaggio
      // di perdita.
      return encoded.lengthInBytes < bytes.lengthInBytes ? encoded : bytes;
    } on Exception catch (_) {
      return bytes;
    }
  }
}
