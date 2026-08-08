import 'package:firebase_core/firebase_core.dart';

import 'firebase_bootstrap_result.dart';

abstract final class FirebaseBootstrap {
  static Future<FirebaseBootstrapResult> initialize() async {
    if (Firebase.apps.isNotEmpty) {
      return const FirebaseBootstrapResult.configured();
    }

    try {
      await Firebase.initializeApp();
      return const FirebaseBootstrapResult.configured();
    } on Exception catch (error) {
      return FirebaseBootstrapResult.unavailable(
        'Firebase non configurato localmente: $error',
      );
    }
  }
}
