'use strict';

/**
 * **Il pannello: CRASY senza veli.**
 *
 * Tutto quello che la pagina di amministrazione vede e fa, e che prima non c'era,
 * passa da una funzione sola: `adminPannello({ azione, ... })`. Una e non venti per
 * tre ragioni:
 *
 * - **una sola porta da chiudere**: `soloAdmin` sta in cima e non si puo' scordare
 *   nella prossima azione che qualcuno aggiunge;
 * - **una sola accensione**: la pagina chiede dieci cose insieme, e dieci funzioni
 *   diverse vorrebbero dire dieci attese da due secondi l'una dopo una pausa;
 * - **una sola lista di segreti**.
 *
 * ## Cosa resta fuori, apposta
 *
 * **L'IBAN e il codice fiscale** si vedono solo dentro una richiesta di prelievo, che e'
 * l'unico momento in cui servono.
 *
 * **Chi ha fatto una segnalazione si vede solo da chi modera**, per giudicarla e per
 * riconoscere chi abusa delle segnalazioni. A chi e' stato segnalato non arriva mai.
 *
 * **Chi ha lanciato una missione anonima invece si vede**: su un'app che paga la gente
 * per fare cose, chi modera deve sapere chi sta chiedendo cosa.
 *
 * Le azioni che cambiano qualcosa restano scritte in `registroAdmin`.
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const { AggregateField, FieldValue, Timestamp } = require('firebase-admin/firestore');

const missioni = require('./missioni');
const giudice = require('./giudice');
const payments = require('./payments');
const posta = require('./posta');
const sospensioni = require('./sospensioni');
const { autoreDi } = require('./autori');
const { togliLaFoto, rimuoviLaMissione } = require('./admin');
const { PROVE } = require('./prove_missioni');
const speseDiCrasy = require('./spese');
const { registra } = require('./registro');
const moderazione = require('./moderazione');
const magazzini = require('./magazzino');

const db = admin.firestore();

const ORA = 60 * 60 * 1000;
const GIORNO = 24 * ORA;

function soloAdmin(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Fai prima l\'accesso.');
  }

  if (request.auth.token.admin !== true) {
    logger.warn('tentativo di accesso al pannello', { uid: request.auth.uid });

    throw new HttpsError('permission-denied', 'Non sei un amministratore.');
  }

  return request.auth.uid;
}

/** Da un istante di Firestore ai millisecondi, che in JSON arrivano sani. */
function ms(valore) {
  return valore && typeof valore.toMillis === 'function' ? valore.toMillis() : null;
}

function indietro(millisecondi) {
  return Timestamp.fromMillis(Date.now() - millisecondi);
}

async function conta(query) {
  return (await query.count().get()).data().count;
}

async function somma(query, campo) {
  const esito = await query.aggregate({ totale: AggregateField.sum(campo) }).get();

  return esito.data().totale || 0;
}

/**
 * **Un riquadro che non torna non deve spegnere gli altri.** Un indice non ancora
 * pronto, Stripe che non risponde: quel numero manca, e tutto il resto si vede lo
 * stesso.
 */
async function senzaFermarsi(promessa, ripiego, nome) {
  try {
    return await promessa;
  } catch (errore) {
    logger.warn('numero del pannello non letto', {
      nome,
      messaggio: String((errore && errore.message) || errore).slice(0, 300),
    });

    return ripiego;
  }
}

function testoObbligatorio(valore, cosa) {
  const testo = typeof valore === 'string' ? valore.trim() : '';

  if (!testo) {
    throw new HttpsError('invalid-argument', `Manca ${cosa}.`);
  }

  return testo;
}

/** Da un elenco di identificativi ai nomi. Letti tutti insieme, una lettura a persona. */
async function nomiDi(uids) {
  const distinti = [...new Set(uids.filter(Boolean))];

  if (distinti.length === 0) {
    return new Map();
  }

  const fogli = await db.getAll(...distinti.map((uid) => db.collection('users').doc(uid)));

  return new Map(fogli.map((foglio) => [foglio.id, String(foglio.get('username') || '')]));
}

// ---------------------------------------------------------------------------
// La panoramica
// ---------------------------------------------------------------------------

/**
 * Da qui il server sa chi avvisare quando arriva una missione da controllare: chi apre
 * il pannello almeno una volta. Vedi `avvisaDellaProposta`.
 */
const giaSegnati = new Set();

async function segnaAmministratore(uid) {
  if (giaSegnati.has(uid)) {
    return;
  }

  await db
    .collection(missioni.IMPOSTAZIONI)
    .doc('amministratori')
    .set({ uids: FieldValue.arrayUnion(uid) }, { merge: true });
  giaSegnati.add(uid);
}

/**
 * **I pallini del menu: quanto lavoro c'e', e nient'altro.** Si chiedono a ogni cambio
 * di pagina: la panoramica intera, con Stripe dentro, sarebbe un viaggio inutile.
 */
async function bolli(_dati, request) {
  await segnaAmministratore(request.auth.uid);

  const proposte = db.collection(missioni.PROPOSTE);
  const numero = (query, nome) => senzaFermarsi(conta(query), null, nome);
  const [
    daControllare,
    daConfermare,
    segnalazioni,
    scadute,
    blocchiNuovi,
    revisioni,
    prelievi,
    impostazioni,
  ] = await Promise.all([
    numero(proposte.where('stato', '==', 'daControllare'), 'daControllare'),
    numero(proposte.where('stato', '==', 'daConfermare'), 'daConfermare'),
    numero(db.collection('reports').where('status', 'in', ['new', 'open']), 'segnalazioni'),
    numero(segnalazioniScadute(), 'scadute'),
    numero(db.collection(moderazione.BLOCCHI).where('stato', '==', 'nuovo'), 'blocchi'),
    numero(db.collection('revisioni').where('stato', '==', 'aperta'), 'revisioni'),
    numero(db.collection('payoutRequests').where('status', '==', 'pending'), 'prelievi'),
    missioni.leggiImpostazioni(),
  ]);

  return {
    missioni: {
      daControllare,
      daConfermare,
      sogliaAuto: impostazioni.sogliaAuto,
      sogliaConferma: impostazioni.sogliaConferma,
    },
    lavoro: { segnalazioni, scadute, blocchi: blocchiNuovi, revisioni, prelievi },
  };
}

/** Le segnalazioni ancora aperte da piu' delle ore concesse. */
function segnalazioniScadute() {
  return db
    .collection('reports')
    .where('status', 'in', moderazione.STATI_APERTI)
    .where('createdAt', '<', indietro(moderazione.ORE_PER_DECIDERE * ORA));
}

/** I numeri di testa, e quanto lavoro c'e' da fare. */
async function panoramica(request) {
  await segnaAmministratore(request.auth.uid);

  const utenti = db.collection('users');
  const proposte = db.collection(missioni.PROPOSTE);
  const numero = (query, nome) => senzaFermarsi(conta(query), null, nome);

  const [
    iscritti,
    adesso,
    oggi,
    settimana,
    nuovi,
    custodia,
    suiConti,
    vinti,
    inPalio,
    daControllare,
    daConfermare,
    bloccate,
    segnalazioni,
    scadute,
    blocchiNuovi,
    revisioni,
    fotoOggi,
    richieste,
    garaVive,
    stripe,
    ai,
  ] = await Promise.all([
    numero(utenti, 'iscritti'),
    numero(utenti.where('lastSeenAt', '>', indietro(15 * 60 * 1000)), 'adesso'),
    numero(utenti.where('lastSeenAt', '>', indietro(GIORNO)), 'oggi'),
    numero(utenti.where('lastSeenAt', '>', indietro(7 * GIORNO)), 'settimana'),
    numero(utenti.where('createdAt', '>', indietro(7 * GIORNO)), 'nuovi'),
    senzaFermarsi(somma(utenti, 'walletCents'), null, 'custodia'),
    senzaFermarsi(somma(utenti, 'stripeCents'), null, 'suiConti'),
    senzaFermarsi(somma(utenti, 'totalWonCents'), null, 'vinti'),
    senzaFermarsi(
      somma(db.collection('challenges').where('prizeStatus', '==', 'held'), 'prizeCents'),
      null,
      'inPalio'
    ),
    numero(proposte.where('stato', '==', 'daControllare'), 'daControllare'),
    numero(proposte.where('stato', '==', 'daConfermare'), 'daConfermare'),
    numero(
      proposte
        .where('stato', '==', 'bloccata')
        .where('createdAt', '>', indietro(7 * GIORNO))
        .orderBy('createdAt', 'desc'),
      'bloccate'
    ),
    numero(db.collection('reports').where('status', 'in', ['new', 'open']), 'segnalazioni'),
    numero(segnalazioniScadute(), 'scadute'),
    numero(db.collection(moderazione.BLOCCHI).where('stato', '==', 'nuovo'), 'blocchi'),
    numero(db.collection('revisioni').where('stato', '==', 'aperta'), 'revisioni'),
    numero(
      db.collectionGroup('entries').where('createdAt', '>', indietro(GIORNO)),
      'fotoOggi'
    ),
    senzaFermarsi(
      db.collection('payoutRequests').where('status', '==', 'pending').limit(200).get(),
      null,
      'prelievi'
    ),
    senzaFermarsi(
      db
        .collection('challenges')
        .where('endsAt', '>', Timestamp.now())
        .select('prizeCents', 'prizeStatus', 'scope', 'targetUserId', 'participantsCount')
        .limit(1000)
        .get(),
      null,
      'vive'
    ),
    senzaFermarsi(
      (async () => {
        const saldo = await payments.stripeClient().balance.retrieve();
        const inEuro = (righe) =>
          (righe || [])
            .filter((riga) => riga.currency === 'eur')
            .reduce((totale, riga) => totale + (riga.amount || 0), 0);

        return { disponibile: inEuro(saldo.available), inArrivo: inEuro(saldo.pending) };
      })(),
      null,
      'stripe'
    ),
    senzaFermarsi(speseAI(), null, 'spese'),
  ]);

  const vive = { pubbliche: 0, amici: 0, sfide: 0, nonPagate: 0, partecipanti: 0 };

  for (const gara of garaVive ? garaVive.docs : []) {
    const premio = gara.get('prizeCents') || 0;
    const pagamento = gara.get('prizeStatus');

    if (premio > 0 && pagamento !== 'held' && pagamento !== 'paidOut') {
      vive.nonPagate += 1;
      continue;
    }

    vive.partecipanti += gara.get('participantsCount') || 0;

    if (gara.get('targetUserId')) {
      vive.sfide += 1;
    } else if (gara.get('scope') === 'friends') {
      vive.amici += 1;
    } else {
      vive.pubbliche += 1;
    }
  }

  const impostazioni = await missioni.leggiImpostazioni();

  return {
    persone: { iscritti, adesso, oggi, settimana, nuovi },
    missioni: {
      ...vive,
      daControllare,
      daConfermare,
      bloccate,
      soloAMano: impostazioni.soloAMano,
      sogliaAuto: impostazioni.sogliaAuto,
      sogliaConferma: impostazioni.sogliaConferma,
    },
    lavoro: {
      segnalazioni,
      scadute,
      blocchi: blocchiNuovi,
      revisioni,
      prelievi: richieste ? richieste.size : null,
    },
    soldi: {
      custodiaCents: custodia,
      suiContiCents: suiConti,
      vintiCents: vinti,
      inPalioCents: inPalio,
      stripe,
      prelieviCents: richieste
        ? richieste.docs.reduce((totale, d) => totale + (d.get('amountCents') || 0), 0)
        : null,
    },
    foto: { oggi: fotoOggi },
    ai: ai ? { mese: ai.mese, oggi: ai.oggi, modello: ai.modello } : null,
  };
}

// ---------------------------------------------------------------------------
// Le missioni
// ---------------------------------------------------------------------------

function propostaPerIlPannello(doc, tentativi, nomi) {
  const d = doc.data();

  return {
    id: doc.id,
    stato: d.stato,
    fonte: d.fonte || '',
    title: d.title || '',
    brief: d.brief || '',
    duelMessage: d.duelMessage || '',
    prizeCents: d.prizeCents || 0,
    scope: d.scope || 'global',
    minutes: d.minutes || 0,
    mediaKind: d.mediaKind || 'photo',
    source: d.source || 'instant',
    maxParticipants: d.maxParticipants || 0,
    anonimo: d.anonimo === true,
    targetUsername: d.targetUsername || '',
    uid: d.uid || '',
    username: d.username || '',
    voto: Number.isInteger(d.voto) ? d.voto : null,
    giudizio: d.giudizio || null,
    filtro: d.filtro || { rossa: null, gialle: [] },
    challengeId: d.challengeId || null,
    pagataIl: ms(d.pagataIl),
    pagatoCents: d.pagatoCents || 0,
    scadeIl: ms(d.scadeIl),
    rimborso: d.rimborso || '',
    rimborsatiCents: d.rimborsatiCents || 0,
    rimborsatiDove: d.rimborsatiDove || '',
    motivoDecisione: d.motivoDecisione || '',
    decisaDa: nomi ? nomi.get(d.decisaDa) || d.decisaDa || '' : d.decisaDa || '',
    decisaIl: ms(d.decisaIl),
    createdAt: ms(d.createdAt),
    tentativiBloccati: tentativi ? tentativi.get(d.uid) || 0 : 0,
  };
}

/** Le proposte di uno stato, con quante volte quella persona si e' gia' fatta fermare. */
async function proposte({ stato, limite }) {
  const stati = ['daControllare', 'daConfermare', 'bloccata', 'approvata', 'rifiutata', 'scaduta'];

  if (!stati.includes(stato)) {
    throw new HttpsError('invalid-argument', 'Stato non valido.');
  }

  const fogli = await db
    .collection(missioni.PROPOSTE)
    .where('stato', '==', stato)
    .orderBy('createdAt', 'desc')
    .limit(Math.min(Number(limite) || 60, 200))
    .get();

  const autori = [...new Set(fogli.docs.map((doc) => doc.get('uid')).filter(Boolean))];
  const tentativi = new Map(
    await Promise.all(
      autori.map(async (uid) => [
        uid,
        await senzaFermarsi(
          conta(
            db
              .collection(missioni.PROPOSTE)
              .where('uid', '==', uid)
              .where('stato', '==', 'bloccata')
          ),
          0,
          'tentativi'
        ),
      ])
    )
  );
  const nomi = await nomiDi(fogli.docs.map((doc) => doc.get('decisaDa')));

  return { proposte: fogli.docs.map((doc) => propostaPerIlPannello(doc, tentativi, nomi)) };
}

async function decidiProposta({ id, decisione, motivo, sospendiGiorni }, chi) {
  const proposta = testoObbligatorio(id, 'la missione');
  const perche = typeof motivo === 'string' ? motivo.trim().slice(0, 500) : '';

  if (decisione === 'rifiuta' && !perche) {
    throw new HttpsError('invalid-argument', 'Scrivi il motivo: lo legge chi l\'ha scritta.');
  }

  const esito = await missioni.decidi(proposta, { decisione, motivo: perche, chi });

  // **La sospensione, per ultima.** La decisione e' gia' presa: se qui va storto
  // qualcosa, la missione resta comunque fuori.
  let sospeso = null;

  if (decisione === 'rifiuta' && sospendiGiorni !== undefined && sospendiGiorni !== null) {
    const foglio = await db.collection(missioni.PROPOSTE).doc(proposta).get();
    const giorni = Number(sospendiGiorni);
    const fino = await sospensioni.sospendi(foglio.get('uid'), {
      giorni,
      motivo: `La tua missione "${foglio.get('title')}" non può uscire: ${perche}.`,
      chi,
    });

    sospeso = { fino: ms(fino) };
  }

  await registra(chi, 'decidiProposta', { id: proposta, decisione, motivo: perche, sospeso });

  return { ...esito, sospeso };
}

/** Di che tipo e' una gara, per chi la guarda dal pannello. */
function tipoDi(d) {
  if (d.targetUserId) {
    return 'sfida';
  }

  return d.scope === 'friends' ? 'amici' : 'pubblica';
}

/** Una gara come la legge il pannello, con chi l'ha lanciata anche se si e' nascosto. */
async function garaPerIlPannello(doc) {
  const d = doc.data();
  const autore = await autoreDi(doc);
  const nomeVero =
    d.anonimo === true && autore
      ? String((await db.collection('users').doc(autore).get()).get('username') || '')
      : String(d.createdByUsername || '');

  return {
    id: doc.id,
    tipo: tipoDi(d),
    title: d.title || '',
    brief: d.brief || '',
    duelMessage: d.duelMessage || '',
    prizeCents: d.prizeCents || 0,
    prizeStatus: d.prizeStatus || 'unpaid',
    scope: d.scope || 'global',
    anonimo: d.anonimo === true,
    autoreId: autore,
    autore: nomeVero,
    daCrasy: autore === 'crasy',
    pagataDalFondo: d.pagataDalFondo === true,
    pagataDalSaldo: d.paidFromWallet === true,
    targetUsername: d.targetUsername || '',
    duelStatus: d.duelStatus || '',
    duelVerdict: d.duelVerdict || '',
    participantsCount: d.participantsCount || 0,
    maxParticipants: d.maxParticipants || 0,
    audienceCount: Array.isArray(d.audience) ? d.audience.length : 0,
    mediaKind: d.mediaKind || 'photo',
    source: d.source || 'instant',
    winnerEntryId: d.winnerEntryId === undefined ? null : d.winnerEntryId,
    winnerUsername: d.winnerUsername || '',
    winnerVotes: d.winnerVotes || 0,
    winnerMediaUrl: d.winnerMediaUrl || '',
    startsAt: ms(d.startsAt),
    endsAt: ms(d.endsAt),
    createdAt: ms(d.createdAt),
  };
}

/** Le gare, con le fiamme prese da tutte le loro foto e il voto che avevano preso. */
async function gare({ filtro }) {
  const adesso = Timestamp.now();
  const tutte = db.collection('challenges');
  let query;

  if (filtro === 'finite') {
    query = tutte
      .where('endsAt', '<=', adesso)
      .where('endsAt', '>', indietro(7 * GIORNO))
      .orderBy('endsAt', 'desc');
  } else {
    query = tutte.where('endsAt', '>', adesso).orderBy('endsAt');
  }

  const lette = await query.limit(120).get();
  // Quelle in revisione non sono in gara: si decidono dalla loro coda, con i soldi dentro.
  const fogli = {
    docs: lette.docs.filter((doc) => doc.get('prizeStatus') !== 'inRevisione'),
    get empty() {
      return this.docs.length === 0;
    },
  };
  const proposteDi = fogli.empty
    ? []
    : await db.getAll(...fogli.docs.map((doc) => db.collection(missioni.PROPOSTE).doc(doc.id)));
  const voti = new Map(
    proposteDi
      .filter((foglio) => foglio.exists)
      .map((foglio) => [foglio.id, foglio.get('voto')])
  );

  const righe = await Promise.all(
    fogli.docs.map(async (doc) => {
      const fiamme = await senzaFermarsi(
        somma(doc.ref.collection('entries'), 'votes'),
        0,
        'fiamme'
      );

      return {
        ...(await garaPerIlPannello(doc)),
        fiamme,
        voto: Number.isInteger(voti.get(doc.id)) ? voti.get(doc.id) : null,
      };
    })
  );

  return { gare: righe };
}

function fotoPerIlPannello(doc) {
  const d = doc.data();

  return {
    challengeId: doc.ref.parent.parent.id,
    entryId: doc.id,
    userId: d.userId || doc.id,
    authorName: d.authorName || '',
    challengeTitle: d.challengeTitle || '',
    caption: d.caption || '',
    mediaUrl: d.mediaUrl || '',
    thumbUrl: d.thumbUrl || '',
    mediaKind: d.mediaKind || 'photo',
    votes: d.votes || 0,
    moderation: d.moderation || 'approved',
    moderationReason: d.moderationReason || '',
    moderationReasons: Array.isArray(d.moderationReasons) ? d.moderationReasons : [],
    // Quante persone l'hanno segnalata. Il numero si', i nomi mai.
    segnalazioni: Array.isArray(d.reporters) ? d.reporters.length : 0,
    createdAt: ms(d.createdAt),
  };
}

/** Una gara per intero: tutte le foto, le fiamme, e il giudizio che aveva preso. */
async function gara({ id }) {
  const garaId = testoObbligatorio(id, 'la missione');
  const doc = await db.collection('challenges').doc(garaId).get();

  if (!doc.exists) {
    throw new HttpsError('not-found', 'Questa missione non c\'è più.');
  }

  const [entries, proposta, segnalazioni, giudizio] = await Promise.all([
    doc.ref.collection('entries').limit(500).get(),
    db.collection(missioni.PROPOSTE).doc(garaId).get(),
    db.collection('reports').where('challengeId', '==', garaId).limit(100).get(),
    db
      .collection(missioni.GIUDIZI)
      .doc(missioni.improntaDi({
        title: doc.get('title') || '',
        brief: doc.get('brief') || '',
        duelMessage: doc.get('duelMessage') || '',
      }))
      .get(),
  ]);

  const foto = entries.docs
    .map(fotoPerIlPannello)
    .sort((a, b) => b.votes - a.votes);

  return {
    gara: {
      ...(await garaPerIlPannello(doc)),
      fiamme: foto.reduce((totale, f) => totale + f.votes, 0),
    },
    foto,
    proposta: proposta.exists ? propostaPerIlPannello(proposta) : null,
    giudizio: giudizio.exists
      ? {
          punteggio: Number.isInteger(giudizio.get('punteggio')) ? giudizio.get('punteggio') : null,
          categoria: giudizio.get('categoria') || '',
          motivo: giudizio.get('motivo') || '',
          decisione: giudizio.get('decisione') || '',
        }
      : null,
    segnalazioni: segnalazioni.size,
  };
}

async function togliGara({ id, motivo, sospendiGiorni }, chi) {
  const garaId = testoObbligatorio(id, 'la missione');
  const perche = testoObbligatorio(motivo, 'il motivo');
  const doc = await db.collection('challenges').doc(garaId).get();

  if (!doc.exists) {
    throw new HttpsError('not-found', 'Questa missione non c\'è più.');
  }

  if (doc.get('prizeStatus') === 'inRevisione') {
    throw new HttpsError('failed-precondition', 'È in revisione: decidila dalle Missioni.');
  }

  const autore = await autoreDi(doc);
  const titolo = doc.get('title') || '';

  // Il premio torna a chi l'ha messo, senza le spese: vedi `rimuoviLaMissione`.
  await rimuoviLaMissione(garaId, chi);

  let sospeso = null;

  if (autore && autore !== 'crasy' && sospendiGiorni !== undefined && sospendiGiorni !== null) {
    const fino = await sospensioni.sospendi(autore, {
      giorni: Number(sospendiGiorni),
      motivo: `La tua missione "${titolo}" è stata rimossa: ${perche}.`,
      chi,
    });

    sospeso = { fino: ms(fino) };
  }

  await registra(chi, 'togliGara', { id: garaId, titolo, motivo: perche, sospeso });

  return { tolta: true, sospeso };
}

/**
 * **Chiude una gara prima del tempo.** Si sposta la fine ad adesso, e al resto pensa
 * il giro delle chiusure, entro cinque minuti: vince chi ha piu' fiamme a questo punto,
 * e il premio segue la strada di sempre. Nessun percorso speciale per i soldi.
 */
async function chiudiGara({ id }, chi) {
  const garaId = testoObbligatorio(id, 'la missione');
  const ref = db.collection('challenges').doc(garaId);
  const doc = await ref.get();

  if (!doc.exists) {
    throw new HttpsError('not-found', 'Questa missione non c\'è più.');
  }

  if (doc.get('prizeStatus') === 'inRevisione') {
    throw new HttpsError('failed-precondition', 'È in revisione: decidila dalle Missioni.');
  }

  const fine = doc.get('endsAt');

  if (!fine || fine.toMillis() <= Date.now()) {
    return { chiusa: false, motivo: 'già finita' };
  }

  await ref.update({ endsAt: Timestamp.now() });
  await registra(chi, 'chiudiGara', { id: garaId, titolo: doc.get('title') || '' });

  return { chiusa: true };
}

/**
 * **Il voto a una missione uscita prima che esistesse il controllo.** Non cambia niente
 * da solo: dice a chi guarda cosa ne pensa l'AI, e a togliere la missione resta un
 * tasto premuto da una persona.
 */
async function valutaGara({ id }) {
  const garaId = testoObbligatorio(id, 'la missione');
  const doc = await db.collection('challenges').doc(garaId).get();

  if (!doc.exists) {
    throw new HttpsError('not-found', 'Questa missione non c\'è più.');
  }

  const esito = await missioni.valuta(
    {
      title: doc.get('title') || '',
      brief: doc.get('brief') || '',
      duelMessage: doc.get('duelMessage') || '',
    },
    await missioni.leggiImpostazioni()
  );

  return { filtro: esito.filtro, giudizio: esito.giudizio, voto: esito.voto, strada: esito.strada };
}

// ---------------------------------------------------------------------------
// I conti
// ---------------------------------------------------------------------------

/** Il giorno di oggi meno [quanti] giorni, nella forma con cui si chiamano i fogli. */
function giornoFa(quanti) {
  return new Date(Date.now() - quanti * GIORNO).toLocaleDateString('sv-SE', {
    timeZone: 'Europe/Rome',
  });
}

function sommaLeSpese(fogli) {
  const totale = { giudizi: 0, riusati: 0, prove: 0, entrata: 0, uscita: 0, dollari: 0 };

  for (const foglio of fogli) {
    for (const campo of Object.keys(totale)) {
      totale[campo] += foglio.get(campo) || 0;
    }
  }

  return totale;
}

/**
 * **Quanto costa il modello.** Il conto si fa sui gettoni che OpenAI dichiara a ogni
 * risposta: e' una stima precisa ma non e' la fattura, che resta sul loro sito. La
 * chiave che usiamo non puo' leggerla, e non deve poterlo.
 */
async function speseAI() {
  const fogli = await db
    .collection(missioni.SPESE)
    .orderBy('giorno', 'desc')
    .limit(400)
    .get();
  const dal = (giorni) => {
    const soglia = giornoFa(giorni - 1);

    return fogli.docs.filter((foglio) => foglio.get('giorno') >= soglia);
  };
  const sempre = sommaLeSpese(fogli.docs);

  return {
    modello: giudice.MODELLO,
    prezzi: giudice.PREZZI,
    oggi: sommaLeSpese(dal(1)),
    settimana: sommaLeSpese(dal(7)),
    mese: sommaLeSpese(dal(30)),
    sempre,
    // Quanto costerebbero mille missioni, col costo medio vero di quelle giudicate.
    allaMissione: sempre.giudizi ? sempre.dollari / sempre.giudizi : null,
    giorni: fogli.docs.slice(0, 30).map((foglio) => ({
      giorno: foglio.get('giorno'),
      giudizi: foglio.get('giudizi') || 0,
      riusati: foglio.get('riusati') || 0,
      prove: foglio.get('prove') || 0,
      dollari: foglio.get('dollari') || 0,
    })),
  };
}

/**
 * **Tutto quello che passa da Stripe e che non e' un incasso.**
 *
 * I guadagni di `adminGuadagni` guardano gli incassi, e le spese scritte sopra ognuno.
 * Ma Stripe si fa pagare anche a parte: i conti dei vincitori attivi, le contestazioni,
 * le conversioni. Sono righe del registro con un altro nome, e senza questa somma
 * "quanto mi costa Stripe" verrebbe piu' basso del vero.
 *
 * Qui si dividono anche i soldi che escono senza essere una spesa: i rimborsi, i premi
 * girati ai vincitori, quello che e' andato sul conto in banca.
 */
async function contiStripe({ giorni }) {
  const quanti = Math.min(Math.max(Number(giorni) || 30, 1), 365);
  const daQuando = Math.floor(Date.now() / 1000) - quanti * 24 * 60 * 60;
  const stripe = payments.stripeClient();
  const conti = { altreSpese: 0, rimborsi: 0, aiVincitori: 0, inBanca: 0, altro: 0, voci: {} };

  for await (const movimento of stripe.balanceTransactions.list({
    limit: 100,
    created: { gte: daQuando },
  })) {
    const { type: tipo, amount: quanto = 0, fee = 0 } = movimento;

    // Gli incassi li conta gia' `adminGuadagni`, con le loro spese.
    if (tipo === 'charge' || tipo === 'payment') {
      continue;
    }

    conti.altreSpese += fee;

    if (movimento.reporting_category === 'fee' || /(^|_)fee$/.test(tipo)) {
      conti.altreSpese += -quanto;
    } else if (/refund/.test(tipo) && !/^transfer/.test(tipo)) {
      conti.rimborsi += -quanto;
    } else if (/^transfer/.test(tipo)) {
      conti.aiVincitori += -quanto;
    } else if (/^payout/.test(tipo)) {
      conti.inBanca += -quanto;
    } else {
      conti.altro += quanto;
    }

    conti.voci[tipo] = (conti.voci[tipo] || 0) + 1;
  }

  const fogli = await db
    .collection(missioni.SPESE)
    .where('giorno', '>=', giornoFa(quanti - 1))
    .get();

  return { giorni: quanti, ...conti, ai: sommaLeSpese(fogli.docs) };
}

// ---------------------------------------------------------------------------
// Tutte le spese
// ---------------------------------------------------------------------------

/** Le spese scritte a mano: un foglio solo, che non legge nessuno fuori dal pannello. */
const SPESE_FISSE = 'speseFisse';

/**
 * **Tutte le spese, voce per voce.** Vedi `spese.js`. Ogni pezzo per conto suo: se Google non
 * risponde, Stripe si deve vedere lo stesso, e il pannello dice cosa manca dal totale.
 */
async function tutteLeSpese({ giorni }) {
  const quanti = Math.min(Math.max(Number(giorni) || 30, 1), 365);
  const [stripe, consumi, vero, foglioFisse, fogliAI] = await Promise.all([
    senzaFermarsi(
      (async () => speseDiCrasy.speseStripe({ giorni: quanti }, payments.stripeClient()))(),
      null,
      'spese di Stripe'
    ),
    senzaFermarsi(speseDiCrasy.consumiGoogle({ giorni: quanti }), null, 'consumi di Google'),
    senzaFermarsi(speseDiCrasy.contoVero({ giorni: quanti }), null, 'fattura di Google'),
    db.collection(missioni.IMPOSTAZIONI).doc(SPESE_FISSE).get(),
    db.collection(missioni.SPESE).where('giorno', '>=', giornoFa(quanti - 1)).get(),
  ]);
  const ai = sommaLeSpese(fogliAI.docs);
  const fisse = speseDiCrasy.fissePerIlPeriodo(foglioFisse.get('voci'), quanti);
  const googleVero = Boolean(vero && vero.attivo && vero.righe.length);
  const consumiInCents = consumi ? Math.round(consumi.costo * 100) : null;
  const parti = {
    stripe: stripe ? stripe.totale : null,
    ai: Math.round(ai.dollari * speseDiCrasy.DOLLARO_IN_EURO * 100),
    google: googleVero ? Math.round(vero.netto * 100) : consumiInCents,
    fisse: fisse.totale,
  };

  return {
    giorni: quanti,
    stripe,
    consumi,
    vero,
    googleVero,
    ai,
    cambio: speseDiCrasy.DOLLARO_IN_EURO,
    fisse,
    parti,
    totale: Object.values(parti).reduce((somma, parte) => somma + (parte || 0), 0),
  };
}

async function aggiungiSpesaFissa(dati, chi) {
  let voce;

  try {
    voce = speseDiCrasy.nuovaSpesaFissa(dati);
  } catch (errore) {
    throw new HttpsError('invalid-argument', errore.message);
  }

  const ref = db.collection(missioni.IMPOSTAZIONI).doc(SPESE_FISSE);

  await db.runTransaction(async (transazione) => {
    const foglio = await transazione.get(ref);
    const voci = foglio.get('voci') || [];

    if (voci.length >= 100) {
      throw new HttpsError('failed-precondition', 'Ce ne sono già cento: toglierne una prima.');
    }

    transazione.set(ref, { voci: [...voci, voce] }, { merge: true });
  });

  await registra(chi, 'spesaFissa', { nome: voce.nome, cents: voce.cents, ogni: voce.ogni });

  return { voce };
}

async function togliSpesaFissa({ id }, chi) {
  const quale = testoObbligatorio(id, 'la spesa');
  const ref = db.collection(missioni.IMPOSTAZIONI).doc(SPESE_FISSE);
  let tolta = null;

  await db.runTransaction(async (transazione) => {
    const foglio = await transazione.get(ref);
    const voci = foglio.get('voci') || [];

    tolta = voci.find((voce) => voce.id === quale) || null;

    if (tolta) {
      transazione.set(ref, { voci: voci.filter((voce) => voce.id !== quale) }, { merge: true });
    }
  });

  if (!tolta) {
    throw new HttpsError('not-found', 'Questa spesa non c\'è più.');
  }

  await registra(chi, 'togliSpesaFissa', { nome: tolta.nome });

  return { ok: true };
}

// ---------------------------------------------------------------------------
// Le foto
// ---------------------------------------------------------------------------

async function foto({ ordine }) {
  const tutte = db.collectionGroup('entries');
  const fogli = await (ordine === 'fiamme'
    ? tutte.where('createdAt', '>', indietro(3 * GIORNO)).orderBy('createdAt', 'desc').limit(200)
    : tutte.orderBy('createdAt', 'desc').limit(90)
  ).get();

  const righe = fogli.docs.map(fotoPerIlPannello);

  if (ordine === 'fiamme') {
    righe.sort((a, b) => b.votes - a.votes);
  }

  return { foto: righe.slice(0, 90) };
}

/** Toglie una foto dalla gara senza che ci sia una segnalazione di mezzo. */
async function togliFoto({ challengeId, entryId, motivo }, chi) {
  const gara = testoObbligatorio(challengeId, 'la missione');
  const foto = testoObbligatorio(entryId, 'la foto');
  const voce = ['pericolo', 'sessuale', 'violenza', 'odio', 'minore', 'illegale', 'spam'].includes(
    motivo
  )
    ? motivo
    : 'altro';

  const esito = await togliLaFoto(
    db.collection('challenges').doc(gara).collection('entries').doc(foto),
    { chi, motivo: voce }
  );

  await registra(chi, 'togliFoto', { challengeId: gara, entryId: foto, motivo: voce });

  return esito;
}

// ---------------------------------------------------------------------------
// Il banco di prova
// ---------------------------------------------------------------------------

/** La missione per finta. Vedi `missioni.valutaPerProva`. */
async function provaLancio({ title, brief, duelMessage }) {
  const titolo = typeof title === 'string' ? title.trim() : '';

  if (!titolo) {
    throw new HttpsError('invalid-argument', 'Scrivi almeno il titolo.');
  }

  const impostazioni = await missioni.leggiImpostazioni();
  const esito = await missioni.valutaPerProva(
    {
      title: titolo,
      brief: typeof brief === 'string' ? brief.trim() : '',
      duelMessage: typeof duelMessage === 'string' ? duelMessage.trim() : '',
    },
    impostazioni
  );

  return {
    ...esito,
    soglie: { sogliaAuto: impostazioni.sogliaAuto, sogliaConferma: impostazioni.sogliaConferma },
  };
}

/** Gli esempi insegnati, dal foglio delle impostazioni: stanno li' perche' si leggono insieme. */
function fogliEsempi() {
  return db.collection(missioni.IMPOSTAZIONI).doc('moderazione');
}

async function esempi() {
  const foglio = await fogliEsempi().get();
  const elenco = foglio.exists && Array.isArray(foglio.get('esempi')) ? foglio.get('esempi') : [];

  return { esempi: [...elenco].reverse(), massimo: giudice.ESEMPI_MASSIMI };
}

/**
 * **Insegna al modello il voto giusto per una missione.** Vale subito per le prove e per
 * le missioni vere, e i voti gia' dati si rifanno: vedi `versioneDelleIstruzioni`.
 */
async function insegna({ title, brief, duelMessage, voto, motivo }, chi) {
  const titolo = testoObbligatorio(title, 'il titolo');
  const perche = testoObbligatorio(motivo, 'il motivo').slice(0, 200);
  const numero = Number(voto);

  if (!Number.isInteger(numero) || numero < 0 || numero > 100) {
    throw new HttpsError('invalid-argument', 'Il voto va da 0 a 100.');
  }

  const voce = {
    id: db.collection('_').doc().id,
    title: titolo.slice(0, 60),
    brief: typeof brief === 'string' ? brief.trim().slice(0, 280) : '',
    duelMessage: typeof duelMessage === 'string' ? duelMessage.trim().slice(0, 140) : '',
    voto: numero,
    motivo: perche,
    chi,
    il: Date.now(),
  };

  await db.runTransaction(async (t) => {
    const foglio = await t.get(fogliEsempi());
    const elenco = foglio.exists && Array.isArray(foglio.get('esempi')) ? foglio.get('esempi') : [];

    // La stessa missione corretta due volte vale una volta sola: l'ultima.
    const altre = elenco.filter((e) => !(e.title === voce.title && e.brief === voce.brief));

    if (altre.length >= giudice.ESEMPI_MASSIMI) {
      throw new HttpsError(
        'failed-precondition',
        `Sono già ${giudice.ESEMPI_MASSIMI}: dimenticane uno prima di aggiungerne un altro.`
      );
    }

    t.set(fogliEsempi(), { esempi: [...altre, voce] }, { merge: true });
  });

  missioni.dimenticaImpostazioni();
  await registra(chi, 'insegna', { title: voce.title, voto: numero, motivo: perche });

  return { id: voce.id };
}

async function dimentica({ id }, chi) {
  const quale = testoObbligatorio(id, 'l\'esempio');

  await db.runTransaction(async (t) => {
    const foglio = await t.get(fogliEsempi());
    const elenco = foglio.exists && Array.isArray(foglio.get('esempi')) ? foglio.get('esempi') : [];

    t.set(fogliEsempi(), { esempi: elenco.filter((e) => e.id !== quale) }, { merge: true });
  });

  missioni.dimenticaImpostazioni();
  await registra(chi, 'dimentica', { id: quale });

  return { tolto: true };
}

/** Quante prove della batteria vanno insieme: una alla volta non starebbe nel tempo. */
const PROVE_INSIEME = 12;

/**
 * **La batteria: tutte le missioni di prova, piu' quelle insegnate.** Quello che conta e'
 * una riga sola: una missione pericolosa che uscirebbe da sola.
 *
 * Non scrive niente, se non la spesa. Le insegnate che passano dal modello con il loro
 * esempio davanti sono una prova debole, ma dicono se il modello lo sta rispettando.
 */
async function batteria() {
  const impostazioni = await missioni.leggiImpostazioni();
  const elenco = [
    ...PROVE.map(([atteso, title, brief]) => ({ atteso, title, brief, duelMessage: '' })),
    ...impostazioni.esempi.map((e) => ({
      atteso: e.voto >= impostazioni.sogliaAuto ? 'sola' : 'persona',
      title: e.title,
      brief: e.brief,
      duelMessage: e.duelMessage || '',
      insegnata: true,
    })),
  ];
  const righe = [];

  for (let i = 0; i < elenco.length; i += PROVE_INSIEME) {
    const gruppo = elenco.slice(i, i + PROVE_INSIEME);

    righe.push(
      ...(await Promise.all(
        gruppo.map(async (prova) => {
          const e = await missioni.valutaPerProva(prova, impostazioni);
          const esce = e.strada === 'inGara';
          const guasto = e.strada !== 'bloccata' && (!e.giudizio || e.giudizio.esito !== 'fatto');
          let esito = 'ok';

          if (guasto) {
            esito = 'guasto';
          } else if (prova.atteso === 'persona' && esce) {
            esito = 'pericoloso';
          } else if (prova.atteso === 'sola' && !esce) {
            esito = 'prudente';
          }

          return {
            title: prova.title,
            brief: prova.brief,
            atteso: prova.atteso,
            insegnata: prova.insegnata === true,
            voto: e.voto,
            strada: e.strada,
            esito,
            motivo: e.filtro.rossa
              ? `Fermata dal filtro: ${e.filtro.rossa.termine}`
              : (e.giudizio && e.giudizio.motivo) || '',
            costo: e.costo,
          };
        })
      ))
    );
  }

  const costo = righe.reduce((totale, r) => totale + r.costo, 0);
  const giudicate = righe.filter((r) => r.costo > 0).length;

  return {
    righe: righe.map(({ costo: _costo, ...resto }) => resto),
    costo,
    perMille: giudicate ? (costo / giudicate) * 1000 : null,
  };
}

// ---------------------------------------------------------------------------
// Le persone
// ---------------------------------------------------------------------------

/** Una riga di persona, con email e stato dell'account presi da Firebase Auth. */
function personaPerIlPannello(doc, conto) {
  const d = doc.data() || {};

  return {
    uid: doc.id,
    username: d.username || '',
    displayName: d.displayName || '',
    photoUrl: d.photoUrl || '',
    city: d.city || '',
    walletCents: d.walletCents || 0,
    stripeCents: d.stripeCents || 0,
    totalWonCents: d.totalWonCents || 0,
    totalWonCount: d.totalWonCount || 0,
    followersCount: d.followersCount || 0,
    followingCount: d.followingCount || 0,
    verificato: d.verificato === true,
    conContoStripe: Boolean(d.stripeAccountId),
    payoutReady: d.payoutReady === true,
    lastSeenAt: ms(d.lastSeenAt),
    createdAt: ms(d.createdAt),
    email: conto ? conto.email || '' : '',
    disabled: conto ? conto.disabled === true : false,
  };
}

async function contiDi(uids) {
  const conti = new Map();

  for (let i = 0; i < uids.length; i += 100) {
    const risposta = await admin
      .auth()
      .getUsers(uids.slice(i, i + 100).map((uid) => ({ uid })));

    for (const conto of risposta.users) {
      conti.set(conto.uid, conto);
    }
  }

  return conti;
}

async function persone({ ordine, q, dopo }) {
  const utenti = db.collection('users');
  const LIMITE = 60;
  let fogli;

  const cerca = String(q || '').trim().toLowerCase().replace(/^@/, '');

  if (cerca.length >= 2) {
    fogli = (
      await utenti.orderBy('username').startAt(cerca).endAt(`${cerca}`).limit(LIMITE).get()
    ).docs;
  } else if (ordine === 'soldi') {
    // **I soldi stanno in due campi**, e Firestore non ordina per una somma: si
    // prendono quelli che hanno qualcosa in uno dei due, e si ordinano qui. Non sono
    // mai tanti: chi ha un saldo e' chi ha vinto qualcosa.
    const [conCustodia, conConto] = await Promise.all([
      utenti.where('walletCents', '>', 0).limit(500).get(),
      utenti.where('stripeCents', '>', 0).limit(500).get(),
    ]);
    const insieme = new Map([...conCustodia.docs, ...conConto.docs].map((d) => [d.id, d]));
    const quanto = (d) => (d.get('walletCents') || 0) + (d.get('stripeCents') || 0);

    fogli = [...insieme.values()].sort((a, b) => quanto(b) - quanto(a)).slice(0, 200);
  } else {
    const campi = {
      recenti: 'lastSeenAt',
      nuovi: 'createdAt',
      vincite: 'totalWonCents',
      follower: 'followersCount',
    };
    const campo = campi[ordine] || 'lastSeenAt';
    let query = utenti.orderBy(campo, 'desc').limit(LIMITE);

    if (dopo) {
      const ultimo = await utenti.doc(String(dopo)).get();

      if (ultimo.exists) {
        query = query.startAfter(ultimo);
      }
    }

    fogli = (await query.get()).docs;
  }

  const conti = await senzaFermarsi(contiDi(fogli.map((d) => d.id)), new Map(), 'conti');

  return {
    persone: fogli.map((d) => personaPerIlPannello(d, conti.get(d.id))),
    ancora: !cerca && ordine !== 'soldi' && fogli.length === LIMITE,
  };
}

/** I saldi veri, chiesti a Stripe. Un po' per volta: e' una chiamata a persona. */
async function saldiConti({ uids }) {
  const elenco = (Array.isArray(uids) ? uids : []).map(String).slice(0, 30);

  if (elenco.length === 0) {
    return { saldi: {} };
  }

  const fogli = await db.getAll(...elenco.map((uid) => db.collection('users').doc(uid)));
  const saldi = {};
  let stripe;

  try {
    stripe = payments.stripePayoutClient();
  } catch (errore) {
    logger.warn('Stripe non si accende: i saldi restano quelli della nostra copia');

    return { saldi };
  }

  await Promise.all(
    fogli.map(async (foglio) => {
      const conto = foglio.get('stripeAccountId');

      if (!conto) {
        return;
      }

      try {
        saldi[foglio.id] = await payments.saldoDelConto(stripe, conto);
      } catch (errore) {
        saldi[foglio.id] = { errore: true };
        logger.warn('saldo non letto', { uid: foglio.id });
      }
    })
  );

  return { saldi };
}

/** Tutto quello che c'e' su una persona. */
async function persona({ uid }) {
  const id = testoObbligatorio(uid, 'la persona');
  const ref = db.collection('users').doc(id);
  const doc = await ref.get();

  if (!doc.exists) {
    throw new HttpsError('not-found', 'Questa persona non c\'è.');
  }

  const conto = await senzaFermarsi(admin.auth().getUser(id), null, 'conto');

  const [
    movimenti,
    registro,
    proposteDi,
    firmate,
    anonime,
    entries,
    amici,
    segnalazioniContro,
    fiammeDate,
    sospensione,
    bloccataDa,
    firme,
  ] = await Promise.all([
    senzaFermarsi(ref.collection('wallet').orderBy('createdAt', 'desc').limit(40).get(), null, 'mov'),
    senzaFermarsi(ref.collection('ledger').orderBy('at', 'desc').limit(40).get(), null, 'registro'),
    senzaFermarsi(
      db.collection(missioni.PROPOSTE).where('uid', '==', id).limit(60).get(),
      null,
      'proposte'
    ),
    senzaFermarsi(
      db.collection('challenges').where('createdByUserId', '==', id).limit(60).get(),
      null,
      'firmate'
    ),
    senzaFermarsi(db.collection('autoriAnonimi').where('uid', '==', id).limit(30).get(), null, 'anonime'),
    senzaFermarsi(
      db.collectionGroup('entries').where('userId', '==', id).orderBy('createdAt', 'desc').limit(60).get(),
      null,
      'foto'
    ),
    senzaFermarsi(conta(ref.collection('friends')), 0, 'amici'),
    senzaFermarsi(conta(db.collection('reports').where('reportedUserId', '==', id)), 0, 'segn'),
    senzaFermarsi(conta(ref.collection('votes')), 0, 'date'),
    sospensioni.statoDi(id),
    senzaFermarsi(
      conta(db.collection(moderazione.BLOCCHI).where('bloccatoId', '==', id)),
      0,
      'bloccataDa'
    ),
    senzaFermarsi(
      ref.collection('consents').where('kind', '==', 'legale').limit(50).get(),
      null,
      'firme'
    ),
  ]);

  // Il conto Stripe si chiede per ultimo, e se non risponde non ferma niente.
  let stripe = null;
  const contoStripe = doc.get('stripeAccountId');

  if (contoStripe) {
    // Dentro una funzione e non qui sotto: se la chiave manca, l'errore arriva gia' nel
    // creare il cliente, e deve restare un riquadro vuoto invece di una pagina rotta.
    stripe = await senzaFermarsi(
      (async () => payments.saldoDelConto(payments.stripePayoutClient(), contoStripe))(),
      { errore: true },
      'saldo'
    );
  }

  const foto = entries ? entries.docs.map(fotoPerIlPannello) : [];
  const leAnonime = anonime
    ? await Promise.all(
        anonime.docs.map((foglio) => db.collection('challenges').doc(foglio.id).get())
      )
    : [];
  const garePropie = await Promise.all(
    [...(firmate ? firmate.docs : []), ...leAnonime.filter((g) => g.exists)].map(garaPerIlPannello)
  );

  garePropie.sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));

  const nomi = proposteDi
    ? await nomiDi(proposteDi.docs.map((foglio) => foglio.get('decisaDa')))
    : new Map();

  const movimentoDi = (foglio) => {
    const d = foglio.data();

    return {
      id: foglio.id,
      kind: d.kind || '',
      amountCents: d.amountCents || 0,
      pagatoCents: d.pagatoCents || 0,
      challengeTitle: d.challengeTitle || d.title || '',
      quando: ms(d.createdAt) || ms(d.at),
    };
  };

  return {
    persona: personaPerIlPannello(doc, conto),
    profilo: {
      bio: doc.get('bio') || '',
      birthDate: ms(doc.get('birthDate')),
      emailVerificata: conto ? conto.emailVerified === true : null,
      telefono: conto ? conto.phoneNumber || '' : '',
      // **Cosa ha accettato, e quando.** Le righe vere del registro, che nessuno puo'
      // modificare: la prova, se qualcuno la chiede.
      firme: (firme ? firme.docs : [])
        .map((riga) => ({
          version: String(riga.get('version') || ''),
          origine: String(riga.get('origine') || ''),
          at: ms(riga.get('at')),
        }))
        .sort((a, b) => (b.at || 0) - (a.at || 0)),
      ultimoAccesso: conto ? Date.parse(conto.metadata.lastSignInTime) || null : null,
      admin: conto ? (conto.customClaims || {}).admin === true : false,
    },
    numeri: {
      amici,
      fiammeDate,
      segnalazioniContro,
      bloccataDa,
      fiammeRicevute: foto.reduce((totale, f) => totale + f.votes, 0),
    },
    stripe,
    sospensione,
    movimenti: movimenti ? movimenti.docs.map(movimentoDi) : [],
    registro: registro ? registro.docs.map(movimentoDi) : [],
    proposte: proposteDi
      ? proposteDi.docs
          .map((foglio) => propostaPerIlPannello(foglio, null, nomi))
          .sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0))
      : [],
    gare: garePropie,
    foto,
  };
}

async function sospendi({ uid, giorni, motivo }, chi) {
  const id = testoObbligatorio(uid, 'la persona');
  const perche = testoObbligatorio(motivo, 'il motivo');
  const fino = await sospensioni.sospendi(id, { giorni: Number(giorni), motivo: perche, chi });

  await registra(chi, 'sospendi', { uid: id, giorni: Number(giorni), motivo: perche });

  return { fino: ms(fino) };
}

/**
 * **Espellere qualcuno: l'account si elimina per davvero.**
 *
 * Non si puo' tornare indietro, e per questo chiede di riscrivere il nome. Chi vuole
 * tenere fuori una persona **di solito vuole "sospendi per sempre"**: l'account resta
 * spento e il numero di telefono occupato, mentre qui email e numero tornano liberi e
 * ci si puo' reiscrivere.
 *
 * **Con dei soldi dentro non si fa.** Il premio di qualcuno non si cancella con un
 * clic: si sospende, e si chiude quando il saldo e' a zero. E' la stessa regola che
 * vale per chi cancella il proprio account da solo.
 *
 * Toglie quello che toglierebbe la persona stessa, piu' le sue foto ancora in gara e i
 * suoi commenti. **Resta il registro dei consensi e quello dei movimenti**: sono le
 * prove che la legge chiede di conservare.
 */
async function eliminaAccount({ uid, motivo, conferma }, chi) {
  const id = testoObbligatorio(uid, 'la persona');
  const perche = testoObbligatorio(motivo, 'il motivo');

  if (id === 'crasy') {
    throw new HttpsError('failed-precondition', 'L\'account ufficiale non si elimina.');
  }

  const ref = db.collection('users').doc(id);
  const doc = await ref.get();
  const nome = String(doc.get('username') || id);

  if (String(conferma || '').trim().replace(/^@/, '').toLowerCase() !== nome.toLowerCase()) {
    throw new HttpsError('invalid-argument', `Per confermare scrivi il nome: ${nome}.`);
  }

  const conto = await senzaFermarsi(admin.auth().getUser(id), null, 'conto');

  if (conto && conto.customClaims && conto.customClaims.admin === true) {
    throw new HttpsError('failed-precondition', 'È un amministratore: non si elimina da qui.');
  }

  const soldi = ['walletCents', 'withdrawingCents', 'stripeCents', 'spostandoCents'].reduce(
    (totale, campo) => totale + (doc.get(campo) || 0),
    0
  );

  if (soldi > 0) {
    throw new HttpsError(
      'failed-precondition',
      'Ha ancora dei soldi su CRASY: sospendila, e chiudi l\'account quando il saldo è a zero.'
    );
  }

  const prelievi = await conta(
    db
      .collection('payoutRequests')
      .where('userId', '==', id)
      .where('status', '==', 'pending')
  );

  if (prelievi > 0) {
    throw new HttpsError('failed-precondition', 'Ha un prelievo in corso: prima va chiuso.');
  }

  // Le foto ancora in gara escono come se le togliesse una persona: fuori dal conto
  // dei partecipanti, e le fiamme tornano a chi le aveva date. Una foto che ha vinto
  // resta: li' c'e' un premio gia' assegnato.
  const foto = await senzaFermarsi(
    db.collectionGroup('entries').where('userId', '==', id).limit(200).get(),
    null,
    'foto'
  );

  for (const partecipazione of foto ? foto.docs : []) {
    if (partecipazione.get('isWinner') === true) {
      continue;
    }

    await togliLaFoto(partecipazione.ref, { chi, autore: id, motivo: 'altro' }).catch((errore) => {
      logger.warn('foto non tolta', { uid: id, errore: String(errore).slice(0, 200) });
    });
  }

  const commenti = await senzaFermarsi(
    db.collectionGroup('comments').where('userId', '==', id).limit(400).get(),
    null,
    'commenti'
  );

  await Promise.all((commenti ? commenti.docs : []).map((c) => c.ref.delete().catch(() => {})));

  const amici = await ref.collection('friends').get();

  await Promise.all(
    amici.docs.map((amico) =>
      db.collection('users').doc(amico.id).collection('friends').doc(id).delete().catch(() => {})
    )
  );

  for (const raccolta of [
    'friends',
    'notifications',
    'votes',
    'friendRequests',
    'following',
    'private',
    'devices',
    'blocked',
    'pushFiamme',
    'revealsSeen',
  ]) {
    const righe = await ref.collection(raccolta).limit(500).get();

    await Promise.all(righe.docs.map((riga) => riga.ref.delete().catch(() => {})));
  }

  for (const magazzino of magazzini.tuttiIMagazzini()) {
    await magazzino.deleteFiles({ prefix: `profiles/${id}/` }).catch((errore) => {
      logger.warn('foto profilo non cancellata', { uid: id, errore: String(errore).slice(0, 200) });
    });
  }

  await ref.delete();

  // Chi non puo' piu' entrare deve sapere perche', e come contestarlo.
  if (conto && conto.email) {
    await posta
      .spedisci({
        from: '"CRASY" <' + posta.CASELLA + '>',
        to: conto.email,
        subject: 'Il tuo account CRASY è stato eliminato',
        text:
          `${perche} Per questo il tuo account è stato eliminato, come previsto dai Termini. ` +
          'Se pensi che sia un errore, scrivi a info@crasyapp.com.',
      })
      .catch((errore) => {
        logger.error('email di eliminazione non partita', errore);
      });
  }

  await db.collection('sospensioni').doc(id).set({
    attiva: false,
    eliminato: true,
    username: nome,
    motivo: perche,
    da: chi,
    il: FieldValue.serverTimestamp(),
  });

  if (conto) {
    await admin.auth().deleteUser(id);
  }

  await registra(chi, 'eliminaAccount', { uid: id, username: nome, motivo: perche });

  return { eliminato: true };
}

// ---------------------------------------------------------------------------
// I blocchi
// ---------------------------------------------------------------------------

/**
 * **Chi ha bloccato chi.** Non sono segnalazioni e non c'e' niente da decidere: e' il
 * modo in cui il team viene a sapere che fra due persone qualcosa non va, come chiede
 * Apple. Dalla scheda della persona, se serve, si interviene.
 */
async function blocchi({ stato }) {
  const eventi = db.collection(moderazione.BLOCCHI);
  const query =
    stato === 'nuovo' || stato === 'visto' ? eventi.where('stato', '==', stato) : eventi;

  // Stesso discorso delle segnalazioni: l'indice si costruisce con calma, e la pagina
  // deve funzionare anche nei minuti dopo il rilascio.
  const fogli = await query
    .orderBy('createdAt', 'desc')
    .limit(100)
    .get()
    .catch(() => query.limit(100).get());
  const conti = new Map();

  await Promise.all(
    [...new Set(fogli.docs.map((d) => String(d.get('bloccatoId') || '')))].filter(Boolean).map(
      async (uid) => {
        conti.set(
          uid,
          await senzaFermarsi(conta(eventi.where('bloccatoId', '==', uid)), 0, 'contro')
        );
      }
    )
  );

  return {
    blocchi: fogli.docs
      .map((d) => ({
        id: d.id,
        bloccaId: String(d.get('bloccaId') || ''),
        bloccaNome: String(d.get('bloccaNome') || ''),
        bloccatoId: String(d.get('bloccatoId') || ''),
        bloccatoNome: String(d.get('bloccatoNome') || ''),
        origine: String(d.get('origine') || ''),
        challengeId: String(d.get('challengeId') || ''),
        entryId: String(d.get('entryId') || ''),
        commentId: String(d.get('commentId') || ''),
        stato: String(d.get('stato') || 'nuovo'),
        createdAt: ms(d.get('createdAt')),
        sbloccatoIl: ms(d.get('sbloccatoIl')),
        contro: conti.get(String(d.get('bloccatoId') || '')) || 1,
      }))
      .sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0)),
  };
}

/** "L'ho visto": toglie il blocco dal lavoro da fare, e resta scritto chi l'ha guardato. */
async function segnaBlocco({ id }, chi) {
  const riferimento = db.collection(moderazione.BLOCCHI).doc(testoObbligatorio(id, 'il blocco'));
  const foglio = await riferimento.get();

  if (!foglio.exists) {
    throw new HttpsError('not-found', 'Questo blocco non c\'è più.');
  }

  // Due clic: il secondo non riscrive e non lascia una seconda riga.
  if (foglio.get('stato') === 'visto') {
    return { stato: 'visto' };
  }

  await riferimento.update({ stato: 'visto', vistoDa: chi, vistoIl: FieldValue.serverTimestamp() });
  await registra(chi, 'segnaBlocco', {
    id: foglio.id,
    uid: String(foglio.get('bloccatoId') || ''),
    bloccaNome: String(foglio.get('bloccaNome') || ''),
    bloccatoNome: String(foglio.get('bloccatoNome') || ''),
  });

  return { stato: 'visto' };
}

// ---------------------------------------------------------------------------
// Le impostazioni e il registro
// ---------------------------------------------------------------------------

function elencoDiParole(valore) {
  if (!Array.isArray(valore)) {
    return [];
  }

  return [...new Set(valore.map((t) => String(t).trim().toLowerCase()).filter(Boolean))].slice(
    0,
    500
  );
}

async function leggiImpostazioni() {
  const { sogliaAuto, sogliaConferma, soloAMano, tettoGiudizi, rosseAggiunte, gialleAggiunte, consentite } =
    await missioni.leggiImpostazioni();
  const oggi = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Rome' });
  const contatore = await db.collection(missioni.LIMITI).doc(`giudizi_${oggi}`).get();
  const spese = await senzaFermarsi(speseAI(), null, 'spese');

  return {
    sogliaAuto,
    sogliaConferma,
    soloAMano,
    tettoGiudizi,
    rosseAggiunte,
    gialleAggiunte,
    consentite,
    modello: giudice.MODELLO,
    giudiziOggi: contatore.exists ? contatore.get('quanti') || 0 : 0,
    spese,
    chiave: Boolean(giudice.chiaveVera(giudice.OPENAI_API_KEY.value())),
  };
}

async function scriviImpostazioni(dati, chi) {
  const sogliaAuto = Number(dati.sogliaAuto);
  const sogliaConferma = Number(dati.sogliaConferma);
  const tettoGiudizi = Number(dati.tettoGiudizi);

  if (
    !Number.isInteger(sogliaAuto) ||
    !Number.isInteger(sogliaConferma) ||
    sogliaAuto < 1 ||
    sogliaAuto > 100 ||
    sogliaConferma < 0 ||
    sogliaConferma >= sogliaAuto
  ) {
    throw new HttpsError(
      'invalid-argument',
      'Le soglie vanno da 0 a 100, e la conferma deve stare sotto l\'uscita automatica.'
    );
  }

  if (!Number.isInteger(tettoGiudizi) || tettoGiudizi < 0 || tettoGiudizi > 20000) {
    throw new HttpsError('invalid-argument', 'Il tetto dei giudizi non è valido.');
  }

  const nuove = {
    sogliaAuto,
    sogliaConferma,
    tettoGiudizi,
    soloAMano: dati.soloAMano === true,
    rosseAggiunte: elencoDiParole(dati.rosseAggiunte),
    gialleAggiunte: elencoDiParole(dati.gialleAggiunte),
    consentite: elencoDiParole(dati.consentite),
  };

  await db
    .collection(missioni.IMPOSTAZIONI)
    .doc('moderazione')
    .set({ ...nuove, cambiateDa: chi, cambiateIl: FieldValue.serverTimestamp() }, { merge: true });
  missioni.dimenticaImpostazioni();
  await registra(chi, 'impostazioni', nuove);

  return leggiImpostazioni();
}

async function registro() {
  const fogli = await db.collection('registroAdmin').orderBy('il', 'desc').limit(150).get();
  const nomi = await nomiDi(fogli.docs.map((doc) => doc.get('chi')));

  return {
    righe: fogli.docs.map((doc) => ({
      id: doc.id,
      chi: nomi.get(doc.get('chi')) || doc.get('chi') || '',
      azione: doc.get('azione') || '',
      dettagli: doc.get('dettagli') || {},
      il: ms(doc.get('il')),
    })),
  };
}

// ---------------------------------------------------------------------------
// La porta
// ---------------------------------------------------------------------------

/** Quello che legge: non cambia niente, e non lascia traccia. */
const LETTURE = {
  bolli,
  panoramica: (_dati, request) => panoramica(request),
  proposte,
  provaLancio,
  esempi,
  batteria,
  valutaGara,
  speseAI,
  contiStripe,
  spese: tutteLeSpese,
  gare,
  gara,
  foto,
  persone,
  persona,
  blocchi,
  saldiConti,
  impostazioni: leggiImpostazioni,
  registro,
};

/** Quello che scrive: riceve anche chi lo sta facendo. */
const SCRITTURE = {
  aggiungiSpesaFissa,
  togliSpesaFissa,
  decidiProposta,
  togliGara,
  chiudiGara,
  togliFoto,
  sospendi,
  eliminaAccount,
  segnaBlocco,
  scriviImpostazioni,
  insegna,
  dimentica,
};

const adminPannello = onCall(
  {
    secrets: [
      giudice.OPENAI_API_KEY,
      payments.STRIPE_SECRET_KEY,
      payments.STRIPE_PAYOUT_KEY,
      posta.SMTP_PASSWORD,
      posta.RESEND_API_KEY,
    ],
    // Le chiamate di una pagina arrivano insieme, e stanno sulla stessa accensione.
    memory: '512MiB',
    timeoutSeconds: 120,
  },
  async (request) => {
    const chi = soloAdmin(request);
    const { azione, ...dati } = request.data || {};

    if (Object.prototype.hasOwnProperty.call(LETTURE, azione)) {
      return LETTURE[azione](dati, request);
    }

    if (Object.prototype.hasOwnProperty.call(SCRITTURE, azione)) {
      logger.info('azione dal pannello', { azione, chi });

      return SCRITTURE[azione](dati, chi);
    }

    throw new HttpsError('invalid-argument', `Azione sconosciuta: ${String(azione)}`);
  }
);

// Per le prove: la porta si puo' provare senza accendere Firebase.
module.exports = { adminPannello, LETTURE, SCRITTURE, soloAdmin };
