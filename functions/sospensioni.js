'use strict';

/**
 * **Sospendere un account, per un tempo scelto da una persona.**
 *
 * Si sospende dal pannello delle segnalazioni, insieme alla rimozione: chi ha
 * scritto una missione vietata, o mandato una foto vietata, perde l'accesso
 * per 1, 7 o 30 giorni, oppure per sempre. Fino a qui una sospensione si
 * poteva fare solo a mano dalla console di Firebase, e quindi non si faceva.
 *
 * ## Come funziona
 *
 * - **L'account si spegne su Firebase** (`disabled`), e i gettoni gia' dati si
 *   revocano: chi e' dentro esce al primo rinnovo, e non rientra.
 * - **La sospensione si scrive in `sospensioni/{uid}`**, una raccolta che
 *   nessun telefono legge: il profilo lo vedono tutti, e il motivo di una
 *   sospensione non e' affare di tutti.
 * - **Alla scadenza si riaccende da solo** (`riattivaISospesi`, ogni ora).
 *   "Per sempre" non ha scadenza: si riattiva solo a mano.
 * - **La persona lo sa, e sa perche'.** Le arriva un'email con il motivo, la
 *   durata e il modo di contestare: e' quello che il Digital Services Act
 *   chiede (art. 17) a chi limita un account.
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const posta = require('./posta');

const db = admin.firestore();

/** Le durate che si possono scegliere dal pannello, in giorni. Zero e' per sempre. */
const DURATE = [1, 7, 30, 0];

const SOSPENSIONI = 'sospensioni';

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

/** La durata scritta per una persona: "fino al 2 novembre 2026" o "a tempo indeterminato". */
function quanto(fino) {
  if (!fino) {
    return 'a tempo indeterminato';
  }

  return 'fino al ' + fino.toDate().toLocaleDateString('it-IT', {
    timeZone: 'Europe/Rome',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
}

/**
 * Sospende [uid] per [giorni] (zero: per sempre), con il [motivo] che la
 * persona leggera'. Torna la scadenza, o `null` se e' per sempre.
 */
async function sospendi(uid, { giorni, motivo, chi }) {
  if (!uid || uid === 'crasy') {
    return null;
  }

  if (!DURATE.includes(giorni)) {
    throw new HttpsError('invalid-argument', 'Durata della sospensione non valida.');
  }

  const utente = await admin.auth().getUser(uid);

  // Un amministratore non si sospende da qui: un clic sbagliato chiuderebbe
  // fuori chi deve poter rimediare.
  if (utente.customClaims && utente.customClaims.admin === true) {
    throw new HttpsError('failed-precondition', 'È un amministratore: non si sospende da qui.');
  }

  const fino = giorni
    ? admin.firestore.Timestamp.fromMillis(Date.now() + giorni * 24 * 3600 * 1000)
    : null;

  await admin.auth().updateUser(uid, { disabled: true });
  await admin.auth().revokeRefreshTokens(uid);

  await db.collection(SOSPENSIONI).doc(uid).set({
    attiva: true,
    fino,
    giorni,
    motivo,
    da: chi,
    il: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.info('account sospeso', { uid, giorni, da: chi });

  // L'email non deve far fallire la sospensione: e' gia' in vigore.
  if (utente.email) {
    try {
      await posta.spedisci({
        from: '"CRASY" <' + posta.CASELLA + '>',
        to: utente.email,
        subject: 'Il tuo account CRASY è sospeso',
        text:
          motivo + ' Per questo il tuo account è sospeso ' + quanto(fino) +
          '. Se pensi che sia un errore, scrivi a info@crasyapp.com.',
        html: posta.vestito({
          titolo: 'ACCOUNT SOSPESO',
          testo:
            motivo + ' Per questo il tuo account è sospeso ' + quanto(fino) +
            ', come previsto dai Termini (punto 8).',
          tasto: 'SCRIVICI',
          link: 'mailto:info@crasyapp.com',
          nota:
            'Se pensi che sia un errore, scrivi a info@crasyapp.com: ' +
            'una persona del team riguarda la decisione.',
        }),
      });
    } catch (guaio) {
      logger.error('Email della sospensione non partita.', guaio);
    }
  }

  return fino;
}

/** Riaccende [uid] e chiude la sua sospensione. */
async function riattiva(uid, chi) {
  await admin.auth().updateUser(uid, { disabled: false });
  await db.collection(SOSPENSIONI).doc(uid).set(
    {
      attiva: false,
      riattivataDa: chi,
      riattivataIl: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  logger.info('account riattivato', { uid, da: chi });
}

/** Com'e' messa la sospensione di [uid], per il pannello. */
async function statoDi(uid) {
  const doc = await db.collection(SOSPENSIONI).doc(uid).get();

  if (!doc.exists || doc.get('attiva') !== true) {
    return null;
  }

  const fino = doc.get('fino');

  return { fino: fino ? fino.toMillis() : null, motivo: doc.get('motivo') || '' };
}

/** **Riattiva a mano**, dal pannello: la decisione era sbagliata o e' cambiata. */
const adminRiattiva = onCall(async (request) => {
  const chi = soloAdmin(request);
  const uid = String(request.data?.userId || '');

  if (!uid) {
    throw new HttpsError('invalid-argument', 'Manca la persona.');
  }

  await riattiva(uid, chi);

  return { riattivato: true };
});

/** **Alla scadenza si riaccende da solo.** "Per sempre" non scade. */
const riattivaISospesi = onSchedule(
  { schedule: 'every 60 minutes', timeZone: 'Europe/Rome' },
  async () => {
    const scadute = await db
      .collection(SOSPENSIONI)
      .where('attiva', '==', true)
      .where('fino', '<=', admin.firestore.Timestamp.now())
      .limit(100)
      .get();

    for (const doc of scadute.docs) {
      try {
        await riattiva(doc.id, 'scadenza');
      } catch (errore) {
        logger.error(`Sospensione di ${doc.id} non chiusa.`, errore);
      }
    }
  },
);

module.exports = { DURATE, sospendi, riattiva, statoDi, adminRiattiva, riattivaISospesi };
