/// L'eta' minima per stare su CRASY.
///
/// **Diciotto anni, e non e' un dettaglio burocratico.** Qui girano soldi veri e
/// si chiede alla gente di uscire e fare qualcosa di assurdo per vincerli: e'
/// esattamente il tipo di spinta che a un ragazzino non va data. Un maggiorenne
/// che fa una scemenza per cento euro se ne assume la responsabilita'; un
/// quindicenne no.
///
/// Va detto con chiarezza cosa questo controllo **non** e': una data di nascita
/// che uno si scrive da solo non e' una verifica dell'eta'. Ferma chi e'
/// onesto e chi non ci ha pensato, non chi vuole mentire. Una verifica vera
/// richiede un documento, e quella e' una decisione di prodotto e di privacy da
/// prendere prima di aprire l'app al pubblico.
abstract final class AgePolicy {
  static const int minimumAge = 18;

  /// L'eta' compiuta a [now], contando il compleanno.
  static int ageAt(DateTime birthDate, {DateTime? now}) {
    final today = now ?? DateTime.now();
    var age = today.year - birthDate.year;

    // Il compleanno di quest'anno non e' ancora arrivato: un anno in meno.
    final hadBirthday =
        today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);

    if (!hadBirthday) {
      age -= 1;
    }

    return age;
  }

  static bool isAdult(DateTime birthDate, {DateTime? now}) {
    return ageAt(birthDate, now: now) >= minimumAge;
  }

  /// L'ultima data di nascita che risulta maggiorenne oggi.
  ///
  /// Serve al selettore di data: gli si dice fin dove puo' arrivare, cosi' chi
  /// e' minorenne **non riesce nemmeno a scegliere** una data che poi verrebbe
  /// rifiutata.
  static DateTime latestAdultBirthDate({DateTime? now}) {
    final today = now ?? DateTime.now();

    return DateTime(today.year - minimumAge, today.month, today.day);
  }

  static String? validate(DateTime? birthDate, {DateTime? now}) {
    if (birthDate == null) {
      return 'Inserisci la tua data di nascita.';
    }

    final today = now ?? DateTime.now();

    if (birthDate.isAfter(today)) {
      return 'La data di nascita non puo\' essere nel futuro.';
    }

    if (!isAdult(birthDate, now: today)) {
      return 'Devi avere almeno $minimumAge anni per usare CRASY.';
    }

    return null;
  }
}
