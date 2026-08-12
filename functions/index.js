'use strict';

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions } = require('firebase-functions/v2');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

// Stessa regione del database: una funzione che scrive su Firestore va dove sta
// il database, altrimenti ogni scrittura fa un giro per mezzo mondo.
setGlobalOptions({ region: 'europe-west8', maxInstances: 10 });

/**
 * Proclama i vincitori delle challenge scadute.
 *
 * E' l'unica cosa che il client non puo' fare e che nessuno puo' fare a mano:
 * chiudere una gara con dei soldi in palio. La regola e' quella scritta nelle
 * challenge — **vince la foto con piu' voti allo scadere del tempo** — e viene
 * applicata qui, una volta sola, da chi ha l'ultima parola sui dati.
 *
 * Gira ogni cinque minuti e non a fine giornata: una challenge che si e' chiusa
 * un'ora fa e non ha ancora un vincitore e' una challenge che sembra rotta.
 */
exports.closeExpiredChallenges = onSchedule('every 5 minutes', async () => {
  const now = admin.firestore.Timestamp.now();

  // Le candidate sono le challenge gia' scadute a cui non e' ancora stato
  // assegnato un vincitore. `winnerEntryId` nullo e' il segno che la
  // proclamazione non e' stata fatta.
  const expired = await db
    .collection('challenges')
    .where('endsAt', '<=', now)
    .where('winnerEntryId', '==', null)
    .limit(50)
    .get();

  if (expired.empty) {
    return;
  }

  for (const challenge of expired.docs) {
    await closeChallenge(challenge);
  }

  logger.info(`Chiuse ${expired.size} challenge.`);
});

/**
 * Chiude una singola challenge e proclama chi ha vinto.
 */
async function closeChallenge(challenge) {
  // Le partecipazioni si leggono tutte e si ordinano qui, invece di farsele
  // ordinare da Firestore. Una query con `orderBy('votes')` **salta i documenti
  // senza quel campo**, e una foto scritta da una versione vecchia dell'app non
  // deve poter essere esclusa dalla gara per un dettaglio del suo formato: qui
  // si sta assegnando del denaro.
  const entries = await challenge.ref.collection('entries').limit(500).get();

  if (entries.empty) {
    // Nessuno ha partecipato. Si marca lo stesso, con la stringa vuota, per non
    // riprovare a chiuderla ogni cinque minuti da qui all'eternita'.
    await challenge.ref.update({ winnerEntryId: '' });
    logger.info(`Challenge ${challenge.id} chiusa senza partecipanti.`);

    return;
  }

  // Piu' fiamme per prima; a parita', chi ha mandato prima. Serve una regola
  // qualunque per il pareggio, ma serve che sia sempre la stessa: con dei soldi
  // in mezzo, un pareggio risolto a caso e' una lite.
  const ranked = entries.docs.slice().sort((a, b) => {
    const byVotes = (b.get('votes') || 0) - (a.get('votes') || 0);

    if (byVotes !== 0) {
      return byVotes;
    }

    const at = a.get('createdAt');
    const bt = b.get('createdAt');

    return (at ? at.toMillis() : 0) - (bt ? bt.toMillis() : 0);
  });

  const winner = ranked[0];

  // Le due scritture vanno insieme: una challenge che indica un vincitore che
  // non si sa di essere stato proclamato, o viceversa, e' il tipo di stato che
  // poi nessuno sa piu' come rimettere a posto.
  const batch = db.batch();
  batch.update(challenge.ref, { winnerEntryId: winner.id });
  batch.update(winner.ref, { isWinner: true });
  await batch.commit();

  logger.info(
    `Challenge ${challenge.id}: vince ${winner.id} con ` +
      `${winner.get('votes') || 0} voti.`
  );
}
