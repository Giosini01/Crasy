import 'package:crasy/app.dart';
import 'package:crasy/core/errors/error_reporter.dart';
import 'package:crasy/services/firebase/firebase_bootstrap.dart';
import 'package:crasy/services/firebase/firebase_bootstrap_result.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // **CRASY sta in piedi, e basta.**
  //
  // Non e' una preferenza estetica: e' quello che l'app fa. Si scatta una foto
  // tenendo il telefono come lo si tiene sempre, le partecipazioni sono
  // quadrate o verticali, e la proclamazione occupa lo schermo per intero.
  // Coricato non ci sarebbe niente da guadagnare e ci sarebbe da perdere —
  // meta' delle schermate diventano una striscia, la fotocamera si gira mentre
  // qualcuno sta inquadrando, e la foto vincitrice esce dal riquadro.
  //
  // **Il blocco vero pero' non e' questa riga**: e' nel manifesto di Android e
  // nel plist di iOS. Da qui si comanda quello che succede **dopo** che l'app
  // e' partita, e resterebbe fuori il pezzo che si vede per primo — la
  // schermata di avvio, che si girerebbe lo stesso.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

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
