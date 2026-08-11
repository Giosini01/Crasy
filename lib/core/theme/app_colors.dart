import 'package:flutter/material.dart';

/// Colori grezzi dell'app.
///
/// C'e' **una sola tinta di viola**: [iris]. Non esistono accenti secondari,
/// gradienti o ramp. Il viola non decora: dice "questa e' l'azione" oppure
/// "questo e' selezionato". Tutto il resto e' bianco, biancastro o grigio, e
/// il colore vero lo mettono le foto.
///
/// L'app ha un solo aspetto, chiaro, anche quando il sistema e' in tema scuro.
abstract final class AppColors {
  /// Il viola del marchio. Su bianco ha un contrasto di 7.3:1, quindi regge
  /// sia come riempimento con testo bianco sopra sia come colore di testo.
  static const iris = Color(0xFF8A00C4);

  /// [iris] al 10% posato su bianco, precalcolato per restare `const`.
  static const irisTint = Color(0xFFF3E6F9);

  // --- Neutrali -------------------------------------------------------------

  /// Fondo pagina: un bianco appena sporco di viola.
  ///
  /// Non e' bianco pieno di proposito: le schede sono bianche, e su un fondo
  /// bianco identico sparirebbero. Mezzo punto di differenza basta a farle
  /// **galleggiare** senza disegnare un bordo attorno a ognuna.
  static const background = Color(0xFFF7F6F9);

  /// Le schede e i fogli: bianco pieno.
  static const surface = Color(0xFFFFFFFF);

  /// Riempimenti tenui: campi, pillole a riposo, tracce di progresso.
  static const surfaceMuted = Color(0xFFF0EFF3);

  /// Separatori e contorni, dove servono ancora.
  static const border = Color(0xFFE6E4EC);

  /// Nero non assoluto: sul bianco il nero pieno taglia, questo posa.
  static const textPrimary = Color(0xFF0B0B0F);

  static const textSecondary = Color(0xFF6E6E78);

  // --- Errori ---------------------------------------------------------------

  /// systemRed.
  static const danger = Color(0xFFFF3B30);
}
