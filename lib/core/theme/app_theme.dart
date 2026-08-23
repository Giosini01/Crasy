import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/theme/app_typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  /// L'unico tema di CRASY.
  ///
  /// Non c'e' una variante scura, e non e' una mancanza: le foto delle
  /// challenge devono cadere sempre sullo stesso fondo, e il rosso deve avere
  /// sempre lo stesso peso. Un tema scuro darebbe due prodotti diversi.
  ///
  /// Qui dentro si spegne quasi tutto quello che Material accende da solo —
  /// tinte sulle superfici, ombre, onde al tocco, sfondi delle barre. Ognuna di
  /// quelle cose, presa singolarmente, e' innocua; tutte insieme fanno l'app
  /// piena di roba che CRASY non vuole essere.
  static ThemeData light() => _build(AppPalette.light);

  static ThemeData _build(AppPalette palette) {
    final textTheme = AppTypography.textTheme(
      primary: palette.textPrimary,
      secondary: palette.textSecondary,
    );

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: palette.accent,
          brightness: Brightness.light,
        ).copyWith(
          primary: palette.accent,
          onPrimary: palette.onAccent,
          primaryContainer: palette.accentTint,
          onPrimaryContainer: palette.accent,
          secondary: palette.textPrimary,
          onSecondary: palette.background,
          surface: palette.background,
          onSurface: palette.textPrimary,
          onSurfaceVariant: palette.textSecondary,
          surfaceContainerHighest: palette.surfaceMuted,
          outline: palette.line,
          outlineVariant: palette.line,
          error: palette.danger,
        );

    // Il comando e' un rettangolo appena smussato, a tutta larghezza. Non una
    // pillola: la pillola e' morbida, e qui sotto c'e' del denaro in palio.
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      textTheme: textTheme,
      extensions: [palette],
      // Nessuna onda al tocco: e' l'animazione piu' invasiva che Material
      // faccia, e su una schermata fatta di foto e spazio bianco si nota solo
      // lei.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: palette.surfaceMuted,
      // **Si torna indietro come su un telefono, non come su Android.**
      //
      // Le pagine entrano da destra e si tirano via col dito dal bordo
      // sinistro, su tutte le piattaforme — telefono e browser. Non e' gusto
      // personale per iOS: e' che quel gesto lo conoscono tutti, funziona senza
      // che ci sia niente da toccare a schermo, e lascia l'interfaccia vuota
      // com'e' giusto che sia qui dentro.
      //
      // Perche' valga davvero, le pagine vanno aperte come `CupertinoPage`: il
      // gesto sta nella rotta, non nel tema. Vedi `app_router.dart`.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const CupertinoPageTransitionsBuilder(),
        },
      ),
      // Il ritorno indietro e' un accento sottile, non la freccia piena di
      // Material: quella e' la cosa che fa sembrare "un'app Android" una
      // schermata per il resto identica.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) =>
            const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          // Il riempimento prende la fiamma profonda, non quella accesa:
          // l'etichetta bianca a 14 punti su quella accesa non avrebbe
          // abbastanza contrasto.
          backgroundColor: palette.accentDeep,
          foregroundColor: palette.onAccent,
          disabledBackgroundColor: palette.surfaceMuted,
          disabledForegroundColor: palette.textFaint,
          minimumSize: const Size.fromHeight(56),
          textStyle: textTheme.labelLarge,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: const Size.fromHeight(56),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: palette.line),
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.textPrimary,
          textStyle: textTheme.titleMedium,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        ),
      ),
      // I campi non hanno riquadro: solo un filetto sotto, come una riga su cui
      // scrivere. Un rettangolo grigio attorno a ogni campo e' il modo piu'
      // veloce di far sembrare un'app un modulo da compilare.
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        labelStyle: textTheme.labelSmall,
        floatingLabelStyle: textTheme.labelSmall?.copyWith(
          color: palette.accent,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: palette.textFaint),
        prefixIconColor: palette.textFaint,
        suffixIconColor: palette.textFaint,
        border: _underline(palette.line),
        enabledBorder: _underline(palette.line),
        focusedBorder: _underline(palette.textPrimary, width: 1.5),
        errorBorder: _underline(palette.danger),
        focusedErrorBorder: _underline(palette.danger, width: 1.5),
        errorStyle: textTheme.bodySmall?.copyWith(color: palette.danger),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accent,
        linearTrackColor: palette.surfaceMuted,
        circularTrackColor: palette.surfaceMuted,
        linearMinHeight: 2,
      ),
      dividerTheme: DividerThemeData(
        color: palette.line,
        thickness: 0.5,
        space: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.background,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
      iconTheme: IconThemeData(color: palette.textPrimary, size: 22),
    );
  }

  static UnderlineInputBorder _underline(Color color, {double width = 1}) {
    return UnderlineInputBorder(
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
