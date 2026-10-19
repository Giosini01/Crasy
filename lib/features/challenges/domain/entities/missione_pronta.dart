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
  /// Audaci, da far colpo. **Mai sessuali**: sguardi, appuntamenti,
  /// dichiarazioni. Il filtro e le regole di CRASY restano quelli di sempre.
  hot('HOT'),

  /// Dalla galleria: una cosa successa, che adesso non si puo' rifare.
  ricordo('RICORDO'),

  /// Si fa adesso, dove sei, con quello che hai intorno.
  adesso('ADESSO'),

  /// Toste: resistere, riuscire, non ridere. Mai pericolose.
  sfida('SFIDA'),

  /// Solo nella stagione di Halloween, e allora in testa alla fila.
  halloween('HALLOWEEN');

  const CategoriaMissione(this.etichetta);

  final String etichetta;
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
/// **Devono far dire "questa la lancio io".** Non "fotografa la scrivania":
/// una cosa che si vuole vedere fare agli altri. Quindi:
///
/// - **un po' imbarazzanti, mai difficili**. Chi guarda vuole vedere qualcuno
///   che ci ha provato, non qualcuno che è bravo;
/// - **si capiscono dal titolo**, senza aprire. Spesso è l'unica cosa che si
///   legge;
/// - **le hot sono audaci, non sessuali**, e le sfide sono toste, non
///   pericolose: passano tutte il filtro dei contenuti, e c'e' una prova che
///   lo controlla;
/// - **i ricordi sono da grandi**: niente foto di quando si era bambini, che
///   in un'app per maggiorenni sono foto di minori.
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

  /// **Quelle di oggi: le stesse per tutti, diverse domani.**
  ///
  /// L'elenco e' sempre quello, cambia l'ordine — e cambia **una volta al
  /// giorno**, non a ogni apertura. Un ordine che cambia a ogni apertura e' un
  /// elenco che non si impara mai; e due amici che si parlano devono aver visto
  /// la stessa cosa: *"hai visto quella del limone?"* deve voler dire qualcosa.
  ///
  /// ## A turno, una per tipo
  ///
  /// Le prime tre sono le uniche che si vedono senza scorrere, e devono essere
  /// **diverse**: una hot, un ricordo, una sfida — non tre foto del frigo. Le
  /// missioni si mescolano dentro ogni tipo, i tipi si alternano, e quale tipo
  /// apre la fila cambia anche lui col giorno.
  ///
  /// **Nella stagione di Halloween** quelle di Halloween entrano in testa: e'
  /// il momento in cui una missione col costume la vuole lanciare chiunque.
  static List<MissionePronta> diOggi([DateTime? quando]) {
    final oggi = quando ?? DateTime.now();

    // Il giorno come un numero solo. Non l'ora: dentro la stessa giornata
    // l'ordine non si deve muovere.
    final seme = oggi.year * 10000 + oggi.month * 100 + oggi.day;
    final halloween = Season.accese && Season.of(oggi) == Season.halloween;

    final perTipo = <CategoriaMissione, List<MissionePronta>>{};

    for (final missione in [...tutte, if (halloween) ...diHalloween]) {
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

    final fila = <MissionePronta>[];
    final quante = perTipo.values.fold<int>(0, (n, e) => n + e.length);

    for (var turno = 0; fila.length < quante; turno++) {
      for (final tipo in ordine) {
        final elenco = perTipo[tipo]!;

        if (turno < elenco.length) {
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

  /// Le missioni di tutto l'anno.
  static const List<MissionePronta> tutte = [
    // --- HOT: audaci, da far colpo. Mai sessuali. ---------------------------
    MissionePronta(
      titolo: 'IL TUO SGUARDO DA 10 SU 10',
      consegna:
          'Un selfie con lo sguardo che usi quando vuoi far colpo. Niente '
          'filtri: deve bastare la faccia.',
      categoria: CategoriaMissione.hot,
    ),
    MissionePronta(
      titolo: 'OUTFIT DA PRIMO APPUNTAMENTO',
      consegna:
          'Vestiti come se stasera avessi l\'appuntamento della vita e '
          'scatta allo specchio. Vince chi ci porteremmo a cena.',
      categoria: CategoriaMissione.hot,
    ),
    MissionePronta(
      titolo: 'LA TUA FRASE PER RIMORCHIARE',
      consegna:
          'Dilla alla telecamera, guardando dritto, convinto. Vince quella '
          'che funzionerebbe davvero, o quella che fa più pena.',
      categoria: CategoriaMissione.hot,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'DICHIARATI ALLA TELECAMERA',
      consegna:
          'Dieci secondi di dichiarazione d\'amore, come nel finale di un '
          'film. A chi, lo sai solo tu.',
      categoria: CategoriaMissione.hot,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'LA POSA DA COPERTINA',
      consegna:
          'Sei sulla copertina di una rivista, dove sei adesso. Serio, '
          'convinto, fino in fondo. Ridere è vietato.',
      categoria: CategoriaMissione.hot,
    ),
    MissionePronta(
      titolo: 'IL TUO BALLO PIÙ AUDACE',
      consegna:
          'Dieci secondi del passo che tiri fuori solo alle feste, quando '
          'pensi che nessuno guardi.',
      categoria: CategoriaMissione.hot,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'LA FOTO CHE TI HA FATTO CONQUISTARE QUALCUNO',
      consegna:
          'Quella che ha funzionato. Nella foto ci sei solo tu, e il resto '
          'della storia lo immaginiamo noi.',
      categoria: CategoriaMissione.hot,
      source: ChallengeSource.archive,
    ),
    MissionePronta(
      titolo: 'IL MESSAGGIO CHE TI HA FATTO ARROSSIRE',
      consegna:
          'Lo screenshot, con nomi e foto coperti. Si deve capire perché '
          'sei arrossito.',
      categoria: CategoriaMissione.hot,
      source: ChallengeSource.archive,
    ),

    // --- RICORDO: dalla galleria, e da grandi. ------------------------------
    MissionePronta(
      titolo: 'LA FOTO PIÙ BRUTTA CHE HAI IN GALLERIA',
      consegna:
          'Cercala davvero. Quella che non hai mai fatto vedere a nessuno.',
      categoria: CategoriaMissione.ricordo,
      source: ChallengeSource.archive,
    ),
    MissionePronta(
      titolo: 'L\'ULTIMA FOTO DELLA TUA GALLERIA',
      consegna:
          'Apri la galleria e manda l\'ultima, qualunque sia. Niente scelte, '
          'niente scuse.',
      categoria: CategoriaMissione.ricordo,
      source: ChallengeSource.archive,
    ),
    MissionePronta(
      titolo: 'LA FOTO DELLE 4 DI NOTTE',
      consegna:
          'Quella scattata a fine serata, che non ricordi di aver fatto. Più '
          'è senza senso, più vale.',
      categoria: CategoriaMissione.ricordo,
      source: ChallengeSource.archive,
    ),
    MissionePronta(
      titolo: 'IL TAGLIO DI CAPELLI CHE RIMPIANGI',
      consegna:
          'Una foto di te con il taglio peggiore degli ultimi anni. '
          'Confessa.',
      categoria: CategoriaMissione.ricordo,
      source: ChallengeSource.archive,
    ),
    MissionePronta(
      titolo: 'IL PIATTO PIÙ BRUTTO CHE HAI CUCINATO',
      consegna:
          'Quello che hai avuto il coraggio di fotografare. Più fa paura, '
          'meglio è.',
      categoria: CategoriaMissione.ricordo,
      source: ChallengeSource.archive,
    ),
    MissionePronta(
      titolo: 'LA VACANZA ANDATA MALISSIMO',
      consegna:
          'Una foto sola che racconta il disastro senza bisogno di '
          'spiegazioni.',
      categoria: CategoriaMissione.ricordo,
      source: ChallengeSource.archive,
    ),
    MissionePronta(
      titolo: 'LA FOTO CHE NON HAI MAI POSTATO',
      consegna:
          'Quella che ti piace da morire ma non hai mai avuto il coraggio '
          'di mettere online. È il momento.',
      categoria: CategoriaMissione.ricordo,
      source: ChallengeSource.archive,
    ),
    MissionePronta(
      titolo: 'IL POSTO PIÙ BELLO DOVE SEI STATO',
      consegna:
          'Una foto fatta da te, non presa da internet. Si vede la '
          'differenza.',
      categoria: CategoriaMissione.ricordo,
      source: ChallengeSource.archive,
    ),

    // --- ADESSO: dove sei, con quello che hai intorno. ----------------------
    MissionePronta(
      titolo: 'LA TUA FACCIA ADESSO',
      consegna:
          'Un selfie in questo momento, com\'è venuto. Niente filtri e '
          'niente secondo tentativo.',
      categoria: CategoriaMissione.adesso,
    ),
    MissionePronta(
      titolo: 'COSA C\'È NEL TUO FRIGO',
      consegna: 'Apri il frigo e scatta. Vince il più disperato.',
      categoria: CategoriaMissione.adesso,
    ),
    MissionePronta(
      titolo: 'IL TUO LETTO, ADESSO',
      consegna:
          'Com\'è in questo momento, senza toccare niente. Si vede chi '
          'ha sistemato.',
      categoria: CategoriaMissione.adesso,
    ),
    MissionePronta(
      titolo: 'LA VISTA DALLA TUA FINESTRA',
      consegna: 'Apri e scatta, adesso. Vince quella che nessuno si aspetta.',
      categoria: CategoriaMissione.adesso,
    ),
    MissionePronta(
      titolo: 'LA COSA PIÙ STRANA CHE HAI IN BORSA',
      consegna:
          'Svuota borsa, zaino o tasche e fotografa il pezzo più assurdo. '
          'Spiegarlo non è obbligatorio.',
      categoria: CategoriaMissione.adesso,
    ),
    MissionePronta(
      titolo: 'IL TUO ANIMALE MENTRE FA UNA COSA STUPIDA',
      consegna:
          'Aspetta il momento e scatta. Se non hai un animale, va bene anche '
          'quello di qualcun altro.',
      categoria: CategoriaMissione.adesso,
    ),
    MissionePronta(
      titolo: 'IMITA QUALCUNO CHE CONOSCIAMO TUTTI',
      consegna:
          'Dieci secondi di imitazione. Non dire chi è: si capisce o non si '
          'capisce.',
      categoria: CategoriaMissione.adesso,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'BALLA PER DIECI SECONDI',
      consegna:
          'Un video dove balli, dove sei adesso. Più è fuori luogo il posto, '
          'meglio è.',
      categoria: CategoriaMissione.adesso,
      mediaKind: MediaKind.video,
    ),

    // --- SFIDA: toste, mai pericolose. -------------------------------------
    MissionePronta(
      titolo: 'MANGIA UN LIMONE SENZA SMORFIE',
      consegna:
          'Uno spicchio intero, guardando la telecamera. Vince chi tiene la '
          'faccia più ferma.',
      categoria: CategoriaMissione.sfida,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'UN MINUTO DI PLANK',
      consegna:
          'Un video solo, senza tagli, con il cronometro in vista. Chi molla '
          'prima perde anche la faccia.',
      categoria: CategoriaMissione.sfida,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'FLESSIONI IN TRENTA SECONDI',
      consegna:
          'Contale ad alta voce in un video solo. Vince chi ne fa di più, o '
          'chi le fa peggio.',
      categoria: CategoriaMissione.sfida,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'DIECI SECONDI SENZA RIDERE',
      consegna:
          'Guarda la telecamera mentre qualcuno fuori campo prova a farti '
          'ridere. Se cedi, si vede.',
      categoria: CategoriaMissione.sfida,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'CANTA A SQUARCIAGOLA DOVE SEI',
      consegna:
          'Il ritornello della tua canzone preferita, a tutto volume, nel '
          'posto dove ti trovi adesso.',
      categoria: CategoriaMissione.sfida,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'IL TUO TALENTO INUTILE',
      consegna:
          'Dieci secondi della cosa assurda che sai fare solo tu. Più è '
          'inutile, più vale.',
      categoria: CategoriaMissione.sfida,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'IL TRUCCO DI MAGIA PIÙ SCARSO',
      consegna:
          'Tutto in un video, senza tagli. Più si vede il trucco, meglio è.',
      categoria: CategoriaMissione.sfida,
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'IL TUO NOME A OCCHI CHIUSI',
      consegna:
          'Scrivilo su un foglio a occhi chiusi, con la mano sbagliata, e '
          'fotografa il risultato.',
      categoria: CategoriaMissione.sfida,
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
