import 'package:crasy/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap_result.dart';

abstract final class FirebaseBootstrap {
  static Future<FirebaseBootstrapResult> initialize() async {
    if (Firebase.apps.isNotEmpty) {
      return const FirebaseBootstrapResult.configured();
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await _rememberTheSession();
      return const FirebaseBootstrapResult.configured();
    } on Exception catch (error) {
      return FirebaseBootstrapResult.unavailable(
        'Firebase non disponibile: $error',
      );
    } on Error catch (error) {
      return FirebaseBootstrapResult.unavailable(
        'Firebase non disponibile: $error',
      );
    }
  }

  /// **Chi ha fatto l'accesso resta dentro.**
  ///
  /// Sul telefono e' gia' cosi' e non serve dire niente. Sul web no: il valore
  /// predefinito di Firebase e' `LOCAL`, ma basta poco a farlo scivolare su
  /// `SESSION` — una configurazione, un aggiornamento del pacchetto — e da
  /// quel momento chiudere la scheda vuol dire rifare l'accesso. Dirlo per
  /// esteso costa una riga e toglie di mezzo l'intera categoria di problema.
  ///
  /// Va detto anche cosa questo **non** puo' fare: la sessione vive
  /// nell'archivio del browser, e quell'archivio e' legato all'indirizzo. Finche'
  /// CRASY girava su un tunnel che cambiava nome a ogni riavvio, ogni apertura
  /// era un sito nuovo e l'accesso ripartiva da zero. Non era una dimenticanza
  /// del codice: era l'indirizzo. Su un dominio stabile il problema non esiste
  /// piu'.
  static Future<void> _rememberTheSession() async {
    if (!kIsWeb) {
      return;
    }

    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    } on Exception catch (_) {
      // Se il browser non lo permette — navigazione privata, archivio pieno —
      // l'app funziona lo stesso, semplicemente chiedendo l'accesso piu'
      // spesso. Non e' un motivo per non partire.
    }
  }
}
