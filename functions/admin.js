/**
 * **Il tavolo dell'amministratore: le segnalazioni, e cosa se ne fa.**
 *
 * Sta in un file a parte come i soldi, e per la stessa ragione: tutto quello
 * che un utente normale non deve poter fare si legge in un posto solo, e chi
 * cerca il buco sa dove guardare.
 *
 * ## Come e' protetto
 *
 * **Non basta nascondere la pagina.** La dashboard e' HTML statico servito da
 * Hosting: chiunque puo' aprirla, leggerne il sorgente e copiarne le chiamate.
 * Quello che la tiene in piedi e' che **la pagina non legge niente da sola** —
 * non tocca Firestore, non tocca Storage, non conosce nessun percorso del
 * database. Chiede tutto a queste funzioni, e queste funzioni fanno una cosa
 * prima di ogni altra: guardano il `custom claim` `admin` dentro il gettone di
 * chi chiama.
 *
 * Il claim sta **dentro il gettone firmato da Firebase**, non dentro un
 * documento che qualcuno possa scrivere: non si puo' falsificare da un
 * telefono, non si puo' mettere da soli, e non passa dalle regole di Firestore
 * — le attraversa proprio. A metterlo e' `tool/nomina_admin.js`, che gira sul
 * computer di chi tiene il progetto con le credenziali del progetto.
 *
 * Dall'altra parte le regole di Firestore restano chiuse: `/reports` non lo
 * legge nessuno e non lo aggiorna nessuno, nemmeno chi l'ha scritto. Anche se
 * un domani qualcuno si prendesse il claim, dal client non ci arriverebbe
 * comunque: passa da qui, e qui c'e' scritto chi puo'.
 *
 * ## Nessuna soglia
 *
 * Non c'e' niente che tolga una foto da solo. Una segnalazione porta il
 * contenuto qui e basta; a decidere e' una persona, **anche su una
 * segnalazione sola**. Il vecchio meccanismo — trenta segnalazioni e la foto
 * usciva — e' stato tolto: un contatore non ha mai guardato una foto, e tre
 * account bastavano a far sparire quella di un rivale il giorno prima che
 * vincesse un premio.
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const {
  avvisaChiLHaMandata,
  togliLAvvisoDiRimozione,
  avvisaCheETornata,
  motivoDallaSegnalazione,
} = require('./avvisi');
const { revisioneDi, chiudiLaRevisione } = require('./revisioni');
const { liberaLeFiamme } = require('./fiamme');
const { magazzinoDi } = require('./magazzino');
const { autoreDi } = require('./autori');
const posta = require('./posta');
const sospensioni = require('./sospensioni');
const { registra } = require('./registro');
const { avvisaDelContenutoTolto } = require('./avvisi');
const { ORE_PER_DECIDERE, SEGNALANTI, scadenzaDi } = require('./moderazione');

const db = admin.firestore();

// Le missioni automatiche: vedi `salvadanaio.js`.
const fondo = require('./salvadanaio');

// Serve a una cosa sola: restituire il premio quando si toglie di mezzo una
// missione segnalata. Vedi `adminResolveReport`.
const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY');

/** Quante segnalazioni si mandano alla dashboard in un colpo solo. */
const PAGINA = 50;

/**
 * Gli stati di una segnalazione, scritti come stanno sul database.
 *
 * `open` non c'e' fra quelli che si possono scrivere ed e' voluto: e' il
 * valore vecchio, quello di tutte le segnalazioni arrivate prima che questi
 * stati esistessero. Si **legge** come `new`, e nessuno lo scrive piu'.
 */
const STATI = ['new', 'reviewing', 'fake', 'removed'];

/** Come si legge uno stato scritto sul database, `open` compreso. */
function statoDi(valore) {
  if (!valore || valore === 'open') {
    return 'new';
  }

  return STATI.includes(valore) ? valore : 'new';
}

/**
 * Si ferma qui se chi chiama non e' un amministratore.
 *
 * Due controlli e non uno: **c'e' un gettone** e **quel gettone dice `admin`**.
 * Separati perche' sono due errori diversi da spiegare — non hai fatto
 * l'accesso, e non sei un amministratore — e chi apre la dashboard deve
 * leggere quello giusto invece di un rifiuto muto.
 */
function soloAdmin(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Fai prima l\'accesso.');
  }

  if (request.auth.token.admin !== true) {
    logger.warn('tentativo di accesso amministrativo', {
      uid: request.auth.uid,
    });

    throw new HttpsError('permission-denied', 'Non sei un amministratore.');
  }

  return request.auth.uid;
}

/**
 * Il riferimento alla partecipazione segnalata, o `null` se non ce n'e' una.
 *
 * **Solo per le segnalazioni su una foto.** Un commento segnalato porta anche lui la
 * gara e la foto a cui sta sotto, per dire dov'e': decidere su quello non deve
 * toccare la foto di nessuno.
 */
function fotoDi(dati) {
  const challengeId = String(dati.challengeId || '');
  const entryId = String(dati.entryId || '');

  if (dati.kind !== 'entry' || !challengeId || !entryId) {
    return null;
  }

  return db
    .collection('challenges')
    .doc(challengeId)
    .collection('entries')
    .doc(entryId);
}

/**
 * **Dice soltanto se chi chiama e' un amministratore.**
 *
 * Serve alla dashboard per decidere cosa mostrare subito dopo l'accesso: senza,
 * dovrebbe chiedere l'elenco delle segnalazioni e interpretare un rifiuto, che
 * e' il modo piu' storto di fare una domanda a cui si puo' rispondere si' o no.
 *
 * Non rivela niente: chi non e' amministratore riceve `false`, che e' una cosa
 * che sapeva gia'.
 */
exports.adminWhoAmI = onCall(async (request) => {
  return {
    admin: Boolean(request.auth && request.auth.token.admin === true),
    uid: request.auth ? request.auth.uid : null,
  };
});

/**
 * L'elenco delle segnalazioni, gia' pronto da mostrare.
 *
 * **Torna anche cio' che il database non ha scritto dentro la segnalazione**:
 * la foto viva, quante persone diverse hanno segnalato quella stessa
 * partecipazione, se e' gia' fuori dalla gara. Sono le tre cose che servono a
 * decidere, e nessuna delle tre sta dentro il documento della segnalazione.
 *
 * Dove la partecipazione esiste ancora **vince lei**: la foto e il nome
 * dell'autore si leggono di li'. La copia scritta dentro la segnalazione e'
 * un ripiego per quando la partecipazione e' stata cancellata dalla pulizia
 * delle quarantotto ore — arriva da un telefono, quindi va bene per far vedere
 * qualcosa, non per fondarci una decisione.
 *
 * ## I filtri e la scadenza
 *
 * Per stato, tipo di contenuto, motivo e data. **Le aperte arrivano dalla piu'
 * vecchia**: e' quella che scade prima, e il tetto delle 24 ore si rispetta
 * guardando prima lei. Le chiuse dalla piu' recente.
 *
 * Quelle mandate da chi ne ha mandate troppe (`sospetta`) stanno in fondo alle
 * aperte: vedi `moderazione.js`.
 */
exports.adminListReports = onCall(async (request) => {
  soloAdmin(request);

  const filtri = request.data || {};
  const stato = filtri.status;
  const limite = Math.min(Number(filtri.limit || PAGINA), PAGINA);
  const tipo = String(filtri.kind || '');
  const motivo = String(filtri.reason || '');
  const dal = Number(filtri.dal) || 0;
  const al = Number(filtri.al) || 0;

  const documenti = await leggiLeSegnalazioni(stato, { dal, al });
  const righe = [];

  for (const doc of documenti) {
    const dati = doc.data() || {};
    const suo = statoDi(dati.status);
    const quando = dati.createdAt ? dati.createdAt.toMillis() : 0;

    if (
      (stato && stato !== 'all' && suo !== stato) ||
      (tipo && dati.kind !== tipo) ||
      (motivo && dati.reason !== motivo) ||
      (dal && quando < dal) ||
      (al && quando > al)
    ) {
      continue;
    }

    righe.push({ doc, dati, stato: suo, quando });
  }

  const aperta = (riga) => riga.stato === 'new' || riga.stato === 'reviewing';

  righe.sort((a, b) => {
    // Prima quelle da decidere, e fra queste la piu' vecchia: e' la piu' vicina
    // alla scadenza. Le sospette in fondo alle aperte.
    if (aperta(a) !== aperta(b)) {
      return aperta(a) ? -1 : 1;
    }

    if (!aperta(a)) {
      return b.quando - a.quando;
    }

    const sospette = Number(a.dati.sospetta === true) - Number(b.dati.sospetta === true);

    return sospette || a.quando - b.quando;
  });

  const scelte = righe.slice(0, limite);

  // **Chi ha segnalato, e quante delle sue sono state respinte.** Il team lo deve
  // poter vedere: serve a giudicare e a riconoscere chi usa le segnalazioni come
  // arma. Non esce mai da qui: a chi e' stato segnalato non arriva, in nessuna
  // schermata e in nessun avviso.
  const chiSegnala = [...new Set(scelte.map((r) => String(r.dati.reporterId || '')).filter(Boolean))];
  // E chi ha deciso: un nome, non un identificativo.
  const chiNominare = [
    ...new Set([...chiSegnala, ...scelte.map((r) => String(r.dati.resolvedBy || '')).filter(Boolean)]),
  ];
  const [nomi, reputazioni] = chiSegnala.length
    ? await Promise.all([
        db.getAll(...chiNominare.map((uid) => db.collection('users').doc(uid))),
        db.getAll(...chiSegnala.map((uid) => db.collection(SEGNALANTI).doc(uid))),
      ])
    : [[], []];
  const nomeDi = new Map(nomi.map((d) => [d.id, String(d.get('username') || '')]));
  const respinteDi = new Map(reputazioni.map((d) => [d.id, Number(d.get('respinte') || 0)]));
  const adesso = Date.now();

  // Le partecipazioni si leggono una volta per foto, non una per segnalazione:
  // dieci segnalazioni sulla stessa foto sono dieci righe e **una** lettura.
  const cache = new Map();

  async function partecipazione(dati) {
    const riferimento = fotoDi(dati);

    if (!riferimento) {
      return null;
    }

    const chiave = riferimento.path;

    if (!cache.has(chiave)) {
      cache.set(chiave, await riferimento.get());
    }

    const trovata = cache.get(chiave);

    return trovata.exists ? trovata : null;
  }

  const reports = [];

  for (const riga of scelte) {
    const { doc, dati } = riga;
    const foto = await partecipazione(dati);
    const chiHaSegnalato = foto ? foto.get('reporters') : null;
    const vero = dati.verificato || {};
    const reporterId = String(dati.reporterId || '');
    const scadeIl = riga.quando ? scadenzaDi(riga.quando) : null;

    reports.push({
      id: doc.id,
      status: riga.stato,
      kind: String(dati.kind || ''),
      reason: String(dati.reason || ''),
      note: String(dati.note || ''),
      challengeId: String(dati.challengeId || ''),
      challengeTitle: String(
        (foto && foto.get('challengeTitle')) || vero.titolo || dati.challengeTitle || ''
      ),
      entryId: String(dati.entryId || ''),
      commentId: String(dati.commentId || ''),
      reportedUserId: String(dati.reportedUserId || ''),
      reportedUsername: String(
        (foto && foto.get('authorName')) || vero.autoreNome || dati.reportedUsername || ''
      ),
      // Quello che il server ha letto arrivando la segnalazione: il commento o la
      // consegna possono non esserci piu', e chi decide li deve poter leggere.
      testo: String(vero.testo || dati.commentText || ''),
      reporterId,
      reporterUsername: nomeDi.get(reporterId) || '',
      reporterRespinte: respinteDi.get(reporterId) || 0,
      sospetta: dati.sospetta === true,
      mediaUrl: String((foto && foto.get('mediaUrl')) || vero.mediaUrl || dati.mediaUrl || ''),
      mediaKind: String((foto && foto.get('mediaKind')) || vero.mediaKind || 'photo'),
      createdAt: dati.createdAt ? dati.createdAt.toMillis() : null,
      resolvedAt: dati.resolvedAt ? dati.resolvedAt.toMillis() : null,
      resolvedBy: String(dati.resolvedBy || ''),
      resolvedByUsername: nomeDi.get(String(dati.resolvedBy || '')) || '',
      // **Il tetto delle 24 ore, per chi guarda.** Vale per quelle ancora da
      // decidere: una chiusa non scade.
      scadeIl: aperta(riga) ? scadeIl : null,
      scaduta: aperta(riga) && scadeIl !== null && scadeIl < adesso,
      // Quante persone **diverse** hanno segnalato questa stessa foto. Non
      // decide niente — non c'e' nessuna soglia — ma davanti a venti
      // segnalazioni si guarda prima.
      reportsOnTarget: Array.isArray(chiHaSegnalato) ? chiHaSegnalato.length : 1,
      // Se e' gia' fuori dalla gara: evita di decidere due volte la stessa
      // cosa, e dice perche' la foto non si vede piu'.
      entryExists: Boolean(foto),
      entryModeration: foto ? String(foto.get('moderation') || 'approved') : '',
    });
  }

  return { reports, total: righe.length, orePerDecidere: ORE_PER_DECIDERE };
});

/**
 * **Le segnalazioni giuste, gia' in ordine, dal database.**
 *
 * Prima si prendevano cinquecento documenti qualunque e si filtrava dopo: passate
 * le cinquecento, le piu' recenti potevano restare fuori — cioe' proprio quelle da
 * guardare entro 24 ore, senza che nessuno se ne accorgesse.
 *
 * **Se l'indice non e' ancora pronto si ripiega sul vecchio modo.** Si pubblica
 * insieme al resto, ma si costruisce con calma: per qualche minuto dopo il rilascio
 * la lista deve funzionare lo stesso.
 */
async function leggiLeSegnalazioni(stato, { dal, al }) {
  const stati = stato === 'new' ? ['new', 'open'] : STATI.includes(stato) ? [stato] : null;

  try {
    let query = db.collection('reports');

    if (stati) {
      query = query.where('status', 'in', stati);
    }

    if (dal) {
      query = query.where('createdAt', '>=', admin.firestore.Timestamp.fromMillis(dal));
    }

    if (al) {
      query = query.where('createdAt', '<=', admin.firestore.Timestamp.fromMillis(al));
    }

    const crescente = stato === 'new' || stato === 'reviewing';

    return (await query.orderBy('createdAt', crescente ? 'asc' : 'desc').limit(500).get()).docs;
  } catch (errore) {
    logger.warn('segnalazioni lette senza indice', {
      messaggio: String((errore && errore.message) || errore).slice(0, 200),
    });

    return (await db.collection('reports').limit(500).get()).docs;
  }
}

/**
 * **Toglie un commento segnalato.** Si cancella davvero: non ha un file e non ha
 * un'attesa da rispettare, e il testo resta scritto nella segnalazione e nel
 * registro. Torna quello che c'era scritto, o `null` se non c'era piu'.
 */
async function togliIlCommento(dati, motivo) {
  const riferimento = db
    .collection('challenges')
    .doc(String(dati.challengeId || ''))
    .collection('entries')
    .doc(String(dati.entryId || ''))
    .collection('comments')
    .doc(String(dati.commentId || ''));
  const commento = await riferimento.get();

  if (!commento.exists) {
    return null;
  }

  await riferimento.delete();
  await avvisaDelContenutoTolto(String(commento.get('userId') || ''), {
    cosa: 'commento',
    id: riferimento.id,
    motivo,
    automatico: false,
  });

  return String(commento.get('text') || '');
}

/**
 * Se due segnalazioni parlano della stessa cosa: si chiudono insieme.
 *
 * **Il tipo conta.** Un commento segnalato sta sotto la stessa foto e sta nella
 * stessa gara di quella foto: decidere sul commento non chiude le segnalazioni sulla
 * foto, e viceversa.
 */
function stessoBersaglio(a, b) {
  return (
    a.kind === b.kind &&
    String(a.challengeId || '') === String(b.challengeId || '') &&
    String(a.entryId || '') === String(b.entryId || '') &&
    String(a.commentId || '') === String(b.commentId || '') &&
    (a.kind !== 'user' || String(a.reportedUserId || '') === String(b.reportedUserId || ''))
  );
}

/** Le altre segnalazioni che parlano della stessa cosa. */
async function segnalazioniSorelle(dati) {
  const reports = db.collection('reports');
  let query = null;

  // Due uguaglianze non vogliono un indice composto: Firestore le incrocia da solo
  // sugli indici dei singoli campi.
  if (dati.kind === 'user' && dati.reportedUserId) {
    query = reports.where('reportedUserId', '==', String(dati.reportedUserId));
  } else if (dati.challengeId && dati.kind === 'challenge') {
    query = reports.where('challengeId', '==', String(dati.challengeId));
  } else if (dati.challengeId && dati.entryId) {
    query = reports
      .where('challengeId', '==', String(dati.challengeId))
      .where('entryId', '==', String(dati.entryId));
  }

  if (!query) {
    return [];
  }

  const trovate = await query.limit(200).get();

  return trovate.docs.filter((doc) => stessoBersaglio(doc.data() || {}, dati));
}

/**
 * **Toglie una foto dalla gara.** Da un punto solo, che serva a una segnalazione o
 * a un tasto del pannello: stesse conseguenze, stesso avviso.
 *
 * **Chi esce dalla gara non conta piu' fra i partecipanti.** Il controllo
 * automatico lo faceva gia'; qui no, e una missione con l'unica foto tolta restava
 * a "1 partecipante": chi l'aveva lanciata non poteva piu' cancellarla, perche' il
 * tasto c'e' solo a zero. Si abbassa una volta sola: una foto gia' fuori non esce
 * due volte.
 *
 * **Perche' e' uscita, scritto sulla foto stessa.** Fra una tolta dal riconoscimento
 * immagini e una tolta da una persona c'e' una differenza enorme il giorno in cui
 * qualcuno chiede spiegazioni, e senza questo campo le due sono identiche.
 */
async function togliLaFoto(foto, { chi, autore, titolo, motivo = 'altro' }) {
  const adesso = await foto.get();

  if (!adesso.exists) {
    throw new HttpsError('not-found', 'Questa foto non c\'è più.');
  }

  await db.runTransaction(async (t) => {
    const ora = await t.get(foto);

    if (ora.exists && ora.get('moderation') !== 'rejected') {
      t.update(foto.parent.parent, {
        participantsCount: admin.firestore.FieldValue.increment(-1),
      });
    }

    t.update(foto, {
      moderation: 'rejected',
      moderationReason: 'admin',
      moderatedBy: chi,
      moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  const challengeId = foto.parent.parent.id;

  await avvisaChiLHaMandata(
    autore || String(adesso.get('userId') || ''),
    challengeId,
    titolo || String(adesso.get('challengeTitle') || ''),
    { motivo, automatico: false }
  );

  // Le fiamme che aveva preso tornano a chi gliele aveva date.
  await liberaLeFiamme(challengeId, foto.id);

  return { tolta: true };
}

/**
 * **La decisione dell'amministratore su una segnalazione.**
 *
 * Tre sole, e sono quelle che si prendono davvero davanti a una foto:
 *
 * - `reviewing` — l'ho presa in mano, non ho ancora deciso. Serve quando si e'
 *   in due: senza, due persone guardano la stessa foto e decidono due volte.
 * - `fake` — non c'era niente. La foto **resta online**, e torna visibile
 *   anche a chi l'aveva segnalata: quella sparizione era il rispetto di una
 *   sua richiesta, e la richiesta e' stata guardata e respinta. Se era stata
 *   tolta dalla gara, rientra.
 * - `remove` — la foto esce dalla gara. Basta **una** segnalazione: non c'e'
 *   nessuna soglia da raggiungere, perche' a decidere e' una persona che ha
 *   guardato.
 *
 * ## Cosa vuol dire "rimossa"
 *
 * `moderation: 'rejected'`, che e' lo stesso stato del controllo automatico
 * delle immagini: la foto sparisce dalla gara, non prende piu' fiamme e non
 * puo' piu' vincere — `closeChallenge` salta le rifiutate. **Il documento e il
 * file restano.** Cancellare vuol dire non poter piu' tornare indietro su una
 * decisione presa da una persona di fretta, e le decisioni prese di fretta
 * sono esattamente quelle su cui si torna indietro.
 *
 * Tutte le segnalazioni sulla **stessa** foto si chiudono insieme: sono lo
 * stesso caso, e lasciarne nove aperte dopo aver deciso la decima vorrebbe
 * dire rivedere nove volte una cosa gia' vista.
 */
exports.adminResolveReport = onCall(
  // La posta serve all'email di chi viene sospeso: vedi `sospensioni.js`.
  { secrets: [STRIPE_SECRET_KEY, posta.SMTP_PASSWORD, posta.RESEND_API_KEY] },
  async (request) => {
  const chi = soloAdmin(request);

  const reportId = String((request.data && request.data.reportId) || '');
  const decisione = String((request.data && request.data.decision) || '');

  // **Quanti giorni di sospensione, se se ne sceglie una.** Assente: nessuna
  // sospensione. Zero: per sempre. Vale solo con la rimozione.
  const giorniRichiesti = request.data && request.data.sospendiGiorni;
  const giorni =
    giorniRichiesti === undefined || giorniRichiesti === null
      ? null
      : Number(giorniRichiesti);

  if (!reportId) {
    throw new HttpsError('invalid-argument', 'Manca la segnalazione.');
  }

  if (!['reviewing', 'fake', 'remove'].includes(decisione)) {
    throw new HttpsError('invalid-argument', 'Decisione non valida.');
  }

  if (giorni !== null && !sospensioni.DURATE.includes(giorni)) {
    throw new HttpsError('invalid-argument', 'Durata della sospensione non valida.');
  }

  const riferimento = db.collection('reports').doc(reportId);
  const segnalazione = await riferimento.get();

  if (!segnalazione.exists) {
    throw new HttpsError('not-found', 'Segnalazione non trovata.');
  }

  const dati = segnalazione.data() || {};
  const nuovo = decisione === 'remove' ? 'removed' : decisione;
  const foto = fotoDi(dati);
  // **Due clic, o due amministratori insieme.** La stessa decisione due volte non
  // deve togliere due volte, avvisare due volte o contare due volte. Resta da fare
  // solo una sospensione scelta dopo: "togli" prima, e "sospendi" ripensandoci.
  const giaDecisa = statoDi(dati.status) === nuovo;

  if (giaDecisa && (decisione !== 'remove' || giorni === null)) {
    return { status: nuovo, insieme: 0, sospeso: null, giaDecisa: true };
  }

  // **Una missione segnalata si toglie tutta, non foto per foto.**
  //
  // Finora si poteva segnalare solo chi aveva partecipato, cioe' chi aveva
  // obbedito alla richiesta — la vittima, non chi l'aveva scritta. Adesso si
  // segnala anche la consegna, e toglierla vuol dire toglierla davvero: la
  // missione sparisce, e con lei le foto che erano state mandate per
  // eseguirla.
  //
  // **E il premio torna a chi l'aveva messo, senza le spese.** Anche quando la
  // missione era sua ed era sbagliata: la si toglie perche' non deve esistere,
  // non per tenerne i soldi. Le spese del pagamento invece restano a lui: ha
  // scritto una missione vietata. E' scritto anche nelle condizioni d'uso.
  // **Chi sospendere, se si sospende**: chi ha scritto la missione, o chi ha
  // mandato la foto. L'autore di una missione si legge prima di toglierla:
  // dopo non c'e' piu' niente da leggere.
  let daSospendere = '';
  let perche = '';

  if (decisione === 'remove' && giorni !== null) {
    const titolo = String(dati.challengeTitle || '');

    if (!foto && dati.kind === 'challenge') {
      const gara = await db
        .collection('challenges')
        .doc(String(dati.challengeId || ''))
        .get();

      daSospendere = gara.exists ? await autoreDi(gara) : '';
      perche =
        `La tua missione "${gara.get('title') || titolo}" è stata rimossa ` +
        'perché violava le regole di CRASY.';
    } else {
      // **Chi ha pubblicato lo dice il contenuto, non la segnalazione.** Il campo
      // lo scrive il telefono di chi segnala: fidandosene, bastava scrivere il
      // nome di un altro per far sospendere chi non c'entrava niente.
      const foglio = foto ? await foto.get() : null;

      daSospendere = String(
        (foglio && foglio.exists && foglio.get('userId')) ||
          (dati.verificato && dati.verificato.autoreId) ||
          dati.reportedUserId ||
          ''
      );
      // Una persona segnalata non ha mandato nessuna foto: l'email deve dire la cosa
      // vera, e' quella che legge chi deve capire perche' non puo' piu' entrare.
      perche = foto
        ? `La tua foto nella missione "${titolo}" è stata rimossa perché ` +
          'violava le regole di CRASY.'
        : dati.kind === 'comment'
        ? 'Un tuo commento è stato rimosso perché violava le regole di CRASY.'
        : 'Il tuo profilo è stato segnalato, e una persona del team ha ' +
          'verificato che violava le regole di CRASY.';
    }
  }

  if (!giaDecisa && dati.kind === 'comment' && decisione === 'remove') {
    await togliIlCommento(dati, motivoDallaSegnalazione(dati.reason));
  }

  if (!giaDecisa && !foto && dati.kind === 'challenge' && decisione === 'remove') {
    await rimuoviLaMissione(String(dati.challengeId || ''), chi);
  }

  if (foto && !giaDecisa) {
    const adesso = await foto.get();

    if (adesso.exists) {
      if (decisione === 'remove') {
        await togliLaFoto(foto, {
          chi,
          autore: String(adesso.get('userId') || dati.reportedUserId || ''),
          titolo: String(adesso.get('challengeTitle') || dati.challengeTitle || ''),
          // L'ha decisa una persona, per la voce scelta da chi ha segnalato.
          motivo: motivoDallaSegnalazione(dati.reason),
        });
      }

      if (decisione === 'fake') {
        const rimessa = {
          // **Si svuota l'elenco di chi ha segnalato.** Quell'elenco fa una
          // cosa sola: nascondere la foto agli occhi di chi l'ha segnalata. La
          // richiesta e' stata guardata e respinta, quindi la foto torna
          // visibile a tutti — lasciarla nascosta a qualcuno vorrebbe dire che
          // una segnalazione infondata ha comunque ottenuto qualcosa.
          reporters: [],
          moderationReason: admin.firestore.FieldValue.delete(),
          moderatedBy: chi,
          moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        // Rientra in gara solo se ne era uscita **per le segnalazioni**: una
        // foto rifiutata dal riconoscimento immagini non la rimette dentro una
        // segnalazione infondata: sono due giudizi su due cose diverse.
        if (
          adesso.get('moderation') === 'rejected' &&
          adesso.get('moderationReason') === 'admin'
        ) {
          rimessa.moderation = 'approved';
        }

        await foto.update(rimessa);

        if (rimessa.moderation === 'approved') {
          // Rientra in gara, quindi torna a contare: l'opposto di `remove`.
          await foto.parent.parent.update({
            participantsCount: admin.firestore.FieldValue.increment(1),
          });

          await togliLAvvisoDiRimozione(
            String(adesso.get('userId') || dati.reportedUserId || ''),
            String(dati.challengeId || '')
          );
        }
      }
    }
  }

  // **Tutte le segnalazioni sulla stessa foto si chiudono insieme.**
  //
  // La stessa foto vuol dire **la stessa gara e la stessa partecipazione**, e
  // servono tutte e due. `entryId` da solo non identifica niente: in CRASY la
  // partecipazione ha per identificativo **chi l'ha mandata** — e' la regola
  // "una foto a testa per gara" scritta nella forma dei dati — quindi
  // `entryId` e' l'identificativo di una **persona**, uguale su ogni foto che
  // quella persona ha mandato in vita sua.
  //
  // Cercando per quello soltanto, decidere su una segnalazione decideva su
  // **tutte le foto di quella persona, in tutte le gare**: un "fake" su uno
  // scatto archiviava in silenzio anche la segnalazione grave arrivata su un
  // altro. E' successo davvero, su tre segnalazioni di prova.
  //
  const sorelle = await segnalazioniSorelle(dati);
  const scrittura = db.batch();
  // **"La guardo io" non e' una decisione.** Dice chi l'ha presa in mano, e la
  // segnalazione resta aperta: scrivendo che era risolta, sembrava chiusa a chi la
  // cercava.
  const chiusura =
    decisione === 'reviewing'
      ? {
          status: nuovo,
          presaDa: chi,
          presaIl: admin.firestore.FieldValue.serverTimestamp(),
        }
      : {
          status: nuovo,
          resolvedBy: chi,
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

  scrittura.update(riferimento, chiusura);

  // "La guardo io" prende in mano solo quello che e' ancora da guardare: una sorella
  // gia' decisa resta decisa.
  const altre = sorelle.filter(
    (doc) =>
      doc.id !== reportId &&
      (decisione !== 'reviewing' || statoDi(doc.get('status')) === 'new')
  );

  for (const doc of altre) {
    scrittura.update(doc.ref, chiusura);
  }

  // **Quante segnalazioni di ciascuno sono state respinte.** Non blocca nessuno e
  // non decide niente: lo vede chi modera, accanto al nome, per capire se ha davanti
  // qualcuno che segnala per dare fastidio.
  if (decisione === 'fake') {
    const chiHaSegnalato = [dati, ...altre.map((doc) => doc.data() || {})]
      .filter((d) => statoDi(d.status) !== 'fake')
      .map((d) => String(d.reporterId || ''))
      .filter(Boolean);

    for (const uid of new Set(chiHaSegnalato)) {
      scrittura.set(
        db.collection(SEGNALANTI).doc(uid),
        { respinte: admin.firestore.FieldValue.increment(1) },
        { merge: true }
      );
    }
  }

  if (!giaDecisa) {
    await scrittura.commit();
  }

  logger.info('segnalazione decisa', {
    reportId,
    decisione,
    admin: chi,
    insieme: altre.length + 1,
  });

  // **La sospensione, per ultima.** La rimozione e' gia' fatta: se qui
  // qualcosa va storto, il contenuto vietato e' comunque sparito.
  let sospeso = null;

  if (daSospendere) {
    const fino = await sospensioni.sospendi(daSospendere, {
      giorni,
      motivo: perche,
      chi,
    });

    sospeso = { userId: daSospendere, fino: fino ? fino.toMillis() : null };
  }

  // **Resta scritto chi ha deciso cosa.** Per ultimo: e' il racconto di quello che
  // e' successo, e deve dire anche la sospensione.
  await registra(chi, 'decidiSegnalazione', {
    id: reportId,
    decisione: nuovo,
    kind: String(dati.kind || ''),
    reason: String(dati.reason || ''),
    uid: daSospendere || String(dati.reportedUserId || ''),
    insieme: altre.length + 1,
    sospeso: sospeso ? { giorni } : null,
  });

  return { status: nuovo, insieme: altre.length + 1, sospeso };
  }
);

/**
 * **Le foto che il controllo automatico ha scartato da solo.**
 *
 * SafeSearch sbaglia, e sbaglia nel verso voluto: e' severo apposta. Ma una
 * foto innocua scartata per errore e' una persona che crede di essere in gara
 * e non c'e', e finora nessuno lo vedeva. Qui si vedono tutte, con il motivo,
 * e da qui si rimettono.
 *
 * Solo quelle **automatiche**: le tolte a mano da un amministratore portano
 * `moderationReason: 'admin'` e stanno gia' fra le segnalazioni, dove si
 * decidono.
 *
 * Ci sono finche' c'e' la partecipazione: la pulizia delle quarantotto ore le
 * cancella insieme alle altre.
 */
exports.adminFotoScartate = onCall(async (request) => {
  soloAdmin(request);

  // **In ordine crescente, e si gira dopo.** `limitToLast` chiede a Firestore
  // l'ordine al contrario, e quell'indice non c'e': la chiamata falliva e la
  // pagina mostrava solo "internal". L'indice crescente c'e' gia', e le
  // partecipazioni durano quarantotto ore: sono poche, si prendono tutte.
  const scartate = await db
    .collectionGroup('entries')
    .where('moderation', '==', 'rejected')
    .orderBy('createdAt')
    .limit(300)
    .get();

  // **Le revisioni chieste, insieme alle foto.** Chi ha chiesto che una
  // persona riguardi la sua foto deve trovarla in cima, con il segno: e' una
  // persona che sta aspettando una risposta, spesso a gara ancora aperta.
  const revisioni = scartate.empty
    ? []
    : await db.getAll(
        ...scartate.docs.map((doc) =>
          revisioneDi(doc.ref.parent.parent.id, doc.id)
        )
      );
  const revisioneDiFoto = new Map(
    revisioni
      .filter((r) => r.exists)
      .map((r) => [
        `${r.get('challengeId')}__${r.get('userId')}`,
        {
          stato: String(r.get('stato') || ''),
          chiestaIl: r.get('chiestaIl') ? r.get('chiestaIl').toMillis() : null,
        },
      ])
  );

  const foto = [];

  for (const doc of scartate.docs) {
    const dati = doc.data() || {};
    const revisione =
      revisioneDiFoto.get(`${doc.ref.parent.parent.id}__${doc.id}`) || null;

    // Quelle tolte da una persona stanno fra le segnalazioni, gia' decise: qui
    // tornano solo se chi l'ha mandata chiede che qualcuno le riguardi.
    if (
      dati.moderationReason === 'admin' &&
      !(revisione && revisione.stato === 'aperta')
    ) {
      continue;
    }

    foto.push({
      challengeId: doc.ref.parent.parent.id,
      entryId: doc.id,
      challengeTitle: String(dati.challengeTitle || ''),
      authorName: String(dati.authorName || ''),
      userId: String(dati.userId || ''),
      mediaUrl: String(dati.mediaUrl || ''),
      mediaKind: String(dati.mediaKind || 'photo'),
      motivi: Array.isArray(dati.moderationReasons) ? dati.moderationReasons : [],
      createdAt: dati.createdAt ? dati.createdAt.toMillis() : null,
      moderatedAt: dati.moderatedAt ? dati.moderatedAt.toMillis() : null,
      daUnaPersona: dati.moderationReason === 'admin',
      revisione,
    });
  }

  // Le piu' recenti in cima: sono quelle su cui c'e' ancora tempo per fare
  // qualcosa, a gara aperta. E sopra tutte, chi aspetta una revisione.
  foto.reverse();
  foto.sort(
    (a, b) =>
      Number(Boolean(b.revisione && b.revisione.stato === 'aperta')) -
      Number(Boolean(a.revisione && a.revisione.stato === 'aperta'))
  );

  return { foto };
});

/**
 * **Rimette in gara una foto scartata per errore.**
 *
 * Torna `approved`, e il conto dei partecipanti risale: lo scarto lo aveva
 * abbassato di uno, e chi rientra in gara c'e'. Si scrive anche chi l'ha
 * rimessa, perche' il giorno che una foto sbagliata finisce davanti a tutti
 * si deve poter sapere se l'ha fatta passare la macchina o una persona.
 */
exports.adminRimettiFoto = onCall(async (request) => {
  const chi = soloAdmin(request);

  const challengeId = String((request.data && request.data.challengeId) || '');
  const entryId = String((request.data && request.data.entryId) || '');

  if (!challengeId || !entryId) {
    throw new HttpsError('invalid-argument', 'Manca la foto.');
  }

  const gara = db.collection('challenges').doc(challengeId);
  const foto = gara.collection('entries').doc(entryId);

  const esito = await db.runTransaction(async (t) => {
    const adesso = await t.get(foto);

    if (!adesso.exists) {
      return 'sparita';
    }

    // Due clic, o due amministratori insieme: la seconda volta non deve
    // contare il partecipante un'altra volta.
    if (adesso.get('moderation') !== 'rejected') {
      return 'gia-in-gara';
    }

    t.update(foto, {
      moderation: 'approved',
      moderationReason: 'rimessa',
      moderatedBy: chi,
      moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    t.update(gara, {
      participantsCount: admin.firestore.FieldValue.increment(1),
    });

    return 'rimessa';
  });

  if (esito === 'sparita') {
    throw new HttpsError('not-found', 'La foto non c\'è più.');
  }

  if (esito === 'rimessa') {
    // La partecipazione si chiama come chi l'ha mandata.
    await togliLAvvisoDiRimozione(entryId, challengeId);

    // **E glielo si dice.** Se aveva chiesto una revisione, questa e' la
    // risposta; se non l'aveva chiesta, e' comunque una buona notizia che non
    // deve scoprire per caso.
    await chiudiLaRevisione(challengeId, entryId, 'accolta', chi);
    const gara = await db.collection('challenges').doc(challengeId).get();
    await avvisaCheETornata(
      entryId,
      challengeId,
      String((gara.exists && gara.get('title')) || '')
    );
  }

  logger.info('foto rimessa in gara', { challengeId, entryId, admin: chi, esito });

  if (esito === 'rimessa') {
    await registra(chi, 'rimettiFoto', { challengeId, entryId, uid: entryId });
  }

  return { esito };
});

/**
 * **"L'abbiamo riguardata: resta fuori."**
 *
 * L'altra risposta possibile a una revisione. La foto non si tocca — era gia'
 * fuori — e chi l'aveva chiesta lo legge nella stessa riga della campanella
 * che gli aveva detto della rimozione: niente notifica nuova, perche' una
 * conferma di un no non e' una notizia da schermo bloccato.
 */
exports.adminRespingiRevisione = onCall(async (request) => {
  const chi = soloAdmin(request);

  const challengeId = String((request.data && request.data.challengeId) || '');
  const userId = String((request.data && request.data.userId) || '');

  if (!challengeId || !userId) {
    throw new HttpsError('invalid-argument', 'Manca la foto.');
  }

  const esito = await chiudiLaRevisione(challengeId, userId, 'respinta', chi);

  logger.info('revisione respinta', { challengeId, userId, admin: chi, esito });
  await registra(chi, 'respingiRevisione', { challengeId, uid: userId });

  return { esito };
});

/**
 * **Quanto guadagna davvero CRASY, incasso per incasso.**
 *
 * Su Stripe arrivano soldi che non sono ricavi: chi lancia una missione da 2 €
 * ne paga 2,29, Stripe ne trattiene circa 0,28, 1,80 vanno al vincitore, e
 * quello che resta e' di CRASY. Il cruscotto di Stripe mostra solo il totale;
 * questa funzione fa la divisione, riga per riga.
 *
 * **Le spese di Stripe sono quelle vere**, lette dal registro dei movimenti,
 * non calcolate con la formula: una carta extra europea costa di piu', e la
 * differenza la paga CRASY.
 *
 * E' la stessa regola di `tool/contabilita.js`, che resta per il
 * commercialista; questa e' per guardarla al volo.
 */
exports.adminGuadagni = onCall(
  { secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    soloAdmin(request);

    const giorni = Math.min(
      Math.max(Number((request.data && request.data.giorni) || 30), 1),
      365
    );
    const daQuando = Math.floor(Date.now() / 1000) - giorni * 24 * 60 * 60;

    const stripe = require('stripe')(STRIPE_SECRET_KEY.value());

    const righe = [];
    const totali = {
      incassato: 0,
      speseStripe: 0,
      aiVincitori: 0,
      guadagno: 0,
      guadagnoInAttesa: 0,
      mance: 0,
      altro: 0,
    };

    // Le gare si leggono una volta sola anche se ricorrono.
    const gare = new Map();

    async function gara(id) {
      if (!gare.has(id)) {
        gare.set(id, await db.collection('challenges').doc(id).get());
      }

      return gare.get(id);
    }

    // **Dal registro di Stripe, non dai pagamenti**: e' l'unico posto in cui
    // la commissione e' quella vera.
    for await (const movimento of stripe.balanceTransactions.list({
      limit: 100,
      created: { gte: daQuando },
      expand: ['data.source'],
    })) {
      if (movimento.type !== 'charge' && movimento.type !== 'payment') {
        continue;
      }

      const fonte = movimento.source || {};
      let meta = { ...(fonte.metadata || {}) };

      // **I metadati non sempre arrivano sull'addebito.** Un pagamento fatto
      // dalla pagina di Stripe li tiene sulla sessione, non qui. Si guarda il
      // pagamento, e se nemmeno li' c'e' la gara, la si cerca fra quelle
      // pagate con quel pagamento.
      if (!meta.challengeId && !meta.kind && fonte.payment_intent) {
        const piId =
          typeof fonte.payment_intent === 'string'
            ? fonte.payment_intent
            : fonte.payment_intent.id;

        try {
          const pi = await stripe.paymentIntents.retrieve(piId);
          meta = { ...(pi.metadata || {}), ...meta };
        } catch (errore) {
          logger.warn('pagamento non letto', { piId });
        }

        if (!meta.challengeId && !meta.kind) {
          const pagata = await db
            .collection('challenges')
            .where('stripePaymentIntentId', '==', piId)
            .limit(1)
            .get();

          if (!pagata.empty) {
            meta.challengeId = pagata.docs[0].id;
          }
        }
      }

      const reso = fonte.amount_refunded || 0;
      const netto = movimento.amount - reso;
      const quando = movimento.created * 1000;

      totali.incassato += movimento.amount;
      totali.speseStripe += movimento.fee;

      // La mancia e' tutta di CRASY, meno quello che si prende Stripe.
      if (meta.kind === 'mancia') {
        const tuo = netto - movimento.fee;

        totali.mance += tuo;
        totali.guadagno += tuo;
        righe.push({
          quando,
          cosa: 'Mancia',
          titolo: meta.beneficiarioUsername ? `per @${meta.beneficiarioUsername}` : '',
          pagato: movimento.amount,
          reso,
          stripe: movimento.fee,
          alVincitore: 0,
          tuo,
          stato: 'incassata',
        });

        continue;
      }

      // **Senza una gara dietro non e' un guadagno**: una ricarica del fondo,
      // un pagamento fatto a mano. Si mostra, ma non si conta come tuo.
      // **Una missione annullata non c'e' piu' nel database**, ma il rimborso
      // su Stripe si': e' un premio tornato indietro, e quello che resta —
      // le spese trattenute, meno quelle di Stripe — e' tuo, anche in perdita.
      if (!meta.challengeId && reso > 0) {
        const tuo = netto - movimento.fee;

        totali.guadagno += tuo;
        righe.push({
          quando,
          cosa: 'Missione',
          titolo: fonte.description || '(missione annullata)',
          pagato: movimento.amount,
          reso,
          stripe: movimento.fee,
          alVincitore: 0,
          tuo,
          stato: reso >= movimento.amount ? 'rimborsata' : 'annullata, premio reso',
        });

        continue;
      }

      if (!meta.challengeId) {
        totali.altro += netto - movimento.fee;
        righe.push({
          quando,
          cosa: 'Altro',
          titolo: fonte.description || 'Pagamento senza missione (ricarica fondo?)',
          pagato: movimento.amount,
          reso,
          stripe: movimento.fee,
          alVincitore: 0,
          tuo: 0,
          stato: 'non e\' guadagno',
        });

        continue;
      }

      const doc = await gara(meta.challengeId);
      const premio = Number(meta.prizeCents || 0) || (doc.exists ? doc.get('prizeCents') || 0 : 0);

      // Il vincitore riceve il premio meno il dieci per cento. **Se c'e' stato
      // un rimborso non c'e' nessun vincitore**: la missione e' stata annullata
      // (torna il premio) o e' finita senza nessuno (torna tutto tranne le
      // commissioni di Stripe). Quello che
      // resta sono le spese di incasso trattenute, e sono di CRASY — prima qui
      // finivano "al vincitore", e una missione annullata risultava in perdita.
      const perIlVincitore = premio - Math.floor(premio / 10);
      const alVincitore =
        reso > 0 ? 0 : Math.max(0, Math.min(perIlVincitore, netto));

      // Le spese di Stripe restano anche sui rimborsi: una missione annullata
      // lascia CRASY sotto di qualche centesimo.
      const tuo = netto - alVincitore - movimento.fee;

      const statoPremio = doc.exists ? String(doc.get('prizeStatus') || '') : 'cancellata';
      const stato = reso >= movimento.amount
        ? 'rimborsata'
        : reso > 0 && reso === premio
        ? 'annullata, premio reso'
        : reso > 0
        ? 'rimborsata, senza le commissioni di Stripe'
        : statoPremio === 'paidOut'
        ? 'pagata al vincitore'
        : statoPremio === 'held'
        ? 'in gara / da pagare'
        : statoPremio === 'inRevisione'
        ? 'pagata, in revisione'
        : statoPremio || 'cancellata';

      totali.aiVincitori += alVincitore;
      totali.guadagno += tuo;

      // **In attesa** finche' i soldi del vincitore non sono usciti: la gara
      // puo' ancora chiudersi senza nessuno e tornare tutta indietro.
      if ((statoPremio === 'held' || statoPremio === 'inRevisione') && reso === 0) {
        totali.guadagnoInAttesa += tuo;
      }

      righe.push({
        quando,
        cosa: 'Missione',
        titolo: doc.exists ? String(doc.get('title') || '') : '(missione cancellata)',
        pagato: movimento.amount,
        reso,
        stripe: movimento.fee,
        alVincitore,
        tuo,
        stato,
      });
    }

    righe.sort((a, b) => b.quando - a.quando);

    return { giorni, totali, righe };
  }
);

/**
 * Toglie di mezzo una missione, le sue foto e i suoi file.
 *
 * **Il premio prima di tutto.** Si restituisce finche' la missione c'e'
 * ancora: cancellandola per prima, su Stripe resterebbero dei soldi senza piu'
 * niente che dica a chi tornano — lo stesso ordine che vale quando una
 * missione la cancella chi l'ha lanciata.
 */
async function rimuoviLaMissione(challengeId, chi) {
  if (!challengeId) {
    return;
  }

  const riferimento = db.collection('challenges').doc(challengeId);
  const gara = await riferimento.get();

  if (!gara.exists) {
    return;
  }

  if (gara.get('prizeStatus') === 'held') {
    // **Torna il premio, non le spese.** Una missione si toglie da qui solo
    // dopo una segnalazione guardata da una persona, cioe' perche' chiedeva
    // una cosa vietata: le spese del pagamento le paga chi l'ha scritta, come
    // quando una missione la cancella lui. Il premio invece torna: non e' di
    // CRASY, e' di chi l'ha versato (Termini, punti 4 e 7).
    await require('./payments')
      .refundChallenge(challengeId, { soloIlPremio: true })
      .catch((errore) => logger.error('Premio non reso.', errore));
  }

  // Pagata e mai uscita: tornano i soldi come quando la si rifiuta.
  if (gara.get('prizeStatus') === 'inRevisione') {
    await require('./payments')
      .refundChallenge(challengeId, {
        inRevisione: true,
        motivoDelRimborso: 'non-accettata',
      })
      .catch((errore) => logger.error('Premio non reso.', errore));
  }

  const partecipazioni = await riferimento.collection('entries').get();

  for (const entry of partecipazioni.docs) {
    const percorso = entry.get('storagePath');

    if (percorso) {
      await magazzinoDi(entry)
        .file(percorso)
        .delete({ ignoreNotFound: true })
        .catch(() => {});
    }

    await entry.ref.delete();
  }

  await riferimento.delete();

  logger.info(`Missione ${challengeId} rimossa da ${chi}.`);
}

/**
 * **Quanta gente c'e', per la dashboard.**
 *
 * Non esiste un "online adesso" vero: per averlo servirebbe una connessione
 * aperta con ogni telefono, che costa e serve a poco. Quello che c'e' e'
 * `lastSeenAt`, scritto quando qualcuno apre o riapre l'app — ed e' abbastanza
 * per rispondere alla domanda vera, che non e' *chi sta guardando lo schermo in
 * questo istante* ma **quanta gente sta usando CRASY**.
 *
 * Per questo si contano tre finestre invece di un numero solo: un quarto d'ora
 * dice chi c'e' adesso, oggi dice se la giornata sta andando, la settimana dice
 * se l'app e' viva. Un numero solo si presta a leggerlo male in tutti e due i
 * versi.
 */
exports.adminOnline = onCall(async (request) => {
  soloAdmin(request);

  const adesso = Date.now();

  async function quanti(minuti) {
    const soglia = admin.firestore.Timestamp.fromMillis(
      adesso - minuti * 60000
    );

    // `count()` non porta indietro i documenti: e' una lettura sola qualunque
    // sia il numero, e su una dashboard che si ricarica spesso e' la
    // differenza fra un conto e una bolletta.
    const esito = await db
      .collection('users')
      .where('lastSeenAt', '>', soglia)
      .count()
      .get();

    return esito.data().count;
  }

  const tutti = await db.collection('users').count().get();

  return {
    adesso: await quanti(15),
    oggi: await quanti(60 * 24),
    settimana: await quanti(60 * 24 * 7),
    iscritti: tutti.data().count,
  };
});

/**
 * **Cerca una persona per nome, dal pannello.**
 *
 * Per dare o togliere il verificato bisogna prima trovarla. Cerca per inizio
 * del nome (come la ricerca dell'app) e torna anche chi e' gia' verificato,
 * cosi' dal pannello si vede a colpo d'occhio.
 */
exports.adminCercaUtenti = onCall(async (request) => {
  soloAdmin(request);

  const q = String(request.data?.q || '').trim().toLowerCase().replace(/^@/, '');

  if (q.length < 2) {
    return { utenti: [] };
  }

  const snapshot = await db
    .collection('users')
    .orderBy('username')
    .startAt(q)
    .endAt(q + '\uf8ff')
    .limit(20)
    .get();

  return {
    utenti: await Promise.all(
      snapshot.docs.map(async (doc) => ({
        userId: doc.id,
        username: doc.get('username') || '',
        displayName: doc.get('displayName') || '',
        photoUrl: doc.get('photoUrl') || '',
        verificato: doc.get('verificato') === true,
        verificatoDa: doc.get('verificatoDa') || '',
        // Se e' sospeso, fino a quando: `fino` nullo vuol dire per sempre.
        sospeso: await sospensioni.statoDi(doc.id),
      })),
    ),
  };
});

/**
 * **Da' o toglie il verificato.** Solo il server lo puo' scrivere: le regole
 * del database lo vietano a qualunque telefono.
 */
exports.adminImpostaVerificato = onCall(async (request) => {
  const chi = soloAdmin(request);
  const userId = String(request.data?.userId || '');
  const verificato = request.data?.verificato === true;

  if (!userId) {
    throw new HttpsError('invalid-argument', 'Manca la persona.');
  }

  const ref = db.collection('users').doc(userId);
  const snapshot = await ref.get();

  if (!snapshot.exists) {
    throw new HttpsError('not-found', "Questa persona non c'e'.");
  }

  await ref.update(
    verificato
      ? {
          verificato: true,
          verificatoDa: 'admin',
          verificatoIl: admin.firestore.FieldValue.serverTimestamp(),
          verificatoDaChi: chi,
        }
      : {
          verificato: false,
          verificatoDa: '',
          verificatoIl: admin.firestore.FieldValue.delete(),
          verificatoDaChi: chi,
        }
  );

  logger.info('verificato cambiato', { userId, verificato, da: chi });
  await registra(chi, 'verificato', { uid: userId, verificato });

  return { ok: true, verificato };
});

/**
 * **Il fondo delle missioni automatiche, per la pagina di amministrazione.**
 *
 * Risponde alla domanda che non aveva risposta: *come faccio a capire che
 * stanno finendo i soldi?* Prima non c'era nessun posto che lo dicesse, e
 * l'unico modo di accorgersene sarebbe stato notare che le missioni avevano
 * smesso di uscire.
 *
 * Torna anche le ultime lanciate, perche' "restano dodici euro" da solo non
 * dice se il meccanismo sta funzionando: dodici euro possono voler dire che
 * va tutto bene o che e' fermo da tre giorni.
 */
exports.adminFondo = onCall(async (request) => {
  soloAdmin(request);

  const salvadanai = await db.collection('salvadanai').get();
  const fondi = [];

  for (const salvadanaio of salvadanai.docs) {
    const dati = salvadanaio.data() || {};
    const utente = await db.collection('users').doc(salvadanaio.id).get();

    const lanciate = await salvadanaio.ref
      .collection('lanciate')
      .orderBy('quando', 'desc')
      .limit(8)
      .get();

    fondi.push({
      uid: salvadanaio.id,
      username: utente.get('username') || salvadanaio.id,
      acceso: dati.acceso === true,
      spentoPerche: dati.spentoPerche || '',
      fondoCents: dati.fondoCents || 0,
      spesiCents: dati.spesiCents || 0,
      premioCents: dati.premioCents || 0,
      alGiorno: dati.alGiorno || 0,
      maxPartecipanti: dati.maxPartecipanti || 0,
      oreDiGara: dati.oreDiGara || 0,
      fino: dati.fino || '',
      fatte: dati.fatte || 0,
      giorno: dati.giorno || '',
      // Le prossime cinque, con l'orario: e' quello che permette di
      // accorgersi **prima** che domani alle dieci esce una missione uguale
      // alla sfida del giorno.
      // **Tutte, non le prime cinque.** La domanda che uno si fa aprendo
      // questa pagina non e' "cosa esce stasera" ma "cosa ho in programma":
      // e' guardando il piano intero che ci si accorge che giovedi' esce una
      // missione uguale alla sfida del giorno, o che le prime sei sono tutte
      // dall'archivio di fila. Cinque righe non bastano per vedere niente di
      // tutto questo.
      //
      // Quante ne stanno nel fondo, e non una in piu': oltre quelle non c'e'
      // nessun programma, ci sono soldi che non esistono.
      prossime: fondo.prossime(
        salvadanaio,
        dati.premioCents
          ? Math.min(40, Math.floor((dati.fondoCents || 0) / dati.premioCents))
          : 0
      ),
      ultime: lanciate.docs.map((riga) => ({
        gara: riga.id,
        titolo: riga.get('titolo') || '',
        premioCents: riga.get('premioCents') || 0,
        quando: riga.get('quando') ? riga.get('quando').toMillis() : null,
      })),
    });
  }

  return { fondi };
});

/**
 * Ferma o riaccende il fondo di una persona.
 *
 * **Fermare non tocca le gare gia' aperte**, e non e' una dimenticanza: quelle
 * hanno un premio pagato e delle persone dentro che hanno speso una delle loro
 * cinque di oggi. Si chiudono da sole come tutte le altre. Questo interruttore
 * dice "non lanciarne altre", non "annulla quello che c'e'".
 */
exports.adminFermaIlFondo = onCall(async (request) => {
  soloAdmin(request);

  const uid = String((request.data && request.data.uid) || '');
  const acceso = Boolean(request.data && request.data.acceso);

  if (!uid) {
    throw new HttpsError('invalid-argument', 'Manca di chi.');
  }

  await db
    .collection('salvadanai')
    .doc(uid)
    .update({ acceso, spentoPerche: acceso ? '' : 'a mano' });

  return { ok: true, acceso };
});

/**
 * Lancia subito una missione dal fondo, senza aspettare l'orario.
 *
 * Serve a due cose diverse e tutte e due vere: provare che il meccanismo
 * funziona senza stare sveglio fino alle dieci, e avere un modo di riempire
 * la giornata quando serve — una sera in cui non c'e' niente di aperto.
 *
 * **Conta nel limite giornaliero**, come le altre. Un tasto che scavalca il
 * tetto e' un tetto che non c'e'.
 */
exports.adminLanciaDalFondo = onCall(async (request) => {
  soloAdmin(request);

  const uid = String((request.data && request.data.uid) || '');

  if (!uid) {
    throw new HttpsError('invalid-argument', 'Manca di chi.');
  }

  const salvadanaio = await db.collection('salvadanai').doc(uid).get();

  if (!salvadanaio.exists) {
    throw new HttpsError('not-found', 'Nessun fondo per questa persona.');
  }

  const esito = await fondo.lanciaOra(salvadanaio);

  return esito;
});

/**
 * Salta la prossima missione in coda, rimandandola in fondo al giro.
 */
exports.adminSaltaLaProssima = onCall(async (request) => {
  soloAdmin(request);

  const uid = String((request.data && request.data.uid) || '');

  if (!uid) {
    throw new HttpsError('invalid-argument', 'Manca di chi.');
  }

  const salvadanaio = await db.collection('salvadanai').doc(uid).get();

  if (!salvadanaio.exists) {
    throw new HttpsError('not-found', 'Nessun fondo per questa persona.');
  }

  return fondo.salta(salvadanaio);
});

// Per il pannello: vedi `pannello.js`.
exports.togliLaFoto = togliLaFoto;
exports.rimuoviLaMissione = rimuoviLaMissione;
