import 'package:crasy/core/services/refresh/auto_refresh.dart';
import 'package:crasy/core/theme/app_theme.dart';
import 'package:crasy/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CrasyApp extends ConsumerWidget {
  const CrasyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'CRASY',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Bloccata sul chiaro: l'app non segue il tema di sistema, cosi' le foto
      // cadono sempre sullo stesso fondo e il rosso ha sempre lo stesso peso.
      themeMode: ThemeMode.light,
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      // Le liste con una data dentro si rifanno da sole ogni pochi secondi.
      // Sta qui e non dentro una schermata perche' vale per tutte, e perche'
      // deve continuare a girare anche mentre si cambia scheda.
      builder: (context, child) =>
          AutoRefresh(child: child ?? const SizedBox.shrink()),
    );
  }
}
