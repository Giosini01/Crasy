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

  /// Il lato lungo di una miniatura, in punti.
  ///
  /// **Settecentoventi, e il numero precedente era sbagliato di brutto.**
  ///
  /// Era quattrocento, scelto pensando a un quadratino di griglia. Ma la stessa
  /// miniatura finiva anche sotto le foto larghe quanto lo schermo, e li'
  /// quattrocento punti stirati su un telefono a tripla densita' — che di punti
  /// ne vuole mille e passa — davano un'immagine visibilmente sgranata. Su un
  /// prodotto dove la foto **e' il contenuto**, e' il difetto peggiore che si
  /// potesse introdurre per risparmiare qualche centesimo di banda.
  ///
  /// Adesso le foto larghe usano l'originale e basta, e la miniatura resta dove
  /// serviva davvero: le griglie. Settecentoventi copre con margine anche la
  /// griglia a due colonne del dettaglio, dove ogni quadrato vale circa
  /// cinquecento punti veri.
  static const int thumbSide = 720;

  /// Quanto si stringe una miniatura.
  ///
  /// Piu' del normale. A quattrocento punti i difetti della compressione non si
  /// vedono, e ogni punto percentuale qui e' banda che non si paga: la
  /// miniatura viene scaricata **decine di volte** per ogni volta che si apre
  /// l'originale.
  static const int thumbQuality = 80;

  /// La copia piccola, quella che riempie gli elenchi.
  ///
  /// **Perche' esiste.** Fino a ieri saliva un file solo, da circa trecento
  /// chilobyte, e quel file veniva scaricato dappertutto: nella copertina di
  /// una gara, dove e' alto duecento punti; nella griglia del profilo, dove e'
  /// un quadratino da cento; nella scheda degli amici. **Trecento chilobyte per
  /// disegnarne quaranta**, ogni volta, per ogni foto di ogni schermata.
  ///
  /// Con la miniatura da quarantacinque, aprire la home con otto gare scarica
  /// trecentosessanta chilobyte invece di due megabyte e mezzo. Sul conto di
  /// fine mese la banda si divide per cinque; su una connessione lenta la
  /// differenza fra otto secondi e uno.
  ///
  /// Torna `null` quando non c'e' niente da fare — un formato che non sappiamo
  /// leggere, o un'immagine gia' piccolissima — e chi la chiama sa cosa fare:
  /// niente. Senza miniatura si continua a mostrare l'originale, come prima.
  static Uint8List? thumbnail(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        return null;
      }

      final longest = decoded.width > decoded.height
          ? decoded.width
          : decoded.height;

      // Gia' piccola: una seconda copia della stessa cosa non serve a nessuno e
      // costa spazio.
      if (longest <= thumbSide) {
        return null;
      }

      final small = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? thumbSide : null,
        height: decoded.height > decoded.width ? thumbSide : null,
        interpolation: img.Interpolation.average,
      );

      return img.encodeJpg(small, quality: thumbQuality);
    } catch (_) {
      // **Si prende tutto, non solo le eccezioni.** Davanti a un file
      // rovinato la libreria delle immagini non lancia un'eccezione: lancia un
      // `RangeError`, che e' un `Error` e da un `on Exception` passa dritto.
      // L'ha trovato un test con quattro byte a caso dentro.
      //
      // Qui prendere tutto e' la cosa giusta, non la scorciatoia: **una
      // miniatura mancata non deve far fallire una partecipazione.** Nel dubbio
      // si mostra l'originale, che e' come si e' sempre fatto.
      return null;
    }
  }

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
  static Uint8List shrink(Uint8List bytes, {bool mirror = false}) {
    // **Con lo specchio si passa sempre di qui**, anche per una foto gia'
    // piccola: ribaltarla non e' un'ottimizzazione da saltare, e' quello che
    // rende la foto uguale a quella che si e' vista.
    if (!mirror && bytes.lengthInBytes <= leaveAloneBelowBytes) {
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

      // **Il ribaltamento, per i selfie.**
      //
      // Nell'anteprima ci si vede come in uno specchio — e' l'unico modo per
      // riuscire a inquadrarsi — e la foto deve venire **uguale a quella
      // anteprima**. Senza questo passaggio il sensore consegna l'immagine dal
      // suo punto di vista, cioe' ribaltata rispetto a quella che hai appena
      // guardato: alzi la mano destra e nella foto e' a sinistra, le scritte
      // sulla maglietta sono al contrario, e la faccia non e' quella con cui ti
      // sei visto un secondo prima.
      //
      // La regola e' una sola e vale sempre: **quello che vedi e' quello che
      // mandi.**
      final finale = mirror ? img.flipHorizontal(resized) : resized;
      final encoded = img.encodeJpg(finale, quality: quality);

      // Se il giro non ha guadagnato niente si tiene l'originale. Capita con le
      // foto gia' compresse bene, e riscriverle sarebbe solo un altro passaggio
      // di perdita. **Ribaltata no**: li' i byte nuovi sono l'unica versione
      // giusta, pesino quello che pesano.
      if (mirror) {
        return encoded;
      }

      return encoded.lengthInBytes < bytes.lengthInBytes ? encoded : bytes;
    } catch (_) {
      // Come sopra: un file che il decodificatore non digerisce lancia un
      // `Error`, non un'eccezione. Nel dubbio sale l'originale — pesante, ma in
      // gara.
      return bytes;
    }
  }
}
