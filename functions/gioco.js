'use strict';

/**
 * **Il gioco: sfide del giorno, traguardi, XP e livelli, contati dal server.**
 *
 * Le regole stanno in `gioco_regole.js` (cosa vale quanto) e nel documento
 * `config/gioco` (le sfide e i livelli, modificabili dal pannello). Qui c'e'
 * solo il collegamento con il database: quali fatti veri muovono cosa.
 *
 * ## Dove sta tutto
 *
 * - `gioco/{uid}` — XP, livello, contatori, sfide fatte, le sfide di oggi.
 *   Lo legge solo il diretto interessato, non lo scrive nessun telefono.
 * - `gioco/{uid}/xp/{chiave}` — **ogni XP dato**, con la sua chiave: `p_id`
 *   per un traguardo (una volta per sempre), `g_giorno_id` per una sfida del
 *   giorno (una volta per giorno). La chiave e' il motivo per cui un premio
 *   non si puo' prendere due volte.
 * - `gioco/{uid}/eventi/{chiave}` — ogni fatto contato, e se vale ancora:
 *   e' cosi' che una fiamma tolta e rimessa non conta due volte, e che il
 *   server, quando riprova, non conta di nuovo la stessa cosa.
 *
 * ## Quando conta
 *
 * Una foto quando il controllo la **approva**, non quando parte; una fiamma
 * dentro il tetto di tre per gara; un'amicizia quando c'e' da tutte e due le
 * parti; un commento una volta per foto, e solo sotto le foto degli altri;
 * una vittoria quando la gara la assegna. Cio' che sparisce **mentre la gara
 * e' aperta** (foto ritirata, fiamma tolta, commento cancellato) si toglie;
 * cio' che sparisce **dopo** e' la pulizia di fine gara, e non tocca niente.
 *
 * Tutto il tempo e' quello del server, in Italia: cambiare l'ora del telefono
 * non fa cambiare il giorno a nessuno.
 */

const { onDocumentWritten, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

const regole = require('./gioco_regole');

const db = admin.firestore();

/** Le regole di partenza, finche' dal pannello non se ne salvano altre. */
const PREDEFINITE = regole.valida(require('./dati/gioco.json'));

const CONFIG = db.collection('config').doc('gioco');

/** L'account di CRASY non gioca. */
const CRASY_ID = 'crasy';

/** Le fiamme di una persona in una gara: oltre, `countVote` le scarta. */
const FIAMME_PER_GARA = 3;

let inMemoria = null;
let lettoIl = 0;

/**
 * **Le regole di adesso.** Si rileggono al massimo una volta al minuto: un
 * cambio dal pannello arriva in fretta, e mille fiamme non fanno mille
 * letture. Se il documento non c'e', si scrivono quelle di partenza — cosi'
 * l'app ha subito qualcosa da mostrare.
 */
async function leRegole() {
  if (inMemoria && Date.now() - lettoIl < 60000) {
    return inMemoria;
  }

  const documento = await CONFIG.get();

  if (!documento.exists) {
    await CONFIG.create(PREDEFINITE).catch(() => {});
    inMemoria = PREDEFINITE;
  } else {
    try {
      inMemoria = regole.valida(documento.data());
    } catch (errore) {
      // Non dovrebbe succedere — il pannello valida prima di salvare — ma se
      // succede il gioco va avanti con quelle di partenza invece di fermarsi.
      logger.error('regole del gioco non valide, si usano quelle di partenza', {
        errore: String(errore.message || errore),
      });
      inMemoria = PREDEFINITE;
    }
  }

  lettoIl = Date.now();

  return inMemoria;
}

function statoRef(uid) {
  return db.collection('gioco').doc(uid);
}

/**
 * **Un fatto vero entra nel gioco di una persona.**
 *
 * `chiave` lo rende unico ("la fiamma di Anna sulla foto di Bruno in quella
 * gara"); `attivo` dice se arriva o se ne va. Per i record (`valore`) non
 * serve chiave: vale il massimo. Tutto in una transazione: contatori, sfide
 * fatte, XP e livello si muovono insieme o non si muovono.
 */
async function registra(uid, { chiave = '', metrica, attivo = true, valore = null }) {
  if (!uid || uid === CRASY_ID || !regole.METRICHE[metrica]) {
    return;
  }

  const giocate = await leRegole();
  const ref = statoRef(uid);

  await db.runTransaction(async (transazione) => {
    const oggi = regole.oggiInItalia();
    const istantanea = await transazione.get(ref);
    const stato = istantanea.exists ? istantanea.data() : regole.statoIniziale();
    let decisione = { delta: 0, contaOggi: false };
    let eventoRef = null;

    if (valore === null) {
      eventoRef = ref.collection('eventi').doc(chiave);
      const evento = await transazione.get(eventoRef);

      decisione = regole.decidi(evento.exists ? evento.data() : null, attivo, oggi);

      if (!decisione.delta) {
        return;
      }
    } else if (((stato.contatori || {})[metrica] || 0) >= valore) {
      return;
    }

    const esito = regole.applica({
      stato,
      regole: giocate,
      uid,
      oggi,
      metrica,
      delta: decisione.delta,
      valore,
      contaOggi: decisione.contaOggi,
      adesso: Date.now(),
    });

    if (eventoRef) {
      transazione.set(eventoRef, {
        ...decisione.evento,
        metrica,
        quando: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    transazione.set(ref, {
      ...esito.stato,
      aggiornato: admin.firestore.FieldValue.serverTimestamp(),
    });

    for (const premio of esito.premi) {
      transazione.set(ref.collection('xp').doc(premio.chiave), {
        ...premio,
        livelloDopo: esito.livelloDopo,
        quando: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
}

/**
 * **Un errore del gioco non ferma niente.** Si riprova solo quando ha senso
 * riprovare — la transazione si e' scontrata con un'altra, o Firestore non
 * rispondeva — e il fatto ha la sua chiave, quindi riprovare non lo conta due
 * volte. Tutto il resto si scrive nei log e basta.
 */
async function proteggi(lavoro, dove) {
  try {
    await lavoro();
  } catch (errore) {
    const codice = errore && (errore.code || '');

    if ([10, 4, 14, 'aborted', 'deadline-exceeded', 'unavailable'].includes(codice)) {
      throw errore;
    }

    logger.error('gioco non aggiornato', { dove, errore: String((errore && errore.message) || errore).slice(0, 300) });
  }
}

/**
 * **La gara e' gia' finita?** Una cosa che sparisce dopo la fine e' la
 * pulizia (le foto che non hanno vinto, le fiamme, i commenti): non e' un
 * ritiro e non toglie niente a nessuno.
 */
async function garaFinita(challengeId, quando) {
  const gara = await db.collection('challenges').doc(challengeId).get();

  if (!gara.exists) {
    return true;
  }

  const fine = gara.get('endsAt');
  const istante = Date.parse(quando) || Date.now();

  return Boolean(fine && fine.toMillis && istante >= fine.toMillis());
}

/** Una foto conta quando il controllo l'ha approvata. */
function fotoValida(documento) {
  return Boolean(documento && documento.exists && documento.get('moderation') === 'approved' && documento.get('userId'));
}

exports.giocoFoto = onDocumentWritten(
  { document: 'challenges/{challengeId}/entries/{entryId}', retry: true },
  async (event) => {
    const prima = event.data && event.data.before;
    const dopo = event.data && event.data.after;
    const valeva = fotoValida(prima);
    const vale = fotoValida(dopo);

    if (valeva === vale) {
      return;
    }

    const { challengeId } = event.params;
    const uid = String(((dopo && dopo.exists ? dopo : prima).get('userId')) || '');

    if (!vale && !(dopo && dopo.exists) && (await garaFinita(challengeId, event.time))) {
      return;
    }

    await proteggi(
      () => registra(uid, { chiave: `foto_${challengeId}`, metrica: 'foto', attivo: vale }),
      'foto'
    );

    // Il giorno di gioco: uno al giorno, e non si toglie.
    if (vale) {
      await proteggi(
        () => registra(uid, { chiave: `giorno_${regole.oggiInItalia()}`, metrica: 'giorniGiocati', attivo: true }),
        'giorni'
      );
    }
  }
);

exports.giocoFiamme = onDocumentWritten(
  { document: 'users/{userId}/votes/{voteId}', retry: true },
  async (event) => {
    const prima = event.data && event.data.before;
    const dopo = event.data && event.data.after;
    const vale = (d) => Boolean(d && d.exists && d.get('scartata') !== true);

    if (vale(prima) === vale(dopo)) {
      return;
    }

    const dati = ((dopo && dopo.exists ? dopo : prima).data()) || {};
    const challengeId = String(dati.challengeId || '');
    const entryId = String(dati.entryId || '');
    const chi = event.params.userId;
    const attivo = vale(dopo);

    if (!challengeId || !entryId || entryId === chi) {
      return;
    }

    if (!attivo && (await garaFinita(challengeId, event.time))) {
      return;
    }

    // **Solo le fiamme dentro il tetto.** Quelle oltre le tre per gara le
    // scarta `countVote` un attimo dopo: non devono fare in tempo a valere.
    if (attivo) {
      const quante = await db
        .collection('users')
        .doc(chi)
        .collection('votes')
        .where('challengeId', '==', challengeId)
        .count()
        .get();

      if (quante.data().count > FIAMME_PER_GARA) {
        return;
      }
    }

    await proteggi(
      () => registra(chi, { chiave: `fiamma_${challengeId}_${entryId}`, metrica: 'fiammeDate', attivo }),
      'fiamme date'
    );
    await proteggi(
      () => registra(entryId, { chiave: `ricevuta_${challengeId}_${chi}`, metrica: 'fiammeRicevute', attivo }),
      'fiamme ricevute'
    );
  }
);

exports.giocoAmici = onDocumentWritten(
  { document: 'users/{userId}/friends/{friendId}', retry: true },
  async (event) => {
    const c = Boolean(event.data && event.data.before && event.data.before.exists);
    const d = Boolean(event.data && event.data.after && event.data.after.exists);
    const { userId, friendId } = event.params;

    if (c === d || userId === friendId || friendId === CRASY_ID) {
      return;
    }

    await proteggi(
      () => registra(userId, { chiave: `amico_${friendId}`, metrica: 'amici', attivo: d }),
      'amici'
    );
  }
);

exports.giocoCommenti = onDocumentWritten(
  { document: 'challenges/{challengeId}/entries/{entryId}/comments/{commentId}', retry: true },
  async (event) => {
    const c = Boolean(event.data && event.data.before && event.data.before.exists);
    const d = Boolean(event.data && event.data.after && event.data.after.exists);

    if (c === d) {
      return;
    }

    const dati = ((d ? event.data.after : event.data.before).data()) || {};
    const chi = String(dati.userId || '');
    const { challengeId, entryId } = event.params;

    // Sotto la propria foto non e' commentare qualcuno: e' rispondere.
    if (!chi || chi === entryId) {
      return;
    }

    if (!d) {
      if (await garaFinita(challengeId, event.time)) {
        return;
      }

      // Se sotto la stessa foto ne ha lasciato un altro, la foto resta
      // commentata.
      const altri = await event.data.before.ref.parent.where('userId', '==', chi).limit(1).get();

      if (!altri.empty) {
        return;
      }
    }

    await proteggi(
      () => registra(chi, { chiave: `commento_${challengeId}_${entryId}`, metrica: 'commenti', attivo: d }),
      'commenti'
    );
  }
);

/**
 * **Le vittorie.** Chi vince e' la foto con `winnerEntryId`, e la foto si
 * chiama come chi l'ha mandata. Se la vittoria passa a un altro — una
 * contestazione, una foto tolta — passa anche qui.
 */
exports.giocoVittorie = onDocumentUpdated(
  { document: 'challenges/{challengeId}', retry: true },
  async (event) => {
    const prima = String(event.data.before.get('winnerEntryId') || '');
    const dopo = String(event.data.after.get('winnerEntryId') || '');

    if (prima === dopo) {
      return;
    }

    const { challengeId } = event.params;

    if (prima) {
      await proteggi(
        () => registra(prima, { chiave: `vittoria_${challengeId}`, metrica: 'vittorie', attivo: false }),
        'vittorie'
      );
    }

    if (dopo) {
      await proteggi(
        () => registra(dopo, { chiave: `vittoria_${challengeId}`, metrica: 'vittorie', attivo: true }),
        'vittorie'
      );
    }
  }
);

/**
 * **Le sfide di oggi, pronte quando si aprono.** Il giorno lo decide il
 * server: un telefono con l'orologio avanti non apre le sfide di domani, e
 * uno indietro non rifa' quelle di ieri. Si puo' chiamare quante volte si
 * vuole: se il giorno e' gia' quello, non cambia niente.
 */
exports.apriLeSfide = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;

  if (!uid) {
    throw new HttpsError('unauthenticated', 'Serve un account.');
  }

  const giocate = await leRegole();
  const ref = statoRef(uid);
  const oggi = regole.oggiInItalia();

  await db.runTransaction(async (transazione) => {
    const istantanea = await transazione.get(ref);
    const stato = istantanea.exists ? istantanea.data() : regole.statoIniziale();
    const rinnovato = regole.rinnova(stato, giocate, uid, oggi);
    // I livelli si possono cambiare dal pannello: il numero si rifa' sugli XP.
    const livello = regole.livelloDi(rinnovato.xp || 0, giocate.livelli).numero;

    if (istantanea.exists && rinnovato === stato && stato.livello === livello) {
      return;
    }

    transazione.set(ref, {
      ...regole.statoIniziale(),
      ...rinnovato,
      livello,
      aggiornato: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { oggi };
});

/**
 * **Il livello lo vedono tutti.** Livello e XP si copiano nel profilo
 * pubblico (`users/{uid}`), che legge chiunque abbia fatto l'accesso: e' li'
 * che l'app li mostra accanto al nome. Il telefono quei due campi non li puo'
 * toccare (`doesNotTouchTheWallet` in `firestore.rules`). Chi non ha mai
 * giocato non ha il campo, e l'app lo mostra al primo livello.
 */
exports.giocoSulProfilo = onDocumentWritten('gioco/{userId}', async (event) => {
  const dopo = event.data && event.data.after;

  if (!dopo || !dopo.exists) {
    return;
  }

  const prima = event.data.before;
  const livello = Number(dopo.get('livello')) || 1;
  const xp = Number(dopo.get('xp')) || 0;

  if (prima && prima.exists && Number(prima.get('livello')) === livello && Number(prima.get('xp')) === xp) {
    return;
  }

  try {
    await db.collection('users').doc(event.params.userId).update({ livello, xp });
  } catch (errore) {
    // Un account cancellato non ha piu' un profilo: niente da copiare.
    if (errore && errore.code !== 5) {
      logger.warn('livello non copiato sul profilo', { uid: event.params.userId, errore: String(errore.message || errore) });
    }
  }
});

exports.leRegole = leRegole;
exports.registra = registra;
exports.proteggi = proteggi;
exports.CONFIG = CONFIG;
