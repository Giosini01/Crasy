import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseBootstrapResultProvider = Provider<FirebaseBootstrapResult>(
  (ref) => const FirebaseBootstrapResult.unavailable(
    'Firebase bootstrap non eseguito.',
  ),
);

class FirebaseBootstrapResult {
  const FirebaseBootstrapResult({required this.isConfigured, this.message});

  const FirebaseBootstrapResult.configured()
    : this(isConfigured: true, message: null);

  const FirebaseBootstrapResult.unavailable(this.message)
    : isConfigured = false;

  final bool isConfigured;
  final String? message;
}
