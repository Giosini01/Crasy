import 'dart:async';

/// **Guardare due flussi insieme, e continuare a guardarli.**
///
/// ## Il difetto che questa funzione esiste per non rifare
///
/// Per mettere insieme due ascolti su Firestore si era usato `asyncExpand`,
/// annidando il secondo dentro il primo:
///
/// ```dart
/// saldo.asyncExpand((s) => movimenti.map((m) => Portafoglio(s, m)));
/// ```
///
/// Sembra giusto e non lo e'. `asyncExpand` aspetta che il flusso interno
/// **finisca** prima di accettare un altro valore da quello esterno — e un
/// ascolto su Firestore non finisce mai. Quindi il valore esterno viene letto
/// **una volta sola**, all'inizio, e da li' in poi resta inchiodato.
///
/// Nel portafoglio si vedeva cosi': si pagava una missione, la riga del
/// pagamento compariva nell'elenco — quello e' il flusso interno, vivo — e il
/// saldo sopra restava quello di prima. Fino alla riapertura dell'app. Per chi
/// guardava non era un difetto dell'interfaccia: erano **soldi spesi che non
/// venivano scalati**, che e' una cosa molto peggiore.
///
/// Non da' nessun errore, non lascia niente nei registri, e si vede solo
/// guardando il numero sbagliato al momento giusto.
///
/// ## Come funziona questa
///
/// Ascolta tutti e due per davvero, tiene l'ultimo valore di ciascuno, ed
/// emette a ogni cambiamento di **uno qualunque** dei due — appena entrambi
/// hanno detto qualcosa almeno una volta. Prima no: un portafoglio con il saldo
/// e senza i movimenti e' mezzo portafoglio, e mezzo portafoglio a schermo e'
/// un lampeggio.
Stream<R> combinaDue<A, B, R>(
  Stream<A> primo,
  Stream<B> secondo,
  R Function(A, B) unisci,
) {
  late StreamController<R> uscita;
  StreamSubscription<A>? daPrimo;
  StreamSubscription<B>? daSecondo;

  var hoA = false;
  var hoB = false;
  late A ultimoA;
  late B ultimoB;

  void emetti() {
    if (hoA && hoB) {
      uscita.add(unisci(ultimoA, ultimoB));
    }
  }

  void parti() {
    daPrimo = primo.listen(
      (valore) {
        hoA = true;
        ultimoA = valore;
        emetti();
      },
      // **L'errore passa, non ferma.** Un ascolto su Firestore puo' sbagliare
      // per un istante — rete, permessi che arrivano tardi — e chi guarda deve
      // poterlo sapere. Chiudere qui vorrebbe dire una schermata che resta
      // ferma per sempre dopo un singolo intoppo.
      onError: uscita.addError,
    );

    daSecondo = secondo.listen((valore) {
      hoB = true;
      ultimoB = valore;
      emetti();
    }, onError: uscita.addError);
  }

  Future<void> ferma() async {
    await daPrimo?.cancel();
    await daSecondo?.cancel();
    daPrimo = null;
    daSecondo = null;
  }

  uscita = StreamController<R>(
    onListen: parti,
    // **Si disdice davvero.** Senza queste tre righe i due ascolti sotto
    // restano aperti anche dopo che la schermata se n'e' andata: letture su
    // Firestore pagate per nessuno, che si accumulano a ogni apertura.
    onCancel: ferma,
    onPause: () {
      daPrimo?.pause();
      daSecondo?.pause();
    },
    onResume: () {
      daPrimo?.resume();
      daSecondo?.resume();
    },
  );

  return uscita.stream;
}

/// Come [combinaDue], con tre flussi.
Stream<R> combinaTre<A, B, C, R>(
  Stream<A> primo,
  Stream<B> secondo,
  Stream<C> terzo,
  R Function(A, B, C) unisci,
) {
  return combinaDue<(A, B), C, R>(
    combinaDue<A, B, (A, B)>(primo, secondo, (a, b) => (a, b)),
    terzo,
    (coppia, c) => unisci(coppia.$1, coppia.$2, c),
  );
}
