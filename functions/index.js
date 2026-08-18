'use strict';

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const vision = require('@google-cloud/vision');

admin.initializeApp();

const db = admin.firestore();

// I soldi stanno in un file a parte, e le sue funzioni si esportano da qui:
// tutto quello che tocca denaro si legge in un posto solo.
const payments = require('./payments');

exports.startChallengePayment = payments.startChallengePayment;
exports.stripeWebhook = payments.stripeWebhook;
exports.createPayoutOnboarding = payments.createPayoutOnboarding;
exports.withdrawWallet = payments.withdrawWallet;

// Stessa regione del database: una funzione che scrive su Firestore va dove sta
// il database, altrimenti ogni scrittura fa un giro per mezzo mondo.
setGlobalOptions({ region: 'europe-west8', maxInstances: 10 });

/**
 * Guarda ogni foto appena arrivata, e decide se puo' stare in gara.
 *
 * **Questo controllo deve girare sul server e non sull'app**, e non e' una
 * questione di prestazioni: un controllo che gira sul telefono di chi carica e'
 * un controllo che chi carica puo' togliere. Qui la foto passa da SafeSearch di
 * Google Vision prima che qualcun altro possa vederla.
 *
 * La soglia e' volutamente severa sul sesso e sulla nudita': `LIKELY` non basta
 * ad assolvere, serve che sia `UNLIKELY` o meno. In un'app che si guardano
 * anche i minorenni per sbaglio, e in cui le foto le vede tutta la gara, e'
 * meglio rifiutare per errore una foto innocua che lasciarne passare una
 * sbagliata: chi si vede rifiutare puo' rimandarne un'altra, il danno opposto
 * non si ripara.
 *
 * Una foto rifiutata resta nel database con il suo stato, e non sparisce: serve
 * a poterla rivedere se qualcuno contesta, e a capire se il controllo sta
 * sbagliando troppo spesso.
 */
const BLOCKED_LIKELIHOODS = new Set(['LIKELY', 'VERY_LIKELY']);

exports.moderateEntryPhoto = onDocumentCreated(
  'challenges/{challengeId}/entries/{entryId}',
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      return;
    }

    const storagePath = snapshot.get('storagePath');

    if (!storagePath) {
      logger.warn(`Partecipazione ${snapshot.id} senza file: rifiutata.`);
      await snapshot.ref.update({ moderation: 'rejected' });

      return;
    }

    const bucket = admin.storage().bucket().name;
    const client = new vision.ImageAnnotatorClient();

    let safeSearch;

    try {
      const [result] = await client.safeSearchDetection(
        `gs://${bucket}/${storagePath}`
      );
      safeSearch = result.safeSearchAnnotation;
    } catch (error) {
      // Se il controllo non riesce, la foto **resta in attesa**. Non si
      // approva per comodita': un guasto nostro non puo' diventare il motivo
      // per cui una foto vietata finisce davanti a tutti.
      logger.error(`Controllo fallito su ${snapshot.id}`, error);

      return;
    }

    const reasons = [];

    if (BLOCKED_LIKELIHOODS.has(safeSearch?.adult)) {
      reasons.push('nudita/sesso');
    }

    if (BLOCKED_LIKELIHOODS.has(safeSearch?.racy)) {
      reasons.push('contenuto allusivo');
    }

    if (BLOCKED_LIKELIHOODS.has(safeSearch?.violence)) {
      reasons.push('violenza');
    }

    const rejected = reasons.length > 0;

    await snapshot.ref.update({
      moderation: rejected ? 'rejected' : 'approved',
      moderationReasons: reasons,
      moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Una foto rifiutata non deve contare fra i partecipanti: quel numero dice
    // quante persone sono in gara, e chi e' stato escluso in gara non c'e'.
    if (rejected) {
      await event.data.ref.parent.parent.update({
        participantsCount: admin.firestore.FieldValue.increment(-1),
      });

      logger.warn(`Partecipazione ${snapshot.id} rifiutata: ${reasons.join(', ')}`);
    }
  }
);

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

    // E il premio torna a chi l'aveva messo. Non c'e' nessuno a cui darlo, e
    // tenerlo sarebbe rubare.
    await payments.refundChallenge(challenge.id);
    logger.info(`Challenge ${challenge.id} chiusa senza partecipanti.`);

    return;
  }

  // Piu' fiamme per prima; a parita', chi ha mandato prima. Serve una regola
  // qualunque per il pareggio, ma serve che sia sempre la stessa: con dei soldi
  // in mezzo, un pareggio risolto a caso e' una lite.
  // Fuori dalla gara chi non ha passato il controllo: una foto rifiutata non
  // puo' vincere dei soldi. Le partecipazioni ancora in attesa restano dentro —
  // il controllo e' nostro e non e' colpa loro se e' lento — ma se il vincitore
  // fosse una di quelle andrebbe guardata da una persona prima di pagare.
  const eligible = entries.docs.filter(
    (doc) => doc.get('moderation') !== 'rejected'
  );

  if (eligible.length === 0) {
    await challenge.ref.update({ winnerEntryId: '' });
    await payments.refundChallenge(challenge.id);
    logger.info(`Challenge ${challenge.id} chiusa: nessuna foto ammessa.`);

    return;
  }

  const ranked = eligible.slice().sort((a, b) => {
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
  // `winnerUserId` accanto a `winnerEntryId` sembra un doppione e non lo e':
  // e' il campo su cui il pagamento cerca chi deve incassare. Ricavarlo ogni
  // volta dalla partecipazione vorrebbe dire, per pagare qualcuno, leggere un
  // documento dentro una sottocollezione partendo dal nulla.
  const batch = db.batch();
  batch.update(challenge.ref, {
    winnerEntryId: winner.id,
    winnerUserId: winner.get('userId') || null,
  });
  batch.update(winner.ref, { isWinner: true });
  await batch.commit();

  logger.info(
    `Challenge ${challenge.id}: vince ${winner.id} con ` +
      `${winner.get('votes') || 0} voti.`
  );

  // Il premio parte subito. Nella maggior parte dei casi non arrivera' — il
  // vincitore non ha ancora un conto su cui riceverlo — e va benissimo: la
  // funzione lo dice e non fa danni, e i soldi ripartono da soli appena si
  // registra.
  try {
    await payments.payWinner(challenge.id);
  } catch (error) {
    logger.error(`Challenge ${challenge.id}: premio non pagato.`, error);
  }
}
