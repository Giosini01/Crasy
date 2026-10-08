import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/seasons/christmas_skin.dart';
import 'package:crasy/core/theme/seasons/halloween_skin.dart';
import 'package:crasy/core/theme/seasons/season.dart';
import 'package:flutter/material.dart';

/// **Quello che una stagione ha il permesso di cambiare.**
///
/// Poche cose, e poche di proposito: il segno della schermata d'apertura, il
/// segno dell'attesa, un velo sopra la pagina, qualche tasto e il blocco di
/// una missione. **Il carattere non si tocca mai**: e' quello di CRASY tutto
/// l'anno. Non c'e' un metodo per
/// cambiare i testi, i colori dei bottoni o la disposizione di una schermata —
/// una stagione che puo' toccare tutto, in due anni, diventa un secondo tema da
/// mantenere accanto al primo.
///
/// ## **La fiamma non si sostituisce: si accompagna**
///
/// Il primo giro di questo livello scambiava la fiamma con una ragnatela, e era
/// sbagliato nel modo peggiore — la fiamma e' il marchio. Un'app che per un mese
/// si apre su un segno che non e' il suo e' un mese in cui nessuno impara come
/// si chiama, e quel mese e' proprio quello in cui esce.
///
/// Quindi i metodi **ricevono il segno di sempre** e tornano quello che gli sta
/// intorno. La fiamma entra da una parte ed esce dall'altra: la ragnatela le si
/// mette dietro, non al posto suo. Una stagione aggiunge; se toglie, non e' una
/// stagione — e' un'altra app.
///
/// Chi non ha niente da aggiungere torna quello che ha ricevuto, e [nessuna] fa
/// esattamente questo da tutti i metodi: fuori stagione l'app e' quella di
/// prima, oggetto per oggetto.
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

  /// Cosa sta attorno alla **fiamma della schermata d'apertura**.
  ///
  /// [fiamma] e' il segno di sempre, e torna in mezzo a quello che si aggiunge:
  /// davanti, non dietro a niente. [misura] e [colore] sono quelli con cui e'
  /// stata disegnata, cosi' che quello che le si mette attorno sia in scala con
  /// lei invece di dimensionarsi da solo.
  Widget accompagnaApertura(
    Widget fiamma, {
    required double misura,
    required Color colore,
  }) => fiamma;

  /// Cosa sta attorno alla **fiamma piccola dell'attesa**.
  Widget accompagnaAttesa(
    Widget fiamma, {
    required double misura,
    required Color colore,
  }) => fiamma;

  /// Quello che gira attorno alla fiamma dell'attesa, al posto dell'arco.
  ///
  /// Qui si sostituisce, e si puo': l'arco non e' il marchio — e' un modo di
  /// dire "sto lavorando", e una tela che gira lo dice uguale.
  ///
  /// [giro] va da 0 a 1 ed e' un giro intero.
  CustomPainter? giostraDAttesa({
    required double giro,
    required AppPalette palette,
  }) => null;

  /// Un segno di stagione su **un tasto**, e non su tutti.
  ///
  /// [seme] e' una parola stabile — l'identificativo di una gara — e serve a far
  /// decidere **sempre la stessa cosa per lo stesso tasto**. Due ragioni, e la
  /// seconda e' quella vera: a caso, il segno salterebbe da un tasto all'altro a
  /// ogni ridisegno, cioe' a ogni scorrimento dell'elenco; e un segno su *ogni*
  /// tasto non e' piu' un dettaglio di stagione, e' una cornice — che e' il modo
  /// in cui una decorazione diventa un elemento dell'interfaccia e smette di
  /// farsi notare.
  ///
  /// Qualche tasto, sparso. Gli altri restano quelli di sempre.
  Widget decoraTasto(Widget tasto, {required String seme}) => tasto;

  /// Un segno di stagione **dentro il blocco di una missione**: una ragnatela
  /// nell'angolo, un ragno appeso. Come per [decoraTasto], [seme] fa decidere
  /// sempre la stessa cosa per la stessa missione.
  ///
  /// Chi decora lascia passare i tocchi: il blocco si apre toccandolo.
  Widget decoraMissione(Widget missione, {required String seme}) => missione;

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
