import 'package:flutter/material.dart';

/// Ombre.
///
/// Su fondo chiaro l'ombra fa il lavoro che sul nero facevano i bordi: separa
/// una superficie dall'altra. Sono **basse e larghe**, mai scure: un'ombra che
/// si nota e' un'ombra sbagliata, e quello che deve saltare all'occhio qui e'
/// la foto, non il riquadro che la contiene.
abstract final class AppShadows {
  /// Schede, pillole, campi in rilievo.
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x0F1A1226),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  /// L'Istantanea e i tasti che stanno per aria sopra di essa.
  static const List<BoxShadow> lifted = [
    BoxShadow(
      color: Color(0x1A1A1226),
      blurRadius: 28,
      offset: Offset(0, 12),
    ),
  ];

  /// Il cuore: la sola ombra colorata dell'app.
  static List<BoxShadow> brand(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.34),
      blurRadius: 22,
      offset: const Offset(0, 10),
    ),
  ];
}
