/// **A che punto e' una persona nel gioco**, come lo scrive il server in
/// `gioco/{uid}`.
///
/// L'app lo legge e basta: le regole non lasciano scrivere niente da qui. Ogni
/// numero arriva gia' deciso — contatori, sfide fatte, XP, livello — e quello
/// che l'app fa e' mostrarlo.
class StatoDelGioco {
  const StatoDelGioco({
    this.xp = 0,
    this.livello = 1,
    this.sfideCompletate = 0,
    this.contatori = const {},
    this.completate = const {},
    this.giorno = '',
    this.scelteDiOggi = const [],
    this.contatoriDiOggi = const {},
    this.completateOggi = const {},
  });

  factory StatoDelGioco.fromMap(Map<String, dynamic> dati) {
    final oggi = dati['oggi'];
    final diOggi = oggi is Map
        ? Map<String, dynamic>.from(oggi)
        : const <String, dynamic>{};

    return StatoDelGioco(
      xp: _intero(dati['xp']),
      livello: _intero(dati['livello'], ripiego: 1),
      sfideCompletate: _intero(dati['sfideCompletate']),
      contatori: _numeri(dati['contatori']),
      completate: _chiavi(dati['completate']),
      giorno: dati['giorno'] as String? ?? '',
      scelteDiOggi: [
        for (final id in (diOggi['scelte'] as List?) ?? const [])
          if (id is String) id,
      ],
      contatoriDiOggi: _numeri(diOggi['contatori']),
      completateOggi: _chiavi(diOggi['completate']),
    );
  }

  final int xp;
  final int livello;

  /// Quante sfide ha fatto, di tutti i giorni e di sempre.
  final int sfideCompletate;

  /// I contatori di sempre: quante foto, quante fiamme...
  final Map<String, int> contatori;

  /// I traguardi raggiunti.
  final Set<String> completate;

  /// Il giorno delle sfide qui sotto, in Italia: `2026-12-02`.
  final String giorno;

  final List<String> scelteDiOggi;
  final Map<String, int> contatoriDiOggi;
  final Set<String> completateOggi;
}

int _intero(Object? valore, {int ripiego = 0}) =>
    valore is num ? valore.toInt() : ripiego;

Map<String, int> _numeri(Object? grezzi) {
  if (grezzi is! Map) {
    return const {};
  }

  return {
    for (final voce in grezzi.entries)
      if (voce.key is String && voce.value is num)
        voce.key as String: (voce.value as num).toInt(),
  };
}

Set<String> _chiavi(Object? grezze) {
  if (grezze is! Map) {
    return const {};
  }

  return {
    for (final chiave in grezze.keys)
      if (chiave is String) chiave,
  };
}

/// **Un premio appena arrivato**: una riga di `gioco/{uid}/xp`.
class PremioXp {
  const PremioXp({
    required this.chiave,
    required this.titolo,
    required this.xp,
    required this.permanente,
    required this.livelloDopo,
  });

  factory PremioXp.fromMap(String chiave, Map<String, dynamic> dati) {
    return PremioXp(
      chiave: chiave,
      titolo: dati['titolo'] as String? ?? '',
      xp: _intero(dati['xp']),
      permanente: dati['tipo'] == 'permanente',
      livelloDopo: _intero(dati['livelloDopo'], ripiego: 1),
    );
  }

  final String chiave;
  final String titolo;
  final int xp;

  /// Un traguardo di sempre, non una sfida del giorno.
  final bool permanente;
  final int livelloDopo;
}
