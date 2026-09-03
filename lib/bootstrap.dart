import 'package:crasy/app.dart';
import 'package:crasy/core/errors/error_reporter.dart';
import 'package:crasy/services/firebase/firebase_bootstrap.dart';
import 'package:crasy/services/firebase/firebase_bootstrap_result.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseBootstrapResult = await FirebaseBootstrap.initialize();

  // **Prima di disegnare qualunque cosa.** Da qui in poi un pezzo di schermata
  // che va in errore diventa un riquadro con scritto cosa e' successo, invece
  // del rettangolo nero che Flutter disegna nelle versioni pubblicate — e
  // lascia una riga nel database, cosi' non tocca a nessuno raccontarcelo.
  ErrorReporter.ascolta(conFirebase: firebaseBootstrapResult.isConfigured);

  runApp(
    ProviderScope(
      overrides: [
        firebaseBootstrapResultProvider.overrideWithValue(
          firebaseBootstrapResult,
        ),
      ],
      child: const CrasyApp(),
    ),
  );
}
