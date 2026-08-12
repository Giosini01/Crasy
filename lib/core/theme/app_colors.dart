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
  /// Il rosso della fiamma, preso dal logotipo.
  ///
  /// Non e' un rosso scelto a tavolino: e' il colore campionato dalle fiamme
  /// della "sy" di `assets/brand/crasy-wordmark.png`, la tinta piu' frequente
  /// dei quasi centomila pixel di fiamma. Il marchio e l'interfaccia usano
  /// letteralmente lo stesso colore, che e' l'unico modo perche' un accento
  /// diventi riconoscibile.
  static const crasyFlame = Color(0xFFFC3000);

  /// Lo stesso fuoco, piu' in fondo alla fiamma.
  ///
  /// Serve a **un solo scopo**: fare da riempimento sotto il testo bianco.
  /// [crasyFlame] su bianco ha un contrasto di 3,8:1 — abbastanza per un premio
  /// scritto a 64 punti, non abbastanza per l'etichetta di un bottone a 14. Qui
  /// si sale a 4,8:1, che passa la soglia.
  ///
  /// Non e' un secondo colore: e' la stessa tinta a una profondita' diversa,
  /// come le due zone di una fiamma vera. La regola resta una — chi scrive del
  /// testo bianco sopra il rosso usa questo, tutti gli altri usano quello.
  static const crasyFlameDeep = Color(0xFFE02200);

  /// La fiamma al 6% su bianco, precalcolata per restare `const`. Serve al
  /// fondo degli stati attivi, dove il rosso pieno griderebbe.
  static const crasyFlameTint = Color(0xFFFFEFEB);

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
