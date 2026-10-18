'use strict';

/**
 * **Chiedere che una persona riguardi una foto tolta.**
 *
 * Il controllo delle immagini e' severo apposta, e ogni tanto sbaglia: una
 * foto in costume, un abbraccio, un quadro. Prima chi se la vedeva togliere
 * poteva solo "scrivere al contatto indicato" — un indirizzo che non c'era —
 * e la sua foto restava fuori da una gara con dei soldi in palio.
 *
 * Adesso dall'avviso si tocca **"Chiedi una revisione"**: la richiesta finisce
 * nella pagina di amministrazione, in cima alle foto scartate, e una persona
 * decide. Se ci siamo sbagliati la foto torna in gara e arriva una notifica;
 * se no, la stessa riga della campanella dice che e' stata riguardata e resta
 * fuori. E' quello che il Digital Services Act chiede a chi toglie dei
 * contenuti: dire perche', e dare un modo vero per contestarlo.
 *
 * **Una revisione per foto.** Chiederla due volte non la fa guardare due
 * volte, e una revisione respinta non si riapre: altrimenti il tasto
 * diventerebbe un modo di insistere finche' qualcuno non cede.
 *
 * I fogli stanno in `revisioni/{gara}__{persona}` e non li legge nessun
 * telefono: chi l'ha chiesta vede lo stato nel proprio avviso.
 */
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

const db = admin.firestore();

/** Il foglio della revisione di una foto. La foto si chiama come chi l'ha mandata. */
function revisioneDi(challengeId, userId) {
  return db.collection('revisioni').doc(`${challengeId}__${userId}`);
}

function avvisoDi(userId, challengeId) {
  return db
    .collection('users')
    .doc(userId)
    .collection('notifications')
    .doc('tolta_' + challengeId);
}

/**
 * Scrive lo stato della revisione dentro l'avviso di rimozione.
 *
 * Con `update` e non con `set`: se l'avviso non c'e' piu', crearne uno con
 * dentro solo lo stato farebbe nascere una notifica vuota — e una notifica che
 * nasce squilla.
 */
async function segnaNellAvviso(userId, challengeId, stato) {
  try {
    await avvisoDi(userId, challengeId).update({ revisione: stato });
  } catch (error) {
    logger.warn('stato della revisione non scritto nell\'avviso', {
      userId,
      challengeId,
      stato,
      error: String((error && error.message) || error).slice(0, 200),
    });
  }
}

exports.chiediRevisione = onCall(async (request) => {
  const userId = request.auth && request.auth.uid;

  if (!userId) {
    throw new HttpsError('unauthenticated', 'Serve l\'accesso.');
  }

  const challengeId = String((request.data && request.data.challengeId) || '');

  if (!challengeId) {
    throw new HttpsError('invalid-argument', 'Manca la missione.');
  }

  const foto = db
    .collection('challenges')
    .doc(challengeId)
    .collection('entries')
    .doc(userId);
  const revisione = revisioneDi(challengeId, userId);

  const esito = await db.runTransaction(async (t) => {
    const [adesso, gia, avviso] = await Promise.all([
      t.get(foto),
      t.get(revisione),
      t.get(avvisoDi(userId, challengeId)),
    ]);

    // Si contesta solo una foto propria, e solo se e' davvero fuori.
    if (!adesso.exists || adesso.get('moderation') !== 'rejected') {
      return 'non-tolta';
    }

    if (gia.exists) {
      return gia.get('stato') === 'aperta' ? 'gia-chiesta' : 'gia-decisa';
    }

    t.create(revisione, {
      challengeId,
      userId,
      entryId: userId,
      challengeTitle: String(adesso.get('challengeTitle') || ''),
      // Dall'avviso, che lo sa: l'ha scritto chi ha tolto la foto.
      motivo: String((avviso.exists && avviso.get('motivo')) || 'altro'),
      automatico: avviso.exists
        ? avviso.get('automatico') === true
        : adesso.get('moderationReason') !== 'admin',
      stato: 'aperta',
      chiestaIl: admin.firestore.FieldValue.serverTimestamp(),
    });

    return 'chiesta';
  });

  if (esito === 'non-tolta') {
    throw new HttpsError(
      'failed-precondition',
      'Questa foto non risulta tolta dalla gara.'
    );
  }

  if (esito === 'chiesta' || esito === 'gia-chiesta') {
    await segnaNellAvviso(userId, challengeId, 'chiesta');
  }

  logger.info('revisione chiesta', { challengeId, userId, esito });

  return { esito };
});

/**
 * Chiude una revisione: `accolta` quando la foto torna in gara, `respinta`
 * quando resta fuori. Se nessuno l'aveva chiesta non fa niente — una foto si
 * puo' rimettere in gara anche senza una richiesta.
 */
async function chiudiLaRevisione(challengeId, userId, esito, chi) {
  const revisione = revisioneDi(challengeId, userId);

  const chiusa = await db.runTransaction(async (t) => {
    const adesso = await t.get(revisione);

    if (!adesso.exists || adesso.get('stato') !== 'aperta') {
      return false;
    }

    t.update(revisione, {
      stato: esito,
      decisaIl: admin.firestore.FieldValue.serverTimestamp(),
      decisaDa: String(chi || ''),
    });

    return true;
  });

  // Rimessa in gara, l'avviso di rimozione se ne va da solo (vedi
  // `togliLAvvisoDiRimozione`): da scrivere resta solo il no.
  if (chiusa && esito === 'respinta') {
    await segnaNellAvviso(userId, challengeId, 'respinta');
  }

  return chiusa ? esito : 'nessuna';
}

module.exports.revisioneDi = revisioneDi;
module.exports.chiudiLaRevisione = chiudiLaRevisione;
