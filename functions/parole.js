'use strict';

/**
 * **Il controllo parola per parola delle missioni, sul server.**
 *
 * E' la prima porta, prima dell'intelligenza artificiale, e fa una cosa sola:
 * legge il testo in tutti i modi in cui qualcuno puo' provare a travestirlo e
 * lo confronta con due elenchi.
 *
 * - **Le parole rosse fermano subito.** "Ammazzati" non ha un contesto in cui
 *   vada bene: la missione non nasce, non si spende niente per giudicarla, e
 *   chi l'ha scritta legge perche'. Il tentativo resta nel pannello.
 * - **Le parole gialle non fermano, ma mandano da una persona.** "Autostrada"
 *   puo' essere la foto di un cartello o una persona che guida col telefono in
 *   mano: decidere e' un mestiere da occhi, non da elenco. Qualunque cosa dica
 *   l'intelligenza artificiale, una missione con una parola gialla **non esce
 *   da sola**. E' la cintura di sicurezza per il giorno in cui il modello si
 *   sbaglia, o qualcuno riesce a convincerlo.
 *
 * ## Le letture
 *
 * Un elenco di parole confrontato col testo cosi' com'e' si aggira in dieci
 * secondi. Qui lo stesso testo si legge in piu' modi, e basta che **una**
 * lettura tocchi l'elenco:
 *
 * - i caratteri di fantasia tornano lettere normali: `𝐚𝐦𝐦𝐚𝐳𝐳𝐚𝐭𝐢`, `ａｍｍａｚｚａｔｉ`,
 *   `ⓐⓜⓜⓐⓩⓩⓐⓣⓘ`, `🅰️`, le lettere cirilliche che sembrano latine;
 * - i caratteri invisibili spariscono: `amm​azzati` con uno spazio largo zero;
 * - i numeri e i simboli si rileggono come lettere: `4MM4ZZ4T1`, `@mm@zz@t!`;
 * - le lettere ripetute si schiacciano: `ammmaaazzatiii`, e anche `amazati`;
 * - le lettere staccate si ricuciono: `a m m a z z a t i`, `a.m.m.a.z.z.a.t.i`;
 * - si rilegge al contrario: `itazzamma`;
 * - si rilegge come suona: `ukkiditi`;
 * - **parola per parola**, con un margine di una lettera sbagliata sulle
 *   espressioni piu' gravi: `amnazzati`, `ammazzsti`.
 *
 * ## Cosa non e'
 *
 * Non capisce il contesto: "vai a duecento con la macchina" non contiene
 * nessuna parola vietata. A quello serve il giudizio di `giudice.js`, e in
 * fondo alla catena una persona.
 *
 * Questo file non tocca Firebase: si prova con `npm test`, senza credenziali.
 */

/** Cosa legge chi si vede fermare una missione, categoria per categoria. */
const CATEGORIE = {
  autolesionismo: {
    nome: 'Autolesionismo',
    messaggio:
      'Non si può chiedere a nessuno di farsi del male. Se stai passando un ' +
      'momento difficile, in Italia il Telefono Amico risponde al 02 2327 2327.',
  },
  violenza: {
    nome: 'Violenza',
    messaggio:
      'Non si può chiedere a nessuno di fare del male a qualcun altro, o a un ' +
      'animale.',
  },
  sessuale: {
    nome: 'Contenuti sessuali',
    messaggio: 'Niente contenuti sessuali o nudità: su CRASY non sono ammessi.',
  },
  pericolo: {
    nome: 'Pericolo',
    messaggio:
      'Questa missione chiede qualcosa che può finire male davvero. Non è quel ' +
      'tipo di app.',
  },
  reato: {
    nome: 'Reato',
    messaggio: 'Questa missione chiede di commettere un reato. Non si può.',
  },
  odio: {
    nome: 'Odio',
    messaggio: 'Niente insulti o attacchi a una persona o a un gruppo.',
  },
  volgarita: {
    nome: 'Volgarità',
    messaggio: 'Riscrivila senza parolacce: la leggono tutti.',
  },
  // Quelle aggiunte a mano dal pannello.
  aggiunta: {
    nome: 'Aggiunta dal pannello',
    messaggio: 'Questa missione non può uscire così. Riscrivila.',
  },
};

// ---------------------------------------------------------------------------
// Gli elenchi rossi
// ---------------------------------------------------------------------------

/**
 * **I pezzi di parola che fermano la missione.** Cercati dentro il testo, senza
 * confini: l'italiano coniuga, e `ammazzat` prende "ammazzati" e "ammazzatevi".
 *
 * Qui ci sta solo cio' che **non ha un'altra lettura innocua**. Un rosso
 * sbagliato costringe qualcuno a riscrivere; quello che e' ambiguo va fra le
 * gialle, dove lo guarda una persona.
 */
const ROSSE = {
  autolesionismo: [
    'suicid', 'ammazzat', 'ammazzart', 'ammazzarsi', 'ammazzarvi',
    'uccidit', 'uccidet', 'uccidert', 'uccidersi', 'uccidervi',
    'tagliati le vene', 'tagliarti le vene', 'tagliarsi le vene', 'tagliatevi le vene',
    'taglia le vene', 'tagliati i polsi', 'tagliarti i polsi', 'tagliarsi i polsi',
    'tagliati il polso', 'tagliati le braccia', 'tagliati il braccio', 'tagliati la gamba',
    'tagliati la mano', 'tagliati le dita', 'tagliati la pelle', 'tagliati la faccia',
    'tagliati la gola', 'tagliarti la gola', 'tagliati con un coltello',
    'tagliati con una lametta', 'tagliati con il vetro', 'tagliarsi la pelle',
    'incidersi', 'inciditi',
    'fine alla tua vita', 'fine alla vita', 'farla finita', 'togliti la vita',
    'toglierti la vita', 'togliersi la vita',
    'impiccat', 'impiccar', 'strangolati', 'strangolarti', 'soffocati', 'soffocarti',
    'avvelenati', 'avvelenarti', 'avvelenarsi', 'sgozzati', 'sgozzarti',
    'autolesion', 'fatti del male', 'farti del male', 'farsi del male', 'fatevi del male',
    'fatti male', 'ferisciti', 'feritevi', 'ferirti', 'bruciarti', 'bruciarsi', 'ustionat',
    'affogat', 'affogart', 'annegat', 'annegart',
    'buttati di sotto', 'buttarti di sotto', 'buttarsi di sotto', 'buttati giu',
    'buttarti giu', 'buttarsi giu', 'buttati dal', 'buttati dalla', 'buttarti dal',
    'gettati dal', 'gettati dalla', 'gettati giu', 'lanciati dal', 'lanciati dalla',
    'lanciati giu', 'lanciarti dal', 'salta dal balcone', 'salta dalla finestra',
    'salta dal ponte', 'salta dal tetto', 'salta giu dal', 'salta giu dalla',
    'saltare dal balcone', 'salta nel vuoto', 'saltare nel vuoto', 'buttati nel vuoto',
    'buttarsi nel vuoto', 'lanciati nel vuoto', 'gettati nel vuoto', 'nel vuoto senza',
    'sotto il treno', 'davanti al treno', 'sotto una macchina', 'sotto un camion',
    'fatti investire', 'farti investire', 'fatti ammazzare', 'farti ammazzare',
    'fatti uccidere', 'farti uccidere', 'overdose',
    'candeggina', 'varechina', 'bevi il detersivo', 'ingoia le pillole', 'ingoia pillole',
    'digiuna per', 'non mangiare per', 'vomita dopo',
    'kill yourself', 'self harm', 'cut yourself', 'hang yourself',
    'sparati in testa', 'sparati alla testa', 'spararti', 'spararsi', 'sparatevi',
    'lasciati morire', 'lasciarti morire',
  ],
  violenza: [
    'picchia', 'picchiare', 'menare qualcuno', 'prendi a pugni', 'prendere a pugni',
    'prendi a calci', 'prendere a calci', 'prendi a schiaffi', 'dai uno schiaffo',
    'dagli uno schiaffo', 'tira un pugno', 'tirare un pugno', 'dai un pugno', 'dagli un pugno',
    'schiaffeggia', 'accoltell', 'coltello a qualcuno', 'spara a', 'sparare a', 'sparagli',
    'aggredisci', 'aggredire qualcuno', 'ammazza il', 'ammazza la', 'ammazza un', 'ammazzare',
    'ammazzalo', 'ammazzala', 'ammazzali', 'ti ammazzo', 'vi ammazzo', 'uccidi ', 'uccidere',
    'uccidilo', 'uccidila', 'uccidili', 'ucciso un', 'ti uccido', 'vi uccido',
    'torturare', 'tortura ', 'torturalo', 'sfregia', 'maltratta', 'seviz',
    'investi con l', 'investi qualcuno', 'investilo', 'investila', 'investire qualcuno',
    'dai fuoco a', 'da fuoco a', 'dare fuoco a', 'incendia', 'stupr', 'violenta qualcuno',
    'violentala', 'violentalo', 'molesta', 'calci al cane', 'calci al gatto',
    'fai male a un animale', 'uccidi un animale', 'sgozza', 'decapita', 'mutila', 'lapida',
    'linciare', 'massacra', 'strangola', 'avvelena',
    'beat someone', 'stab someone', 'shoot someone', 'punch someone', 'kill someone',
  ],
  sessuale: [
    'nud', 'spogliat', 'spogliar', 'senza vestiti', 'senza mutande', 'senza reggiseno',
    'reggiseno', 'perizoma', 'topless', 'seno scoperto', 'genital', 'porno', 'pornograf',
    'masturb', 'atto sessuale', 'rapporto sessuale', 'sessual', 'erotic', 'luci rosse',
    'hard core', 'hardcore', 'onlyfans', 'escort', 'prostitu', 'lap dance', 'orgasm',
    'sotto la doccia', 'in doccia', 'nella vasca senza', 'naked', 'nsfw', 'strip tease',
    'striptease', 'in mutande', 'sexy', 'in slip', 'in tanga', 'in intimo', 'mostra il seno',
    'mostra le tette', 'fai vedere le tette', 'fai vedere il seno', 'fai vedere il culo',
    'mostra il culo', 'mani nelle mutande', 'mano nelle mutande', 'capezzol', 'testicol',
    'clitorid', 'scroto', 'vulva', 'tuo uccello', 'tuo pacco', 'tua patata', 'tua passera',
    'tua topa', 'tua fessa', 'tua figa', 'tua fica', 'tua cosa li', 'parti intime',
    'parti basse', 'zone intime', 'pompin', 'sborra', 'sborre', 'sborrat', 'sperma', 'eiacul',
    'fellatio', 'denud',
    'blowjob', 'cunnilingus', 'incest', 'pedopornograf', 'dickpic', 'dick pic',
    'sotto la gonna', 'upskirt',
  ],
  pericolo: [
    'guida ubriac', 'guidare ubriac', 'guida bendat', 'guidare bendat',
    'guida a occhi chiusi', 'guidare a occhi chiusi', 'contromano',
    'attraversa i binari', 'attraversare i binari', 'sui binari', 'cornicion',
    'tetto del treno', 'sul tetto del palazzo', 'appeso fuori dal', 'appesa fuori dal',
    'fuori dal finestrino', 'in mezzo alla strada', 'in mezzo all autostrada',
    'sdraiati in strada', 'sdraiati sulla strada', 'davanti alle auto', 'davanti alle macchine',
    'alta tensione', 'pastiglie', 'farmaci a caso', 'mischia i farmaci', 'benzina addosso',
    'fuoco addosso', 'datti fuoco', 'darti fuoco', 'mangia fuoco', 'bevi tutto d un fiato',
    'un litro di vodka', 'bottiglia di superalcolico', 'gioco del soffocamento',
    'blackout challenge', 'trattieni il respiro finche', 'sotto il ghiaccio', 'con la corrente',
    'dita nella presa', 'nella presa elettrica', 'senza casco a', 'sul cofano in corsa',
    'aggrappati al bus', 'aggrappati al tram', 'aggrappati al treno', 'train surfing',
    'surf sul treno', 'roulette russa', 'russian roulette', 'mangia vetro', 'mangia il vetro',
    'mangia sapone', 'tide pod', 'capsula di detersivo',
  ],
  reato: [
    'ruba ', 'rubare qualcosa', 'rubare in negozio', 'taccheggio', 'scippa', 'borseggia',
    'entra in casa di', 'spacca il vetro', 'spacca la vetrina', 'vandalizza', 'vendi droga',
    'spaccia', 'cocain', 'eroina', 'metanfetamin', 'compra la droga', 'guida senza patente',
    'clona la carta', 'foto di un documento altrui', 'foto della carta di credito', 'pedofil',
    'shoplift', 'rapina', 'deruba', 'molotov', 'zoofil', 'bestialit', 'ketamina', 'hashish',
    'marijuana', 'spinello', 'ecstasy', 'mdma', 'strage',
  ],
  odio: [
    'sei un ritardat', 'froci', 'ricchion', 'zingar', 'terron', 'handicappat', 'mongoloid',
    'ebrei di merda', 'musulmani di merda', 'tornatene al tuo paese', 'razza inferiore',
    'pezzo di merda', 'culattone',
  ],
  volgarita: [
    'cazzo', 'cazo ', 'cazzat', 'stronz', 'vaffancul', 'affancul', 'fancul', 'coglion', 'rincoglion',
    'puttan', 'mignotta', 'zoccola', 'zoccole', 'porcodio', 'dioporco', 'diocane', 'porcamadonna',
    'bitch', 'asshole', 'fuck',
  ],
};

/**
 * **Le parole che valgono solo se sono intere.** Corte, o troppo dentro ad
 * altre: `pene` sta in "penetrare", `figa` in "sfigata", `topa` in "topaia".
 */
const ROSSE_INTERE = {
  sessuale: [
    'sesso', 'pene', 'vagina', 'tette', 'culo', 'strip', 'nude', 'sex', 'porn', 'pisello',
    'pisellino', 'pistolino', 'minchia', 'fessa', 'figa', 'fica', 'topa', 'passera', 'belino',
    'minne', 'zizze', 'chiappe', 'pube', 'inguine', 'dick', 'pussy', 'boobs', 'tits', 'nudes',
  ],
  violenza: ['stab', 'uccidi', 'ammazza', 'spara', 'pestalo', 'pestala', 'pestali'],
  odio: [
    'negro', 'negri', 'negra', 'negre', 'frocio', 'ricchione', 'ricchioni', 'terrone',
    'terroni', 'zingaro', 'zingari', 'handicappato', 'mongoloide', 'ritardato', 'ritardata',
    'mongolo', 'faggot', 'retard', 'troia', 'troie',
  ],
  autolesionismo: ['vene', 'polsi', 'kys'],
  reato: ['droga', 'droghe', 'ruba', 'rubare', 'rubala', 'rubalo', 'lsd'],
};

/**
 * **Le espressioni riconosciute anche attaccate.** Contro `t a g l i a t i  l e
 * v e n e`. Scelte a mano e lunghe: togliendo tutti gli spazi "che la metta in
 * posa" conterrebbe "lametta", quindi qui sta solo cio' che attaccato non
 * capita per caso. Si cercano anche al contrario, e come suonano.
 */
const ROSSE_ATTACCATE = {
  autolesionismo: [
    'suicidati', 'suicidatevi', 'suicidarti', 'suicidarsi', 'suicidio', 'ucciditi', 'ucciderti',
    'uccidetevi', 'uccidersi', 'ammazzati', 'ammazzarti', 'ammazzatevi', 'ammazzarsi',
    'impiccati', 'impiccarti', 'impiccatevi', 'tagliatilevene', 'tagliartilevene',
    'tagliarsilevene', 'tagliatiipolsi', 'tagliartiipolsi', 'tagliatilagola', 'toglitilavita',
    'farlafinita', 'fattidelmale', 'fartidelmale', 'farsidelmale',
    'buttatidisotto', 'buttatigiu', 'buttatinelvuoto', 'saltanelvuoto', 'sparatiintesta',
    'killyourself', 'autolesionismo',
  ],
  violenza: [
    'accoltella', 'stupra', 'ammazzalo', 'ammazzala', 'uccidilo', 'uccidila', 'torturalo',
    'sgozzalo', 'sgozzala',
  ],
  sessuale: [
    'spogliati', 'spogliatevi', 'spogliarti', 'masturbati', 'masturbazione', 'pornografia',
    'nudointegrale', 'attosessuale', 'senzamutande', 'senzavestiti', 'pisello', 'pisellino',
    'minchia', 'tuopisello', 'tuauccello', 'tuafessa', 'tuafiga', 'tuatopa', 'tuapatata',
  ],
  reato: ['pedofilia', 'spacciare', 'cocaina'],
  odio: ['negrodimerda', 'frociodimerda', 'pezzodimerda'],
  pericolo: ['rouletterussa', 'russianroulette'],
  volgarita: ['porcodio', 'dioporco', 'diocane', 'porcamadonna', 'vaffanculo'],
};

/**
 * **Le piu' gravi, confrontate parola per parola con un margine.** Un errore di
 * una lettera basta a passare un elenco esatto: `amnazzati`, `ammazzsti`.
 *
 * Il margine vale solo qui, e l'elenco e' corto apposta: su parole comuni
 * prenderebbe il vicino innocuo — "picchia" contro "pacchia".
 */
const GRAVISSIME = [
  'ammazzati', 'ammazzarti', 'ammazzatevi', 'ammazzarsi',
  'ucciditi', 'ucciderti', 'uccidetevi', 'uccidersi',
  'suicidati', 'suicidarti', 'suicidatevi', 'suicidarsi', 'suicidio',
  'impiccarti', 'impiccatevi', 'impiccarsi',
  'sgozzati', 'accoltellati', 'accoltellalo', 'accoltellala',
];

/**
 * **Le parole vere che somigliano a quelle vietate.** Le ha trovate la scansione
 * di un dizionario italiano da 280.000 forme: schiacciando le doppie `ficca`
 * diventa `fica` e `venne` diventa `vene`, e con il margine di una lettera
 * `ammalati` e' vicino ad `ammazzati`. Un filtro che ferma "ammalati" o "bellino"
 * dopo tre volte lo spegne chi lo gestisce.
 *
 * Valgono **solo** per le letture che deformano: scritte giuste si confrontano lo
 * stesso con gli elenchi normali, dove non toccano niente.
 */
const INNOCUE = new Set([
  'ficca', 'toppa', 'bellino', 'venne', 'penne', 'mine', 'fesa', 'cullo', 'pennello',
  'ammaccati', 'ammalati', 'ammannati', 'ammarati', 'ammarrati', 'ammassati', 'ammazzai',
  'ammaccarsi', 'ammalarsi', 'ammassarsi', 'arrazzarsi', 'ammalarti', 'ammalatevi', 'ammassatevi',
  'ammaestrati', 'ammattiti', 'ammezzati', 'arrazzati', 'ammuciditi', 'ucciderai', 'uccidesti', 'uccidessi', 'ubbiditi', 'ubbidirti',
  'impiccassi', 'impiccasti', 'impicciarsi', 'impicciatevi', 'impiparsi', 'implicarsi',
  'sbozzati', 'scozzati', 'sgobbati', 'sgolati', 'sgommati',
]);

/**
 * **Quelle che esistono solo con l'accento in fondo.** Togliendo gli accenti,
 * `passerà` diventa `passera`: si tolgono dal testo prima, altrimenti "chi passerà
 * la prova" si ferma per una cosa che non dice.
 */
const TRONCHE_INNOCUE = ['passerà', 'culò', 'cullò', 'pennè', 'negrì', 'taccheggiò', 'cazzò'];

/**
 * **Le richieste pericolose dette senza nessuna parola vietata.** Un elenco prende "salta
 * dal ponte" e non "tuffati dalla scogliera": qui si guardano un'azione e il posto o la
 * cosa che la rende pericolosa, vicini nella stessa frase. "Salta" va benissimo, "il
 * ponte" va benissimo, "salta dal ponte" no.
 *
 * Ogni gruppo e' una lista di radici e **devono esserci tutti i gruppi**, entro `finestra`
 * parole. Una radice vale per ogni parola che comincia cosi'; con `=` davanti vale solo la
 * parola intera, per quelle corte che stanno dentro altre (`=gin` non e' "ginocchio").
 *
 * Sono gli stessi di `_combos` in `lib/core/moderation/content_policy.dart`: li' servono a
 * dirlo subito a chi scrive, qui a fermare chi salta l'app.
 */
const COMBINAZIONI = [
  // Il vuoto: saltare o tuffarsi da qualcosa di alto.
  {
    categoria: 'pericolo',
    gruppi: [
      ['salta', 'salti', 'tuff'],
      [
        'ponte', 'ponti', 'viadott', 'cavalcavia', 'scogliera', 'scogliere', 'burrone', 'precipizio',
        'dirupo', 'tetto', 'tetti', 'terrazz', 'balcon', 'finestr', 'cornicion', 'grattacielo',
        'ringhiera', 'parapetto',
      ],
    ],
  },
  // La strada e i binari: fermarsi, sdraiarsi o attraversare dove non si deve.
  {
    categoria: 'pericolo',
    gruppi: [
      ['sdraia', 'stendi', 'dormi', 'siedi', 'fermati', 'attravers'],
      ['carreggiat', 'autostrad', 'tangenzial', 'rotaia', 'rotaie', 'binari'],
    ],
  },
  // Mandare giu' qualcosa che non si beve.
  {
    categoria: 'autolesionismo',
    gruppi: [
      ['bevi', 'bere', 'ingoia', 'ingoiare', 'ingerisci', 'ingerire', 'assaggia', 'sorseggia', 'assumi', 'mischia', 'mescola'],
      ['candeggin', 'varechin', 'ammoniac', 'detersiv', 'antigel', 'benzina', 'trielina', 'solvent', 'sonnifer', 'psicofarmac'],
    ],
  },
  // L'alcol, ma solo con la quantita': "bevi una birra" non e' un pericolo.
  {
    categoria: 'pericolo',
    finestra: 10,
    gruppi: [
      ['bevi', 'bere', 'scola', 'tracanna', 'ingoia', 'ingoiare'],
      ['alcol', 'vodka', 'whisk', 'grappa', '=rum', '=gin', 'tequila', 'superalcol', '=vino', '=vini', '=birra', '=birre', 'sambuca'],
      ['litro', 'litri', 'intera', 'intero', 'fiato', 'svien', 'ubriac', 'shot', 'cicchett', '=fila'],
    ],
  },
  // Farsi del male con una lama senza dire "vene" ne' "polsi".
  {
    categoria: 'autolesionismo',
    finestra: 4,
    gruppi: [
      ['=tagliati', '=taglia', '=tagliarti', '=tagliarsi', '=incidi', '=incidere', '=graffiati', '=bucati'],
      ['braccio', 'braccia', 'polso', 'polsi', 'coscia', 'cosce', 'pancia', 'pelle', 'corpo', 'gamba', 'gambe', 'avambracc', 'addome'],
    ],
  },
  // Il fuoco sul proprio corpo.
  {
    categoria: 'pericolo',
    gruppi: [
      ['=brucia', '=bruciare', '=brucio'],
      ['capelli', 'mani', 'mano', 'braccio', 'pelle', 'sopracciglia', 'barba'],
    ],
  },
  // Seguire una persona: atti persecutori.
  {
    categoria: 'reato',
    gruppi: [
      ['=pedina', '=pedinare', 'insegui', '=spia', '=spiare'],
      ['sconosciut', 'passant', 'ragazza', 'ragazzo', 'donna', 'bambin', 'vicina', 'vicino', '=ex'],
    ],
  },
  // I minorenni in un posto dove non si fotografano: su questo il margine e' zero.
  {
    categoria: 'sessuale',
    gruppi: [
      ['bambin', 'minorenn', 'ragazzin', 'figli', 'nipotin'],
      ['bagno', 'vasca', 'doccia', 'intim', 'spogliatoi', 'pigiama'],
    ],
  },
];

const FINESTRA_NORMALE = 6;

// ---------------------------------------------------------------------------
// Gli elenchi gialli
// ---------------------------------------------------------------------------

/**
 * **Le parole che mandano la missione da una persona.** Non la fermano: dicono
 * che qui il modello da solo non basta, qualunque voto dia.
 *
 * Non c'e' "balcone" e non c'e' "fiamme", e sono due assenze volute: "foto fuori
 * al balcone" e' una foto, e le fiamme sono i like di CRASY.
 */
const GIALLE = {
  veicoli: [
    'km h', 'kmh', 'km ora', 'km orari', 'chilometri orari', 'chilometri all ora',
    'kilometri all ora', 'km all ora', 'velocita', 'a tutta birra', 'a manetta', 'tachimetro',
    'al volante', 'mentre guidi', 'mentre guida', 'guidando', 'alla guida', 'guidare', 'guidi ',
    'autostrada', 'tangenziale', 'superstrada', 'in corsa', 'con la macchina', 'in macchina',
    'la tua macchina', 'in auto ', 'con l auto ', 'con la moto', 'in moto', 'sulla moto',
    'sul motorino', 'in motorino', 'sullo scooter', 'in scooter', 'monopattino', 'impenna',
    'sgomma', 'drift', 'derapata', 'semaforo rosso', 'col rosso', 'con il rosso', 'sorpass',
    'senza cintura', 'senza casco', 'senza mani', 'senza freni', 'passaggio a livello',
    'corsa clandestina', 'corse clandestine', 'treno in',
  ],
  altezze: [
    'ringhiera', 'parapetto', 'davanzale', 'strapiombo', 'precipizio', 'scogliera',
    'impalcatura', 'traliccio', 'grattacielo', 'sul tetto', 'dal tetto', 'sui tetti',
    'sul bordo', 'in bilico', 'sporgiti', 'sporgerti', 'sporgersi', 'scavalca', 'arrampic',
    'salta da', 'salta giu', 'saltare da', 'saltare giu', 'tuffati', 'tuffarti', 'tuffo da',
    'buttati', 'buttarti', 'gettati', 'lanciati', 'appenditi', 'appeso ', 'appesa ', 'appesi ',
    'vertigin', 'fuori dalla finestra',
  ],
  fuoco: [
    'dai fuoco', 'dare fuoco', 'accendino', 'brucia', 'benzina', 'petard', 'bengala',
    'fuochi d artificio', 'esplosiv', 'bomba',
  ],
  elettricita: ['presa elettrica', 'corrente elettrica', 'folgora', 'cavi elettrici'],
  acqua: [
    'apnea', 'sott acqua', 'sottacqua', 'trattieni il respiro', 'affoga', 'annega',
    'mare mosso', 'mare in tempesta', 'acqua gelata', 'acqua ghiacciata', 'lago ghiacciato',
  ],
  alcol_droghe: [
    'ubriac', 'sbronz', 'shot', 'superalcol', 'vodka', 'tequila', 'grappa', 'whisky', 'alcol',
    'bevi tutto', 'bevi una bottiglia', 'bottiglia di', 'litro di', 'pillol', 'farmaci ', 'farmaco ',
    'psicofarmac', 'xanax', 'tavor', 'fentanil',
  ],
  armi: ['pistola', 'fucile', 'coltello', 'lametta', 'rasoio', 'machete', 'katana'],
  minori: [
    'minorenn', 'bambin', 'bimb', 'ragazzin', 'neonat', 'tuo figlio', 'tua figlia', 'tuoi figli',
    'alunn', 'scuola elementare', 'scuola media', 'asilo',
  ],
  persone_e_privacy: [
    'sconosciut', 'passant', 'di nascosto', 'senza che se ne', 'senza farti vedere', 'spiare',
    'spiala', 'spialo', 'pedinal', 'pedinar', 'targa', 'carta d identita', 'codice fiscale',
    'indirizzo di casa', 'numero di telefono', 'umilia', 'bullizz', 'bullismo', 'insulta',
  ],
  cibo_e_corpo: [
    'digiun', 'senza mangiare', 'senza dormire', 'senza bere', 'vomit', 'lassativ', 'reaper',
    'cucchiaio di', 'ingoia', 'inghiotti', 'detersiv', 'svenire', 'svieni',
    'blackout', 'soffoc', 'strozza',
  ],
  sessuale_ambiguo: [
    'lingerie', 'bikini', 'costume da bagno', 'il sedere', 'tuo sedere', 'culetto', 'lato b',
    'seduc', 'provocant', 'sensual', 'sotto le lenzuola', 'limonare', 'limonarsi', 'slingua', 'scopata',
  ],
  violenza_ambigua: [
    'muori', 'muoia', 'morire', 'sangue', 'ferisci', 'rissa', 'sputa', 'sparati',
  ],
  reato_ambiguo: [
    'senza biglietto', 'senza pagare', 'graffiti', 'imbratta', 'furto', 'sequestr', 'falsific',
    'hacker', 'hackera',
  ],
  // Chi parla al modello invece che alla gente non sta lanciando una missione.
  manipolazione: [
    'ignora le', 'ignora tutte', 'istruzioni', 'prompt', 'punteggio', 'score ',
    'sei un ai', 'sei un modello', 'intelligenza artificiale', 'assistant', 'claude', 'chatgpt',
  ],
};

const GIALLE_INTERE = {
  fuoco: ['fuoco'],
  armi: ['arma', 'armi', 'mitra'],
  violenza_ambigua: ['crepa', 'morte', 'schiaffo', 'pugno', 'pugni', 'calci', 'botte'],
  sessuale_ambiguo: ['hot', 'scopa', 'scopare', 'sega', 'seghe', 'bacia', 'bacio', 'intimo'],
  alcol_droghe: ['coca', 'rum', 'gin', 'alcool', 'crack', 'sostanza', 'sostanze'],
  reato_ambiguo: ['documento', 'documenti'],
  persone_e_privacy: ['spia'],
};

/** Gli emoji che, in una missione, vogliono uno sguardo. */
const EMOJI_GIALLE = {
  armi: ['🔪', '🔫', '🪓', '🗡', '⚔', '💣', '🧨'],
  violenza_ambigua: ['🩸', '⚰', '☠', '💀'],
  alcol_droghe: ['💉', '💊'],
  sessuale_ambiguo: ['🍆', '🍑', '💦', '🔞'],
};

// ---------------------------------------------------------------------------
// Le letture
// ---------------------------------------------------------------------------

/**
 * Le lettere che somigliano a quelle latine. Il cirillico `а` e il latino `a`
 * sullo schermo sono uguali, e per un elenco di parole sono due mondi.
 */
const OMOGRAFI = {
  // cirillico
  а: 'a', в: 'b', е: 'e', ё: 'e', к: 'k', м: 'm', н: 'h', о: 'o', р: 'p', с: 'c', т: 't',
  у: 'y', х: 'x', і: 'i', ї: 'i', ј: 'j', ѕ: 's', һ: 'h', ԁ: 'd', ԛ: 'q', ԝ: 'w', з: 'z',
  // greco
  α: 'a', β: 'b', γ: 'y', δ: 'd', ε: 'e', ζ: 'z', η: 'n', ι: 'i', κ: 'k', λ: 'l', μ: 'm',
  ν: 'v', ξ: 'x', ο: 'o', π: 'n', ρ: 'p', σ: 's', ς: 's', τ: 't', υ: 'u', φ: 'f', χ: 'x',
  ψ: 'y', ω: 'w',
  // maiuscolette, e le lettere girate sottosopra
  ᴀ: 'a', ʙ: 'b', ᴄ: 'c', ᴅ: 'd', ᴇ: 'e', ꜰ: 'f', ɢ: 'g', ʜ: 'h', ɪ: 'i', ᴊ: 'j', ᴋ: 'k',
  ʟ: 'l', ᴍ: 'm', ɴ: 'n', ᴏ: 'o', ᴘ: 'p', ǫ: 'q', ʀ: 'r', ꜱ: 's', ᴛ: 't', ᴜ: 'u', ᴠ: 'v',
  ᴡ: 'w', ʏ: 'y', ᴢ: 'z', ɐ: 'a', ǝ: 'e', ɯ: 'm', ɹ: 'r', ʇ: 't', ʌ: 'v', ʍ: 'w', ʎ: 'y',
  ɥ: 'h', ɟ: 'f', ɔ: 'c', ɾ: 'j', ʞ: 'k',
  // le altre latine
  ı: 'i', ø: 'o', đ: 'd', ł: 'l', ð: 'd', þ: 'p', ß: 'ss', æ: 'ae', œ: 'oe', ƒ: 'f', ħ: 'h',
  ŋ: 'n', ſ: 's', '€': 'e', '£': 'l', '¥': 'y', '¢': 'c',
};

/** I numeri riletti come lettere. */
const NUMERI = { 0: 'o', 1: 'i', 2: 'z', 3: 'e', 4: 'a', 5: 's', 6: 'g', 7: 't', 8: 'b', 9: 'g' };

/**
 * I simboli riletti come lettere. **In una lettura a parte**: "foto!" non e'
 * "fotoi", e un `!` a fine parola non deve nascondere la parola che lo precede.
 */
const SIMBOLI = {
  '@': 'a', $: 's', '!': 'i', '|': 'i', '+': 't', '§': 's', '¡': 'i', '(': 'c', '€': 'e',
  '£': 'l', '*': 'a',
};

/** Le lettere di fantasia che Unicode non riporta da solo a quelle normali. */
function letteraDiFantasia(punto) {
  // 🅐 cerchiate nere, 🅰 quadrate nere, 🇦 le lettere delle bandiere.
  for (const inizio of [0x1f150, 0x1f170, 0x1f1e6]) {
    if (punto >= inizio && punto < inizio + 26) {
      return String.fromCharCode(97 + punto - inizio);
    }
  }

  return null;
}

/**
 * **Riporta il testo alle lettere normali, senza ancora toccare numeri e
 * simboli.** Maiuscole, accenti, caratteri di fantasia, omografi, invisibili.
 */
function pulisci(testo) {
  const base = String(testo || '')
    // NFKD fa la meta' del lavoro da solo: `𝐚`, `ａ`, `ⓐ`, `①`, `à`.
    .normalize('NFKD')
    .toLowerCase();

  let uscita = '';

  for (const carattere of base) {
    const fantasia = letteraDiFantasia(carattere.codePointAt(0));

    if (fantasia) {
      uscita += fantasia;
    } else {
      uscita += OMOGRAFI[carattere] !== undefined ? OMOGRAFI[carattere] : carattere;
    }
  }

  // Accenti rimasti sciolti, tasti numerati degli emoji, selettori, e tutti i
  // caratteri invisibili: vanno tolti, non sostituiti, o spezzerebbero la parola.
  return uscita.replace(/[\p{M}\p{Cf}\p{Cc}]/gu, (carattere) =>
    carattere === '\n' || carattere === '\t' ? ' ' : ''
  );
}

/** Solo lettere e spazi, con ogni altro carattere che diventa uno spazio. */
function soloLettere(testo) {
  return testo.replace(/[^a-z]+/g, ' ').trim();
}

function conNumeri(testo) {
  return testo.replace(/[0-9]/g, (cifra) => NUMERI[cifra]);
}

function conSimboli(testo) {
  let uscita = '';

  for (const carattere of testo) {
    uscita += SIMBOLI[carattere] !== undefined ? SIMBOLI[carattere] : carattere;
  }

  return uscita;
}

/** Ogni lettera ripetuta diventa una sola: `ammmazzati` e anche `ammazzati` → `amazati`. */
function schiaccia(testo) {
  return testo.replace(/([a-z])\1+/g, '$1');
}

/** Come suona: `ukkiditi` → `ucciditi`. */
function comeSuona(testo) {
  return testo
    .replace(/ph/g, 'f')
    .replace(/k/g, 'c')
    .replace(/q/g, 'c')
    .replace(/[jy]/g, 'i')
    .replace(/w/g, 'v')
    .replace(/x/g, 's');
}

/**
 * Ricuce le lettere staccate: `a m m a z z a t i` → `ammazzati`, lasciando stare
 * tutto il resto. Tre lettere isolate di fila non capitano in una frase vera.
 */
function ricuci(testo) {
  return testo.replace(/\b[a-z](?: [a-z]\b){2,}/g, (pezzo) => pezzo.replace(/ /g, ''));
}

/**
 * Tutte le letture di un testo, ognuna con gli spazi attorno: cosi' una parola
 * intera si cerca con `' parola '` anche all'inizio e alla fine.
 */
function letture(testo) {
  const senzaTronche = TRONCHE_INNOCUE.reduce(
    (uscita, parola) => uscita.split(parola).join(' '),
    String(testo || '').normalize('NFC').toLowerCase()
  );
  const chiaro = pulisci(senzaTronche);
  const conCifre = soloLettere(conNumeri(chiaro));
  const conTutto = soloLettere(conNumeri(conSimboli(chiaro)));
  const senzaCifre = soloLettere(chiaro);

  const distinte = (elenco) => [...new Set(elenco.filter(Boolean))];

  const normali = distinte([
    senzaCifre,
    conCifre,
    conTutto,
    ricuci(conCifre),
    ricuci(conTutto),
  ]);
  const senzaInnocue = (lettura) =>
    lettura
      .split(' ')
      .filter((parola) => !INNOCUE.has(parola))
      .join(' ');
  const schiacciate = distinte(normali.map(senzaInnocue).map(schiaccia));
  const alRovescio = (parole) =>
    [...parole].reverse().map((parola) => [...parola].reverse().join(''));
  const dritte = distinte([conCifre, conTutto]).map((lettura) => lettura.split(' '));

  return {
    chiaro,
    normali: normali.map((lettura) => ` ${lettura} `),
    schiacciate: schiacciate.map((lettura) => ` ${lettura} `),
    // Parola per parola, per i giri di parole. Le ripetizioni si riducono a due e non a
    // una: l'italiano ha le doppie, e `salta` deve restare `salta` in `saltaaaa`.
    frasi: distinte(normali.map((lettura) => lettura.replace(/([a-z])\1{2,}/g, '$1$1'))).map(
      (lettura) => lettura.split(' ')
    ),
    // Le stesse parole, dritte e lette dall'ultima lettera alla prima.
    sequenze: [...dritte, ...dritte.map(alRovescio)],
    // Le parole una per una, per il confronto con un margine di errore.
    parole: distinte(schiacciate.flatMap((lettura) => lettura.split(' '))),
  };
}

// ---------------------------------------------------------------------------
// Il confronto
// ---------------------------------------------------------------------------

function radiceCombacia(parola, radice) {
  return radice.startsWith('=') ? parola === radice.slice(1) : parola.startsWith(radice);
}

/**
 * La prima richiesta pericolosa fatta a giri di parole: si scorre il testo a finestre, e
 * in una finestra deve esserci una parola per ogni gruppo.
 */
function cercaCombinazione(parole, consentite) {
  for (const { categoria, gruppi, finestra = FINESTRA_NORMALE } of COMBINAZIONI) {
    for (let inizio = 0; inizio < parole.length; inizio += 1) {
      const tratto = parole.slice(inizio, inizio + finestra);
      const trovate = gruppi.map((gruppo) =>
        tratto.find((parola) => gruppo.some((radice) => radiceCombacia(parola, radice)))
      );

      if (trovate.every(Boolean)) {
        const termine = trovate.join(' + ');

        if (!consentite.has(termine)) {
          return { categoria, termine };
        }
      }
    }
  }

  return null;
}

/** Quante correzioni di una lettera separano due parole, fermandosi a due. */
function quasiUguali(a, b) {
  if (a === b) {
    return true;
  }

  if (Math.abs(a.length - b.length) > 1) {
    return false;
  }

  let i = 0;

  while (i < a.length && i < b.length && a[i] === b[i]) {
    i += 1;
  }

  const restoA = a.slice(i);
  const restoB = b.slice(i);

  return (
    restoA.slice(1) === restoB.slice(1) || // una lettera cambiata
    restoA === restoB.slice(1) || // una lettera in piu'
    restoA.slice(1) === restoB || // una lettera in meno
    // due lettere scambiate
    (restoA.length > 1 &&
      restoB.length > 1 &&
      restoA[0] === restoB[1] &&
      restoA[1] === restoB[0] &&
      restoA.slice(2) === restoB.slice(2))
  );
}

/** Un termine dell'elenco, come si cerca in ogni lettura. */
function preparaFrammento(termine) {
  // Lo spazio in fondo vuol dire "e qui la parola finisce".
  const finisce = /\s$/.test(termine) ? ' ' : '';
  const parole = soloLettere(pulisci(termine));
  const schiacciato = schiaccia(parole);

  return {
    termine: termine.trim(),
    // **Sempre dall'inizio di una parola.** `lucidità` contiene `ucidit`,
    // `amputando` contiene `putan`, `disputa` contiene `sputa`: l'italiano si
    // coniuga in fondo, non davanti, quindi si perde poco e si guadagna tutto.
    normale: ` ${parole}${finisce}`,
    // **Schiacciato solo se resta abbastanza lungo.** `rissa` diventerebbe
    // `risa`, dentro "risate"; `alunn` diventerebbe `alun`, dentro "allunare".
    // Se non aveva doppie non cambia niente, e vale a qualunque lunghezza.
    schiacciato:
      schiacciato === parole || schiacciato.length >= 5 ? ` ${schiacciato}${finisce}` : null,
  };
}

function preparaIntera(termine) {
  const parole = soloLettere(pulisci(termine));

  return {
    termine,
    normale: ` ${parole} `,
    schiacciato: ` ${schiaccia(parole)} `,
  };
}

function preparaElenco(elenco, prepara) {
  return Object.entries(elenco).map(([categoria, termini]) => ({
    categoria,
    termini: termini.map(prepara),
  }));
}

const ROSSE_PRONTE = preparaElenco(ROSSE, preparaFrammento);
const ROSSE_INTERE_PRONTE = preparaElenco(ROSSE_INTERE, preparaIntera);
const ATTACCATE_PRONTE = Object.entries(ROSSE_ATTACCATE).flatMap(([categoria, termini]) =>
  termini.map((termine) => {
    const attaccato = schiaccia(soloLettere(pulisci(termine)).replace(/ /g, ''));

    return { categoria, termine, attaccato, suono: comeSuona(attaccato) };
  })
);
const PER_TESTO = new Map(ATTACCATE_PRONTE.map((voce) => [voce.attaccato, voce]));
const PER_SUONO = new Map(ATTACCATE_PRONTE.map((voce) => [voce.suono, voce]));

/** Quanti pezzi puo' avere una parola spezzata: `t a g l i a t i l e v e n e` sono 14. */
const PEZZI_MASSIMI = 30;

/**
 * **Le espressioni spezzate o attaccate, senza inventarsi niente fra una parola e
 * l'altra.** Togliere tutti gli spazi e cercare dentro non si puo': "stivali lucidi lo
 * scorso natale" attaccato contiene `ucidilo`. Quindi due casi soli:
 *
 * - dentro una parola sola: `daiammazzati`;
 * - a cavallo di piu' parole, solo se insieme fanno **esattamente** l'espressione:
 *   `am maz za ti`, `dio cane`.
 */
function cercaAttaccata(parole, consentite) {
  for (let i = 0; i < parole.length; i += 1) {
    const una = schiaccia(parole[i]);
    const unaComeSuona = comeSuona(una);

    for (const voce of ATTACCATE_PRONTE) {
      if (
        !consentite.has(voce.termine) &&
        (una.includes(voce.attaccato) || unaComeSuona.includes(voce.suono))
      ) {
        return voce;
      }
    }

    let insieme = parole[i];

    for (let j = i + 1; j < Math.min(parole.length, i + PEZZI_MASSIMI); j += 1) {
      insieme += parole[j];

      const schiacciato = schiaccia(insieme);
      const voce = PER_TESTO.get(schiacciato) || PER_SUONO.get(comeSuona(schiacciato));

      if (voce && !consentite.has(voce.termine)) {
        return voce;
      }
    }
  }

  return null;
}

const GRAVISSIME_PRONTE = GRAVISSIME.map((termine) => ({
  termine,
  schiacciato: schiaccia(termine),
}));
const GIALLE_PRONTE = preparaElenco(GIALLE, preparaFrammento);
const GIALLE_INTERE_PRONTE = preparaElenco(GIALLE_INTERE, preparaIntera);

function cercaInLetture(elenchi, let_, consentite) {
  for (const { categoria, termini } of elenchi) {
    for (const voce of termini) {
      if (consentite.has(voce.termine)) {
        continue;
      }

      if (let_.normali.some((lettura) => lettura.includes(voce.normale))) {
        return { categoria, termine: voce.termine };
      }

      if (
        voce.schiacciato &&
        let_.schiacciate.some((lettura) => lettura.includes(voce.schiacciato))
      ) {
        return { categoria, termine: voce.termine };
      }
    }
  }

  return null;
}

/**
 * **I numeri di una velocita' da strada.** "Vai a 200 km/h con la macchina" non
 * contiene una sola parola vietata, e dal punto di vista di un elenco e' uguale a
 * "foto del cartello dei 50 km/h". Da centotrenta in su, cioe' dove in Italia
 * nessuna strada lo permette, ci si ferma qui.
 */
const VELOCITA_VIETATA = 130;

function velocitaVietata(chiaro) {
  // "All'ora" e "km/h" sono velocita' per forza. I chilometri da soli no: "a 200 km da
  // casa" e' una distanza. Valgono solo se intorno si parla di veicoli, e non se dopo
  // viene "da" o "di".
  const unita = /\b([0-9oil]{2,4})\s*(km\s*\/?\s*h\b|kmh\b|km\s*orari|km\s*all['’ ]?ora|chilometri\s*(?:orari|all['’ ]?ora)|kilometri\s*(?:orari|all['’ ]?ora)|all['’ ]?ora\b|orari\b|km\b(?!\s+(?:da|di|dal|dalla|dalle|lontano)\b))/g;
  const conVeicoli = /\b(?:vai|andare|corri|sfreccia|macchina|auto|moto|motorino|scooter|guid|tachimetro|velocit)/;
  let trovata = unita.exec(chiaro);

  while (trovata) {
    const numero = Number(trovata[1].replace(/o/g, '0').replace(/[il]/g, '1'));
    const soloChilometri = /^km$/.test(trovata[2]);

    if (
      Number.isFinite(numero) &&
      numero >= VELOCITA_VIETATA &&
      (!soloChilometri || conVeicoli.test(chiaro))
    ) {
      return `${numero} km/h`;
    }

    trovata = unita.exec(chiaro);
  }

  const aParole =
    /\b(?:centotrenta|centoquaranta|centocinquanta|centosessanta|centosettanta|centottanta|centonovanta|duecento|duecentocinquanta|trecento)\s*(?:km\s*\/?\s*h|kmh|km\s*orari|km\s*all['’ ]?ora|chilometri\s*(?:orari|all['’ ]?ora)|all['’ ]?ora|orari)/;
  const scritta = aParole.exec(chiaro);

  return scritta ? scritta[0] : null;
}

/** Le aggiunte fatte a mano dal pannello. */
function preparaAggiunte(aggiunte) {
  const voci = (Array.isArray(aggiunte) ? aggiunte : [])
    .map((termine) => String(termine || '').trim())
    .filter((termine) => soloLettere(pulisci(termine)).length >= 2);

  return voci.map(preparaFrammento);
}

/**
 * **Il controllo.** Passa titolo, consegna e riga per l'amico insieme.
 *
 * Torna `{ rossa, gialle }`: `rossa` e' la prima parola che ferma la missione
 * (o `null`), `gialle` tutte quelle che la mandano da una persona.
 *
 * `opzioni` viene dal pannello: `rosseAggiunte`, `gialleAggiunte` e `consentite`,
 * per chiudere un travestimento nuovo o riaprire un falso allarme senza dover
 * pubblicare il codice.
 */
function controlla(testi, opzioni = {}) {
  const pezzi = (Array.isArray(testi) ? testi : [testi]).map((t) => String(t || ''));
  const consentite = new Set(
    (opzioni.consentite || []).map((t) => String(t).trim()).filter(Boolean)
  );
  const rosseAggiunte = [
    { categoria: 'aggiunta', termini: preparaAggiunte(opzioni.rosseAggiunte) },
  ];
  const gialleAggiunte = [
    { categoria: 'aggiunta', termini: preparaAggiunte(opzioni.gialleAggiunte) },
  ];

  let rossa = null;
  const gialle = new Map();

  const segnaRossa = (categoria, termine, testo) => {
    if (!rossa) {
      rossa = {
        categoria,
        termine,
        testo,
        messaggio: (CATEGORIE[categoria] || CATEGORIE.pericolo).messaggio,
      };
    }
  };

  for (const testo of pezzi) {
    if (!testo.trim()) {
      continue;
    }

    const let_ = letture(testo);

    // Prima le rosse, a partire da quelle aggiunte: sono le piu' recenti, cioe'
    // i travestimenti che qualcuno sta usando adesso.
    const trovata =
      cercaInLetture(rosseAggiunte, let_, consentite) ||
      cercaInLetture(ROSSE_PRONTE, let_, consentite) ||
      cercaInLetture(ROSSE_INTERE_PRONTE, let_, consentite);

    if (trovata) {
      segnaRossa(trovata.categoria, trovata.termine, testo);
    }

    const velocita = velocitaVietata(let_.chiaro);

    if (velocita && !consentite.has(velocita)) {
      segnaRossa('pericolo', velocita, testo);
    }

    for (const parole of let_.sequenze) {
      const voce = cercaAttaccata(parole, consentite);

      if (voce) {
        segnaRossa(voce.categoria, voce.termine, testo);
      }
    }

    for (const parole of let_.frasi) {
      const giro = cercaCombinazione(parole, consentite);

      if (giro) {
        segnaRossa(giro.categoria, giro.termine, testo);
      }
    }

    for (const parola of let_.parole) {
      if (parola.length < 6) {
        continue;
      }

      for (const voce of GRAVISSIME_PRONTE) {
        if (!consentite.has(voce.termine) && quasiUguali(parola, voce.schiacciato)) {
          segnaRossa('autolesionismo', voce.termine, testo);
        }
      }
    }

    // Poi le gialle, tutte e non solo la prima: nel pannello si deve vedere
    // perche' la missione e' arrivata li'.
    for (const elenchi of [gialleAggiunte, GIALLE_PRONTE, GIALLE_INTERE_PRONTE]) {
      for (const { categoria, termini } of elenchi) {
        for (const voce of termini) {
          if (consentite.has(voce.termine)) {
            continue;
          }

          if (
            let_.normali.some((lettura) => lettura.includes(voce.normale)) ||
            (voce.schiacciato &&
              let_.schiacciate.some((lettura) => lettura.includes(voce.schiacciato)))
          ) {
            gialle.set(voce.termine, { categoria, termine: voce.termine });
          }
        }
      }
    }

    // Una velocita' qualunque, anche sotto il limite: la guarda una persona.
    if (/\b[0-9oil]{2,4}\s*(?:km\b|kmh\b)/.test(let_.chiaro)) {
      gialle.set('velocita', { categoria: 'veicoli', termine: 'velocità' });
    }

    for (const [categoria, simboli] of Object.entries(EMOJI_GIALLE)) {
      for (const simbolo of simboli) {
        if (testo.includes(simbolo)) {
          gialle.set(simbolo, { categoria, termine: simbolo });
        }
      }
    }
  }

  return { rossa, gialle: [...gialle.values()] };
}

/**
 * Il testo come lo guarda chi confronta due missioni: stesso testo, stessa
 * impronta, anche con le maiuscole e gli spazi diversi. Vedi `giudice.js`.
 */
function formaCanonica(testo) {
  return pulisci(testo).replace(/\s+/g, ' ').trim();
}

module.exports = {
  CATEGORIE,
  VELOCITA_VIETATA,
  controlla,
  formaCanonica,
  letture,
  pulisci,
  // Per le prove e per la scansione col dizionario.
  COMBINAZIONI,
  ROSSE,
  ROSSE_INTERE,
  GIALLE,
  GIALLE_INTERE,
};
