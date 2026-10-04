/// **Le stagioni di CRASY.**
///
/// Per qualche settimana l'anno l'app si veste: ragnatele a fine ottobre,
/// fiocchi a dicembre. Il resto dell'anno e' quella di sempre.
///
/// ## Perche' una stagione e non un ramo di codice
///
/// La tentazione, a ottobre, e' aprire i file e cambiare la fiamma in
/// ragnatela. Funziona, e il 2 novembre si scopre che non si sa piu' com'era
/// prima: il codice originale e' stato sovrascritto, e per tornare indietro
/// bisogna ricordarsi a mente tutto quello che si e' toccato — in dieci file
/// diversi, un mese dopo.
///
/// Qui la stagione e' **un livello sopra**. I file originali restano scritti
/// come sono: dove la stagione puo' mettere qualcosa, il codice di sempre
/// resta sotto come alternativa (`stagione ?? originale`). Spenta la stagione,
/// l'app e' esattamente quella di prima — non "quasi", letteralmente la stessa
/// riga.
///
/// E a dicembre non si rifa' niente: si aggiunge un valore qui e una pelle in
/// questa cartella.
enum Season {
  /// CRASY come e'. Bianco, nero, un rosso.
  base,

  /// Tutto ottobre, e i due giorni di novembre che gli appartengono.
  halloween,

  /// Dall'8 dicembre al 6 gennaio.
  natale;

  /// La stagione di una data.
  ///
  /// **Halloween prende tutto ottobre**, e non e' per allungare la festa: CRASY
  /// esce il 31: aprendo l'app in anteprima a inizio mese, chi la guarda deve
  /// vedere quella che uscira', non quella di settembre che diventa un'altra
  /// cosa la settimana dopo. Una finestra che si apre il 20 vorrebbe dire due
  /// app diverse nelle tre settimane in cui si decide se spedirla.
  ///
  /// Il natale resta stretto, e li' il motivo di prima vale ancora: una
  /// decorazione che comincia a fine novembre, il 25 dicembre non la vede piu'
  /// nessuno.
  static Season of(DateTime quando) {
    final mese = quando.month;
    final giorno = quando.day;

    if (mese == 10 || (mese == 11 && giorno <= 2)) {
      return Season.halloween;
    }

    if ((mese == 12 && giorno >= 8) || (mese == 1 && giorno <= 6)) {
      return Season.natale;
    }

    return Season.base;
  }

  /// **La stagione forzata a mano.**
  ///
  /// Serve a due cose e nessuna e' un trucco: guardare la pelle di Halloween a
  /// luglio mentre la si disegna, e tenerla ferma nelle prove — una prova che
  /// legge l'orologio vero passa o cade a seconda del giorno in cui gira, che
  /// e' il modo piu' veloce di rendere inutile una prova.
  ///
  /// In produzione resta `null` e decide il calendario.
  static Season? fissata;

  /// La stagione di adesso.
  static Season get corrente => fissata ?? of(DateTime.now());
}
