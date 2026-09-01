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

    try {
      final permesso = await _messaging.requestPermission();

      if (permesso.authorizationStatus == AuthorizationStatus.denied) {
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
        return;
      }

      await _salva(userId, token);

      // L'indirizzo scade e viene rinnovato dal sistema, di solito senza che
      // nessuno se ne accorga. Senza questo ascolto, da quel momento le
      // notifiche partono verso un indirizzo morto.
      await _ascoltoRinnovi?.cancel();
      _ascoltoRinnovi = _messaging.onTokenRefresh.listen(
        (nuovo) => _salva(userId, nuovo),
      );
    } on Object catch (_) {
      // Permesso negato, servizi Google assenti, rete che non risponde: in
      // tutti i casi l'app continua senza notifiche.
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

  /// Toglie questo telefono dal registro.
  ///
  /// **Si chiama uscendo.** Senza, il telefono di chi ha fatto uscire l'account
  /// continua a ricevere le notifiche di quella persona — anche mesi dopo, anche
  /// se nel frattempo lo usa qualcun altro.
  Future<void> unregister(String userId) async {
    await _ascoltoRinnovi?.cancel();
    _ascoltoRinnovi = null;

    if (userId.isEmpty) {
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
