'use strict';

/**
 * **Le missioni nascono qui, e solo qui.**
 *
 * Fino a ieri una missione la scriveva il telefono direttamente sul database, e
 * il controllo vero stava nell'app: chi la modificava, o scriveva sul database da
 * se', mandava davanti a tutti quello che voleva. Le regole di Firestore leggono
 * solo il testo in chiaro, quindi `4MM4ZZ4T1` passava.
 *
 * Adesso le regole non lasciano creare nessuna missione a nessun telefono. L'app
 * manda la richiesta qui, e il testo fa tre passi:
 *
 * 1. **Parola per parola** (`parole.js`). Una parola rossa ferma tutto, subito.
 * 2. **L'intelligenza artificiale** (`giudice.js`). Da' un voto da 0 a 100.
 * 3. **La strada** (`stradaDi`): da 90 esce da sola, da 80 a 89 chiede una
 *    conferma dal pannello, sotto la guarda una persona.
 *
 * ## Prima si controlla, poi si paga
 *
 * Una missione ferma in controllo **non e' ancora una missione**: sta in
 * `missioniProposte`, e nessuno ha tirato fuori un euro. Se viene rifiutata non c'e'
 * niente da rimborsare e nessuna spesa da perdere; se viene approvata, chi l'ha
 * scritta riceve l'avviso e paga in quel momento. Cosi' CRASY non tiene soldi per
 * una cosa che magari non uscira' mai.
 *
 * ## La stessa missione si giudica una volta
 *
 * I voti restano in `giudizi/{impronta}`, e per due ragioni: non si paga due volte
 * lo stesso giudizio, e soprattutto **non si puo' riprovare finche' il voto non
 * esce alto**. Lo stesso testo prende lo stesso voto.
 *
 * Li' resta anche cosa ha deciso una persona: una missione gia' approvata esce
 * subito anche la prossima volta, e una gia' rifiutata non torna in coda.
 *
 * ## Dove stanno le cose
 *
 * `missioniProposte`, `giudizi`, `impostazioni`, `limiti`: nessun telefono le legge
 * e nessun telefono le scrive. Chi ha scritto una missione non deve poter leggere
 * il suo voto, o imparerebbe in fretta come scrivere la prossima.
 */

const crypto = require('node:crypto');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const { controlla, formaCanonica, CATEGORIE } = require('./parole');
const giudice = require('./giudice');
const { foglioDi } = require('./autori');

const PROPOSTE = 'missioniProposte';
const GIUDIZI = 'giudizi';
const IMPOSTAZIONI = 'impostazioni';
const LIMITI = 'limiti';
const SPESE = 'spese';

/** Quante missioni puo' proporre una persona in un giorno. Protegge dagli abusi e dal conto. */
const TETTO_A_PERSONA = 30;

/** Le soglie di partenza. Si cambiano dal pannello. */
const SOGLIE_DI_PARTENZA = { sogliaAuto: 90, sogliaConferma: 80 };

/** Quanti giudizi al giorno, in tutto: se qualcosa impazzisce, il conto resta piccolo. */
const TETTO_GIUDIZI = 500;

/** Le regole di forma: le stesse che stavano in `firestore.rules`. */
const AMBITI = ['global', 'country', 'local', 'friends', 'private'];
const PREMIO_MASSIMO_CENTS = 10000;
const PREMIO_MINIMO_CENTS = 100;
const MINUTI_MASSIMI = 24 * 60;
const POSTI_MASSIMI = 1000;
const DESTINATARI_MASSIMI = 300;

/** Un rifiuto fatto bene: un codice per l'app, una frase per chi legge. */
function rifiuta(codice, frase) {
  return new HttpsError(codice, frase);
}

/**
 * **La richiesta dell'app, ricontrollata campo per campo.**
 *
 * Arriva da un telefono, quindi non vale niente finche' non e' passata di qui. E'
 * quello che facevano le regole di Firestore quando la scrittura era del telefono:
 * adesso scrive il server, che quelle regole non le attraversa, e se non lo fa lui
 * non lo fa nessuno.
 */
function leggiLaRichiesta(dati) {
  const d = dati || {};
  const testo = (valore) => (typeof valore === 'string' ? valore.trim() : '');

  const title = testo(d.title);
  const brief = testo(d.brief);
  const scope = testo(d.scope) || 'global';
  const targetUserId = testo(d.targetUserId);
  const duelMessage = testo(d.duelMessage);
  const prizeCents = d.prizeCents;
  const minutes = d.minutes;
  const maxParticipants = d.maxParticipants === undefined ? 0 : d.maxParticipants;
  const mediaKind = testo(d.mediaKind) || 'photo';
  const source = testo(d.source) || 'instant';
  const anonimo = d.anonimo === true;

  if (title.length < 3 || title.length > 60) {
    throw rifiuta('invalid-argument', 'Il titolo va da 3 a 60 caratteri.');
  }

  if (brief.length < 1 || brief.length > 280) {
    throw rifiuta('invalid-argument', 'La consegna va da 1 a 280 caratteri.');
  }

  if (!AMBITI.includes(scope)) {
    throw rifiuta('invalid-argument', 'Chi la può vedere non è valido.');
  }

  if (!['photo', 'video'].includes(mediaKind) || !['instant', 'archive'].includes(source)) {
    throw rifiuta('invalid-argument', 'Il tipo di missione non è valido.');
  }

  if (!Number.isInteger(prizeCents) || prizeCents < 0 || prizeCents > PREMIO_MASSIMO_CENTS) {
    throw rifiuta('invalid-argument', 'Il premio massimo è 100 euro.');
  }

  // **Un euro di minimo, tranne fra amici.** Sotto un euro un premio non e' un premio;
  // fra amici zero si', perche' la sfida vale gia' per conto suo.
  if (prizeCents < PREMIO_MINIMO_CENTS && !(scope === 'friends' && prizeCents === 0)) {
    throw rifiuta('invalid-argument', 'Il premio minimo è 1 euro.');
  }

  if (!Number.isInteger(minutes) || minutes < 1 || minutes > MINUTI_MASSIMI) {
    throw rifiuta('invalid-argument', 'Una missione dura da 1 minuto a 24 ore.');
  }

  if (
    !Number.isInteger(maxParticipants) ||
    maxParticipants < 0 ||
    maxParticipants > POSTI_MASSIMI
  ) {
    throw rifiuta('invalid-argument', 'Il numero di posti non è valido.');
  }

  if (duelMessage.length > 140) {
    throw rifiuta('invalid-argument', 'Il messaggio arriva al massimo a 140 caratteri.');
  }

  // La riga per l'amico sta solo sulle sfide: su una gara aperta la leggerebbero tutti.
  if (duelMessage && !targetUserId) {
    throw rifiuta('invalid-argument', 'Il messaggio si può scrivere solo su una sfida.');
  }

  if (targetUserId && scope !== 'friends') {
    throw rifiuta('invalid-argument', 'Una sfida è sempre fra amici.');
  }

  return {
    title,
    brief,
    scope,
    prizeCents,
    minutes,
    maxParticipants: targetUserId ? 1 : maxParticipants,
    mediaKind,
    source,
    anonimo,
    targetUserId,
    duelMessage,
  };
}

/**
 * **L'impronta del testo**: lo stesso testo, la stessa impronta, anche con le
 * maiuscole e gli spazi diversi. Non basta cambiare una maiuscola per farsi
 * rigiudicare.
 */
function improntaDi({ title, brief, duelMessage }) {
  return crypto
    .createHash('sha256')
    .update(
      [title, brief, duelMessage || '']
        .map((testo) => formaCanonica(testo))
        .join('\n')
    )
    .digest('hex');
}

/**
 * **La gara, con gli stessi campi di sempre.**
 *
 * Se ne manca uno, quella gara sparisce dalle ricerche che filtrano su di lui senza
 * nessun errore: lo stesso corpo lo scrive il fondo in `salvadanaio.js`.
 *
 * In anonimo non partono ne' il nome ne' l'identificativo: chi l'ha lanciata si
 * scrive in `autoriAnonimi/{gara}`, che legge solo lui.
 */
function corpoDellaGara(proposta, { adesso, audience, username }) {
  const anonimo = proposta.anonimo === true;

  return {
    title: proposta.title,
    brief: proposta.brief,
    prizeCents: proposta.prizeCents,
    scope: proposta.scope,
    source: proposta.source,
    audience,
    maxParticipants: proposta.maxParticipants,
    place: '',
    rules: [],
    mediaKind: proposta.mediaKind,
    createdByUsername: anonimo ? '' : username,
    createdByUserId: anonimo ? '' : proposta.uid,
    anonimo,
    startsAt: adesso,
    endsAt: admin.firestore.Timestamp.fromMillis(
      adesso.toMillis() + proposta.minutes * 60 * 1000
    ),
    participantsCount: 0,
    winnerEntryId: null,
    targetUserId: proposta.targetUserId || '',
    targetUsername: proposta.targetUsername || '',
    duelMessage: proposta.duelMessage || '',
    duelStatus: 'pending',
    respondedAt: null,
    // Nasce sempre non pagata: a renderla viva e' il pagamento. Quelle gratis si
    // vedono da subito, vedi `isPayable` nell'app.
    prizeStatus: 'unpaid',
    // Lo spazzino cerca `purgedAt == null`, e un campo che non c'e' non corrisponde a
    // nessun confronto: senza questa riga le foto resterebbero in magazzino per sempre.
    purgedAt: null,
  };
}

/**
 * **Chi puo' vedere la missione**, deciso qui e non dal telefono. L'elenco degli
 * amici si legge al momento in cui la missione esce, non quando e' stata scritta:
 * fra le due cose possono passare delle ore.
 */
async function audienceDi(proposta) {
  const { uid, anonimo, targetUserId, scope } = proposta;

  if (targetUserId) {
    return anonimo ? [targetUserId] : [uid, targetUserId];
  }

  if (scope !== 'friends') {
    return ['*'];
  }

  const amici = await admin
    .firestore()
    .collection('users')
    .doc(uid)
    .collection('friends')
    .limit(DESTINATARI_MASSIMI - 1)
    .get();
  const elenco = amici.docs.map((doc) => doc.id);

  if (anonimo) {
    if (elenco.length === 0) {
      throw rifiuta('failed-precondition', 'Per lanciarla in anonimo serve almeno un amico.');
    }

    return elenco;
  }

  return [uid, ...elenco];
}

/**
 * **Scrive la gara.** L'identificativo e' quello della proposta: dal pannello si
 * passa dall'una all'altra senza cercare, e la stessa proposta non puo' generare due
 * gare.
 */
async function creaLaGara(id, proposta) {
  const db = admin.firestore();
  const profilo = await db.collection('users').doc(proposta.uid).get();
  const username = String(profilo.get('username') || '');
  const audience = await audienceDi(proposta);
  const gara = db.collection('challenges').doc(id);
  const scrittura = db.batch();

  scrittura.set(gara, {
    ...corpoDellaGara(proposta, {
      adesso: admin.firestore.Timestamp.now(),
      audience,
      username,
    }),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  if (proposta.anonimo === true) {
    scrittura.set(foglioDi(id), {
      uid: proposta.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  scrittura.update(db.collection(PROPOSTE).doc(id), { challengeId: id });

  await scrittura.commit();

  return id;
}

/**
 * **Le impostazioni del controllo**, che si cambiano dal pannello senza pubblicare
 * niente. Restano in memoria un minuto: si leggono a ogni missione proposta.
 */
let copiaImpostazioni = null;
let copiaImpostazioniDel = 0;

async function leggiImpostazioni() {
  if (copiaImpostazioni && Date.now() - copiaImpostazioniDel < 60 * 1000) {
    return copiaImpostazioni;
  }

  const foglio = await admin
    .firestore()
    .collection(IMPOSTAZIONI)
    .doc('moderazione')
    .get();
  const d = foglio.exists ? foglio.data() : {};

  copiaImpostazioni = {
    sogliaAuto: Number.isInteger(d.sogliaAuto) ? d.sogliaAuto : SOGLIE_DI_PARTENZA.sogliaAuto,
    sogliaConferma: Number.isInteger(d.sogliaConferma)
      ? d.sogliaConferma
      : SOGLIE_DI_PARTENZA.sogliaConferma,
    soloAMano: d.soloAMano === true,
    tettoGiudizi: Number.isInteger(d.tettoGiudizi) ? d.tettoGiudizi : TETTO_GIUDIZI,
    rosseAggiunte: Array.isArray(d.rosseAggiunte) ? d.rosseAggiunte : [],
    gialleAggiunte: Array.isArray(d.gialleAggiunte) ? d.gialleAggiunte : [],
    consentite: Array.isArray(d.consentite) ? d.consentite : [],
    // Quello che il team ha insegnato al modello dal banco di prova.
    esempi: Array.isArray(d.esempi) ? d.esempi : [],
  };
  copiaImpostazioniDel = Date.now();

  return copiaImpostazioni;
}

function dimenticaImpostazioni() {
  copiaImpostazioni = null;
}

/** Il giorno di oggi in Italia. */
function oggi() {
  return new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Rome' });
}

/**
 * **Aggiunge uno a un contatore del giorno** e dice se e' ancora dentro il tetto. In
 * una transazione: due richieste insieme non devono leggere lo stesso numero.
 */
async function dentroIlTetto(nome, tetto) {
  const db = admin.firestore();
  const ref = db.collection(LIMITI).doc(`${nome}_${oggi()}`);

  return db.runTransaction(async (t) => {
    const foglio = await t.get(ref);
    const quanti = foglio.exists ? foglio.get('quanti') || 0 : 0;

    if (quanti >= tetto) {
      return false;
    }

    t.set(ref, { quanti: quanti + 1, giorno: oggi() }, { merge: true });

    return true;
  });
}

/**
 * **Quanto si spende per il modello, giorno per giorno.** Un foglio al giorno in
 * `spese`, che il pannello somma. Se la scrittura va storta il giudizio vale lo stesso:
 * una missione non deve fermarsi per un numero di contabilita'.
 *
 * Si conta anche quando un voto si riusa, ed e' il numero che dice quanto si risparmia.
 */
async function segnaLaSpesa(giudizio, { prova = false } = {}) {
  const { increment } = admin.firestore.FieldValue;
  const giorno = oggi();
  const gettoni = giudizio.gettoni;
  const riga = gettoni
    ? {
        giudizi: increment(1),
        entrata: increment(gettoni.entrata || 0),
        inMemoria: increment(gettoni.inMemoria || 0),
        uscita: increment(gettoni.uscita || 0),
        dollari: increment(giudice.costoInDollari(gettoni)),
        modello: giudizio.modello || giudice.MODELLO,
        ...(prova ? { prove: increment(1) } : {}),
      }
    : { riusati: increment(1) };

  try {
    await admin
      .firestore()
      .collection(SPESE)
      .doc(giorno)
      .set({ ...riga, giorno }, { merge: true });
  } catch (errore) {
    logger.warn('spesa del modello non segnata', { errore: String(errore).slice(0, 200) });
  }
}

/**
 * Il voto: quello gia' dato a questo stesso testo, se c'e', altrimenti si chiede.
 *
 * Non si conserva un voto se qualcosa e' andato storto: la prossima volta si deve
 * poter riprovare, e il guasto non deve restare appiccicato a quel testo.
 */
async function votoDi(impronta, testi, impostazioni) {
  const db = admin.firestore();
  const ref = db.collection(GIUDIZI).doc(impronta);
  const gia = await ref.get();

  if (
    gia.exists &&
    Number.isInteger(gia.get('punteggio')) &&
    gia.get('versione') === giudice.versioneDelleIstruzioni(impostazioni.esempi)
  ) {
    await segnaLaSpesa({});

    return {
      esito: 'fatto',
      punteggio: gia.get('punteggio'),
      categoria: gia.get('categoria') || 'altro',
      motivo: gia.get('motivo') || '',
      modello: gia.get('modello') || '',
      gia: true,
    };
  }

  if (!(await dentroIlTetto('giudizi', impostazioni.tettoGiudizi))) {
    logger.warn('tetto dei giudizi di oggi raggiunto: le missioni vanno da una persona');

    return { esito: 'tetto' };
  }

  const giudizio = await giudice.giudica(testi, { esempi: impostazioni.esempi });

  if (giudizio.esito === 'fatto') {
    await segnaLaSpesa(giudizio);
    await ref.set(
      {
        punteggio: giudizio.punteggio,
        categoria: giudizio.categoria,
        motivo: giudizio.motivo,
        modello: giudizio.modello,
        versione: giudice.versioneDelleIstruzioni(impostazioni.esempi),
        il: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }

  return giudizio;
}

/**
 * **Il testo passa dal filtro e dal modello**, e torna cosa ne pensano. Non scrive
 * niente: lo usa anche il tasto "Prova il filtro" del pannello.
 */
async function valuta({ title, brief, duelMessage }, impostazioni) {
  const testi = [title, brief, duelMessage || ''];
  const impronta = improntaDi({ title, brief, duelMessage });
  const filtro = controlla(testi, impostazioni);

  if (filtro.rossa) {
    return { impronta, filtro, giudizio: null, voto: null, strada: 'bloccata' };
  }

  const giudizio = await votoDi(
    impronta,
    { titolo: title, consegna: brief, messaggio: duelMessage },
    impostazioni
  );
  const { voto, strada } = giudice.stradaDi({
    giudizio,
    gialle: filtro.gialle,
    soglie: impostazioni,
    soloAMano: impostazioni.soloAMano,
  });

  return { impronta, filtro, giudizio, voto, strada };
}

/**
 * **Una missione per finta, per il banco di prova.** Stessi controlli di una vera, ma
 * non si scrive niente: niente gara, niente proposta, niente avvisi. E il voto si chiede
 * sempre da capo senza finire nella memoria, cosi' si vede cosa dice il modello adesso e
 * le missioni vere non ereditano niente da una prova. Si paga, quindi si segna.
 */
async function valutaPerProva({ title, brief, duelMessage }, impostazioni) {
  const testi = [title, brief, duelMessage || ''];
  const impronta = improntaDi({ title, brief, duelMessage });
  const precedente = await admin.firestore().collection(GIUDIZI).doc(impronta).get();
  const decisione = precedente.exists ? precedente.get('decisione') : null;
  const filtro = controlla(testi, impostazioni);
  const base = {
    filtro,
    precedente: decisione || null,
    motivoPrecedente: decisione ? String(precedente.get('motivoDecisione') || '') : '',
  };

  if (filtro.rossa) {
    return { ...base, giudizio: null, voto: null, strada: 'bloccata', costo: 0 };
  }

  const giudizio = await giudice.giudica(
    { titolo: title, consegna: brief, messaggio: duelMessage },
    { esempi: impostazioni.esempi }
  );

  if (giudizio.esito === 'fatto') {
    await segnaLaSpesa(giudizio, { prova: true });
  }

  const { voto, strada } = giudice.stradaDi({
    giudizio,
    gialle: filtro.gialle,
    soglie: impostazioni,
    soloAMano: impostazioni.soloAMano,
  });

  return {
    ...base,
    giudizio,
    voto,
    strada,
    costo: giudizio.gettoni ? giudice.costoInDollari(giudizio.gettoni) : 0,
  };
}

/** Il giudizio come si conserva sulla proposta, e come lo legge il pannello. */
function giudizioDaSalvare(giudizio) {
  if (!giudizio) {
    return null;
  }

  return {
    esito: giudizio.esito,
    punteggio: Number.isInteger(giudizio.punteggio) ? giudizio.punteggio : null,
    categoria: giudizio.categoria || '',
    motivo: giudizio.motivo || '',
    modello: giudizio.modello || '',
    perche: giudizio.perche || '',
    ms: giudizio.ms || 0,
    gettoni: giudizio.gettoni || null,
    gia: giudizio.gia === true,
  };
}

/**
 * **Propone una missione a nome di [uid].** E' tutto il percorso, e torna una di
 * queste:
 *
 * - `{ stato: 'inGara', challengeId }`: e' uscita. Se c'e' un premio, si paga;
 * - `{ stato: 'inControllo', propostaId }`: la guarda una persona. Non si paga niente;
 * - `{ stato: 'daPagare', propostaId }`: una persona l'aveva gia' approvata;
 * - `{ stato: 'bloccata', messaggio }`: non puo' uscire, e il messaggio dice perche'.
 */
async function proponi(uid, richiesta) {
  const db = admin.firestore();
  const proposte = db.collection(PROPOSTE);
  const impostazioni = await leggiImpostazioni();

  // **Lo sfidato dev'esistere, e non aver bloccato chi lo sfida.** Il blocco non si
  // scavalca con una sfida: tanto meno con una anonima, dove chi la riceve non saprebbe
  // nemmeno da chi si sta difendendo.
  let targetUsername = '';

  if (richiesta.targetUserId) {
    if (richiesta.targetUserId === uid) {
      throw rifiuta('invalid-argument', 'Scegli un amico da sfidare.');
    }

    const sfidato = await db.collection('users').doc(richiesta.targetUserId).get();

    if (!sfidato.exists) {
      throw rifiuta('not-found', 'Questa persona non c’è più.');
    }

    const bloccato = await sfidato.ref.collection('blocked').doc(uid).get();

    if (bloccato.exists) {
      throw rifiuta('permission-denied', 'Non puoi sfidare questa persona.');
    }

    targetUsername = String(sfidato.get('username') || '');
  }

  const profilo = await db.collection('users').doc(uid).get();
  const username = String(profilo.get('username') || '');
  const impronta = improntaDi(richiesta);

  const base = {
    ...richiesta,
    targetUsername,
    uid,
    username,
    impronta,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    challengeId: null,
  };

  // **La stessa missione gia' in coda non ci va due volte.** Chi non vede arrivare la
  // risposta riprova: non deve ritrovarsi la coda piena di copie.
  const uguali = await proposte
    .where('uid', '==', uid)
    .where('impronta', '==', impronta)
    .limit(10)
    .get();

  for (const doc of uguali.docs) {
    const stato = doc.get('stato');

    if (stato === 'daControllare' || stato === 'daConfermare') {
      return { stato: 'inControllo', propostaId: doc.id };
    }

    if (stato === 'approvata' && !doc.get('challengeId') && doc.get('prizeCents') > 0) {
      return { stato: 'daPagare', propostaId: doc.id };
    }
  }

  // **Cosa ha gia' deciso una persona su questo stesso testo** vale piu' di tutto.
  const precedente = await db.collection(GIUDIZI).doc(impronta).get();
  const giaDeciso = precedente.exists ? precedente.get('decisione') : null;

  if (giaDeciso === 'rifiutata') {
    const motivo = String(precedente.get('motivoDecisione') || '');

    await proposte.add({
      ...base,
      stato: 'rifiutata',
      fonte: 'precedente',
      motivoDecisione: motivo,
      filtro: { rossa: null, gialle: [] },
      giudizio: null,
      voto: null,
    });

    return {
      stato: 'bloccata',
      messaggio:
        'Abbiamo già controllato questa missione e non può uscire' +
        (motivo ? `: ${motivo}` : '.'),
    };
  }

  if (giaDeciso === 'approvata') {
    const ref = proposte.doc();

    await ref.set({
      ...base,
      stato: 'approvata',
      fonte: 'precedente',
      filtro: { rossa: null, gialle: [] },
      giudizio: null,
      voto: null,
    });
    await creaLaGara(ref.id, { ...base });

    return { stato: 'inGara', challengeId: ref.id };
  }

  const { filtro, giudizio, voto, strada } = await valuta(richiesta, impostazioni);

  // **Fermata dalle parole.** Non nasce niente, ma il tentativo resta nel pannello:
  // chi ci prova tre volte di fila e' un'informazione, e un falso allarme si riapre.
  if (strada === 'bloccata') {
    const ref = proposte.doc();

    await ref.set({
      ...base,
      stato: 'bloccata',
      fonte: 'filtro',
      filtro,
      giudizio: null,
      voto: null,
    });

    logger.warn('missione fermata dalle parole', {
      propostaId: ref.id,
      uid,
      categoria: filtro.rossa.categoria,
    });

    return {
      stato: 'bloccata',
      categoria: filtro.rossa.categoria,
      messaggio: filtro.rossa.messaggio,
    };
  }

  const ref = proposte.doc();
  const dati = {
    ...base,
    filtro,
    giudizio: giudizioDaSalvare(giudizio),
    voto,
  };

  if (strada === 'inGara') {
    await ref.set({ ...dati, stato: 'approvata', fonte: 'ai' });
    await creaLaGara(ref.id, base);

    logger.info('missione uscita da sola', { propostaId: ref.id, voto });

    return { stato: 'inGara', challengeId: ref.id };
  }

  // La coda. L'avviso a chi modera parte da `avvisaDellaProposta`, alla nascita di
  // questo documento.
  await ref.set({ ...dati, stato: strada, fonte: 'in-attesa' });

  logger.info('missione in controllo', { propostaId: ref.id, voto, strada });

  return { stato: 'inControllo', propostaId: ref.id };
}

/** Avvisa chi ha scritto la missione. La push la manda `sendPushOnNotification`. */
async function avvisa(proposta, id, tipo, altro) {
  await admin
    .firestore()
    .collection('users')
    .doc(proposta.uid)
    .collection('notifications')
    .doc(`${tipo}_${id}`)
    .set({
      kind: tipo,
      actorId: '',
      actorUsername: '',
      challengeId: altro.challengeId || '',
      challengeTitle: proposta.title,
      propostaId: id,
      motivo: altro.motivo || '',
      premioCents: proposta.prizeCents || 0,
      dalServer: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}

/**
 * **Una persona ha deciso.**
 *
 * - Approvata e gratis: esce subito.
 * - Approvata con un premio: chi l'ha scritta riceve l'avviso, e paga quando vuole.
 * - Rifiutata: chi l'ha scritta legge il motivo. Non ha pagato niente.
 *
 * **Tutte le proposte con lo stesso testo si chiudono insieme**: dieci persone che
 * scelgono la stessa missione gia' pronta sono lo stesso caso, non dieci. E la
 * decisione resta sull'impronta, cosi' la prossima volta non torna in coda.
 */
async function decidi(id, { decisione, motivo = '', chi }) {
  const db = admin.firestore();
  const ref = db.collection(PROPOSTE).doc(id);
  const foglio = await ref.get();

  if (!foglio.exists) {
    throw rifiuta('not-found', 'Questa proposta non c’è più.');
  }

  const scelta = decisione === 'approva' ? 'approvata' : decisione === 'rifiuta' ? 'rifiutata' : '';

  if (!scelta) {
    throw rifiuta('invalid-argument', 'Decisione non valida.');
  }

  const impronta = foglio.get('impronta');
  const inCoda = await db
    .collection(PROPOSTE)
    .where('impronta', '==', impronta)
    .where('stato', 'in', ['daControllare', 'daConfermare', 'bloccata'])
    .limit(50)
    .get();

  const daChiudere = new Map(inCoda.docs.map((doc) => [doc.id, doc]));

  // Una decisione si puo' anche cambiare: quella che si guarda c'e' sempre, anche se
  // non era piu' in coda.
  daChiudere.set(id, foglio);

  await db
    .collection(GIUDIZI)
    .doc(impronta)
    .set(
      {
        decisione: scelta,
        motivoDecisione: motivo,
        decisaDa: chi,
        decisaIl: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  const esiti = [];

  for (const [propostaId, doc] of daChiudere) {
    const proposta = doc.data();

    // Gia' uscita o gia' pagata: non si tocca da qui. Per togliere una missione in
    // gara c'e' il suo tasto, che restituisce il premio.
    if (proposta.challengeId) {
      esiti.push({ propostaId, saltata: 'già in gara' });
      continue;
    }

    await doc.ref.update({
      stato: scelta,
      fonte: 'admin',
      motivoDecisione: motivo,
      decisaDa: chi,
      decisaIl: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (scelta === 'rifiutata') {
      // Chi si e' visto fermare dalle parole lo ha gia' letto nel modulo, quando e'
      // successo: un secondo avviso sarebbe solo rumore.
      if (proposta.stato !== 'bloccata') {
        await avvisa(proposta, propostaId, 'missionRejected', { motivo });
      }

      esiti.push({ propostaId, stato: scelta });
      continue;
    }

    if (proposta.prizeCents > 0) {
      await avvisa(proposta, propostaId, 'missionApproved', {});
      esiti.push({ propostaId, stato: scelta, daPagare: true });
      continue;
    }

    try {
      await creaLaGara(propostaId, proposta);
      await avvisa(proposta, propostaId, 'missionApproved', { challengeId: propostaId });
      esiti.push({ propostaId, stato: scelta, challengeId: propostaId });
    } catch (errore) {
      logger.error('missione approvata ma non creata', { propostaId, errore });
      esiti.push({ propostaId, stato: scelta, errore: errore.message || 'errore' });
    }
  }

  logger.info('proposta decisa', { id, scelta, insieme: esiti.length, chi });

  return { stato: scelta, esiti };
}

/**
 * **Chi ha una missione approvata la lancia, e paga.**
 *
 * La gara nasce adesso e non al momento dell'approvazione: fra le due cose possono
 * passare dei giorni, e una gara scritta prima sarebbe gia' scaduta quando arriva il
 * pagamento. Se aveva gia' provato e aveva lasciato perdere, riparte da capo.
 */
async function lanciaApprovata(uid, id) {
  const db = admin.firestore();
  const ref = db.collection(PROPOSTE).doc(id);
  const foglio = await ref.get();

  if (!foglio.exists || foglio.get('uid') !== uid) {
    throw rifiuta('not-found', 'Questa missione non c’è più.');
  }

  if (foglio.get('stato') !== 'approvata') {
    throw rifiuta('failed-precondition', 'Questa missione non è approvata.');
  }

  const gara = db.collection('challenges').doc(id);
  const esiste = await gara.get();

  if (esiste.exists) {
    const pagamento = esiste.get('prizeStatus');
    const fine = esiste.get('endsAt');

    if (pagamento === 'held' || pagamento === 'paidOut') {
      return { challengeId: id, giaPagata: true };
    }

    if (fine && fine.toMillis() > Date.now() && esiste.get('winnerEntryId') === null) {
      return { challengeId: id };
    }

    // Scaduta prima che venisse pagata: non l'ha vista nessuno, si riscrive.
    await gara.delete();
  }

  await creaLaGara(id, foglio.data());

  return { challengeId: id };
}

/** Per l'app: cosa puo' sapere chi l'ha scritta. Il voto no, e nemmeno le parole. */
function comeLaVedeChiLHaScritta(id, d) {
  return {
    propostaId: id,
    stato: d.stato,
    title: d.title,
    brief: d.brief,
    prizeCents: d.prizeCents,
    scope: d.scope,
    challengeId: d.challengeId || null,
    motivo: d.stato === 'rifiutata' ? d.motivoDecisione || '' : '',
  };
}

function chiChiama(request) {
  const uid = request.auth && request.auth.uid;

  if (!uid) {
    throw rifiuta('unauthenticated', 'Serve un account.');
  }

  return uid;
}

/** Quello che l'app chiama per lanciare una missione. Vedi [proponi]. */
const proponiMissione = onCall(
  {
    secrets: [giudice.OPENAI_API_KEY],
    memory: '512MiB',
    // Il tempo del modello, piu' margine. Oltre, il modello e' gia' un guasto.
    timeoutSeconds: 70,
  },
  async (request) => {
    const uid = chiChiama(request);
    const richiesta = leggiLaRichiesta(request.data);

    if (
      request.auth.token.admin !== true &&
      !(await dentroIlTetto(`persona_${uid}`, TETTO_A_PERSONA))
    ) {
      throw rifiuta(
        'resource-exhausted',
        'Hai proposto troppe missioni per oggi. Riprova domani.'
      );
    }

    return proponi(uid, richiesta);
  }
);

/** Per la pagina "La tua missione è approvata". */
const leggiLaMiaProposta = onCall(async (request) => {
  const uid = chiChiama(request);
  const id = String((request.data && request.data.propostaId) || '');

  if (!id) {
    throw rifiuta('invalid-argument', 'Manca la missione.');
  }

  const foglio = await admin.firestore().collection(PROPOSTE).doc(id).get();

  if (!foglio.exists || foglio.get('uid') !== uid) {
    throw rifiuta('not-found', 'Questa missione non c’è più.');
  }

  return comeLaVedeChiLHaScritta(id, foglio.data());
});

/** Crea la gara di una missione approvata, per poterla pagare. */
const lanciaMissioneApprovata = onCall(async (request) => {
  const uid = chiChiama(request);
  const id = String((request.data && request.data.propostaId) || '');

  if (!id) {
    throw rifiuta('invalid-argument', 'Manca la missione.');
  }

  return lanciaApprovata(uid, id);
});

/**
 * **Quanto si tengono le proposte: sei mesi.** Servono a capire chi ci prova e a
 * rispondere a chi chiede spiegazioni; oltre, sono testi di persone che non servono
 * piu' a nessuno. I contatori dei giorni vecchi se ne vanno con loro.
 */
const pulisciLeProposte = onSchedule(
  { schedule: 'every 24 hours', timeZone: 'Europe/Rome' },
  async () => {
    const db = admin.firestore();
    const soglia = admin.firestore.Timestamp.fromMillis(
      Date.now() - 180 * 24 * 60 * 60 * 1000
    );
    const vecchie = await db
      .collection(PROPOSTE)
      .where('createdAt', '<', soglia)
      .limit(300)
      .get();
    const scrittura = db.batch();

    for (const doc of vecchie.docs) {
      scrittura.delete(doc.ref);
    }

    const ieri = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toLocaleDateString('sv-SE', {
      timeZone: 'Europe/Rome',
    });
    const contatori = await db
      .collection(LIMITI)
      .where('giorno', '<', ieri)
      .limit(200)
      .get();

    for (const doc of contatori.docs) {
      scrittura.delete(doc.ref);
    }

    await scrittura.commit();

    logger.info('pulizia delle proposte', {
      proposte: vecchie.size,
      contatori: contatori.size,
    });
  }
);

module.exports = {
  CATEGORIE,
  GIUDIZI,
  IMPOSTAZIONI,
  LIMITI,
  PROPOSTE,
  SOGLIE_DI_PARTENZA,
  SPESE,
  TETTO_GIUDIZI,
  corpoDellaGara,
  decidi,
  dimenticaImpostazioni,
  improntaDi,
  leggiImpostazioni,
  leggiLaMiaProposta,
  leggiLaRichiesta,
  lanciaMissioneApprovata,
  proponiMissione,
  pulisciLeProposte,
  valuta,
  valutaPerProva,
};
