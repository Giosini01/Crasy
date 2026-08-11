/// Gli interessi selezionabili e il calcolo dell'affinita'.
///
/// Sono un elenco chiuso e non testo libero: "palestra" e "vado in palestra"
/// sono la stessa cosa per una persona ma due cose diverse per un confronto,
/// e senza elenco chiuso nessuna percentuale avrebbe senso.
abstract final class ProfileInterests {
  /// Quanti se ne devono scegliere almeno.
  ///
  /// Tre e' il minimo perche' il confronto dia numeri sensati: con un solo
  /// interesse a testa, due persone risultano quasi sempre incompatibili
  /// anche quando non lo sono.
  static const int minChoices = 3;

  /// Oltre questo numero si diventa compatibili con tutti, e la percentuale
  /// smette di dire qualcosa.
  static const int maxChoices = 10;

  /// Identificativo ed etichetta. L'identificativo e' quello che finisce su
  /// Firestore e non va piu' cambiato; l'etichetta si puo' riscrivere.
  static const Map<String, String> catalogue = {
    'musica': 'Musica',
    'concerti': 'Concerti',
    'cinema': 'Cinema',
    'serie': 'Serie TV',
    'libri': 'Libri',
    'arte': 'Arte',
    'teatro': 'Teatro',
    'fotografia': 'Fotografia',
    'videogiochi': 'Videogiochi',
    'tecnologia': 'Tecnologia',
    'motori': 'Motori',
    'calcio': 'Calcio',
    'palestra': 'Palestra',
    'corsa': 'Corsa',
    'yoga': 'Yoga',
    'ballo': 'Ballo',
    'cucina': 'Cucina',
    'vino': 'Vino',
    'birra': 'Birra',
    'caffe': 'Caffe',
    'viaggi': 'Viaggi',
    'mare': 'Mare',
    'montagna': 'Montagna',
    'natura': 'Natura',
    'animali': 'Animali',
    'moda': 'Moda',
    'volontariato': 'Volontariato',
    'scrittura': 'Scrittura',
    'podcast': 'Podcast',
    'faidate': 'Fai da te',
  };

  static List<String> get allIds => catalogue.keys.toList();

  /// Etichetta da mostrare. Torna l'identificativo se non e' piu' in elenco,
  /// cosi' un interesse ritirato non fa sparire la riga.
  static String labelOf(String id) => catalogue[id] ?? id;

  /// Percentuale di affinita' fra due insiemi di interessi.
  ///
  /// E' il rapporto fra quelli in comune e quelli complessivi: due persone con
  /// gli stessi identici interessi fanno 100, due che non ne condividono
  /// nessuno fanno 0. Chi sceglie molti interessi risulta un po' meno affine
  /// a tutti, ed e' corretto: avere venti interessi in comune su venti conta
  /// piu' che averne tre su tre.
  static int compatibility(Iterable<String> a, Iterable<String> b) {
    final first = a.toSet();
    final second = b.toSet();

    if (first.isEmpty || second.isEmpty) {
      return 0;
    }

    final shared = first.intersection(second).length;
    final total = first.union(second).length;

    return (shared * 100 / total).round();
  }

  /// Gli interessi condivisi, nell'ordine dell'elenco: e' quello che si
  /// mostra sotto la percentuale, ed e' cio' di cui si puo' parlare.
  static List<String> shared(Iterable<String> a, Iterable<String> b) {
    final second = b.toSet();

    return [
      for (final id in allIds)
        if (a.contains(id) && second.contains(id)) id,
    ];
  }
}
