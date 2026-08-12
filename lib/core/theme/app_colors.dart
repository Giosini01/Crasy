import 'package:flutter/material.dart';

/// I colori grezzi di CRASY.
///
/// La regola e' una sola e non si negozia: **bianco, nero, grigi, e un rosso**.
/// Il rosso non decora niente. Dice tre cose e basta — quanto si vince, cosa
/// toccare, cosa e' attivo. Se compare altrove ha gia' smesso di significare
/// qualcosa, ed e' cosi' che una palette da quattro tinte diventa una da otto.
///
/// Il colore vero lo mettono le foto delle challenge. L'interfaccia sta zitta.
abstract final class AppColors {
  /// Il rosso di CRASY.
  ///
  /// Scelto perche' regge **entrambi** i ruoli: su bianco si legge come testo,
  /// e riempito con del bianco sopra fa un bottone che si vede da lontano. Un
  /// accento che funziona solo come riempimento costringe prima o poi a
  /// inventarne un secondo per il testo, e i colori diventano due.
  static const crasyRed = Color(0xFFFF2D1A);

  /// Il rosso al 6% su bianco, precalcolato per restare `const`. Serve al
  /// fondo degli stati attivi, dove il rosso pieno griderebbe.
  static const crasyRedTint = Color(0xFFFFF0EE);

  // --- Neutrali -------------------------------------------------------------

  /// Fondo pagina: bianco pieno.
  ///
  /// Non un bianco sporco: le schermate non hanno schede da far galleggiare,
  /// quindi non serve un fondo diverso dalle superfici. Le foto cadono sul
  /// bianco e il bianco sparisce.
  static const paper = Color(0xFFFFFFFF);

  /// Riempimenti tenui: il posto di una foto che non c'e' ancora, i campi.
  static const paperMuted = Color(0xFFF4F4F5);

  /// I filetti. Sottilissimi, quasi invisibili: separano senza disegnare.
  static const line = Color(0xFFE8E8EA);

  /// Nero non assoluto. Sul bianco il nero pieno taglia, questo posa.
  static const ink = Color(0xFF0A0A0B);

  /// Il grigio del testo di servizio: tempo, partecipanti, categorie.
  static const inkSoft = Color(0xFF6B6B70);

  /// Il grigio piu' tenue, per cio' che c'e' ma non va letto per primo.
  static const inkFaint = Color(0xFFA1A1A6);
}
