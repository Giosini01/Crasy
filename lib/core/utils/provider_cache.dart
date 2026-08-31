import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tiene in vita un provider `autoDispose` per un po' dopo che nessuno lo
/// guarda piu'.
///
/// **Il problema che risolve costa soldi veri.** Un provider `autoDispose` si
/// spegne nell'istante in cui l'ultimo widget che lo guardava esce dall'albero
/// — e in una lista che scorre questo succede in continuazione: la scheda esce
/// dallo schermo, il listener si chiude; si torna indietro con il dito, il
/// listener si riapre. **Firestore fa pagare l'apertura di un listener come una
/// lettura di ogni documento che gli risponde**, quindi ogni andata e ritorno
/// con il dito rilegge da capo tutta la lista. Scorrere avanti e indietro dieci
/// volte su otto gare non e' un gesto costoso per l'utente: e' qualche migliaio
/// di letture.
///
/// Con questa, il provider **resta acceso ancora un minuto** dopo che l'ultimo
/// lo ha lasciato. Se in quel minuto qualcuno torna a guardarlo — cioe' quasi
/// sempre, perche' e' il tempo di uno scorrimento — non si riapre niente: i
/// dati sono ancora li', e sono anche aggiornati, perche' nel frattempo il
/// listener non ha mai smesso di ascoltare.
///
/// **Non e' una cache che invecchia.** Non si serve niente di vecchio: finche'
/// il provider e' vivo, e' un ascolto vero su Firestore. Cambia solo *quando*
/// lo si spegne — dopo un minuto invece che subito.
void cacheFor(Ref ref) {
  final quanto = ref.read(providerCacheProvider);

  // Zero vuol dire "come se non ci fosse": si spegne appena lo lasciano.
  if (quanto == Duration.zero) {
    return;
  }

  _tieniAcceso(ref, quanto);
}

/// Per quanto un ascolto sopravvive a chi lo guardava.
///
/// E' un provider e non una costante per un motivo solo: **nelle prove vale
/// zero**. Un timer di un minuto lasciato acceso fa fallire i test dei widget —
/// il framework controlla che non resti niente in sospeso — e soprattutto una
/// prova deve vedere il provider spegnersi quando l'ultimo lo lascia, che e'
/// il comportamento che sta verificando.
final providerCacheProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 1),
);

void _tieniAcceso(Ref ref, Duration quanto) {
  final legame = ref.keepAlive();
  Timer? spegnimento;

  // Quando il provider muore davvero, la sveglia non deve restare in giro: un
  // timer appeso a un provider morto e' la stessa perdita, in piccolo.
  ref.onDispose(() => spegnimento?.cancel());

  // L'ultimo che guardava se n'e' andato: si parte a contare.
  ref.onCancel(() {
    spegnimento?.cancel();
    spegnimento = Timer(quanto, legame.close);
  });

  // E' tornato qualcuno prima dello scadere: si annulla lo spegnimento.
  ref.onResume(() {
    spegnimento?.cancel();
    spegnimento = null;
  });
}
