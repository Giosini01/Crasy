import 'dart:io';

import 'package:video_player/video_player.dart';

/// Il video appena registrato, letto dal telefono.
///
/// **Serve a rivederlo prima di mandarlo.** Una partecipazione si manda una
/// volta sola e non si cambia: guardare cosa e' venuto prima di consegnarlo non
/// e' una comodita', e' la differenza fra mandare quello che si voleva e
/// scoprire dopo di aver mandato tre secondi di soffitto.
///
/// Dal disco e non dalla rete: il file e' ancora sul telefono e non e' salito
/// da nessuna parte — e il telefono che l'ha girato sa sempre riaprirlo, anche
/// quando e' in un formato che altri apparecchi rifiutano.
VideoPlayerController? lettoreDalDisco(String percorso) {
  if (percorso.isEmpty) {
    return null;
  }

  return VideoPlayerController.file(File(percorso));
}
