'use strict';

/**
 * **Il fondo delle missioni automatiche: missioni vere, pagate da CRASY, che
 * partono da sole finche' i soldi durano.**
 *
 * ## A cosa serve, e per quanto
 *
 * All'inizio su CRASY non lancia nessuno. Non per cattiveria: partecipare e'
 * **reagire** — l'idea l'ha messa un altro — mentre lanciare e' **inventare**,
 * e per di piu' si paga. Un'app che il primo giorno e' vuota non da' a nessuno
 * il motivo per riempirla.
 *
 * Qui CRASY mette dei soldi da parte e il server lancia qualche missione al
 * giorno, finche' quei soldi non finiscono. Poi smette da solo.
 *
 * **E' una spinta per far partire il motore, non una funzione dell'app.** Se
 * resta accesa per sempre, nessuno ha piu' motivo di lanciare: c'e' gia' tutto
 * da fare, gratis. Per questo il fondo non si ricarica da solo: quando finisce,
 * finisce, ed e' una decisione presa adesso invece che rimandata.
 *
 * ## Un portafoglio solo
 *
 * Prima c'era un fondo per ogni persona che lo pagava, caricato a mano con
 * uno strumento. Adesso il fondo e' **uno**, `salvadanai/crasy`, e si ricarica
 * dalla pagina di amministrazione con la carta: la pagina di Stripe, la sua
 * ricevuta, e il webhook che scrive nel fondo **quello che e' arrivato
 * davvero**, cioe' tolte le commissioni (vedi `registraRicarica`).
 *
 * Una missione andata a vuoto — nessuno ha partecipato, o nessuna foto valida
 * — rimette il premio **qui**, non sulla carta: lo fa `refundChallenge` in
 * `payments.js`, che riconosce le gare del fondo da `pagataDalFondo`.
 *
 * ## Facce vere, premio dichiarato
 *
 * Le missioni escono **a turno a nome di alcune persone** (`autori`): chi apre
 * l'app vede facce, tocca il nome e arriva al profilo, come in tutte le altre
 * gare. Ma **il premio lo paga CRASY, e la gara lo dice**: porta
 * `pagataDalFondo`, e l'app scrive accanto al nome "premio di CRASY". Fino al
 * 23 ottobre uscivano firmate @crasy proprio per non far passare un premio
 * nostro per il premio di un utente: la faccia torna, la trasparenza resta.
 *
 * Per lo stesso motivo:
 *
 * - **non contano nella classifica di chi fa giocare**: quella e' per chi mette
 *   soldi suoi, e questi non lo sono;
 * - **chi la firma non ci partecipa**, come in tutte le gare a premio (vedi
 *   `lanciataDa` in `firestore.rules`). Tutti gli altri si', anche chi presta
 *   la faccia alle altre: per un giorno c'era un elenco di esclusi, ma teneva
 *   fuori proprio chi stava provando le missioni, ed e' stato tolto.
 *
 * ## Dove si accende
 *
 * In `salvadanai/crasy`, che nessun telefono puo' nemmeno aprire:
 *
 * - `acceso` — false ferma tutto all'istante;
 * - `fondoCents` — quanto resta da spendere. Scende a ogni missione;
 * - `alGiorno` — quante missioni al giorno, da una a cinque;
 * - `premioCents` — il premio di una missione che non ne dice uno suo;
 * - `oreDiGara`, `maxPartecipanti` — come sono fatte le gare;
 * - `dal`, `fino` — il primo e l'ultimo giorno in cui si lancia;
 * - `autori` — chi presta la faccia, a turno: `[{ uid, username }]`.
 *
 * Si toccano dalla pagina di amministrazione (`admin.js`), mai da un telefono.
 */

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

const pagamenti = require('./payments');
const posta = require('./posta');
const calendario = require('./calendario_del_fondo');

const db = admin.firestore();

/**
 * **Le missioni, in ordine.** Stanno in `dati/missioni_automatiche.json`:
 * `titolo`, `consegna`, `media` (`photo` o `video`), `fonte` (`instant` o
 * `archive`) e `euro`, il premio. Si gira in tondo: finite tutte, si
 * ricomincia dalla prima.
 *
 * Fuori dal codice perche' e' la parte che cambia di piu', e chi la cambia
 * deve poterla leggere come un elenco, non come un programma.
 */
const MISSIONI = require('./dati/missioni_automatiche.json');

/** Il fondo, e anche il nome con cui scrive nel registro. */
const CENTRALE = 'crasy';

/** Dove arrivano gli avvisi del fondo: e' un fatto del team, non di una persona. */
const CASELLA_DEL_TEAM = 'info@crasyapp.com';

/** Come nasce il fondo la prima volta che ci entrano dei soldi: spento. */
const INIZIALE = {
  acceso: false,
  spentoPerche: 'nuovo',
  fondoCents: 0,
  spesiCents: 0,
  ricaricatiCents: 0,
  // Tre: mattina, pomeriggio e sera (vedi `ORARI` in `calendario_del_fondo.js`).
  alGiorno: 3,
  premioCents: 100,
  oreDiGara: 24,
  maxPartecipanti: 10,
  dal: '',
  fino: '',
  autori: [],
};

/** Una ricarica va da cinque a cinquecento euro. */
const RICARICA_MINIMA = 500;
const RICARICA_MASSIMA = 50000;

/** Da dove si puo' aprire la pagina di pagamento, e dove si torna. */
const SITI = [
  'https://crasyapp.com',
  'https://www.crasyapp.com',
  'https://crasy.web.app',
  'https://crasy.firebaseapp.com',
];

function fondoRef() {
  return db.collection('salvadanai').doc(CENTRALE);
}

/**
 * Scrive la gara, con **lo stesso corpo** che scriverebbe l'app.
 *
 * I campi sono quelli di `ChallengeMapper.toCreateMap`: se qui ne mancasse
 * uno, quella gara sparirebbe dalle query che filtrano su di lui — e il modo
 * in cui se ne accorgerebbe qualcuno e' che la missione non compare da nessuna
 * parte, senza nessun errore.
 *
 * Nasce **non pagata**, come tutte: a renderla viva e' il pagamento, un
 * istante dopo. Se quello fallisce resta li' spenta e non la vede nessuno.
 */
async function scriviLaGara(autore, missione, fondo, premio) {
  const adesso = admin.firestore.Timestamp.now();
  const ore = fondo.oreDiGara || 24;

  return db.collection('challenges').add({
    title: missione.titolo,
    brief: missione.consegna,
    prizeCents: premio,
    scope: 'global',
    source: missione.fonte === 'archive' ? 'archive' : 'instant',
    // **L'asterisco, non la parola.** La home chiede `audience` che contiene
    // `'*'` — vedi `Challenge.everyone` nell'app. Scrivendoci `'everyone'` la
    // gara nasce giusta in tutto il resto e **non compare da nessuna parte**.
    audience: ['*'],
    // **Dieci posti, salvo diverso.** Con dieci foto si guardano tutte e il
    // voto vale qualcosa; senza tetto, chi arriva ultimo sa gia' di non
    // vincere e non manda niente.
    maxParticipants: fondo.maxPartecipanti || 10,
    place: '',
    rules: [],
    mediaKind: missione.media === 'video' ? 'video' : 'photo',
    createdByUsername: autore.username,
    createdByUserId: autore.uid,
    // **Il segno che il premio e' nostro**, in chiaro sulla gara: l'app lo
    // legge per scrivere "premio di CRASY" accanto al nome.
    pagataDalFondo: true,
    startsAt: adesso,
    endsAt: admin.firestore.Timestamp.fromMillis(adesso.toMillis() + ore * 3600000),
    participantsCount: 0,
    winnerEntryId: null,
    // **Esplicitamente non ripulita.** La pulizia cerca `purgedAt == null`, e
    // un campo che non c'e' non corrisponde a nessun confronto.
    purgedAt: null,
    targetUserId: '',
    targetUsername: '',
    duelMessage: '',
    duelStatus: 'pending',
    respondedAt: null,
    prizeStatus: 'unpaid',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * **A chi tocca.** Si parte dal turno e si salta chi non c'e' piu': un account
 * cancellato o sospeso non deve lanciare missioni, e nemmeno bloccare la fila.
 * Torna anche di quanti passi si e' andati avanti, perche' il turno scorra
 * oltre chi e' stato saltato.
 */
async function chiLancia(fondo) {
  const autori = fondo.autori || [];

  for (let passo = 0; passo < autori.length; passo += 1) {
    const candidato = calendario.autoreAl(fondo, passo);
    const profilo = await db.collection('users').doc(candidato.uid).get();

    if (!profilo.exists) {
      logger.warn('faccia del fondo senza profilo, saltata', { uid: candidato.uid });
      continue;
    }

    try {
      const account = await admin.auth().getUser(candidato.uid);

      if (account.disabled) {
        logger.warn('faccia del fondo sospesa, saltata', { uid: candidato.uid });
        continue;
      }
    } catch (errore) {
      logger.warn('faccia del fondo senza account, saltata', { uid: candidato.uid });
      continue;
    }

    return {
      uid: candidato.uid,
      // Il nome di adesso, non quello di quando e' entrato in fila.
      username: profilo.get('username') || candidato.username,
      passi: passo + 1,
    };
  }

  return null;
}

/**
 * **Scala il premio dal fondo e accende la gara**, tutto in una transazione:
 * o scende il fondo e la gara diventa viva, o non succede niente.
 */
async function pagaDalFondo(gara, premio, passi) {
  const oggi = calendario.oggiInItalia();

  const esito = await db.runTransaction(async (transaction) => {
    const fresco = await transaction.get(fondoRef());
    const dati = fresco.data() || {};
    const fondo = dati.fondoCents || 0;

    // Si rilegge qui dentro: fra il controllo di prima e adesso puo' essere
    // passato un lancio a mano dalla pagina di amministrazione.
    if (fondo < premio) {
      return { ok: false, reason: 'fondo-finito' };
    }

    const adesso = admin.firestore.Timestamp.now();

    transaction.update(gara, {
      prizeStatus: 'held',
      paidAt: adesso,
      pagataDalFondo: true,
      startsAt: adesso,
      endsAt: admin.firestore.Timestamp.fromMillis(
        adesso.toMillis() + (dati.oreDiGara || 24) * 3600000
      ),
    });

    transaction.update(fondoRef(), {
      fondoCents: admin.firestore.FieldValue.increment(-premio),
      spesiCents: admin.firestore.FieldValue.increment(premio),
      giorno: oggi,
      fatte: (dati.giorno === oggi ? dati.fatte || 0 : 0) + 1,
      lanciate: (dati.lanciate || 0) + 1,
      turno: (dati.turno || 0) + passi,
      ultima: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { ok: true, restano: fondo - premio };
  });

  if (esito.ok) {
    await pagamenti.scriviNelRegistro(CENTRALE, `pagamento_${gara.id}`, {
      kind: 'challengePayment',
      amountCents: -premio,
      challengeId: gara.id,
      challengeTitle: (await gara.get()).get('title') || '',
      source: 'fondo',
      note: 'Premio messo in palio dal fondo delle missioni automatiche',
    });
  }

  return esito;
}

/**
 * **Avvisa il team che il fondo sta finendo**, o che e' finito.
 *
 * A tre missioni dalla fine, non all'ultima: serve il tempo di decidere se
 * ricaricare, non un necrologio. Una volta sola per ricarica (`avvisato`).
 */
async function avvisa(restano, finito) {
  const quanti = (restano / 100).toFixed(2).replace('.', ',');

  try {
    await posta.spedisci({
      from: '"CRASY" <' + posta.CASELLA + '>',
      to: CASELLA_DEL_TEAM,
      subject: finito
        ? 'Il fondo delle missioni è finito — CRASY'
        : 'Il fondo delle missioni sta finendo — CRASY',
      text: finito
        ? 'Il fondo e finito e le missioni automatiche si sono fermate. Le gare gia aperte restano aperte.'
        : 'Nel fondo restano ' + quanti + ' euro. Si ricarica dalla pagina Automatiche del pannello.',
      html: posta.vestito({
        titolo: finito ? 'IL FONDO È FINITO' : 'IL FONDO STA FINENDO',
        testo: finito
          ? 'Le missioni automatiche si sono fermate. Le gare già aperte restano aperte e si chiudono da sole.'
          : 'Nel fondo restano ' + quanti + ' €. Quando finiscono si ferma da solo.',
        tasto: 'APRI IL PANNELLO',
        link: 'https://crasyapp.com/admin/#/automatiche',
        nota: 'Questa email arriva a chi gestisce CRASY.',
        a: CASELLA_DEL_TEAM,
      }),
    });
  } catch (errore) {
    // Un avviso che non parte non deve fermare le missioni.
    logger.warn('avviso del fondo non partito', { errore: String(errore).slice(0, 200) });
  }
}

/**
 * **Lancia una missione dal fondo.** La strada e' una sola, per la funzione a
 * orario e per il tasto della pagina di amministrazione: un tasto che prende
 * una scorciatoia prova una cosa diversa da quella che poi gira da sola.
 *
 * A mano non conta `dal` — e' un "lancia adesso" detto apposta — ma conta il
 * tetto di oggi: un tasto che scavalca il tetto e' un tetto che non c'e'.
 */
async function lanciaUna({ aMano = false } = {}) {
  const istantanea = await fondoRef().get();

  if (!istantanea.exists) {
    return { ok: false, reason: 'nessun-fondo' };
  }

  const fondo = istantanea.data() || {};
  const oggi = calendario.oggiInItalia();

  if (!aMano && fondo.dal && oggi < fondo.dal) {
    return { ok: false, reason: 'non-ancora' };
  }

  if (fondo.fino && oggi > fondo.fino) {
    await fondoRef().update({ acceso: false, spentoPerche: 'scaduto' });

    return { ok: false, reason: 'scaduto' };
  }

  const fatteOggi = fondo.giorno === oggi ? fondo.fatte || 0 : 0;

  if (fatteOggi >= (fondo.alGiorno || 1)) {
    return { ok: false, reason: 'tetto-di-oggi' };
  }

  if (!MISSIONI.length) {
    return { ok: false, reason: 'nessuna-missione' };
  }

  const indice = (fondo.lanciate || 0) + (fondo.saltate || 0);
  const missione = calendario.missioneAl(MISSIONI, indice);
  const premio = calendario.premioDi(missione, fondo);

  // **Finiti i soldi, si spegne e si dice perche'.** Lasciarlo acceso vorrebbe
  // dire provare e fallire cinque volte al giorno per sempre.
  if ((fondo.fondoCents || 0) < premio) {
    await fondoRef().update({ acceso: false, spentoPerche: 'finiti' });
    await avvisa(fondo.fondoCents || 0, true);

    return { ok: false, reason: 'fondo-finito' };
  }

  const autore = await chiLancia(fondo);

  if (!autore) {
    return { ok: false, reason: 'nessuna-faccia' };
  }

  const gara = await scriviLaGara(autore, missione, fondo, premio);
  const esito = await pagaDalFondo(gara, premio, autore.passi);

  if (!esito.ok) {
    // **Non pagata vuol dire non nata.** Una gara senza premio in mezzo alle
    // altre e' peggio di una gara in meno.
    await gara.delete();
    logger.warn('gara del fondo non pagata, tolta', { motivo: esito.reason });

    return esito;
  }

  // **La traccia sta qui dentro**: e' da qui che `refundChallenge` sa dove
  // rimettere il premio, e da qui la pagina di amministrazione legge le
  // ultime uscite.
  await fondoRef().collection('lanciate').doc(gara.id).set({
    titolo: missione.titolo,
    premioCents: premio,
    autoreId: autore.uid,
    autoreUsername: autore.username,
    quando: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.info('missione lanciata dal fondo', {
    gara: gara.id,
    titolo: missione.titolo,
    autore: autore.username,
    premio,
    restano: esito.restano,
    aMano,
  });

  if (!fondo.avvisato && esito.restano < premio * 3) {
    await fondoRef().update({ avvisato: true });
    await avvisa(esito.restano, false);
  }

  return { ok: true, gara: gara.id, titolo: missione.titolo, autore: autore.username, restano: esito.restano };
}

/**
 * Lancia le missioni del fondo, se e' acceso.
 *
 * Si sveglia a **tutte** le ore che una qualunque regola puo' usare
 * (`ORE_DI_LANCIO` in `calendario_del_fondo.js`, scritte qui a mano: si
 * cambiano insieme) e lancia solo se quella e' un'ora di lancio per il numero
 * di missioni al giorno scelto adesso: con tre, le dieci, le due e le sette.
 */
exports.lanciaLeMissioni = onSchedule(
  { schedule: '0 10,13,14,16,19,21 * * *', timeZone: 'Europe/Rome' },
  async () => {
    const fondo = await fondoRef().get();

    if (!fondo.exists || fondo.get('acceso') !== true) {
      return;
    }

    if (!calendario.oreDelGiorno(fondo.get('alGiorno')).includes(calendario.oraInItalia())) {
      return;
    }

    try {
      await lanciaUna();
    } catch (errore) {
      logger.error('missione del fondo non riuscita', { errore: String(errore).slice(0, 300) });
    }
  }
);

// ---------------------------------------------------------------------------
// Per la pagina di amministrazione: chi chiama ha gia' passato `soloAdmin`.
// ---------------------------------------------------------------------------

/** Una data `2026-12-02`, o vuota. Nient'altro. */
function data(valore, nome) {
  const testo = String(valore || '').trim();

  if (testo && !/^\d{4}-\d{2}-\d{2}$/.test(testo)) {
    throw new HttpsError('invalid-argument', `${nome}: scrivila come 2026-12-02.`);
  }

  return testo;
}

function intero(valore, minimo, massimo, nome) {
  const numero = Number(valore);

  if (!Number.isInteger(numero) || numero < minimo || numero > massimo) {
    throw new HttpsError('invalid-argument', `${nome}: da ${minimo} a ${massimo}.`);
  }

  return numero;
}

/**
 * **Tutto quello che serve alla pagina**: il saldo, le regole, le facce, il
 * calendario delle prossime, le ultime uscite, le ricariche, e i fondi vecchi
 * che hanno ancora dei soldi dentro.
 */
async function stato() {
  const [istantanea, lanciate, ricariche, tutti] = await Promise.all([
    fondoRef().get(),
    fondoRef().collection('lanciate').orderBy('quando', 'desc').limit(15).get(),
    fondoRef().collection('ricariche').orderBy('quando', 'desc').limit(10).get(),
    db.collection('salvadanai').get(),
  ]);
  const fondo = { ...INIZIALE, ...(istantanea.exists ? istantanea.data() : {}) };
  const oggi = calendario.oggiInItalia();

  const vecchi = [];

  for (const vecchio of tutti.docs) {
    if (vecchio.id === CENTRALE || !(vecchio.get('fondoCents') > 0)) {
      continue;
    }

    const persona = await db.collection('users').doc(vecchio.id).get();

    vecchi.push({
      uid: vecchio.id,
      username: persona.get('username') || vecchio.id,
      fondoCents: vecchio.get('fondoCents') || 0,
      acceso: vecchio.get('acceso') === true,
    });
  }

  const millis = (t) => (t && t.toMillis ? t.toMillis() : null);

  return {
    esiste: istantanea.exists,
    acceso: fondo.acceso === true,
    spentoPerche: fondo.spentoPerche || '',
    fondoCents: fondo.fondoCents || 0,
    spesiCents: fondo.spesiCents || 0,
    ricaricatiCents: fondo.ricaricatiCents || 0,
    alGiorno: fondo.alGiorno,
    premioCents: fondo.premioCents,
    oreDiGara: fondo.oreDiGara,
    maxPartecipanti: fondo.maxPartecipanti,
    dal: fondo.dal || '',
    fino: fondo.fino || '',
    fatteOggi: fondo.giorno === oggi ? fondo.fatte || 0 : 0,
    autori: fondo.autori || [],
    // Le ore di lancio per ogni numero al giorno: la pagina le scrive accanto
    // alla scelta, e le prende da qui per non doverle copiare.
    orari: calendario.ORARI,
    missioniInElenco: MISSIONI.length,
    prossime: calendario.prossime(fondo, MISSIONI, new Date(), 60),
    ultime: lanciate.docs.map((riga) => ({
      gara: riga.id,
      titolo: riga.get('titolo') || '',
      premioCents: riga.get('premioCents') || 0,
      autore: riga.get('autoreUsername') || '',
      quando: millis(riga.get('quando')),
    })),
    ricariche: ricariche.docs.map((riga) => ({
      id: riga.id,
      tipo: riga.get('tipo') || 'stripe',
      lordoCents: riga.get('lordoCents') || 0,
      commissioneCents: riga.get('commissioneCents') || 0,
      nettoCents: riga.get('nettoCents') || 0,
      da: riga.get('da') || '',
      quando: millis(riga.get('quando')),
    })),
    vecchi,
  };
}

/** Le regole del fondo. Crea il fondo, spento, se non c'era. */
async function imposta(valori) {
  const scelte = {
    alGiorno: intero(valori.alGiorno, 1, calendario.MASSIMO_AL_GIORNO, 'Missioni al giorno'),
    // Ventiquattro ore al massimo: e' il tetto di tutte le gare (vedi
    // `payments.js`), e una gara del fondo non fa eccezione.
    oreDiGara: intero(valori.oreDiGara, 1, 24, 'Ore di gara'),
    maxPartecipanti: intero(valori.maxPartecipanti, 2, 50, 'Posti'),
    premioCents: intero(valori.premioCents, 50, 10000, 'Premio di base'),
    dal: data(valori.dal, 'Parte il'),
    fino: data(valori.fino, 'Finisce il'),
  };

  if (scelte.dal && scelte.fino && scelte.fino < scelte.dal) {
    throw new HttpsError('invalid-argument', 'Finisce prima di partire.');
  }

  const istantanea = await fondoRef().get();

  await fondoRef().set(istantanea.exists ? scelte : { ...INIZIALE, ...scelte }, { merge: true });

  return { ok: true };
}

/**
 * **Chi presta la faccia.** Si scrivono i nomi; il server li cerca e salva
 * gli identificativi, che non cambiano quando uno cambia nome.
 *
 * O tutti o nessuno: con un nome sbagliato si torna indietro con l'elenco di
 * quelli che non ha trovato, invece di salvare una fila con un buco che
 * nessuno nota.
 */
async function impostaAutori(nomi) {
  const puliti = [
    ...new Set(
      (Array.isArray(nomi) ? nomi : [])
        .map((nome) => String(nome || '').trim().toLowerCase().replace(/^@/, ''))
        .filter(Boolean)
    ),
  ];

  if (!puliti.length || puliti.length > 30) {
    throw new HttpsError('invalid-argument', 'Da uno a trenta nomi.');
  }

  const trovati = [];
  const mancano = [];

  for (const nome of puliti) {
    const risposta = await db.collection('users').where('username', '==', nome).limit(1).get();

    if (risposta.empty || risposta.docs[0].id === CENTRALE) {
      mancano.push(nome);
    } else {
      trovati.push({ uid: risposta.docs[0].id, username: nome });
    }
  }

  if (mancano.length) {
    return { ok: false, mancano };
  }

  const istantanea = await fondoRef().get();

  await fondoRef().set(
    istantanea.exists ? { autori: trovati } : { ...INIZIALE, autori: trovati },
    { merge: true }
  );

  return { ok: true, autori: trovati };
}

/**
 * Accende o spegne. **Spegnere non tocca le gare gia' aperte**: hanno un premio
 * pagato e delle persone dentro, si chiudono da sole come tutte le altre.
 */
async function accendi(acceso) {
  const istantanea = await fondoRef().get();
  const fondo = istantanea.data() || {};

  if (!istantanea.exists && !acceso) {
    return { ok: true, acceso: false };
  }

  if (acceso) {
    if (!istantanea.exists || !(fondo.autori || []).length) {
      throw new HttpsError('failed-precondition', 'Prima scegli chi lancia.');
    }

    if (!MISSIONI.length) {
      throw new HttpsError('failed-precondition', 'Non ci sono missioni in elenco.');
    }
  }

  await fondoRef().update({ acceso, spentoPerche: acceso ? '' : 'a mano' });

  return { ok: true, acceso };
}

/**
 * Salta la prossima missione in coda. **Non la toglie dall'elenco: la rimanda
 * al giro dopo.** Una missione che oggi assomiglia alla sfida del giorno fra
 * due settimane non assomigliera' a niente.
 */
async function salta() {
  await fondoRef().update({ saltate: admin.firestore.FieldValue.increment(1) });

  return { ok: true };
}

/**
 * **Apre la pagina di Stripe per ricaricare il fondo.** Torna l'indirizzo: il
 * numero della carta non passa mai da CRASY, come per i premi.
 */
async function creaRicarica({ euro, origine, chi, email }) {
  const cents = calendario.centesimi(euro);

  if (cents < RICARICA_MINIMA || cents > RICARICA_MASSIMA) {
    throw new HttpsError('invalid-argument', 'Una ricarica va da 5 a 500 euro.');
  }

  const sito = SITI.includes(origine) ? origine : SITI[0];
  const ritorno = `${sito}/admin/#/automatiche`;
  const stripe = pagamenti.stripeClient();

  const sessione = await stripe.checkout.sessions.create({
    mode: 'payment',
    line_items: [
      {
        quantity: 1,
        price_data: {
          currency: 'eur',
          unit_amount: cents,
          product_data: {
            name: 'Ricarica del fondo missioni automatiche',
            description: 'Premi delle missioni lanciate da CRASY. Arriva nel fondo tolte le commissioni di Stripe.',
          },
        },
      },
    ],
    ...(email ? { customer_email: email } : {}),
    // Il segno sta anche sul pagamento, non solo sulla sessione: e' quello che
    // fa saltare `accendiLaGara` quando arriva `payment_intent.succeeded`, e
    // quello che resta leggibile su Stripe fra un anno.
    metadata: { kind: 'ricaricaFondo', chi },
    payment_intent_data: {
      metadata: { kind: 'ricaricaFondo', chi },
      description: 'Ricarica del fondo missioni automatiche CRASY',
    },
    success_url: `${ritorno}/ricaricato`,
    cancel_url: ritorno,
  });

  return { url: sessione.url };
}

/**
 * **I soldi sono arrivati: entrano nel fondo, tolte le commissioni.**
 *
 * Nel fondo si scrive quello che e' arrivato davvero, non quello che e'
 * partito dalla carta: ogni euro qui dentro diventa un premio che qualcuno
 * vincera' e prelevera', e un fondo che conta le commissioni come soldi
 * promette premi con denaro che non c'e'.
 *
 * Se Stripe non ha ancora scritto il movimento con le commissioni, si
 * risponde con un errore: il webhook lo rimanda piu' tardi, e intanto non si
 * e' scritto niente. Una sessione si conta una volta sola, comunque arrivi.
 */
async function registraRicarica(sessione) {
  if (!sessione || sessione.payment_status !== 'paid' || !sessione.payment_intent) {
    return;
  }

  const ricevuta = fondoRef().collection('ricariche').doc(sessione.id);

  if ((await ricevuta.get()).exists) {
    return;
  }

  const stripe = pagamenti.stripeClient();
  const pagamento = await stripe.paymentIntents.retrieve(sessione.payment_intent, {
    expand: ['latest_charge.balance_transaction'],
  });
  const carico = pagamento.latest_charge;
  const movimento = carico && typeof carico === 'object' ? carico.balance_transaction : null;

  if (!movimento || typeof movimento !== 'object' || !Number.isInteger(movimento.fee)) {
    throw new Error('movimento della ricarica non ancora pronto');
  }

  const lordo = carico.amount;
  const commissione = movimento.fee;
  const netto = lordo - commissione;

  await db.runTransaction(async (transaction) => {
    const gia = await transaction.get(ricevuta);
    const fondo = await transaction.get(fondoRef());

    if (gia.exists) {
      return;
    }

    transaction.set(ricevuta, {
      tipo: 'stripe',
      lordoCents: lordo,
      commissioneCents: commissione,
      nettoCents: netto,
      pagamento: pagamento.id,
      chi: (sessione.metadata && sessione.metadata.chi) || '',
      quando: admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.set(
      fondoRef(),
      {
        ...(fondo.exists ? {} : INIZIALE),
        fondoCents: admin.firestore.FieldValue.increment(netto),
        ricaricatiCents: admin.firestore.FieldValue.increment(netto),
        // Una ricarica riarma l'avviso di fine fondo.
        avvisato: false,
        ...(fondo.exists && fondo.get('spentoPerche') === 'finiti' ? { spentoPerche: 'ricaricato' } : {}),
      },
      { merge: true }
    );
  });

  logger.info('fondo ricaricato', { sessione: sessione.id, lordo, commissione, netto });
}

/**
 * **Porta nel fondo unico quello che resta in un fondo vecchio**, uno di
 * quelli per persona di prima. Il vecchio si spegne e si ricorda dove sono
 * andati i suoi soldi (`unitoIn`): se una sua gara ancora aperta va a vuoto,
 * il premio torna direttamente qui (vedi `refundChallenge`).
 */
async function unisci(uid) {
  if (!uid || uid === CENTRALE) {
    throw new HttpsError('invalid-argument', 'Quale fondo?');
  }

  const vecchio = db.collection('salvadanai').doc(uid);
  const ricevuta = fondoRef().collection('ricariche').doc();

  const spostati = await db.runTransaction(async (transaction) => {
    const dati = await transaction.get(vecchio);
    const fondo = await transaction.get(fondoRef());
    const quanto = (dati.exists && dati.get('fondoCents')) || 0;

    if (quanto <= 0) {
      return 0;
    }

    transaction.update(vecchio, {
      fondoCents: 0,
      acceso: false,
      spentoPerche: 'unito',
      unitoIn: CENTRALE,
    });

    transaction.set(
      fondoRef(),
      {
        ...(fondo.exists ? {} : INIZIALE),
        fondoCents: admin.firestore.FieldValue.increment(quanto),
        ricaricatiCents: admin.firestore.FieldValue.increment(quanto),
        avvisato: false,
      },
      { merge: true }
    );

    transaction.set(ricevuta, {
      tipo: 'trasferimento',
      da: uid,
      lordoCents: quanto,
      commissioneCents: 0,
      nettoCents: quanto,
      quando: admin.firestore.FieldValue.serverTimestamp(),
    });

    return quanto;
  });

  return { ok: true, spostati };
}

exports.CENTRALE = CENTRALE;
exports.MISSIONI = MISSIONI;
exports.lanciaUna = lanciaUna;
exports.stato = stato;
exports.imposta = imposta;
exports.impostaAutori = impostaAutori;
exports.accendi = accendi;
exports.salta = salta;
exports.creaRicarica = creaRicarica;
exports.registraRicarica = registraRicarica;
exports.unisci = unisci;
