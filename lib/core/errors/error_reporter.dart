import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Cosa succede quando un pezzo di schermata va in errore.
///
/// **In una versione pubblicata, un widget che fallisce diventa un rettangolo
/// grigio-nero.** Non e' una scelta di Flutter fatta a caso: la schermata rossa
/// piena di codice serve a chi programma, e mostrarla a chi usa l'app sarebbe
/// peggio. Il risultato pero' e' che un errore in una schermata a tutto schermo
/// si vede come **uno schermo nero e basta** — nessuna scritta, nessuna via
/// d'uscita, e chi lo trova non ha modo di dire cosa e' successo. E' il difetto
/// piu' difficile da farsi raccontare: "e' diventato tutto nero" e' tutto
/// quello che si puo' sapere.
///
/// Qui si fanno due cose, e sono la stessa cosa vista da due lati.
///
/// **A chi guarda** si dice che quel pezzo non si e' caricato, dentro un
/// riquadro che occupa solo il posto che gli spetta: il resto della schermata
/// resta usabile, e se anche fosse tutta la pagina almeno c'e' scritto cosa
/// sta succedendo.
///
/// **A noi** si lascia una riga nel database. Senza, l'unica traccia di un
/// errore in mano a qualcun altro e' il suo racconto; con questa c'e' il nome
/// del guasto, dove e' successo e a chi. E' lo stesso mestiere che fa
/// `pushStatus` nel profilo, ed e' quello che ha trasformato una caccia alla
/// cieca in una risposta in dieci secondi.
abstract final class ErrorReporter {
  /// Quanti guasti si scrivono al massimo in una sessione.
  ///
  /// **Cinque.** Un errore dentro una lista si ripete a ogni riga e a ogni
  /// respiro dello schermo: senza un tetto, un difetto solo scriverebbe
  /// migliaia di documenti in un minuto — e la prima volta che ce ne
  /// accorgeremmo sarebbe dalla fattura. I primi cinque dicono gia' tutto:
  /// sono sempre lo stesso.
  static const _quantiAlMassimo = 5;

  static var _scritti = 0;

  /// I guasti gia' visti in questa sessione, per non riscrivere lo stesso.
  static final _visti = <String>{};

  /// Mette in ascolto. Si chiama una volta sola, all'avvio.
  static void ascolta({required bool conFirebase}) {
    ErrorWidget.builder = (dettagli) => _RiquadroRotto(dettagli: dettagli);

    // Quello che c'era prima continua a valere: in sviluppo e' quello che
    // stampa l'errore nel terminale, ed e' l'unico modo di vederlo mentre si
    // lavora.
    final precedente = FlutterError.onError;

    FlutterError.onError = (dettagli) {
      precedente?.call(dettagli);

      if (conFirebase) {
        unawaited(_annota(dettagli));
      }
    };
  }

  static Future<void> _annota(FlutterErrorDetails dettagli) async {
    final guasto = dettagli.exceptionAsString();
    // La libreria in cui e' successo distingue due errori che si somigliano.
    final dove = dettagli.library ?? '';
    final firma = '$dove|$guasto';

    if (_scritti >= _quantiAlMassimo || !_visti.add(firma)) {
      return;
    }

    _scritti += 1;

    try {
      await FirebaseFirestore.instance.collection('crashes').add({
        'guasto': guasto.length > 500 ? guasto.substring(0, 500) : guasto,
        'dove': dove,
        // Non tutta la pila: le prime righe dicono gia' quale widget e', e il
        // resto sono trenta livelli di Flutter uguali per qualunque errore.
        'pila': _primeRighe(dettagli.stack),
        'utente': FirebaseAuth.instance.currentUser?.uid ?? '',
        'piattaforma': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'quando': FieldValue.serverTimestamp(),
      });
    } on Object catch (_) {
      // **Un errore mentre si segnala un errore non deve fare rumore.** Se il
      // database non risponde, o le regole non lasciano scrivere, si perde la
      // segnalazione: e' molto meno grave di un'app che va in circolo
      // segnalando il proprio fallimento nel segnalare.
    }
  }

  static String _primeRighe(StackTrace? pila) {
    if (pila == null) {
      return '';
    }

    return pila.toString().split('\n').take(8).join('\n');
  }
}

/// Il riquadro che prende il posto di quello che non si e' caricato.
///
/// **Non usa il tema.** Un widget di errore puo' essere costruito anche fuori
/// da `MaterialApp` — o proprio perche' `MaterialApp` e' quello che ha
/// fallito — e cercare i colori del tema qui dentro vorrebbe dire fallire una
/// seconda volta, stavolta senza rete.
class _RiquadroRotto extends StatelessWidget {
  const _RiquadroRotto({required this.dettagli});

  final FlutterErrorDetails dettagli;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFFF7F5F2),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Questa parte non si è caricata.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF111111),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Torna indietro e riprova.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF777777), fontSize: 13),
            ),
            const SizedBox(height: 10),
            // **La riga del guasto si mostra anche a chi usa l'app.**
            //
            // Non e' per farla leggere: e' perche' chi trova il difetto sia in
            // grado di dircelo. Una fotografia dello schermo con dentro il nome
            // dell'errore vale un pomeriggio di indagini, e "e' diventato tutto
            // nero" non vale niente.
            Text(
              dettagli.exceptionAsString(),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFC8102E), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
