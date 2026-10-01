import 'package:crasy/features/challenges/domain/entities/challenge.dart';

/// **In che ordine si guardano le missioni aperte.**
///
/// La lista arriva dal database ordinata per scadenza, ed e' l'ordine giusto
/// per chi apre l'app senza un'idea precisa: davanti c'e' quello che sta per
/// chiudere, cioe' l'unica cosa che smette di essere possibile se non la fai
/// adesso. Chi invece sta cercando i soldi, o le cose appena uscite, con
/// quell'ordine deve scorrere e sperare.
///
/// **Si riordina qui, non nel database.** Le missioni aperte sono poche
/// decine: riordinarle sul telefono costa niente ed e' immediato — il dito
/// tocca e la lista e' gia' cambiata. Chiederlo a Firestore vorrebbe dire un
/// indice nuovo per ogni ordinamento, una richiesta di rete a ogni tocco, e
/// una lista che sfarfalla mentre arriva. Il giorno in cui le missioni aperte
/// saranno migliaia questa scelta andra' rifatta, e si vedra' da qui.
enum ChallengeSort {
  /// Quella che chiude prima. E' l'ordine con cui la lista nasce.
  inScadenza('IN SCADENZA'),

  /// Il premio piu' alto in cima.
  premioAlto('PREMIO ALTO'),

  /// Il premio piu' basso in cima — che quasi sempre vuol dire le gratis.
  premioBasso('PREMIO BASSO'),

  /// Le ultime arrivate.
  recenti('NUOVE'),

  /// Le piu' vecchie ancora aperte.
  vecchie('MENO RECENTI');

  const ChallengeSort(this.label);

  final String label;
}

/// Rimette in fila le missioni secondo [come].
///
/// Restituisce sempre una lista nuova: ordinare sul posto quella che arriva dal
/// provider vorrebbe dire modificare una cosa che non e' nostra, e il difetto
/// che ne nasce — una lista che cambia ordine da sola sotto un'altra schermata
/// — e' di quelli che si inseguono per giorni.
List<Challenge> ordina(List<Challenge> missioni, ChallengeSort come) {
  final fila = [...missioni];

  switch (come) {
    case ChallengeSort.inScadenza:
      fila.sort((a, b) => a.endsAt.compareTo(b.endsAt));
    case ChallengeSort.premioAlto:
      // **A parita' di premio decide la scadenza.** Senza questa seconda
      // regola, tutte le gratis — che hanno lo stesso premio, zero — si
      // disporrebbero in un ordine qualsiasi, e quell'ordine cambierebbe a
      // ogni apertura della schermata. Una lista che si rimescola da sola fa
      // sembrare rotta anche la parte che funziona.
      fila.sort((a, b) {
        final premio = b.prizeCents.compareTo(a.prizeCents);

        return premio != 0 ? premio : a.endsAt.compareTo(b.endsAt);
      });
    case ChallengeSort.premioBasso:
      fila.sort((a, b) {
        final premio = a.prizeCents.compareTo(b.prizeCents);

        return premio != 0 ? premio : a.endsAt.compareTo(b.endsAt);
      });
    case ChallengeSort.recenti:
      fila.sort((a, b) => b.startsAt.compareTo(a.startsAt));
    case ChallengeSort.vecchie:
      fila.sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  return fila;
}
