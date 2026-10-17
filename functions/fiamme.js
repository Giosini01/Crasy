// Le fiamme di una foto che esce dalla gara.
//
// Sta in un file a parte perche' la chiamano in tre posti — il ritiro, il
// controllo automatico e la rimozione dall'amministrazione — in due file
// diversi: tre copie della stessa regola sono tre regole che al primo
// cambiamento si dicono cose diverse.

const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

/**
 * **Le fiamme date a una foto che non e' piu' in gara tornano a chi le ha
 * date.**
 *
 * Ognuno ne ha tre per gara. Una foto ritirata, o tolta perche' non andava,
 * spariva dalla griglia — ma la fiamma che le si era data restava contata fra
 * le tre, su una foto che non si vedeva piu' e quindi senza nessun modo di
 * riprendersela. Qui si cancellano quei voti: il contatore della foto lo
 * sistema `countVote`, e la fiamma torna libera.
 *
 * Non lancia mai: una fiamma non restituita non vale un ritiro fallito.
 */
async function liberaLeFiamme(challengeId, entryId) {
  if (!challengeId || !entryId) {
    return;
  }

  try {
    const db = admin.firestore();
    // Si cercano per gara e si filtrano per foto: l'indice sul gruppo dei
    // voti c'e' per la gara, non per la coppia.
    const voti = await db
      .collectionGroup('votes')
      .where('challengeId', '==', challengeId)
      .get();
    const suQuesta = voti.docs.filter((voto) => voto.get('entryId') === entryId);

    for (let i = 0; i < suQuesta.length; i += 400) {
      const scrittura = db.batch();

      for (const voto of suQuesta.slice(i, i + 400)) {
        scrittura.delete(voto.ref);
      }

      await scrittura.commit();
    }

    if (suQuesta.length > 0) {
      logger.info('fiamme restituite', {
        challengeId,
        entryId,
        quante: suQuesta.length,
      });
    }
  } catch (error) {
    logger.warn('Fiamme non restituite.', {
      challengeId,
      entryId,
      errore: String((error && error.message) || error).slice(0, 300),
    });
  }
}

module.exports = { liberaLeFiamme };
