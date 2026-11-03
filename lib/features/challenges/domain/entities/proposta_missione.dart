/// **Una missione proposta, come la vede chi l'ha scritta.**
///
/// Prima di uscire una missione passa da un controllo (vedi
/// `functions/missioni.js`), e finche' non e' approvata non e' ancora una gara:
/// sta in un foglio che nessun telefono puo' leggere.
///
/// Quello che c'e' qui lo manda il server, ed e' poco apposta: **niente voto e
/// niente parole che hanno fatto scattare il filtro**. Chi potesse leggerli
/// imparerebbe in fretta come scrivere la prossima.
class PropostaMissione {
  const PropostaMissione({
    required this.id,
    required this.stato,
    required this.title,
    required this.brief,
    required this.prizeCents,
    this.challengeId,
    this.motivo = '',
  });

  /// Dalla risposta di `leggiLaMiaProposta`.
  factory PropostaMissione.fromMap(Map<Object?, Object?> dati) {
    final gara = dati['challengeId'];

    return PropostaMissione(
      id: dati['propostaId'] as String? ?? '',
      stato: dati['stato'] as String? ?? '',
      title: dati['title'] as String? ?? '',
      brief: dati['brief'] as String? ?? '',
      prizeCents: (dati['prizeCents'] as num?)?.toInt() ?? 0,
      challengeId: gara is String && gara.isNotEmpty ? gara : null,
      motivo: dati['motivo'] as String? ?? '',
    );
  }

  final String id;

  /// `daControllare`, `daConfermare`, `approvata`, `rifiutata` o `bloccata`.
  final String stato;

  final String title;
  final String brief;
  final int prizeCents;

  /// La gara nata da questa proposta, se e' gia' nata.
  final String? challengeId;

  /// Perche' una persona del team l'ha rifiutata. Vuoto negli altri casi.
  final String motivo;

  bool get approvata => stato == 'approvata';

  /// Una persona ha detto di no.
  bool get rifiutata => stato == 'rifiutata';

  /// Si e' fermata alle parole, senza che la guardasse nessuno.
  bool get bloccata => stato == 'bloccata';

  /// Non c'e' ancora una risposta: la sta guardando una persona.
  bool get inCoda => !approvata && !rifiutata && !bloccata;
}
