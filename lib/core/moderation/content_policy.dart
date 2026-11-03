/// Cosa non si puo' chiedere alla gente di fare, e cosa non si puo' scrivere.
///
/// Questa e' la parte piu' importante del prodotto, e per un motivo preciso:
/// CRASY **paga la gente per fare cose**. Una challenge non e' un post, e' un
/// incarico con un premio in denaro, e un incarico sbagliato — *tagliati*,
/// *sali sul cornicione*, *picchia qualcuno* — non e' un contenuto discutibile:
/// e' una persona che si fa male perche' gliel'abbiamo chiesto noi.
///
/// ## Cosa fa e cosa non fa
///
/// E' un elenco di parole, e va detto subito cosa **non** e': non capisce il
/// contesto. "Questo film mi ha ucciso" e' innocuo e questa funzione non lo sa.
/// Ferma il caso esplicito — che e' anche il piu' probabile — e i modi piu'
/// ovvi di travestirlo.
///
/// Contro chi prova ad aggirarla fa tre cose, e sono l'aggiunta che conta piu'
/// dell'elenco stesso:
///
/// - **legge i numeri come lettere**: `ucc1d1t1` e' `ucciditi`;
/// - **schiaccia le lettere ripetute**: `spogliaaaati` e' `spogliati`;
/// - **rilegge tutto senza spazi**: `t a g l i a t i   l e   v e n e` diventa
///   una parola sola, e le espressioni piu' gravi si riconoscono anche cosi'.
///
/// L'ultimo passaggio si applica solo a un elenco scelto a mano e non a tutte
/// le parole, ed e' voluto: togliendo gli spazi "che **la metta** in posa"
/// diventa "chelamettainposa", e un elenco che contenesse `lametta` boccerebbe
/// una challenge innocua. **Un filtro che si arrabbia con chi non ha fatto
/// niente perde la fiducia di tutti, e finisce disattivato.**
///
/// **Per le missioni e' solo un primo avviso.** Serve a dirlo subito a chi scrive:
/// un telefono si puo' modificare, quindi l'ultima parola su una missione e' del
/// server, che rilegge il testo con un elenco suo (`functions/parole.js`), lo fa
/// giudicare da un'intelligenza artificiale e se serve da una persona. Vedi
/// `functions/missioni.js`.
///
/// Per commenti, didascalie, nomi e descrizioni, invece, questa resta la porta
/// principale.
abstract final class ContentPolicy {
  /// Perche' un testo e' stato rifiutato.
  ///
  /// Sapere **quale** categoria e' stata toccata serve a dire alla persona una
  /// frase sensata invece di un "non consentito" che non spiega niente.
  static const selfHarm = ContentViolation._(
    'autolesionismo',
    'Non si può chiedere a nessuno di farsi del male. Se stai passando un '
        'momento difficile, in Italia il Telefono Amico risponde al 02 2327 '
        '2327.',
  );

  static const violence = ContentViolation._(
    'violenza',
    'Non si può chiedere a nessuno di fare del male a qualcun altro, o a un '
        'animale.',
  );

  static const sexual = ContentViolation._(
    'sesso',
    'Niente contenuti sessuali o nudità: su CRASY non sono ammessi.',
  );

  static const danger = ContentViolation._(
    'pericolo',
    'Questa challenge chiede qualcosa che può finire male davvero. Non è '
        'quel tipo di app.',
  );

  static const hate = ContentViolation._(
    'odio',
    'Niente insulti o attacchi a una persona o a un gruppo.',
  );

  static const crime = ContentViolation._(
    'reato',
    'Questa challenge chiede di commettere un reato. Non si può.',
  );

  /// Volgarita' e bestemmie.
  ///
  /// **Separata dagli insulti**, e non e' pignoleria: sono due cose che si
  /// fermano per due ragioni diverse, e chi si vede rifiutare un commento ha
  /// diritto di sapere quale delle due ha toccato. Una parolaccia buttata li'
  /// non fa male a nessuno in particolare; un insulto ha un bersaglio.
  static const profanity = ContentViolation._(
    'volgarita',
    'Riscrivilo senza parolacce. Qui sotto ci passano tutti, e non è il '
        'posto.',
  );

  /// I frammenti che fanno scattare ogni categoria.
  ///
  /// Sono frammenti e non parole intere perche' l'italiano coniuga: `ammazzat`
  /// prende "ammazzati" e "ammazzatevi", `spogliat` prende "spogliati" e
  /// "spogliatevi". Il prezzo sono i falsi positivi — un frammento dentro
  /// un'altra parola — e si paga volentieri: rifiutare per sbaglio una
  /// challenge innocua costa a chi la scrive trenta secondi, lasciar passare
  /// "tagliati le vene" costa molto di piu'.
  static const Map<ContentViolation, List<String>> _fragments = {
    selfHarm: [
      'suicid',
      'suicide',
      'ammazzat',
      'uccidit',
      'uccidet',
      'uccidersi',
      'tagliati le vene',
      'tagliarsi le vene',
      'tagliati i polsi',
      'tagliati le braccia',
      'taglia le vene',
      // **"Tagliati" da solo resta permesso, e non e' una svista.** "Tagliati i
      // capelli" e "tagliati le unghie" sono due challenge perfettamente
      // normali, e sono anche il modo piu' comune in cui quella parola compare.
      // Bocciarle per prendere un caso raro vorrebbe dire un filtro che si
      // arrabbia con chi non ha fatto niente — e quello, dopo tre volte, viene
      // disattivato da chi lo gestisce. Si nominano invece le parti del corpo
      // su cui quel verbo non ha nessun uso innocuo.
      'tagliati il braccio',
      'tagliati la gamba',
      'tagliati la mano',
      'tagliati le dita',
      'tagliati la pelle',
      'tagliati la faccia',
      'tagliati con un coltello',
      'tagliati con una lametta',
      'tagliati con il vetro',
      'tagliarsi la pelle',
      'incidersi la pelle',
      'incidersi',
      'inciditi',
      'fine alla tua vita',
      'fine alla vita',
      'farla finita',
      'togliti la vita',
      'togliersi la vita',
      'impiccat',
      'impiccar',
      'strangolati',
      'soffocati',
      'autolesion',
      'fatti del male',
      'farti del male',
      'farsi del male',
      'fatevi del male',
      'ferisciti',
      'feritevi',
      'bruciati',
      'bruciarsi',
      'ustionat',
      'affogat',
      'annegat',
      'buttati di sotto',
      'buttarsi di sotto',
      'buttati giu dal',
      'lanciati dal',
      'salta dal balcone',
      'salta dalla finestra',
      'salta dal ponte',
      // **Il vuoto senza dire da dove.** Mancavano, e sono i modi piu' comuni
      // di dirlo: "salta nel vuoto" non nomina ne' un balcone ne' una finestra,
      // quindi passava attraverso le tre righe qui sopra.
      'salta nel vuoto',
      'saltare nel vuoto',
      'buttati nel vuoto',
      'buttarsi nel vuoto',
      'lanciati nel vuoto',
      'gettati nel vuoto',
      'nel vuoto senza',
      'sotto il treno',
      'davanti al treno',
      'overdose',
      'bevi la candeggina',
      'bevi la varechina',
      'bevi il detersivo',
      'ingoia le pillole',
      'digiuna per',
      'non mangiare per',
      'vomita dopo',
      'kill yourself',
      'kys',
      'self harm',
      'cut yourself',
    ],
    violence: [
      'picchia',
      'picchiare',
      'menare qualcuno',
      'prendi a pugni',
      'prendere a pugni',
      'prendi a calci',
      'dai uno schiaffo',
      'schiaffeggia',
      'accoltell',
      'coltello a qualcuno',
      'spara a',
      'sparare a',
      'aggredisci',
      'aggredire qualcuno',
      'ammazza il',
      'ammazza la',
      'ammazza un',
      'uccidi ',
      'uccidere un',
      'uccidere il',
      'ucciso un',
      'torturare',
      'tortura ',
      'sfregia',
      'maltratta',
      'seviz',
      'investi con l',
      'investi qualcuno',
      'dai fuoco a',
      'da fuoco a',
      'incendia',
      'stupr',
      'violenta qualcuno',
      'molesta',
      'calci al cane',
      'calci al gatto',
      'fai male a un animale',
      'uccidi un animale',
      'beat someone',
      'stab someone',
      'shoot someone',
      'punch someone',
    ],
    sexual: [
      'nud',
      'spogliat',
      'spogliar',
      'senza vestiti',
      'senza mutande',
      'senza reggiseno',
      'topless',
      'seno scoperto',
      'genital',
      'porno',
      'pornograf',
      'masturb',
      'atto sessuale',
      'rapporto sessuale',
      'sessual',
      'erotic',
      'a luci rosse',
      'hard core',
      'hardcore',
      'onlyfans',
      'escort',
      'prostitu',
      'lap dance',
      'pole dance in mutande',
      'orgasm',
      'sotto la doccia',
      'in doccia',
      'nella vasca senza',
      'naked',
      'nsfw',
      'strip tease',
      'striptease',
      // **Il corpo chiesto per nome.** Mancava tutto questo, ed era il buco
      // piu' largo del filtro: "foto al tuo pisello" passava liscio. Le parti
      // del corpo si nominano nell'elenco delle parole intere qui sotto —
      // sono corte e finirebbero dentro parole innocue — mentre qui stanno le
      // **richieste**, che attaccate non capitano per caso.
      // **"In mutande" e "sexy" le rifiutava gia' il database, non l'app.**
      //
      // Erano scritte nelle regole di Firestore e non qui, e le due meta' si
      // contraddicevano: il modulo diceva di si', la scrittura veniva
      // respinta, e chi l'aveva scritta leggeva "operazione non consentita"
      // senza capire cosa avesse sbagliato. E' esattamente il difetto contro
      // cui questo file mette in guardia in cima — quello che il modulo
      // accetta dev'essere quello che il database accetta.
      //
      // Allineate qui: su un'app che **paga** per una foto, "mandami una foto in
      // mutande" e' una richiesta di materiale sessuale con dei soldi in mezzo,
      // non un modo di dire. Oggi sulle missioni l'ultima parola e' del server.
      'in mutande',
      'foto sexy',
      'video sexy',
      'in modo sexy',
      'in slip',
      'in perizoma',
      'in tanga',
      'in reggiseno',
      'in intimo',
      'mostra il seno',
      'mostra le tette',
      'fai vedere le tette',
      'fai vedere il seno',
      'mani nelle mutande',
      'mano nelle mutande',
      'capezzol',
      'testicol',
      'clitorid',
      'scroto',
      'vulva',
      // **Le tre parole che hanno anche un significato del tutto innocuo.**
      //
      // Un uccello e' un uccello, una patata e' una patata, e un pacco e' un
      // pacco: cercarle da sole boccerebbe "foto a un uccello sul balcone",
      // che e' esattamente il tipo di rifiuto che fa perdere fiducia in tutto
      // il filtro. Si nominano solo attaccate al possessivo, dove
      // quell'ambiguita' non c'e' piu'.
      'tuo uccello',
      'tuo pacco',
      'tua patata',
      'tua passera',
      'tua topa',
      'tua fessa',
      'tua figa',
      'tua fica',
      'tua cosa li',
      // **`cazzo` da solo resta permesso, ed e' una scelta gia' presa.** E' la
      // parolaccia piu' comune della lingua e quasi sempre non indica niente:
      // "che cazzo hai fatto" e' stupore, non una richiesta. Un filtro che la
      // ferma boccia meta' delle frasi che la gente scrive davvero, e dopo tre
      // volte lo spegne chi lo gestisce.
      //
      // Quando invece **e' una richiesta**, il possessivo lo dice senza
      // ambiguita' — ed e' li' che si ferma.
      'tuo cazzo',
      'suo cazzo',
      'il cazzo di',
      'vedere il cazzo',
      'foto al cazzo',
      'parti intime',
      'parti basse',
      'zone intime',
    ],
    danger: [
      'guida ubriac',
      'guidare ubriac',
      'guida bendato',
      'contromano',
      'attraversa i binari',
      'sui binari',
      'sul cornicione',
      'sul cornicion',
      'sul tetto del treno',
      'sul tetto del palazzo',
      'appeso fuori dal',
      'fuori dal finestrino',
      'in mezzo alla strada',
      'in mezzo all autostrada',
      'davanti alle auto',
      'sui cavi dell alta tensione',
      'pastiglie',
      'farmaci a caso',
      'mischia i farmaci',
      'benzina addosso',
      'fuoco addosso',
      'mangia fuoco',
      'bevi tutto d un fiato',
      'un litro di vodka',
      'bottiglia di superalcolico',
      'gioco del soffocamento',
      'trattieni il respiro finche',
      'sotto il ghiaccio',
      'con la corrente',
      'senza casco a',
      'sul cofano in corsa',
      'aggrappati al bus',
      'aggrappati al tram',
    ],
    crime: [
      'ruba ',
      'rubare qualcosa',
      'rubare in negozio',
      'taccheggio',
      'scippa',
      'borseggia',
      'entra in casa di',
      'spacca il vetro',
      'spacca la vetrina',
      'vandalizza',
      'incendia il',
      'vendi droga',
      'spaccia',
      'cocain',
      'eroina',
      'metanfetamin',
      'compra la droga',
      'guida senza patente',
      'clona la carta',
      'foto di un documento altrui',
      'foto della carta di credito',
      'pedofil',
      'shoplift',
    ],
    hate: [
      'sei un ritardat',
      'froci',
      'ricchion',
      'zingar',
      'terron',
      'handicappat',
      'mongoloid',
      'ebrei di merda',
      'musulmani di merda',
      'tornatene al tuo paese',
      'razza inferiore',
    ],
  };

  /// Le parole che valgono **solo se sono parole intere**.
  ///
  /// Alcune sono troppo corte o troppo dentro ad altre per essere cercate come
  /// frammento: `pene` sta dentro "penetrare", `sesso` dentro "professo",
  /// `strip` dentro "striptease". Cercarle intere le prende dove contano senza
  /// bocciare mezzo dizionario.
  static const Map<ContentViolation, List<String>> _words = {
    sexual: [
      'sesso',
      'pene',
      'vagina',
      'tette',
      'culo',
      'strip',
      'nude',
      'sex',
      'porn',
      // **Il gergo, che e' il modo in cui la gente lo scrive davvero.**
      //
      // Nessuno scrive "foto ai tuoi genitali": scrive "foto al tuo pisello".
      // L'elenco di prima nominava le parole del referto medico e lasciava
      // passare quelle vere, che e' come chiudere a chiave la porta e lasciare
      // la finestra aperta.
      //
      // **Cercate intere, e conta.** `figa` sta dentro "sfigata", `fessa`
      // dentro "confessa" e "professa", `topa` dentro "topaia": come frammenti
      // boccerebbero frasi che non c'entrano niente. Isolate prendono
      // esattamente cio' che devono.
      'pisello',
      'pisellino',
      'pistolino',
      'minchia',
      'fessa',
      'figa',
      'fica',
      'topa',
      'passera',
      'belino',
      'minne',
      'zizze',
      'chiappe',
      'pube',
      'inguine',
      'dick',
      'pussy',
      'boobs',
      'tits',
      'nudes',
    ],
    violence: ['stab', 'uccidi', 'ammazza', 'spara', 'sgozza'],
    // **Parole intere, mai frammenti.** Sono le piu' corte dell'elenco e le
    // piu' facili da trovare per sbaglio dentro un'altra: `cazzo` come pezzo
    // starebbe dentro parole innocue, `figa` dentro "figurati", `merda`
    // dentro niente ma la regola vale lo stesso. Cercandole isolate — con uno
    // spazio davanti e dietro — un filtro che si arrabbia con chi non ha fatto
    // niente non nasce nemmeno.
    // Gli insulti hanno un bersaglio, e sotto la foto di qualcuno e' sempre
    // quella persona. Restano fuori i mezzi insulti da bar — scemo, stupido —
    // perche' fra amici si dicono per scherzo, e un filtro che li ferma
    // trasforma una presa in giro in un errore rosso.
    hate: [
      // **Parole intere, e non il frammento che c'era.** `negr` fermava anche
      // "negroni", e un filtro che si arrabbia per un cocktail perde la fiducia di
      // tutti.
      'negro',
      'negri',
      'negra',
      'negre',
      'frocio',
      'froci',
      'ricchione',
      'terrone',
      'terroni',
      'zingaro',
      'zingari',
      'handicappato',
      'mongoloide',
      'ritardato',
      'ritardata',
      'faggot',
      'retard',
    ],
    selfHarm: ['vene', 'polsi'],
    crime: ['droga', 'ruba', 'rubare'],
  };

  /// Le espressioni riconosciute **anche senza spazi**.
  ///
  /// Servono contro il trucco piu' banale che esista: scrivere
  /// `t a g l i a t i  l e  v e n e`, oppure `uccidi.ti`. Sono poche e scelte a
  /// mano, perche' cercare tutto l'elenco senza spazi produce disastri —
  /// "che **la metta** in posa" diventa "chelamettainposa" e conterrebbe
  /// "lametta".
  ///
  /// Qui ci stanno solo espressioni che, attaccate, non capitano per caso
  /// dentro una frase italiana.
  static const Map<ContentViolation, List<String>> _evasions = {
    selfHarm: [
      'suicidati',
      'suicidio',
      'ucciditi',
      'ammazzati',
      'impiccati',
      'tagliatilevene',
      'tagliatiipolsi',
      'killyourself',
      'autolesionismo',
    ],
    violence: ['accoltella', 'stupra', 'ammazzalo', 'uccidilo', 'torturalo'],
    sexual: [
      'spogliati',
      'masturbati',
      'pornografia',
      'nudointegrale',
      'attosessuale',
      // Qui **solo le lunghe e senza ambiguita'**. Questa lettura toglie tutti
      // gli spazi, quindi una parola corta ne pesca dentro un'altra: `figa`
      // dentro "che sfiga", `topa` dentro "una topaia". Bloccare "che sfiga"
      // per prendere "f i g a" e' un pessimo affare.
      'pisello',
      'pisellino',
      'minchia',
      'tuopisello',
      'tuauccello',
      'tuafessa',
      'tuafiga',
      'tuatopa',
      'tuapatata',
    ],
    crime: ['pedofilia', 'spacciare'],
    hate: ['negrodimerda', 'frociodimerda', 'pezzodimerda'],
  };

  /// Quello che in una **missione** si ferma, e nel resto dell'app no.
  ///
  /// **Non sta nell'elenco di tutti perche' altrove la decisione e' un'altra.**
  /// "Che cazzo hai fatto" in un commento e' stupore e passa — sta scritto in
  /// `content_policy_test.dart` ed e' una scelta presa. Dentro una missione,
  /// che e' un incarico pagato, si ferma: qui si dice subito, con il messaggio
  /// giusto. L'ultima parola e' del server, in `functions/parole.js`.
  static const Map<ContentViolation, List<String>> _missionOnly = {
    selfHarm: ['candeggina'],
    violence: ['torturar'],
    sexual: ['reggiseno', 'perizoma', 'luci rosse', 'sexy', 'pisellin'],
    danger: ['cornicion', 'tetto del treno', 'soffocamento'],
    profanity: [
      'cazzo',
      'cazzat',
      'stronz',
      'vaffancul',
      'affancul',
      'coglion',
      'puttan',
      'mignotta',
      'zoccola',
      'porcodio',
      'dioporco',
      'diocane',
      'bitch',
      'asshole',
    ],
  };

  /// Le richieste pericolose dette **senza nessuna delle parole dell'elenco**.
  ///
  /// Un elenco di parole prende "salta dal ponte" e lascia passare "tuffati
  /// dalla scogliera", prende "tagliati le vene" e non "incidi la coscia". Qui
  /// si guarda un'altra cosa: un'**azione** e il **posto o la cosa** che la
  /// rende pericolosa, vicini nella stessa frase. "Salta" va benissimo, "il
  /// ponte" va benissimo, "salta dal ponte" no.
  ///
  /// Ogni gruppo e' una lista di radici e **devono comparire tutti i gruppi**,
  /// a non piu' di `window` parole l'uno dall'altro. Una radice vale per ogni
  /// parola che comincia cosi' (`tuff` prende "tuffati" e "tuffarsi"); con `=`
  /// davanti vale solo la parola intera, per quelle corte che stanno dentro
  /// altre (`=gin` non prende "ginocchio", `=spia` non prende "spiaggia").
  ///
  /// **Pochi gruppi, scelti stretti, ed e' voluto.** Ogni coppia nuova costa
  /// una challenge innocua rifiutata per sbaglio, e un filtro che si arrabbia
  /// con chi non ha fatto niente viene spento. Per questo l'azione da sola non
  /// basta mai ("salta", "bevi", "taglia" sono parole di tutti i giorni) e le
  /// finestre sono corte. Prende il giro di parole piu' comune, non quello di
  /// chi ci lavora sopra: la rete vera resta chi guarda.
  ///
  /// Vale solo per le missioni: sono incarichi pagati, e li' un falso positivo
  /// costa trenta secondi mentre un falso negativo costa una persona.
  static const List<_Combo> _combos = [
    // Il vuoto: saltare o tuffarsi da qualcosa di alto.
    _Combo(
      danger,
      [
        // Le forme del verbo e non `salt`: "un salto di gioia davanti al ponte"
        // e' un nome, non una richiesta.
        ['salta', 'salti', 'tuff'],
        [
          'ponte',
          'ponti',
          'viadott',
          'cavalcavia',
          'scogliera',
          'scogliere',
          'burrone',
          'precipizio',
          'dirupo',
          'tetto',
          'tetti',
          'terrazz',
          'balcon',
          'finestr',
          'cornicion',
          'grattacielo',
          'ringhiera',
          'parapetto',
        ],
      ],
    ),
    // La strada e i binari: fermarsi, sdraiarsi o attraversare dove non si deve.
    _Combo(
      danger,
      [
        ['sdraia', 'stendi', 'dormi', 'siedi', 'fermati', 'attravers'],
        [
          'carreggiat',
          'autostrad',
          'tangenzial',
          'rotaia',
          'rotaie',
          'binari',
        ],
      ],
    ),
    // Mandare giu' qualcosa che non si beve.
    _Combo(
      selfHarm,
      [
        [
          'bevi',
          'bere',
          'ingoia',
          'ingoiare',
          'ingerisci',
          'ingerire',
          'assaggia',
          'sorseggia',
          'assumi',
          'mischia',
          'mescola',
        ],
        [
          'candeggin',
          'varechin',
          'ammoniac',
          'detersiv',
          'antigel',
          'benzina',
          'trielina',
          'solvent',
          'sonnifer',
          'psicofarmac',
        ],
      ],
    ),
    // L'alcol, ma **solo con la quantita'**: "bevi una birra" non e' un
    // pericolo, "bevi un litro di grappa d'un fiato" si'. Tre gruppi.
    _Combo(
      danger,
      [
        ['bevi', 'bere', 'scola', 'tracanna', 'ingoia', 'ingoiare'],
        [
          'alcol',
          'vodka',
          'whisk',
          'grappa',
          '=rum',
          '=gin',
          'tequila',
          'superalcol',
          '=vino',
          '=vini',
          '=birra',
          '=birre',
          'sambuca',
        ],
        [
          'litro',
          'litri',
          'intera',
          'intero',
          'fiato',
          'svien',
          'ubriac',
          'shot',
          'cicchett',
          '=fila',
        ],
      ],
      window: 10,
    ),
    // Farsi del male con una lama senza dire "vene" ne' "polsi". Finestra
    // stretta: "taglia la torta e mostra il braccio" non deve scattare.
    _Combo(
      selfHarm,
      [
        [
          '=tagliati',
          '=taglia',
          '=tagliarti',
          '=tagliarsi',
          '=incidi',
          '=incidere',
          '=graffiati',
          '=bucati',
        ],
        [
          'braccio',
          'braccia',
          'polso',
          'polsi',
          'coscia',
          'cosce',
          'pancia',
          'pelle',
          'corpo',
          'gamba',
          'gambe',
          'avambracc',
          'addome',
        ],
      ],
      window: 4,
    ),
    // Il fuoco sul proprio corpo.
    _Combo(
      danger,
      [
        ['=brucia', '=bruciare', '=brucio'],
        [
          'capelli',
          'mani',
          'mano',
          'braccio',
          'pelle',
          'sopracciglia',
          'barba',
        ],
      ],
    ),
    // Seguire una persona: atti persecutori, e un incarico che nessuno dovrebbe
    // dare a un estraneo. "Chiedi a uno sconosciuto" non c'entra: il verbo e'
    // un altro.
    _Combo(
      crime,
      [
        ['=pedina', '=pedinare', 'insegui', '=spia', '=spiare'],
        [
          'sconosciut',
          'passant',
          'ragazza',
          'ragazzo',
          'donna',
          'bambin',
          'vicina',
          'vicino',
          '=ex',
        ],
      ],
    ),
    // I minorenni in un posto dove non si fotografano. Questa app e' per
    // maggiorenni e paga per le foto: su questo il margine e' zero.
    _Combo(
      sexual,
      [
        ['bambin', 'minorenn', 'ragazzin', 'figli', 'nipotin'],
        ['bagno', 'vasca', 'doccia', 'intim', 'spogliatoi', 'pigiama'],
      ],
    ),
  ];

  /// Gli stessi frammenti, con le lettere ripetute schiacciate a una.
  ///
  /// Si calcolano una volta sola all'avvio invece che a ogni controllo: e'
  /// un'operazione su qualche centinaio di parole, e la si farebbe a ogni
  /// tentativo di salvataggio.
  static final Map<ContentViolation, List<String>> _collapsedFragments = {
    for (final entry in _fragments.entries)
      entry.key: [for (final fragment in entry.value) _collapse(fragment)],
  };

  /// Le parole intere, schiacciate allo stesso modo dei frammenti.
  ///
  /// **Mancavano, e lasciavano passare il trucco piu' facile di tutti.** Le
  /// lettere ripetute venivano schiacciate solo per i frammenti: `pisellooooo`
  /// diventava `pisello` in quella lettura, ma le parole intere si cercavano
  /// solo nel testo normalizzato — dove le doppie restano doppie — e quindi
  /// `pisellooooo` non lo prendeva nessuno.
  ///
  /// Anche le parole vanno schiacciate, non solo il testo: `tette` diventa
  /// `tete`, e cercare `tette` dentro un testo gia' schiacciato non troverebbe
  /// mai niente.
  static final Map<ContentViolation, List<String>> _collapsedWords = {
    for (final entry in _words.entries)
      entry.key: [for (final word in entry.value) _collapse(word)],
  };

  /// La prima violazione trovata in [text], oppure `null` se e' pulito.
  ///
  /// L'ordine dei controlli conta poco per il risultato ma molto per il costo:
  /// prima i frammenti, che prendono quasi tutto, poi le parole intere, e solo
  /// alla fine la rilettura senza spazi.
  static ContentViolation? check(String? text) {
    final normalized = _normalize(text ?? '');

    if (normalized.trim().isEmpty) {
      return null;
    }

    for (final entry in _fragments.entries) {
      for (final fragment in entry.value) {
        if (normalized.contains(fragment)) {
          return entry.key;
        }
      }
    }

    // Le parole intere si cercano con uno spazio davanti e uno dietro. Il testo
    // e' gia' stato ripulito: ogni segno di punteggiatura e' diventato uno
    // spazio, quindi "sesso." e "(sesso)" arrivano qui come parole isolate.
    final padded = ' ${normalized.trim()} ';

    for (final entry in _words.entries) {
      for (final word in entry.value) {
        if (padded.contains(' $word ')) {
          return entry.key;
        }
      }
    }

    // Terza lettura: le lettere ripetute schiacciate **a una sola**, da tutte
    // e due le parti. "spogliaaaati" diventa "spogliati", e siccome anche i
    // frammenti vengono schiacciati allo stesso modo, "spogliat" continua a
    // riconoscerlo. Si fa in fondo e non all'inizio perche' e' la lettura che
    // deforma di piu': "nonna" diventa "nona", e va usata solo dopo che le
    // altre due non hanno trovato niente.
    final collapsed = _collapse(normalized);

    for (final entry in _collapsedFragments.entries) {
      for (final fragment in entry.value) {
        if (collapsed.contains(fragment)) {
          return entry.key;
        }
      }
    }

    // Le parole intere anche qui, e sempre con gli spazi attorno: schiacciare
    // deforma — `professa` diventa `profesa` — quindi cercarle come frammenti
    // in questa lettura boccerebbe parole innocue. Isolate no.
    final collapsedPadded = ' ${collapsed.trim()} ';

    for (final entry in _collapsedWords.entries) {
      for (final word in entry.value) {
        if (collapsedPadded.contains(' $word ')) {
          return entry.key;
        }
      }
    }

    final squeezed = collapsed.replaceAll(' ', '');

    for (final entry in _evasions.entries) {
      for (final evasion in entry.value) {
        if (squeezed.contains(evasion)) {
          return entry.key;
        }
      }
    }

    return null;
  }

  /// Comodo per i moduli: torna il messaggio da mostrare, o `null`.
  static String? validate(String? text) => check(text)?.message;

  /// Il controllo per il testo di una **missione**: titolo e consegna.
  ///
  /// E' [check] piu' due cose, e tutte e due valgono solo qui:
  ///
  /// - quello che in una missione si ferma e altrove no (`_missionOnly`), cosi'
  ///   il modulo lo dice subito invece di aspettare la risposta del server;
  /// - le richieste pericolose dette **a giri di parole** (`_combos`): azione e
  ///   posto vicini nella stessa frase, senza nessuna parola da elenco.
  ///
  /// Una missione e' un incarico con dei soldi in mezzo, e per questo qui si
  /// accetta di rifiutare qualcosa in piu'. Commenti, biografie e didascalie
  /// restano su [check].
  static ContentViolation? checkMission(String? text) {
    final violation = check(text);

    if (violation != null) {
      return violation;
    }

    final normalized = _normalize(text ?? '');

    if (normalized.trim().isEmpty) {
      return null;
    }

    for (final entry in _missionOnly.entries) {
      for (final fragment in entry.value) {
        if (normalized.contains(fragment)) {
          return entry.key;
        }
      }
    }

    return _combination(normalized);
  }

  /// Come [validate], per il testo di una missione.
  static String? validateMission(String? text) => checkMission(text)?.message;

  /// La prima richiesta pericolosa fatta a giri di parole, o `null`.
  ///
  /// Scorre il testo a finestre di `window` parole e, per ogni coppia (o
  /// tripletta) di `_combos`, chiede che **ogni gruppo** abbia almeno una
  /// parola dentro la finestra.
  static ContentViolation? _combination(String normalized) {
    final words = normalized.trim().split(' ');

    if (words.length < 2) {
      return null;
    }

    for (final combo in _combos) {
      for (var start = 0; start < words.length; start++) {
        final end = start + combo.window > words.length
            ? words.length
            : start + combo.window;
        final span = words.sublist(start, end);

        final complete = combo.groups.every(
          (group) =>
              span.any((word) => group.any((stem) => _matchesStem(word, stem))),
        );

        if (complete) {
          return combo.violation;
        }
      }
    }

    return null;
  }

  /// Se [word] e' coperta da [stem]: comincia cosi', oppure — con `=` davanti —
  /// e' esattamente quella.
  static bool _matchesStem(String word, String stem) {
    if (stem.startsWith('=')) {
      return word == stem.substring(1);
    }

    return word.startsWith(stem);
  }

  /// Controlla piu' pezzi insieme — titolo e consegna — e torna il primo
  /// problema.
  static ContentViolation? checkAll(Iterable<String?> texts) {
    for (final text in texts) {
      final violation = check(text);

      if (violation != null) {
        return violation;
      }
    }

    return null;
  }

  /// Le sostituzioni con cui si prova ad aggirare un elenco di parole.
  ///
  /// Sono quelle di sempre, e valgono ancora perche' costano niente da fare e
  /// quasi niente da disfare.
  static const _lookalikes = {
    '0': 'o',
    '1': 'i',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '7': 't',
    '8': 'b',
    '@': 'a',
    r'$': 's',
    '!': 'i',
    'ß': 'b',
  };

  static const _accents = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };

  /// Porta un testo nella forma in cui si puo' confrontare.
  ///
  /// Minuscolo, senza accenti, con i numeri riletti come lettere, tutto quello
  /// che non e' una lettera trasformato in spazio, e le ripetizioni schiacciate
  /// a due — due e non una, perche' l'italiano le doppie ce le ha davvero e
  /// `ucciditi` non deve diventare `uciditi`.
  static final RegExp _letter = RegExp('[a-z]');
  static final RegExp _spaces = RegExp(' +');

  static String _normalize(String text) {
    final buffer = StringBuffer();

    for (final char in text.toLowerCase().split('')) {
      final letter = _accents[char] ?? _lookalikes[char] ?? char;

      buffer.write(_letter.hasMatch(letter) ? letter : ' ');
    }

    return _squashRepeats(buffer.toString()).replaceAll(_spaces, ' ');
  }

  /// Schiaccia ogni ripetizione a una sola lettera: `spogliaaaati` diventa
  /// `spogliati`, e anche `spogliati` resta `spogliati`.
  static String _collapse(String text) {
    final buffer = StringBuffer();
    String? previous;

    for (final char in text.split('')) {
      if (char != previous) {
        buffer.write(char);
      }

      previous = char;
    }

    return buffer.toString();
  }

  static String _squashRepeats(String text) {
    final buffer = StringBuffer();
    var previous = '';
    var run = 0;

    for (final char in text.split('')) {
      if (char == previous) {
        run++;

        if (run >= 2) {
          continue;
        }
      } else {
        run = 0;
        previous = char;
      }

      buffer.write(char);
    }

    return buffer.toString();
  }
}

/// Una richiesta pericolosa che si riconosce da **due o tre cose insieme**.
///
/// Vedi `ContentPolicy._combos`: [groups] sono liste di radici, devono esserci
/// tutti i gruppi entro [window] parole.
class _Combo {
  const _Combo(this.violation, this.groups, {this.window = 6});

  final ContentViolation violation;
  final List<List<String>> groups;
  final int window;
}

/// Una regola violata, con la frase da mostrare a chi l'ha violata.
class ContentViolation {
  const ContentViolation._(this.category, this.message);

  /// Come si chiama la categoria, per i registri e per le prove.
  final String category;

  /// Cosa leggera' la persona. Spiega **perche'**, e nel caso piu' delicato
  /// offre un numero da chiamare invece di limitarsi a chiudere la porta.
  final String message;

  @override
  String toString() => 'ContentViolation($category)';
}
