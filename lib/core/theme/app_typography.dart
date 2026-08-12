import 'package:flutter/material.dart';

/// La scala tipografica di CRASY.
///
/// In un'app che non ha colori, ne' schede, ne' ombre, e' la **tipografia** a
/// fare da sola tutta la gerarchia: se il premio non e' enorme e il resto
/// piccolo, non resta niente a dire cosa conta. Per questo la scala e' larga —
/// dal 64 del premio all'11 dell'occhiello — invece che una serie di misure
/// vicine fra loro.
///
/// I titoli grandi hanno tracking negativo e interlinea sotto l'uno: e' la cosa
/// che distingue un titolo *composto* da un testo semplicemente ingrandito. Le
/// etichette dei comandi vanno nella direzione opposta, maiuscole e spaziate.
abstract final class AppTypography {
  static TextTheme textTheme({
    required Color primary,
    required Color secondary,
  }) {
    return TextTheme(
      /// Il premio, quando e' l'eroe della schermata: `€500`.
      displayLarge: TextStyle(
        fontSize: 64,
        fontWeight: FontWeight.w800,
        color: primary,
        height: 0.95,
        letterSpacing: -3,
      ),

      /// Il titolo di una challenge nel feed: `DO SOMETHING CRAZY`.
      displayMedium: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        color: primary,
        height: 0.98,
        letterSpacing: -1.6,
      ),

      /// Titolo di sezione o di pagina.
      displaySmall: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: primary,
        height: 1.05,
        letterSpacing: -1,
      ),

      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.1,
        letterSpacing: -0.6,
      ),

      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.15,
        letterSpacing: -0.4,
      ),

      titleLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: -0.2,
      ),

      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: -0.1,
      ),

      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primary,
        height: 1.5,
        letterSpacing: -0.1,
      ),

      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.5,
      ),

      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.4,
      ),

      /// L'etichetta dei comandi: `PARTECIPA`. Maiuscola e spaziata — a quel
      /// corpo le maiuscole strette diventano un blocco illeggibile.
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: 1.2,
      ),

      /// La riga di servizio sotto una challenge: `4h 32m · 243 partecipanti`.
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: secondary,
        letterSpacing: 0,
      ),

      /// L'occhiello: `GLOBAL`, `ITALIA`, `IN PALIO`. Piccolissimo e spaziato.
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: secondary,
        letterSpacing: 1.6,
      ),
    );
  }
}
