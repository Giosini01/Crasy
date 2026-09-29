/// Perche' si sta segnalando qualcosa.
///
/// **Sono poche e sono secche.** Un elenco di quindici voci sembra piu' serio e
/// funziona peggio: chi segnala ha appena visto una cosa che l'ha disturbato,
/// non ha voglia di scegliere fra sfumature, e davanti a un menu lungo chiude e
/// se ne va. Sei voci si leggono tutte in un colpo d'occhio.
///
/// L'ultima e' quella che tiene in piedi le altre: qualunque cosa non stia
/// nelle cinque sopra ha comunque un posto dove finire.
enum ReportReason {
  /// Il caso piu' grave, e sta per primo apposta.
  danger(
    'Mette in pericolo qualcuno',
    'Chiede o mostra qualcosa che può far male a una persona.',
  ),

  sexual('Contenuto sessuale', 'Nudità o contenuti sessuali.'),

  violence('Violenza', 'Aggressioni, crudelta\' su persone o animali.'),

  hate('Odio o insulti', 'Prende di mira una persona o un gruppo.'),

  minor('C\'è un minore', 'Nella foto o nel video compare un minorenne.'),

  other('Altro', 'Qualcosa che non dovrebbe stare qui.');

  const ReportReason(this.label, this.detail);

  /// Come si chiama nella lista.
  final String label;

  /// La riga sotto: serve a far scegliere la voce giusta senza doverci pensare.
  final String detail;

  static ReportReason fromName(String? value) {
    for (final reason in ReportReason.values) {
      if (reason.name == value) {
        return reason;
      }
    }

    return ReportReason.other;
  }
}

/// Cosa si sta segnalando.
enum ReportTargetKind {
  /// Una foto o un video in gara.
  entry,

  /// Un commento sotto una foto.
  comment,

  /// Una persona.
  user,

  /// Una missione: il testo della consegna, non le foto.
  challenge,
}
