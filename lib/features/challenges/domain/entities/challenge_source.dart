/// Da dove deve arrivare la roba che si manda in gara.
///
/// **E' una scelta di chi lancia la gara, e chi partecipa non la puo'
/// cambiare.** Non e' una comodita' offerta al partecipante: e' una regola del
/// gioco, come il premio e la scadenza. Chi mette i soldi decide se sta
/// chiedendo una cosa fatta **adesso** o una cosa che uno **ha gia'**, e sono
/// due gare diverse.
///
/// ## Perche' esistono tutt'e due
///
/// Per un anno CRASY ha avuto una regola sola, e giusta: si scatta sul momento.
/// Potendo pescare dal rullino si vincerebbe con la foto piu' bella che si ha
/// in archivio invece che con quella piu' folle che si e' avuto il coraggio di
/// fare.
///
/// Quella regola pero' rende **impossibili** delle gare che sarebbero le piu'
/// divertenti di tutte: *il video della tua figura di merda piu' grande* non lo
/// giri a comando. O ce l'hai o non ce l'hai — e quel materiale esiste, sui
/// telefoni di tutti, e oggi non ha nessun posto dove andare.
///
/// ## Perche' non si mescolano mai
///
/// **Una gara accetta una strada sola, e l'altra non e' nemmeno raggiungibile.**
/// Lasciando scegliere al partecipante, la gara istantanea morirebbe da sola:
/// davanti a "scatta adesso" oppure "prendi quella che hai gia'", vince sempre
/// la seconda, e nel giro di un mese CRASY sarebbe un'app di foto come tutte le
/// altre. Lo scatto sul momento e' l'unica cosa che qui c'e' e altrove no.
///
/// C'e' anche una ragione piu' concreta, e ci sono dei soldi in mezzo: lo
/// scatto sul momento e' una **garanzia di autenticita' che non costa niente**.
/// Con la galleria aperta, uno scarica un video virale e vince con la figuraccia
/// di uno sconosciuto. Per questo la gara d'archivio porta un marchio ben
/// visibile: chi vota deve sapere cosa sta guardando **prima** di dare la
/// fiamma.
enum ChallengeSource {
  /// **Si scatta adesso.** Niente galleria, su nessuna piattaforma dove si
  /// possa impedirlo.
  instant('ISTANTANEA', 'Si scatta sul momento, niente galleria'),

  /// **Si pesca dall'archivio.** Niente fotocamera: quello che si cerca qui e'
  /// una cosa gia' successa, e riscattarla non avrebbe senso.
  archive('ARCHIVIO', "Si prende da quello che hai già, niente fotocamera");

  const ChallengeSource(this.label, this.spiegazione);

  /// Come si chiama sulla scheda della gara.
  final String label;

  /// La riga che spiega cosa si puo' mandare, per chi non l'ha mai vista.
  final String spiegazione;

  /// Se qui si scatta sul momento.
  bool get isInstant => this == ChallengeSource.instant;

  /// Se qui si pesca dall'archivio.
  bool get isArchive => this == ChallengeSource.archive;

  /// Come si legge dal database.
  ///
  /// **Il valore di ripiego e' [instant], e conta.** Tutte le gare scritte
  /// prima che questo campo esistesse non ce l'hanno, ed erano tutte
  /// istantanee: leggerle come tali non e' una comodita', e' la verita'. Il
  /// ripiego opposto avrebbe aperto la galleria su migliaia di gare nate
  /// chiuse.
  static ChallengeSource fromName(String? value) {
    for (final source in ChallengeSource.values) {
      if (source.name == value) {
        return source;
      }
    }

    return ChallengeSource.instant;
  }
}
