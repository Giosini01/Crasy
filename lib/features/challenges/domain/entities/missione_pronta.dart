import 'package:crasy/core/theme/seasons/season.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_source.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';

/// **Di che pasta e' una missione pronta**: si legge sulla scheda, in rosso,
/// prima del titolo.
///
/// Chi sfoglia cerca un umore prima di un'idea — stasera voglio una cosa
/// audace, una cosa da ridere, un ricordo — e l'etichetta gli dice dove
/// fermarsi senza leggere tutto.
enum CategoriaMissione {
  /// Da far girare la testa: sguardo, voce, faccia tosta. **Mai il corpo**:
  /// niente da togliersi, niente da far vedere. Il filtro e le regole di CRASY
  /// restano quelli di sempre.
  hot('HOT'),

  /// Quello che non si dice: confessioni, ex, figuracce. Senza nomi, sempre.
  verita('VERITÀ'),

  /// Fuori di casa, davanti alla gente. Chi compare deve essere d'accordo.
  coraggio('CORAGGIO'),

  /// O ci riesci o non ci riesci, e si vede. Mai pericolose.
  abilita('ABILITÀ'),

  /// Roba assurda da fare con una faccia serissima.
  pazza('PAZZA'),

  /// Dalla galleria: una cosa successa, che adesso non si puo' rifare.
  ricordo('RICORDO'),

  /// Solo nella stagione di Halloween, e allora in testa alla fila.
  halloween('HALLOWEEN');

  const CategoriaMissione(this.etichetta);

  final String etichetta;

  /// Come si legge dal database, o `null` se non la conosciamo.
  ///
  /// **Una categoria sconosciuta non si indovina**: e' una missione scritta per
  /// una versione piu' nuova dell'app, e chi legge la salta invece di mostrarla
  /// con l'etichetta sbagliata.
  static CategoriaMissione? fromName(String? value) {
    for (final categoria in CategoriaMissione.values) {
      if (categoria.name == value) {
        return categoria;
      }
    }

    return null;
  }
}

/// **Una missione già scritta, da lanciare con un tocco.**
///
/// ## Il problema che risolve
///
/// Partecipare è **reagire**: l'idea l'ha messa un altro, tu scatti. Lanciare è
/// **inventare**: serve un'idea, va scritta bene, e si scopre solo dopo se
/// faceva ridere. È un lavoro, e per di più si paga.
///
/// È per questo che in ogni app di questo tipo c'è un creatore ogni cento
/// spettatori, e non si risolve abbassando il prezzo: chi non ha un'idea
/// continua a non averla anche a cinquanta centesimi.
///
/// Queste tolgono l'invenzione. Si sfoglia, se ne trova una che fa venire
/// voglia, si tocca, e il modulo è già compilato: restano il premio e il
/// tasto. Il foglio bianco diventa un menù.
///
/// ## Come sono scelte
///
/// **Devono far dire "metto un euro per vedere chi lo fa".** Non "fotografa la
/// scrivania" e non "la tua foto più brutta": una cosa che si vuole vedere
/// fare agli altri. Quindi:
///
/// - **ci si gioca qualcosa**: la faccia, il coraggio, un'abilità che si ha o
///   non si ha;
/// - **si capiscono dal titolo**, senza aprire. Spesso è l'unica cosa che si
///   legge;
/// - **le hot sono audaci, non sessuali**, e le abilità sono toste, non
///   pericolose: passano tutte il filtro dei contenuti, e c'e' una prova che
///   lo controlla;
/// - **nessuno finisce in un video senza saperlo**, e i video stanno nei venti
///   secondi di [MediaKind.maxVideoDuration];
/// - **i ricordi sono da grandi**: niente foto di quando si era bambini, che
///   in un'app per maggiorenni sono foto di minori.
///
/// ## Dove stanno
///
/// Nel database, in `missioniPronte`: si cambiano senza pubblicare un'app, e se
/// una non va bene si toglie subito. Il file da cui nascono è
/// `functions/dati/missioni_pronte.json`, e la prova in
/// `missione_pronta_test.dart` lo passa dal filtro riga per riga. L'elenco qui
/// sotto ([tutte]) è solo il ripiego per quando il database non risponde.
class MissionePronta {
  const MissionePronta({
    required this.titolo,
    required this.consegna,
    required this.categoria,
    this.mediaKind = MediaKind.photo,
    this.source = ChallengeSource.instant,
  });

  /// Il titolo, già nella forma in cui finirà nella gara.
  ///
  /// Sta sotto i sessanta caratteri che il modulo accetta, e c'è un controllo
  /// che lo verifica: una missione pronta che non passa la validazione del
  /// modulo è peggio di nessuna missione pronta — si tocca, si compila da
  /// sola, e il tasto per mandarla resta spento senza che si capisca perché.
  final String titolo;

  /// La consegna: cosa deve fare chi partecipa, in una riga.
  final String consegna;

  final CategoriaMissione categoria;

  final MediaKind mediaKind;

  /// Quasi tutte sono **istantanee**, e non è una svista: è quello che CRASY
  /// è. Quelle d'archivio chiedono una cosa che adesso non si può fare — una
  /// foto di una vacanza andata male non si scatta oggi.
  final ChallengeSource source;

  /// **Quante se ne consigliano alla volta.**
  static const int quanteAllaVolta = 10;

  /// **Ogni quanto cambiano.** Chi riapre la schermata dopo dieci minuti ne
  /// trova altre dieci; dentro la stessa schermata non si muovono mai.
  static const Duration ogni = Duration(minutes: 10);

  /// **Da dove comincia il giro di adesso, per questa persona.**
  ///
  /// Un conto e non un ricordo: non c'è niente da salvare, e sullo stesso
  /// account dà lo stesso risultato su tutti i telefoni. Ogni dieci minuti si
  /// avanza di dieci posti, quindi per finire il catalogo ci vuole un bel po' e
  /// le stesse tornano solo dopo averle viste tutte.
  ///
  /// **Si parte da un punto diverso per ognuno**, ed è quello che tiene viva la
  /// home: se tutti vedessero le stesse dieci, si lancerebbe dieci volte la
  /// stessa gara.
  static int postoDelGiro({
    required String chi,
    required DateTime quando,
    required int totale,
  }) {
    if (totale <= 0) {
      return 0;
    }

    final giro = quando.millisecondsSinceEpoch ~/ ogni.inMilliseconds;
    var partenza = 0;

    for (final unita in chi.codeUnits) {
      partenza = (partenza * 31 + unita) % 1000000007;
    }

    return (partenza + giro * quanteAllaVolta) % totale;
  }

  /// **Le stesse missioni, una per tipo a giro.**
  ///
  /// Le prime tre sono le uniche che si vedono senza scorrere, e devono essere
  /// diverse fra loro. Si apre con una hot, quando c'è: è quella che ferma il
  /// pollice.
  static List<MissionePronta> aTurno(List<MissionePronta> missioni) {
    final perTipo = <CategoriaMissione, List<MissionePronta>>{};

    for (final missione in missioni) {
      perTipo.putIfAbsent(missione.categoria, () => []).add(missione);
    }

    return _aTurno(perTipo, CategoriaMissione.values);
  }

  /// Quelle della stagione di adesso, che entrano in testa alla fila: è il
  /// momento in cui una missione col costume la vuole lanciare chiunque.
  static List<MissionePronta> diStagione(DateTime quando) {
    return Season.accese && Season.of(quando) == Season.halloween
        ? diHalloween
        : const [];
  }

  /// **Quelle di oggi: il ripiego quando il database non risponde.**
  ///
  /// L'elenco e' sempre quello, cambia l'ordine — e cambia **una volta al
  /// giorno**, non a ogni apertura.
  ///
  /// ## A turno, una per tipo
  ///
  /// Le prime tre sono le uniche che si vedono senza scorrere, e devono essere
  /// **diverse**: una hot, un ricordo, una abilità — non tre foto del frigo. Le
  /// missioni si mescolano dentro ogni tipo, i tipi si alternano, e quale tipo
  /// apre la fila cambia anche lui col giorno.
  static List<MissionePronta> diOggi([DateTime? quando]) {
    final oggi = quando ?? DateTime.now();

    // Il giorno come un numero solo. Non l'ora: dentro la stessa giornata
    // l'ordine non si deve muovere.
    final seme = oggi.year * 10000 + oggi.month * 100 + oggi.day;

    final perTipo = <CategoriaMissione, List<MissionePronta>>{};

    for (final missione in [...tutte, ...diStagione(oggi)]) {
      perTipo.putIfAbsent(missione.categoria, () => []).add(missione);
    }

    for (final elenco in perTipo.values) {
      elenco.sort(
        (una, altra) => _posto(una, seme).compareTo(_posto(altra, seme)),
      );
    }

    // L'ordine dei tipi: Halloween davanti quando c'e', gli altri ruotano col
    // giorno.
    final tipi = [
      for (final tipo in CategoriaMissione.values)
        if (tipo != CategoriaMissione.halloween && perTipo.containsKey(tipo))
          tipo,
    ];
    final giro = seme % tipi.length;
    final ordine = [
      if (perTipo.containsKey(CategoriaMissione.halloween))
        CategoriaMissione.halloween,
      ...tipi.skip(giro),
      ...tipi.take(giro),
    ];

    return _aTurno(perTipo, ordine);
  }

  /// Una per tipo a giro, nell'ordine dato, finché ce ne sono.
  static List<MissionePronta> _aTurno(
    Map<CategoriaMissione, List<MissionePronta>> perTipo,
    List<CategoriaMissione> ordine,
  ) {
    final fila = <MissionePronta>[];
    final quante = perTipo.values.fold<int>(0, (n, e) => n + e.length);

    for (var turno = 0; fila.length < quante; turno++) {
      for (final tipo in ordine) {
        final elenco = perTipo[tipo];

        if (elenco != null && turno < elenco.length) {
          fila.add(elenco[turno]);
        }
      }
    }

    return fila;
  }

  /// Il posto di una missione nell'ordine di un certo giorno.
  ///
  /// Si usa `hashCode` della stringa? No: in Dart non e' garantito uguale fra
  /// un avvio e l'altro, quindi due telefoni potrebbero ordinarle in modo
  /// diverso lo stesso giorno. Questo conto invece da' sempre lo stesso
  /// numero.
  static int _posto(MissionePronta missione, int seme) {
    var somma = seme;

    for (final unita in missione.titolo.codeUnits) {
      somma = (somma * 31 + unita) % 1000000007;
    }

    return somma;
  }

  /// **Le scorte: le migliori del catalogo, per quando il database non
  /// risponde.** Sono copie di righe di `functions/dati/missioni_pronte.json`, e
  /// una prova controlla che lo restino.
  static const List<MissionePronta> tutte = [
    // --- HOT: sguardo, voce, faccia tosta. Mai il corpo. -------------------------
    MissionePronta(
      titolo: 'TUTTO VESTITO, MA FAI CALDO LO STESSO',
      consegna:
          'Cappotto, sciarpa, quello che vuoi: zero pelle, tutto '
          'atteggiamento. Vince chi ci fa aprire la finestra.',
      categoria: CategoriaMissione.hot,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'TOGLITI UN GUANTO COME IN GILDA',
      consegna:
          'Un guanto solo, dito per dito, guardando in camera. Ci si '
          'ferma lì: è già troppo.',
      categoria: CategoriaMissione.hot,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'LA LISTA DELLA SPESA PIÙ SEDUCENTE',
      consegna:
          'Leggila a bassa voce, lentissimo, come una dichiarazione. Chi '
          'ride è fuori.',
      categoria: CategoriaMissione.hot,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'SCRIVI A CHI TI PIACE, ADESSO',
      consegna:
          'Una riga sola, quella che rimandi da mesi. Screenshot col nome '
          'coperto. Se risponde, vale doppio.',
      categoria: CategoriaMissione.hot,
      source: ChallengeSource.archive,
    ),
    MissionePronta(
      titolo: 'ANNODA IL PICCIOLO CON LA LINGUA',
      consegna:
          'Una ciliegia, zero mani, venti secondi. Alla fine mostra il '
          'nodo, con la faccia di chi lo sapeva già.',
      categoria: CategoriaMissione.hot,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'LA SCUSA PER RESTARE ANCORA UN PO\'',
      consegna:
          'Fine serata, sei sulla porta, devi andare. Dicci la frase con '
          'cui non te ne vai.',
      categoria: CategoriaMissione.hot,
      mediaKind: MediaKind.video,
    ),

    // --- VERITÀ: quello che non si dice, senza nomi. -----------------------------
    MissionePronta(
      titolo: 'IL TUO EX IN TRE PAROLE',
      consegna: 'Senza nomi, guardando in camera. Vince chi ci fa dire: ahia.',
      categoria: CategoriaMissione.verita,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'IL RED FLAG CHE NASCONDI',
      consegna:
          'Confessalo in dieci secondi, con un sorriso. Vince il più '
          'preoccupante.',
      categoria: CategoriaMissione.verita,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'LA BUGIA PIÙ GROSSA PER FAR COLPO',
      consegna:
          'Quella che hai raccontato davvero per conquistare qualcuno. E '
          'com\'è finita.',
      categoria: CategoriaMissione.verita,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'IL NO PIÙ BRUTALE CHE HAI RICEVUTO',
      consegna:
          'Lo screenshot del rifiuto peggiore, con i nomi coperti. Vince '
          'chi ha sofferto di più.',
      categoria: CategoriaMissione.verita,
      source: ChallengeSource.archive,
    ),
    MissionePronta(
      titolo: 'QUANTO TI PIACI DA 1 A 10',
      consegna:
          'Dì il numero guardando in camera, e difendilo. Vince chi ci '
          'convince.',
      categoria: CategoriaMissione.verita,
      mediaKind: MediaKind.video,
    ),

    // --- CORAGGIO: fuori di casa, davanti alla gente. ----------------------------
    MissionePronta(
      titolo: 'VENDI UNA MONETA DA 1 EURO A 2 EURO',
      consegna:
          'Convinci qualcuno a comprarla. Riprendi te, e l\'altra persona '
          'solo se è d\'accordo.',
      categoria: CategoriaMissione.coraggio,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'FATTI CANTARE TANTI AUGURI DA SCONOSCIUTI',
      consegna:
          'Non è il tuo compleanno. Bar, piazza, dove vuoi: chi canta '
          'deve sapere che lo stai riprendendo.',
      categoria: CategoriaMissione.coraggio,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'RASATI METÀ BARBA E VAI A COMPRARE IL PANE',
      consegna:
          'Una guancia sì e una no. Foto davanti al forno. Se la barba '
          'non ce l\'hai, disegnala.',
      categoria: CategoriaMissione.coraggio,
    ),
    MissionePronta(
      titolo: 'CHIEDI UN CHILO DI WI-FI AL FRUTTIVENDOLO',
      consegna:
          'Serio, fino in fondo. Riprendi solo te, poi raccontaci la '
          'risposta.',
      categoria: CategoriaMissione.coraggio,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'CHIAMA I TUOI E DILLO, ADESSO',
      consegna:
          'Una telefonata, tre parole: ti voglio bene. Riprendi solo la '
          'tua faccia.',
      categoria: CategoriaMissione.coraggio,
      mediaKind: MediaKind.video,
    ),

    // --- ABILITÀ: o ci riesci o non ci riesci. -----------------------------------
    MissionePronta(
      titolo: 'TRE BOTTIGLIE IN PIEDI DI FILA',
      consegna: 'Bottle flip, tre di fila, in un video solo e senza tagli.',
      categoria: CategoriaMissione.abilita,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'TRENTATRÉ TRENTINI SENZA SBAGLIARE',
      consegna:
          'Tre volte di fila, sempre più veloce. Al primo inciampo sei '
          'fuori.',
      categoria: CategoriaMissione.abilita,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'DIECI MONETE SUL GOMITO',
      consegna:
          'Impilale sul gomito e prendile al volo con una mano. Contale '
          'alla fine.',
      categoria: CategoriaMissione.abilita,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'UN CERCHIO PERFETTO A MANO LIBERA',
      consegna:
          'Un colpo solo, penna su foglio, senza compasso. Foto del '
          'cerchio.',
      categoria: CategoriaMissione.abilita,
    ),
    MissionePronta(
      titolo: 'VENTI SECONDI SENZA MAI DIRE LA LETTERA E',
      consegna: 'Parla di quello che vuoi. Chi guarda conta gli errori.',
      categoria: CategoriaMissione.abilita,
      mediaKind: MediaKind.video,
    ),

    // --- PAZZA: assurde, con una faccia serissima. -------------------------------
    MissionePronta(
      titolo: 'INTERVISTA UN PICCIONE',
      consegna:
          'Microfono finto, domande serie, piccione vero. Non toccarlo: '
          'se se ne va, l\'intervista è finita.',
      categoria: CategoriaMissione.pazza,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'L\'OSCAR PER LA LAVATRICE',
      consegna:
          'Hai vinto l\'Oscar per aver fatto il bucato. Ringrazia tutti. '
          'Lacrime obbligatorie.',
      categoria: CategoriaMissione.pazza,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'TITANIC IN VENTI SECONDI',
      consegna:
          'Tutta la trama, con quello che hai intorno. Il finale deve '
          'commuovere.',
      categoria: CategoriaMissione.pazza,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'RICREA UN QUADRO FAMOSO',
      consegna:
          'La Gioconda, L\'Urlo, quello che vuoi, con quello che hai '
          'intorno.',
      categoria: CategoriaMissione.pazza,
    ),
    MissionePronta(
      titolo: 'IL TANGO COL MOCIO',
      consegna: 'Il mocio è il tuo partner. Casquè finale obbligatorio.',
      categoria: CategoriaMissione.pazza,
      mediaKind: MediaKind.video,
    ),

    // --- RICORDO: dalla galleria, e da grandi. -----------------------------------
    MissionePronta(
      titolo: 'LA FOTO DELLE 4 DI NOTTE',
      consegna:
          'Quella scattata a fine serata, che non ricordi di aver fatto. '
          'Più è senza senso, più vale.',
      categoria: CategoriaMissione.ricordo,
      source: ChallengeSource.archive,
    ),
    MissionePronta(
      titolo: 'LA FOTO PROFILO PIÙ BUGIARDA',
      consegna:
          'Quella in cui sembri un\'altra persona. Vince chi dal vivo non '
          'si riconoscerebbe.',
      categoria: CategoriaMissione.ricordo,
      source: ChallengeSource.archive,
    ),
    MissionePronta(
      titolo: 'LA STORIA A CUI NON CREDE NESSUNO',
      consegna: 'La foto che la prova, e una riga per raccontarla.',
      categoria: CategoriaMissione.ricordo,
      source: ChallengeSource.archive,
    ),
    MissionePronta(
      titolo: 'LA FOTO CON IL VIP CHE HAI INCONTRATO',
      consegna: 'Provalo. Vince chi ci fa dire: ma davvero?',
      categoria: CategoriaMissione.ricordo,
      source: ChallengeSource.archive,
    ),
  ];

  /// **Le missioni di Halloween**: si aggiungono in testa alla fila solo nella
  /// stagione. Vedi [diOggi].
  static const List<MissionePronta> diHalloween = [
    MissionePronta(
      titolo: 'IL TUO COSTUME DI HALLOWEEN',
      consegna:
          'Dalla testa ai piedi. Fatto in casa vale doppio, comprato al '
          'supermercato vale lo stesso se lo porti con convinzione.',
      categoria: CategoriaMissione.halloween,
    ),
    MissionePronta(
      titolo: 'LA TUA FACCIA DA ZOMBIE',
      consegna:
          'Trucco, luci, smorfia: hai cinque minuti per fare paura con '
          'quello che hai in casa.',
      categoria: CategoriaMissione.halloween,
    ),
    MissionePronta(
      titolo: 'LA ZUCCA INTAGLIATA PIÙ BRUTTA',
      consegna:
          'Intagliala e fotografala accesa, al buio. Più fa ridere invece '
          'di fare paura, più vale.',
      categoria: CategoriaMissione.halloween,
    ),
    MissionePronta(
      titolo: 'L\'URLO DA FILM DELL\'ORRORE',
      consegna:
          'Dieci secondi di urlo da protagonista di un horror, dove sei '
          'adesso. Vince chi ci fa saltare dalla sedia.',
      categoria: CategoriaMissione.halloween,
      mediaKind: MediaKind.video,
    ),
  ];
}
