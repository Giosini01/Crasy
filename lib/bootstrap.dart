import 'package:crasy/app.dart';
import 'package:crasy/services/firebase/firebase_bootstrap.dart';
import 'package:crasy/services/firebase/firebase_bootstrap_result.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseBootstrapResult = await FirebaseBootstrap.initialize();

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
