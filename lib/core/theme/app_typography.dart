import 'package:flutter/material.dart';

abstract final class AppTypography {
  /// Scala tipografica costruita sui tagli di iOS.
  ///
  /// Il riferimento e' il corpo del testo a 17: e' la misura del testo di
  /// sistema su iPhone, e usarne una piu' piccola e' una delle ragioni per cui
  /// un'app Flutter "sa di Android". I titoli seguono i tagli delle Large
  /// Title (34) e delle Title (28, 22, 20), con tracking appena negativo
  /// invece dei valori marcati di Material.
  static TextTheme textTheme({
    required Color primary,
    required Color secondary,
  }) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.1,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.15,
        letterSpacing: -0.4,
      ),
      displaySmall: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.2,
        letterSpacing: -0.3,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.25,
        letterSpacing: -0.3,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.25,
        letterSpacing: -0.2,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: primary,
        letterSpacing: -0.2,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: primary,
        height: 1.4,
        letterSpacing: -0.2,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.4,
        letterSpacing: -0.1,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.35,
      ),
      labelLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: -0.2,
      ),
      labelMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: secondary,
        letterSpacing: -0.1,
      ),
      // Intestazione di sezione: su iOS e' piccola, maiuscola e grigia.
      labelSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: secondary,
        letterSpacing: 0.4,
      ),
    );
  }
}
