import 'package:app_incontri/core/theme/app_theme.dart';
import 'package:app_incontri/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RawsyApp extends ConsumerWidget {
  const RawsyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Rawsy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Bloccato sul chiaro: l'app non segue il tema di sistema, cosi' le
      // foto cadono sempre sullo stesso fondo.
      themeMode: ThemeMode.light,
      // L'app e' in italiano e basta: senza queste righe i mesi della ruota
      // della data e le voci di sistema restano in inglese, anche su un
      // telefono italiano.
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
