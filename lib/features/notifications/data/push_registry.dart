import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Il registro dei dispositivi a cui mandare le notifiche.
///
/// **Perche' serve un registro e non basta l'utente.** Una notifica non si manda
/// a una persona: si manda a un telefono. La stessa persona puo' avere il
/// telefono e il tablet, puo' cambiare telefono, puo' uscire e rientrare — e
/// ognuna di queste cose produce un indirizzo diverso. Il registro tiene
/// l'elenco degli indirizzi vivi di ciascuno.
///
/// Ogni indirizzo e' un documento sotto la persona a cui appartiene. Il nome del
/// documento **e' l'indirizzo stesso**: riscriverlo due volte non crea un
/// doppione, e mandare due notifiche identiche allo stesso telefono e' il modo
/// piu' veloce di far spegnere le notifiche a qualcuno.
class PushRegistry {
  PushRegistry(this._firestore, this._messaging);

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  StreamSubscription<String>? _ascoltoRinnovi;

  /// L'ultima persona per cui questo telefono e' stato registrato.
  ///
  /// Serve a [forget]: chi esce non ha piu' una sessione, e senza ricordarselo
  /// non sapremmo da quale casella togliere l'indirizzo.
  String? _ultimoUtente;

  CollectionReference<Map<String, dynamic>> _devices(String userId) =>
      _firestore.collection('users').doc(userId).collection('devices');

  /// Chiede il permesso, prende l'indirizzo e lo scrive.
  ///
  /// **Il permesso si chiede qui e non all'avvio.** Sull'iPhone la richiesta si
  /// puo' fare una volta sola: rifiutata, non ricompare mai piu' e per
  /// riattivarla bisogna andare nelle impostazioni di sistema. Chiederla nel
  /// primo secondo di vita dell'app — prima che qualcuno abbia capito cosa sia
  /// CRASY — vuol dire bruciarla.
  ///
  /// Non lancia mai: senza notifiche l'app funziona, e un errore qui non deve
  /// fermare nessuno.
  Future<void> register(String userId) async {
    if (userId.isEmpty) {
      return;
    }

    // **Sul web non si chiede niente, per adesso.**
    //
    // Le notifiche del browser vogliono due cose che qui non ci sono: un file
    // di servizio dentro il sito e una chiave dedicata. Senza, l'indirizzo non
    // si ottiene e nessuna notifica partira' mai — ma il permesso il browser lo
    // chiederebbe lo stesso, con quel riquadro grigio in cima alla pagina.
    //
    // Chiedere un permesso che non serve a niente non e' innocuo: si spende
    // l'unica occasione che si ha di chiederlo, e chi risponde di no non se lo
    // vede riproporre mai piu'. Il giorno in cui le notifiche sul web
    // serviranno davvero, questa riga sparisce.
    if (kIsWeb) {
      return;
    }

    _ultimoUtente = userId;

    try {
      final permesso = await _messaging.requestPermission();

      if (permesso.authorizationStatus == AuthorizationStatus.denied) {
        await _annota(userId, 'permesso negato');

        return;
      }

      // **Su iPhone l'indirizzo arriva solo dopo che Apple ha risposto.**
      // Chiedendolo troppo presto torna nullo, e il telefono resta muto finche'
      // non si riapre l'app. Il ciclo aspetta: pochi tentativi, brevi, e poi si
      // lascia perdere.
      var token = await _messaging.getToken();

      for (var tentativo = 0; token == null && tentativo < 3; tentativo++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        token = await _messaging.getToken();
      }

      if (token == null) {
        // **Succede su iPhone quando il permesso di parlare con Apple non c'e'
        // nel profilo di firma.** L'app chiede, Apple non risponde, e resta un
        // nulla che senza questa riga non lascerebbe traccia da nessuna parte.
        await _annota(userId, 'nessun indirizzo da Apple');

        return;
      }

      await _salva(userId, token);
      await _annota(userId, 'registrato');

      // L'indirizzo scade e viene rinnovato dal sistema, di solito senza che
      // nessuno se ne accorga. Senza questo ascolto, da quel momento le
      // notifiche partono verso un indirizzo morto.
      await _ascoltoRinnovi?.cancel();
      _ascoltoRinnovi = _messaging.onTokenRefresh.listen(
        (nuovo) => _salva(userId, nuovo),
      );
    } on Object catch (errore) {
      // L'app continua senza notifiche — ma **lascia detto perche'**.
      //
      // Prima qui non si scriveva niente, e cercare il motivo dall'esterno era
      // impossibile: si vedeva solo un registro vuoto, che puo' voler dire
      // cinque cose diverse. Una riga nel profilo costa niente e le distingue
      // tutte.
      await _annota(userId, 'errore: $errore');
    }
  }

  /// Lascia detto com'e' andata, nel profilo di chi ha provato.
  ///
  /// **E' una diagnosi, non un dato del prodotto.** Nessuna schermata la
  /// mostra: serve a capire dall'esterno perche' un telefono non riceve le
  /// notifiche, che altrimenti si indovina soltanto.
  Future<void> _annota(String userId, String esito) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'pushStatus': esito,
        'pushStatusAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on Object catch (_) {
      // Se non riesce nemmeno questa, pazienza.
    }
  }

  Future<void> _salva(String userId, String token) async {
    try {
      await _devices(userId).doc(token).set({
        'token': token,
        // Serve a noi, non al telefono: da qui si capisce da dove arrivano le
        // persone senza chiederlo a nessuno.
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on Object catch (_) {
      // Vedi sopra.
    }
  }

  /// Toglie questo telefono dal registro di chi c'era prima.
  ///
  /// **Si chiama solo quando qualcuno esce davvero**, e la differenza e' costata
  /// tutte le notifiche.
  ///
  /// Prima veniva chiamata ogni volta che il provider si rifaceva, e il
  /// provider si rifaceva a ogni respiro della sessione: Firebase avvisa non
  /// solo quando si entra e si esce, ma anche a ogni rinnovo del gettone, a
  /// ogni ricarica dei dati, quando si conferma l'email, quando si aggancia il
  /// numero. Nei primi secondi capita tre o quattro volte.
  ///
  /// Il risultato era una gara persa in partenza: la registrazione ci mette
  /// qualche secondo — su iPhone bisogna aspettare la risposta di Apple — e nel
  /// frattempo il giro successivo cancellava l'indirizzo appena scritto.
  /// **L'app si toglieva dal registro da sola**, e il registro restava vuoto
  /// qualunque cosa si facesse.
  Future<void> forget() async {
    await _ascoltoRinnovi?.cancel();
    _ascoltoRinnovi = null;

    final userId = _ultimoUtente;
    _ultimoUtente = null;

    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      final token = await _messaging.getToken();

      if (token != null) {
        await _devices(userId).doc(token).delete();
      }
    } on Object catch (_) {
      // Vedi sopra.
    }
  }
}
