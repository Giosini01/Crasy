import 'package:app_incontri/core/theme/app_palette.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/core/theme/app_typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  /// L'unico tema dell'app.
  ///
  /// Non esiste una variante scura: l'interfaccia resta chiara anche quando il
  /// sistema e' in tema scuro, cosi' il viola ha sempre lo stesso peso e le
  /// foto cadono sempre sullo stesso fondo.
  ///
  /// Angoli tondi, ombre basse, nessuna onda di tocco: l'interfaccia deve
  /// sparire dietro le foto, non farsi guardare.
  static ThemeData light() => _build(AppPalette.light);

  static ThemeData _build(AppPalette palette) {
    final textTheme = AppTypography.textTheme(
      primary: palette.textPrimary,
      secondary: palette.textSecondary,
    );

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: palette.brand,
          brightness: Brightness.light,
        ).copyWith(
          primary: palette.brand,
          onPrimary: palette.onBrand,
          primaryContainer: palette.brandTint,
          onPrimaryContainer: palette.brand,
          secondary: palette.brand,
          onSecondary: palette.onBrand,
          surface: palette.surface,
          onSurface: palette.textPrimary,
          onSurfaceVariant: palette.textSecondary,
          surfaceContainerHighest: palette.surfaceMuted,
          outline: palette.border,
          outlineVariant: palette.border,
          error: palette.danger,
        );

    // I comandi prendono la pillola: e' la forma piu' morbida che esista, e
    // su una schermata fatta di foto tonde un rettangolo stona.
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      textTheme: textTheme,
      extensions: [palette],
      // Su iOS un tocco non produce onde: schiarisce e basta.
      splashFactory: NoSplash.splashFactory,
      highlightColor: palette.surfaceMuted,
      splashColor: Colors.transparent,
      cupertinoOverrideTheme: NoDefaultCupertinoThemeData(
        primaryColor: palette.brand,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: palette.brand,
          foregroundColor: palette.onBrand,
          disabledBackgroundColor: palette.surfaceMuted,
          disabledForegroundColor: palette.textSecondary,
          minimumSize: const Size.fromHeight(54),
          textStyle: textTheme.labelLarge,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.brand,
          backgroundColor: palette.surfaceMuted,
          minimumSize: const Size.fromHeight(54),
          textStyle: textTheme.labelLarge?.copyWith(color: palette.brand),
          side: BorderSide.none,
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.brand,
          textStyle: textTheme.bodyLarge?.copyWith(color: palette.brand),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm + 2,
        ),
        labelStyle: textTheme.bodyLarge?.copyWith(
          color: palette.textSecondary,
        ),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(color: palette.brand),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: palette.textSecondary,
        ),
        prefixIconColor: palette.textSecondary,
        suffixIconColor: palette.textSecondary,
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(Colors.transparent),
        focusedBorder: _inputBorder(palette.brand),
        errorBorder: _inputBorder(palette.danger),
        focusedErrorBorder: _inputBorder(palette.danger),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.brand,
        linearTrackColor: palette.surfaceMuted,
        circularTrackColor: palette.surfaceMuted,
        linearMinHeight: 4,
      ),
      // Il separatore di iOS e' una linea sottilissima, non un tratto pieno.
      dividerTheme: DividerThemeData(
        color: palette.border,
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
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
      iconTheme: IconThemeData(color: palette.textSecondary),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: color),
    );
  }
}
