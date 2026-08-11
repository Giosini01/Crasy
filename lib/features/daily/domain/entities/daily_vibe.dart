/// L'etichetta che accompagna un'Istantanea: cosa si sta facendo, adesso.
///
/// Serve a dare **un aggancio** alla foto senza chiedere di scrivere: si tocca
/// una parola e si e' detto qualcosa. E' volutamente un elenco chiuso e corto —
/// un campo libero diventerebbe una seconda biografia, e questa app di
/// biografie non ne vuole.
///
/// Vale per una foto sola e sparisce con lei dopo un giorno.
class DailyVibe {
  const DailyVibe(this.id, this.emoji, this.label);

  /// Quello che finisce su Firestore. Sono gli **identificativi** a viaggiare,
  /// non le scritte: cosi' rinominare un'etichetta non tocca i dati gia' in
  /// giro, e le foto vecchie continuano a mostrare la cosa giusta.
  final String id;

  final String emoji;
  final String label;

  String get chip => '$emoji $label';

  static const all = <DailyVibe>[
    DailyVibe('relax', '☕', 'Relax'),
    DailyVibe('musica', '🎧', 'Musica'),
    DailyVibe('allenamento', '🏋️', 'Allenamento'),
    DailyVibe('cena', '🍕', 'Fuori a cena'),
    DailyVibe('studio', '📚', 'Studio'),
    DailyVibe('mare', '🌊', 'Mare'),
    DailyVibe('serata', '🎉', 'Serata'),
    DailyVibe('tranquilla', '😴', 'Giornata tranquilla'),
  ];

  /// Ritrova un'etichetta dal suo identificativo.
  ///
  /// Torna `null` per quelle sconosciute invece di inventarne una: se un
  /// giorno una voce viene tolta, le foto che la portavano semplicemente non
  /// mostrano niente, che e' meglio di mostrare la voce sbagliata.
  static DailyVibe? byId(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }

    for (final vibe in all) {
      if (vibe.id == id) {
        return vibe;
      }
    }

    return null;
  }

  /// Il testo gia' pronto da posare sulla foto, vuoto se non c'e' etichetta.
  static String chipOf(String? id) => byId(id)?.chip ?? '';
}
