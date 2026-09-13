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
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const { avvisaChiLHaMandata } = require('./avvisi');

const db = admin.firestore();

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

/** Il riferimento alla partecipazione segnalata, o `null` se non ce n'e' una. */
function fotoDi(dati) {
  const challengeId = String(dati.challengeId || '');
  const entryId = String(dati.entryId || '');

  if (!challengeId || !entryId) {
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
 */
exports.adminListReports = onCall(async (request) => {
  soloAdmin(request);

  const stato = request.data && request.data.status;
  const limite = Math.min(Number((request.data && request.data.limit) || PAGINA), PAGINA);

  // L'ordinamento e' in memoria e non nella query, per la stessa trappola di
  // sempre: un `orderBy` su un campo salta i documenti che quel campo non ce
  // l'hanno, e una segnalazione scritta un istante prima che il server le desse
  // l'ora sparirebbe dall'elenco invece di comparire in cima.
  const tutte = await db.collection('reports').limit(500).get();

  const righe = [];

  for (const doc of tutte.docs) {
    const dati = doc.data() || {};
    const suo = statoDi(dati.status);

    if (stato && stato !== 'all' && suo !== stato) {
      continue;
    }

    righe.push({ doc, dati, stato: suo });
  }

  righe.sort((a, b) => {
    const at = a.dati.createdAt ? a.dati.createdAt.toMillis() : 0;
    const bt = b.dati.createdAt ? b.dati.createdAt.toMillis() : 0;

    return bt - at;
  });

  const scelte = righe.slice(0, limite);

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

    reports.push({
      id: doc.id,
      status: riga.stato,
      kind: String(dati.kind || ''),
      reason: String(dati.reason || ''),
      note: String(dati.note || ''),
      challengeId: String(dati.challengeId || ''),
      challengeTitle: String(
        (foto && foto.get('challengeTitle')) || dati.challengeTitle || ''
      ),
      entryId: String(dati.entryId || ''),
      commentId: String(dati.commentId || ''),
      reportedUserId: String(dati.reportedUserId || ''),
      reportedUsername: String(
        (foto && foto.get('authorName')) || dati.reportedUsername || ''
      ),
      // **Chi ha segnalato non esce da qui, mai.** Le segnalazioni sono
      // anonime per costruzione, e un amministratore che sa chi e' stato e'
      // un amministratore che puo' dirlo. Il conto si', il nome no.
      mediaUrl: String((foto && foto.get('mediaUrl')) || dati.mediaUrl || ''),
      mediaKind: String((foto && foto.get('mediaKind')) || 'photo'),
      createdAt: dati.createdAt ? dati.createdAt.toMillis() : null,
      resolvedAt: dati.resolvedAt ? dati.resolvedAt.toMillis() : null,
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

  return { reports, total: righe.length };
});

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
exports.adminResolveReport = onCall(async (request) => {
  const chi = soloAdmin(request);

  const reportId = String((request.data && request.data.reportId) || '');
  const decisione = String((request.data && request.data.decision) || '');

  if (!reportId) {
    throw new HttpsError('invalid-argument', 'Manca la segnalazione.');
  }

  if (!['reviewing', 'fake', 'remove'].includes(decisione)) {
    throw new HttpsError('invalid-argument', 'Decisione non valida.');
  }

  const riferimento = db.collection('reports').doc(reportId);
  const segnalazione = await riferimento.get();

  if (!segnalazione.exists) {
    throw new HttpsError('not-found', 'Segnalazione non trovata.');
  }

  const dati = segnalazione.data() || {};
  const nuovo = decisione === 'remove' ? 'removed' : decisione;
  const foto = fotoDi(dati);

  if (foto) {
    const adesso = await foto.get();

    if (adesso.exists) {
      if (decisione === 'remove') {
        await foto.update({
          moderation: 'rejected',
          // **Perche' e' uscita, scritto sulla foto stessa.** Fra una tolta
          // dal riconoscimento immagini e una tolta da una persona c'e' una
          // differenza enorme il giorno in cui qualcuno chiede spiegazioni, e
          // senza questo campo le due sono identiche.
          moderationReason: 'admin',
          moderatedBy: chi,
          moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await avvisaChiLHaMandata(
          String(dati.reportedUserId || adesso.get('userId') || ''),
          String(dati.challengeId || ''),
          String(adesso.get('challengeTitle') || dati.challengeTitle || '')
        );
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
  // Due uguaglianze non vogliono un indice composto: Firestore le incrocia da
  // solo sugli indici dei singoli campi.
  const sorelle =
    dati.entryId && dati.challengeId
      ? await db
          .collection('reports')
          .where('challengeId', '==', String(dati.challengeId))
          .where('entryId', '==', String(dati.entryId))
          .limit(200)
          .get()
      : null;

  const scrittura = db.batch();
  const chiusura = {
    status: nuovo,
    resolvedBy: chi,
    resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  scrittura.update(riferimento, chiusura);

  if (sorelle) {
    for (const doc of sorelle.docs) {
      if (doc.id !== reportId) {
        scrittura.update(doc.ref, chiusura);
      }
    }
  }

  await scrittura.commit();

  logger.info('segnalazione decisa', {
    reportId,
    decisione,
    admin: chi,
    insieme: sorelle ? sorelle.size : 1,
  });

  return { status: nuovo, insieme: sorelle ? sorelle.size : 1 };
});
