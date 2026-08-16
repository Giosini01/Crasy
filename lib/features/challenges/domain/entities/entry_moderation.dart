/// Lo stato del controllo su una foto mandata in gara.
///
/// Le foto le carica la gente e le guardano tutti: **qualcuno deve averle
/// guardate prima**. Nudita' e contenuti sessuali non sono ammessi, e in
/// un'app con dei premi in denaro non basta scriverlo nelle regole — serve un
/// controllo che avvenga davvero, prima che la foto sia visibile.
///
/// Il controllo lo fa il server, non l'app: un controllo che gira sul telefono
/// di chi carica e' un controllo che chi carica puo' saltare.
enum EntryModeration {
  /// Caricata, non ancora controllata. La vede **solo chi l'ha mandata**.
  pending,

  /// Controllata e ammessa: e' in gara e la vedono tutti.
  approved,

  /// Rifiutata. Non si vede, non prende fiamme, non vince.
  rejected;

  static EntryModeration fromName(String? value) {
    for (final status in EntryModeration.values) {
      if (status.name == value) {
        return status;
      }
    }

    // Le partecipazioni scritte prima che questo campo esistesse non hanno
    // nulla da nascondere: erano state accettate quando il controllo non c'era.
    // Trattarle come "in attesa" le farebbe sparire tutte insieme.
    return EntryModeration.approved;
  }
}

/// Se il controllo automatico e' acceso.
///
/// **Adesso e' spento, e va detto invece che nascosto.** Il controllo vero gira
/// in una Cloud Function che usa il riconoscimento immagini di Google, e le
/// Cloud Function richiedono il piano a consumo su Firebase. Finche' quello non
/// e' attivo la funzione non puo' girare, e una foto in attesa resterebbe in
/// attesa per sempre: invisibile a tutti tranne che a chi l'ha mandata.
///
/// Con l'interruttore spento le foto nascono gia' ammesse. Non e' moderazione:
/// e' l'app di prima, con l'impianto pronto. Accendendolo — dopo aver attivato
/// il piano e la Vision API — le foto passano dal controllo prima di farsi
/// vedere, e nel codice non cambia nient'altro.
///
///     flutter run --dart-define=CRASY_PHOTO_MODERATION=true
const bool photoModerationEnabled = bool.fromEnvironment(
  'CRASY_PHOTO_MODERATION',
);
