import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/seasons/christmas_skin.dart';
import 'package:crasy/core/theme/seasons/halloween_skin.dart';
import 'package:crasy/core/theme/seasons/season.dart';
import 'package:flutter/material.dart';

/// **Quello che una stagione ha il permesso di cambiare.**
///
/// Tre cose, e sono poche di proposito: il segno della schermata d'apertura, il
/// segno dell'attesa, e un velo sopra la pagina. Non c'e' un metodo per
/// cambiare i testi, i colori dei bottoni o la disposizione di una schermata —
/// una stagione che puo' toccare tutto, in due anni, diventa un secondo tema da
/// mantenere accanto al primo.
///
/// ## Ogni metodo puo' dire "niente"
///
/// Tornano `null`, e [SeasonSkin.nessuna] torna `null` da tutti. E' questo che
/// tiene intatto il codice di sempre: chi chiama scrive
/// `pelle.segnoDApertura(...) ?? Icon(Icons.local_fire_department)`, quindi la
/// fiamma resta scritta dov'era. Fuori stagione quel ramo e' l'unico che gira,
/// e l'app non sa nemmeno di avere un livello sopra.
abstract class SeasonSkin {
  const SeasonSkin();

  /// La pelle di adesso, decisa dal calendario.
  static SeasonSkin get corrente => perStagione(Season.corrente);

  static SeasonSkin perStagione(Season stagione) => switch (stagione) {
    Season.base => const _NessunaStagione(),
    Season.halloween => const HalloweenSkin(),
    Season.natale => const ChristmasSkin(),
  };

  /// La pelle spenta: CRASY come e'.
  static const SeasonSkin nessuna = _NessunaStagione();

  /// Il segno grande al centro della schermata d'apertura, al posto della
  /// fiamma.
  ///
  /// Arriva [misura] e [colore] gia' calcolati da chi chiama, e chi disegna li
  /// usa senza discutere: l'apertura fa crescere e ondeggiare quello che gli si
  /// mette dentro, e un segno che si dimensiona da solo si scollerebbe
  /// dall'animazione.
  Widget? segnoDApertura({required double misura, required Color colore}) =>
      null;

  /// Il segno fermo al centro dell'attesa, al posto della fiamma piccola.
  Widget? segnoDAttesa({required double misura, required Color colore}) => null;

  /// Quello che gira attorno al segno dell'attesa, al posto dell'arco.
  ///
  /// [giro] va da 0 a 1 ed e' un giro intero.
  CustomPainter? giostraDAttesa({
    required double giro,
    required AppPalette palette,
  }) => null;

  /// Il velo sopra la pagina: ragnatele agli angoli, neve, quel che sia.
  ///
  /// Torna [pagina] cosi' com'e' quando la stagione non ha niente da mettere.
  /// Chi decora **deve** lasciar passare i tocchi: il velo copre tutta la
  /// schermata, e uno che li ferma rende l'app inutilizzabile per due settimane.
  Widget decora(BuildContext context, Widget pagina) => pagina;
}

class _NessunaStagione extends SeasonSkin {
  const _NessunaStagione();
}

extension SeasonSkinContext on BuildContext {
  /// La pelle della stagione.
  ///
  /// Passa dal contesto anche se non lo legge: il giorno in cui la stagione
  /// diventa una cosa che si sceglie nelle impostazioni, cambia solo questo
  /// corpo e nessuna delle chiamate.
  SeasonSkin get stagione => SeasonSkin.corrente;
}
