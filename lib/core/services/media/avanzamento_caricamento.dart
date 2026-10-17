import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';

/// **Quanto si tiene in cache un file mandato in gara: per sempre.**
///
/// Il nome del file e' casuale e il file non cambia mai — le regole di Storage
/// non lasciano sovrascriverlo — quindi chi l'ha gia' scaricato una volta non
/// ha nessun motivo di riscaricarlo. Senza, il browser rifaceva la richiesta a
/// ogni apertura della gara, e con poca rete le foto gia' viste tornavano grigie.
const String perSempreInCache = 'public, max-age=31536000, immutable';

/// Aspetta un caricamento, dicendo man mano **quanto e' salito**, da 0 a 1.
///
/// Serve a chi aspetta: con poca rete un video ci mette un minuto, e una
/// fiamma che gira senza nessun numero accanto non dice se si sta muovendo
/// qualcosa o se e' tutto fermo.
Future<void> seguiIlCaricamento(
  UploadTask compito,
  void Function(double avanzamento)? suAvanzamento,
) async {
  if (suAvanzamento == null) {
    await compito;

    return;
  }

  final ascolto = compito.snapshotEvents.listen(
    (istante) {
      final totale = istante.totalBytes;

      if (totale > 0) {
        suAvanzamento((istante.bytesTransferred / totale).clamp(0, 1));
      }
    },
    // L'errore lo porta gia' il caricamento qui sotto: qui si ascolta e basta.
    onError: (Object _) {},
  );

  try {
    await compito;
  } finally {
    await ascolto.cancel();
  }
}
