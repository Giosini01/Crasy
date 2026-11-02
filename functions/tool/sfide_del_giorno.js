/**
 * **Le sfide del giorno: gratis, una al giorno, fino a una data.**
 *
 * Fa quello che fanno insieme `tool/sfide_del_giorno.py` e
 * `tool/rinnova_le_sfide.py`, ma gira dentro il deploy del server con la sua
 * chiave di servizio: per usare quei due serve un computer con `firebase login`
 * fatto. Le consegne stanno in `functions/dati/sfide_del_giorno.json`, e
 * rilanciare non crea doppioni: il nome del documento e' la data.
 *
 *     node tool/sfide_del_giorno.js --chiave C:/percorso/chiave.json
 *     node tool/sfide_del_giorno.js --chiave C:/percorso/chiave.json --scrivi
 *
 * Senza `--scrivi` dice solo cosa farebbe.
 *
 * **Non ha premio, ed e' la ragione per cui puo' essere di CRASY.** Una societa'
 * che promette un premio fa un concorso a premi (DPR 430/2001); senza premio non
 * c'e' niente da notificare. Per lo stesso motivo non si passa dal conto Stripe, e
 * l'eta' resta quella dichiarata: **qui non ci vanno le missioni hot**.
 *
 * ## Quelle che non si toccano
 *
 * 1. **Quella di oggi, se c'e' gia'.** E' aperta adesso: qualcuno l'ha letta
 *    stamattina, e magari e' gia' uscito di casa per farla.
 * 2. **Quelle che hanno gia' un partecipante.** Quella foto e' stata mandata per
 *    quella consegna, e cambiarla la farebbe diventare fuori tema.
 */

'use strict';

/**
 * **Fino a quando.** L'ultimo giorno compreso: dopo non si scrive piu' niente, e
 * in cima alla home torna una gara di qualcuno (`dailyChallengeProvider`). Per
 * andare avanti basta spostare questa data e aggiungere consegne al file.
 */
const FINO = '2026-11-30';

/** Il primo giorno della fila: dice quale consegna tocca a quale data. */
const PRIMO_GIORNO = '2026-11-01';

/** Deve combaciare con `Challenge.crasyUserId` dentro l'app. */
const CRASY = 'crasy';

/** La faccia di CRASY: l'icona dell'app, servita dal sito. */
const FOTO = 'https://crasy.web.app/icons/Icon-512.png';

const UN_GIORNO = 24 * 60 * 60 * 1000;

/** Oggi in Italia, scritto come il nome delle sfide: `2026-11-02`. */
function oggiInItalia(quando = new Date()) {
  return quando.toLocaleDateString('sv-SE', { timeZone: 'Europe/Rome' });
}

/**
 * La mezzanotte italiana di un giorno.
 *
 * **Non quella di questa macchina**: il deploy gira a Greenwich, e le sfide
 * cominciano e finiscono a mezzanotte di chi usa l'app.
 */
function mezzanotteInItalia(giorno) {
  const utc = new Date(`${giorno}T00:00:00Z`);
  const ora = Number(
    new Intl.DateTimeFormat('en-GB', {
      timeZone: 'Europe/Rome',
      hour: '2-digit',
      hourCycle: 'h23',
    }).format(utc),
  );

  return new Date(utc.getTime() - ora * 60 * 60 * 1000);
}

/** Il giorno dopo, sempre scritto allo stesso modo. */
function giornoDopo(giorno) {
  return new Date(new Date(`${giorno}T00:00:00Z`).getTime() + UN_GIORNO)
    .toISOString()
    .slice(0, 10);
}

/** Tutti i giorni da `da` a `a` compresi. */
function giorniFra(da, a) {
  const giorni = [];

  for (let giorno = da; giorno <= a; giorno = giornoDopo(giorno)) {
    giorni.push(giorno);
  }

  return giorni;
}

/** La consegna di una data: sempre la stessa, chiunque rilanci e quando. */
function consegnaDi(giorno, consegne) {
  const passi = Math.round(
    (new Date(`${giorno}T00:00:00Z`) - new Date(`${PRIMO_GIORNO}T00:00:00Z`)) / UN_GIORNO,
  );

  return consegne[((passi % consegne.length) + consegne.length) % consegne.length];
}

/**
 * I campi di una sfida del giorno. `Date` e non `Timestamp`: l'SDK li converte, e
 * cosi' questa funzione si prova senza un database.
 */
function documentoDi(giorno, consegna) {
  return {
    title: consegna.titolo,
    brief: consegna.consegna,
    // **Zero, e non e' una dimenticanza.** Vedi in cima.
    prizeCents: 0,
    kind: 'daily',
    scope: 'global',
    place: '',
    mediaKind: consegna.media,
    source: consegna.source || 'instant',
    createdByUsername: CRASY,
    createdByUserId: CRASY,
    // **Ventiquattro ore esatte**, da mezzanotte a mezzanotte: la fine dell'una e'
    // l'inizio dell'altra.
    startsAt: mezzanotteInItalia(giorno),
    endsAt: mezzanotteInItalia(giornoDopo(giorno)),
    participantsCount: 0,
    // **Devono esserci e valere nullo.** Le funzioni di pulizia cercano le gare
    // con `winnerEntryId == null` e `purgedAt == null`, e in Firestore un campo
    // che non c'e' non e' nullo: senza, la sfida non si chiuderebbe mai.
    winnerEntryId: null,
    purgedAt: null,
    prizeStatus: 'unpaid',
    rules: [],
    audience: ['*'],
  };
}

/**
 * Cosa fare di un giorno, sapendo cosa c'e' adesso nel database.
 *
 * Torna `scrivi`, oppure il motivo per cui non si tocca.
 */
function decisioneSu(giorno, oggi, attuale, consegna) {
  if (!attuale) {
    return 'scrivi';
  }

  if (giorno === oggi) {
    return "e' quella di oggi";
  }

  if (Number(attuale.participantsCount || 0) > 0) {
    return 'ha gia dei partecipanti';
  }

  if (attuale.title === consegna.titolo && attuale.brief === consegna.consegna) {
    return "c'e' gia";
  }

  return 'scrivi';
}

async function main() {
  const argomenti = process.argv.slice(2);
  const posto = argomenti.indexOf('--chiave');
  const chiave = posto >= 0 ? argomenti[posto + 1] : null;
  const scrivi = argomenti.includes('--scrivi');

  if (!chiave) {
    console.error('Serve --chiave <file json>.');
    process.exit(1);
  }

  const admin = require('firebase-admin');

  admin.initializeApp({ credential: admin.credential.cert(require(chiave)) });

  const db = admin.firestore();
  const consegne = require('../dati/sfide_del_giorno.json');
  const oggi = oggiInItalia();
  let scritte = 0;
  let lasciate = 0;

  for (const giorno of giorniFra(oggi, FINO)) {
    const riferimento = db.collection('challenges').doc(`daily-${giorno}`);
    const attuale = await riferimento.get();
    const consegna = consegnaDi(giorno, consegne);
    const decisione = decisioneSu(
      giorno,
      oggi,
      attuale.exists ? attuale.data() : null,
      consegna,
    );

    console.log(`daily-${giorno} | ${consegna.titolo} | ${decisione}`);

    if (decisione !== 'scrivi') {
      lasciate += 1;
      continue;
    }

    scritte += 1;

    if (scrivi) {
      await riferimento.set(documentoDi(giorno, consegna), { merge: true });
    }
  }

  // Il profilo di CRASY: toccare il nome sotto una sfida deve aprire qualcosa.
  if (scrivi && scritte > 0) {
    await db.collection('users').doc(CRASY).set(
      {
        username: CRASY,
        bio: 'La sfida del giorno. Gratis, ogni giorno.',
        city: '',
        photoUrl: FOTO,
      },
      { merge: true },
    );
  }

  console.log(`Sfide del giorno fino al ${FINO}: ${scritte} da scrivere, ${lasciate} lasciate stare.`);

  if (!scrivi) {
    console.log("Niente e' stato toccato. Rilancia con --scrivi.");
  }
}

if (require.main === module) {
  main().catch((errore) => {
    console.error(errore.message);
    process.exit(1);
  });
}

module.exports = {
  FINO,
  PRIMO_GIORNO,
  oggiInItalia,
  mezzanotteInItalia,
  giorniFra,
  consegnaDi,
  documentoDi,
  decisioneSu,
};
