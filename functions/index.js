'use strict';

const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions } = require('firebase-functions/v2');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const vision = require('@google-cloud/vision');

const {
  canSee,
  buildFeedEntry,
  ageFrom,
  distanceKm,
  interestsOf,
} = require('./matching');

admin.initializeApp();

const db = admin.firestore();

// Stessa regione del database: un trigger Firestore deve nascere dove sta il
// database, altrimenti Eventarc rifiuta di crearlo.
setGlobalOptions({ region: 'europe-west8', maxInstances: 10 });

/// Firestore accetta al massimo 500 scritture per batch.
const BATCH_LIMIT = 450;

/// Quanto vive un'Istantanea. Passate queste, foto e documenti spariscono.
const DAILY_LIFETIME_MS = 24 * 60 * 60 * 1000;

const increment = (by) => admin.firestore.FieldValue.increment(by);

/**
 * Il diario privato di una giornata: quante persone hanno guardato, quanti
 * cuori, quanti match.
 *
 * Sta in una sottocollezione a parte e **non dentro l'Istantanea** proprio
 * perche' deve sopravviverle: la foto dopo un giorno sparisce, i numeri
 * restano. Sono privati per costruzione — li legge solo chi li ha prodotti.
 */
function dayStatsRef(userId, dateKey) {
  return db.collection('users').doc(userId).collection('stats').doc(dateKey);
}

/// I totali di sempre, piu' la striscia di giorni consecutivi.
function lifetimeStatsRef(userId) {
  return db.collection('users').doc(userId).collection('stats').doc('lifetime');
}

function dateKeyOf(date) {
  const month = `${date.getMonth() + 1}`.padStart(2, '0');
  const day = `${date.getDate()}`.padStart(2, '0');

  return `${date.getFullYear()}-${month}-${day}`;
}

function previousDateKey(dateKey) {
  const [year, month, day] = dateKey.split('-').map(Number);
  const previous = new Date(Date.UTC(year, month - 1, day - 1));

  return dateKeyOf(previous);
}

/**
 * Aggiorna la striscia di giorni consecutivi.
 *
 * Si allunga solo se l'ultima Istantanea era **di ieri**: se era di oggi il
 * giorno e' gia' contato (se ne fanno fino a tre), e se era piu' vecchia la
 * striscia si e' interrotta e riparte da uno. Il conto sta sul server perche'
 * un numero che l'utente puo' riscrivere non e' un premio, e' un campo.
 */
async function bumpStreak(userId, dateKey) {
  const ref = lifetimeStatsRef(userId);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const current = snapshot.exists ? snapshot.data() : {};

    if (current.streakLastDate === dateKey) {
      return;
    }

    const continues = current.streakLastDate === previousDateKey(dateKey);

    transaction.set(
      ref,
      {
        streakDays: continues ? (current.streakDays || 0) + 1 : 1,
        streakLastDate: dateKey,
        totalDailies: (current.totalDailies || 0) + 1,
      },
      { merge: true },
    );
  });
}

async function loadProfile(userId) {
  const snapshot = await db.collection('users').doc(userId).get();

  if (!snapshot.exists) {
    return null;
  }

  return { id: snapshot.id, ...snapshot.data() };
}

async function loadCandidates() {
  const snapshot = await db
    .collection('users')
    .where('onboardingCompleted', '==', true)
    .get();

  return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

/** Scrive le voci a blocchi, per non superare il limite del batch. */
async function commitInBatches(writes) {
  for (let index = 0; index < writes.length; index += BATCH_LIMIT) {
    const batch = db.batch();

    for (const write of writes.slice(index, index + BATCH_LIMIT)) {
      batch.set(write.ref, write.data, { merge: true });
    }

    await batch.commit();
  }
}

function feedRef(viewerId, dailyId) {
  return db.collection('users').doc(viewerId).collection('feed').doc(dailyId);
}

/**
 * Porta la nuova Istantanea dentro le righe dei match gia' esistenti.
 *
 * Un match non muore con la foto: passate ventiquattr'ore quella sparisce e
 * la scheda resta senza volto. Quando la persona si fa vedere di nuovo, il
 * giorno dopo, il match torna ad avere una faccia — la faccia di oggi, non
 * quella con cui il match era nato.
 *
 * Le righe sono poche per definizione (i propri match), quindi si scrivono
 * tutte in un colpo.
 */
async function refreshMatchPhotos(authorId, daily) {
  const matches = await db
    .collection('users')
    .doc(authorId)
    .collection('matches')
    .get();

  if (matches.empty) {
    return;
  }

  const writes = matches.docs.map((doc) => ({
    ref: db
      .collection('users')
      .doc(doc.id)
      .collection('matches')
      .doc(authorId),
    data: {
      photoUrl: daily.downloadUrl || '',
      vibe: daily.vibe || '',
      photoCapturedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  }));

  await commitInBatches(writes);

  logger.info('Foto dei match aggiornata', {
    authorId,
    righe: writes.length,
  });
}

const visionClient = new vision.ImageAnnotatorClient();

/**
 * Vero se nella foto c'e' almeno un volto.
 *
 * Il controllo sta qui e non nell'app perche' un controllo fatto sul telefono
 * non e' un controllo: chiunque puo' scavalcare il client e caricare quello
 * che vuole. Questa e' l'unica porta da cui una Daily entra nei feed.
 *
 * Se il servizio di analisi non risponde la foto passa lo stesso: un guasto
 * di Google non deve impedire alle persone di pubblicare. La conseguenza e'
 * che il filtro vale nel funzionamento normale, non durante un disservizio.
 */
async function hasFace(storagePath) {
  const bucket = admin.storage().bucket().name;

  try {
    const [result] = await visionClient.faceDetection(
      `gs://${bucket}/${storagePath}`,
    );

    // Vision non solleva un'eccezione quando non riesce ad aprire il file:
    // risponde regolarmente, con l'errore **dentro** la risposta e nessuna
    // annotazione. Senza questo controllo quel caso finiva nel ramo sotto e
    // veniva letto come "non c'e' nessun volto": una foto perfettamente buona
    // in un formato che Vision non digerisce veniva rifiutata e cancellata.
    if (result.error && result.error.message) {
      logger.error('Immagine non analizzabile, passa', {
        storagePath,
        message: result.error.message,
      });

      return true;
    }

    const faces = (result.faceAnnotations || []).length;

    logger.info('Analisi del volto', { storagePath, volti: faces });

    return faces > 0;
  } catch (error) {
    logger.error('Analisi del volto non riuscita, la foto passa', {
      storagePath,
      message: error.message,
    });

    return true;
  }
}

/**
 * Una Daily e' stata pubblicata: la si consegna a chi ha diritto di vederla.
 *
 * Il ventaglio si apre al momento della pubblicazione invece di calcolare il
 * feed a ogni apertura dell'app: le letture sono molte piu' delle scritture, e
 * cosi' il client legge un solo documento gia' pronto.
 */
exports.fanOutDaily = onDocumentCreated(
  'users/{userId}/dailies/{dailyId}',
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      return;
    }

    const daily = { id: event.params.dailyId, ...snapshot.data() };

    // Le Daily nascono in attesa di verifica: qualunque altro stato significa
    // che questa e' gia' passata di qui.
    if (daily.status !== 'draft') {
      logger.info('Daily gia trattata, nessun ventaglio', {
        dailyId: daily.id,
        status: daily.status,
      });
      return;
    }

    const author = await loadProfile(event.params.userId);

    if (!author) {
      logger.warn('Autore senza profilo', { userId: event.params.userId });
      return;
    }

    if (!(await hasFace(daily.storagePath))) {
      await snapshot.ref.update({ status: 'rejected' });

      // La foto scartata si cancella: non la vedra' mai nessuno, e tenerla
      // sarebbe solo spazio occupato e un dato in piu' da custodire.
      await admin
        .storage()
        .bucket()
        .file(daily.storagePath)
        .delete()
        .catch((error) => {
          logger.warn('Foto scartata non cancellata', {
            storagePath: daily.storagePath,
            message: error.message,
          });
        });

      logger.info('Daily rifiutata: nessun volto', { dailyId: daily.id });
      return;
    }

    await snapshot.ref.update({ status: 'active' });
    await bumpStreak(event.params.userId, daily.dateKey || dateKeyOf(new Date()));

    const now = new Date();
    const candidates = await loadCandidates();
    const writes = [];

    for (const viewer of candidates) {
      if (!canSee(viewer, author)) {
        continue;
      }

      writes.push({
        ref: feedRef(viewer.id, daily.id),
        data: buildFeedEntry(daily, author, viewer, now),
      });
    }

    await commitInBatches(writes);
    await refreshMatchPhotos(event.params.userId, daily);

    logger.info('Daily consegnata', {
      dailyId: daily.id,
      destinatari: writes.length,
    });
  },
);

/**
 * Verifica la foto profilo appena caricata.
 *
 * Stesso patto dell'Istantanea: finche' non e' verificata non la vede
 * nessuno. Il controllo e' qui e non nell'app perche' un controllo fatto sul
 * telefono si aggira.
 */
exports.verifyProfilePhoto = onDocumentWritten(
  'users/{userId}',
  async (event) => {
    const after = event.data && event.data.after;

    if (!after || !after.exists) {
      return;
    }

    const profile = after.data();

    // Solo le foto in attesa: qualunque altro stato e' gia' stato deciso, e
    // riscrivere lo stesso documento farebbe ripartire questa funzione.
    if (profile.photoStatus !== 'pending' || !profile.photoStoragePath) {
      return;
    }

    if (await hasFace(profile.photoStoragePath)) {
      await after.ref.update({ photoStatus: 'active' });
      logger.info('Foto profilo verificata', { userId: event.params.userId });
      return;
    }

    await after.ref.update({
      photoStatus: 'rejected',
      photoUrl: null,
      photoStoragePath: null,
    });

    await admin
      .storage()
      .bucket()
      .file(profile.photoStoragePath)
      .delete()
      .catch((error) => {
        logger.warn('Foto profilo scartata non cancellata', {
          message: error.message,
        });
      });

    logger.info('Foto profilo rifiutata: nessun volto', {
      userId: event.params.userId,
    });
  },
);

/**
 * Un profilo e' stato completato o aggiornato: si recuperano le Daily di oggi
 * gia' pubblicate.
 *
 * Senza questo, chi finisce l'onboarding dopo che gli altri hanno pubblicato
 * vedrebbe un feed vuoto fino al giorno dopo.
 */
exports.backfillFeedOnProfileChange = onDocumentWritten(
  'users/{userId}',
  async (event) => {
    const after = event.data && event.data.after;

    if (!after || !after.exists) {
      return;
    }

    const viewer = { id: event.params.userId, ...after.data() };
    const before = event.data.before;
    const previous = before && before.exists ? before.data() : null;

    // Si rifa' il conto solo se e' cambiato qualcosa che pesa sul criterio:
    // altrimenti ogni scrittura sul profilo scatenerebbe una scansione.
    const unchanged =
      previous &&
      previous.onboardingCompleted === viewer.onboardingCompleted &&
      previous.gender === viewer.gender &&
      previous.interestedIn === viewer.interestedIn &&
      previous.latitude === viewer.latitude &&
      previous.longitude === viewer.longitude;

    if (unchanged) {
      return;
    }

    const now = new Date();
    const dateKey = [
      now.getFullYear(),
      String(now.getMonth() + 1).padStart(2, '0'),
      String(now.getDate()).padStart(2, '0'),
    ].join('-');

    const dailies = await db
      .collectionGroup('dailies')
      .where('dateKey', '==', dateKey)
      .where('status', '==', 'active')
      .get();

    const writes = [];

    for (const doc of dailies.docs) {
      const authorId = doc.ref.parent.parent && doc.ref.parent.parent.id;

      if (!authorId || authorId === viewer.id) {
        continue;
      }

      const author = await loadProfile(authorId);

      if (!author || !canSee(viewer, author)) {
        continue;
      }

      const daily = { id: doc.id, ...doc.data() };

      writes.push({
        ref: feedRef(viewer.id, daily.id),
        data: buildFeedEntry(daily, author, viewer, now),
      });
    }

    await commitInBatches(writes);

    logger.info('Feed recuperato', {
      userId: viewer.id,
      voci: writes.length,
    });
  },
);

/**
 * Qualcuno ha guardato un'Istantanea: si aggiunge una visualizzazione a chi
 * l'ha pubblicata.
 *
 * A dire "l'ho vista" e' chi guarda, scrivendo `seen` **sulla propria** voce
 * di feed: e' l'unico documento che ha il diritto di toccare. Da li' in poi il
 * conteggio lo fa il server, che e' anche l'unico modo per tenerlo onesto.
 *
 * Il contatore non dice **chi**: dice quanti. Sapere chi ti ha guardato
 * significherebbe che qualcuno sa che tu hai guardato lui, e questa app e'
 * costruita perche' non si possa.
 */
exports.countDailyView = onDocumentUpdated(
  'users/{viewerId}/feed/{dailyId}',
  async (event) => {
    const before = event.data && event.data.before;
    const after = event.data && event.data.after;

    if (!before || !after || !after.exists) {
      return;
    }

    // Solo il passaggio da "non vista" a "vista": ogni altra riscrittura del
    // documento — per esempio il recupero del feed — non e' uno sguardo nuovo.
    if (before.data().seen === true || after.data().seen !== true) {
      return;
    }

    const entry = after.data();
    const authorId = entry.authorId;

    if (!authorId || authorId === event.params.viewerId) {
      return;
    }

    const dateKey = entry.dateKey || dateKeyOf(new Date());

    await Promise.all([
      dayStatsRef(authorId, dateKey).set(
        { dateKey, views: increment(1) },
        { merge: true },
      ),
      lifetimeStatsRef(authorId).set(
        { totalViews: increment(1) },
        { merge: true },
      ),
    ]);
  },
);

/**
 * Una persona ha messo cuore: se anche l'altra lo aveva fatto, nasce un match.
 *
 * Il controllo di reciprocita' sta sul server perche' e' l'unico punto che
 * puo' leggere la decisione dell'altra persona: nessun client deve poter
 * sapere chi lo ha messo da parte.
 */
exports.createMatchOnMutualLike = onDocumentCreated(
  'users/{userId}/decisions/{targetId}',
  async (event) => {
    const snapshot = event.data;

    if (!snapshot || snapshot.data().liked !== true) {
      return;
    }

    const { userId, targetId } = event.params;
    const today = dateKeyOf(new Date());

    // Il cuore si conta subito, prima di sapere se e' ricambiato: e' una cosa
    // che e' successa a chi lo riceve, e vale anche se resta senza risposta.
    await Promise.all([
      dayStatsRef(targetId, today).set(
        { dateKey: today, likes: increment(1) },
        { merge: true },
      ),
      lifetimeStatsRef(targetId).set(
        { totalLikes: increment(1) },
        { merge: true },
      ),
    ]);

    const reciprocal = await db
      .collection('users')
      .doc(targetId)
      .collection('decisions')
      .doc(userId)
      .get();

    if (!reciprocal.exists || reciprocal.data().liked !== true) {
      return;
    }

    const [first, second] = await Promise.all([
      loadProfile(userId),
      loadProfile(targetId),
    ]);

    if (!first || !second) {
      return;
    }

    const now = new Date();
    const matchedAt = admin.firestore.FieldValue.serverTimestamp();

    /**
     * L'ultima Istantanea di una persona, per metterla nella riga del match.
     *
     * Va copiata qui perche' nessun client puo' leggere le Daily altrui, e
     * dopo un giorno quella foto non esistera' piu': la riga terra' un
     * indirizzo morto, e la schermata ripiega sull'iniziale del nome. E'
     * voluto — la foto dura un giorno anche quando e' diventata un match.
     */
    async function lastDaily(id) {
      const snapshot = await db
        .collection('users')
        .doc(id)
        .collection('dailies')
        .where('status', '==', 'active')
        .orderBy('capturedAt', 'desc')
        .limit(1)
        .get();

      return snapshot.empty ? {} : snapshot.docs[0].data();
    }

    const [firstDaily, secondDaily] = await Promise.all([
      lastDaily(userId),
      lastDaily(targetId),
    ]);

    // Le righe allegate ai due cuori si **scambiano**: nella riga di ciascuno
    // finisce quello che ha scritto l'altro. Fino a questo istante nessuna
    // delle due era leggibile da nessuno, ed e' cio' che rende innocuo
    // scrivere a chi poi ti passa oltre.
    const myMessage = snapshot.data().message || '';
    const theirMessage = reciprocal.data().message || '';
    const distance = distanceKm(first, second);

    // Una riga per parte: ciascuno legge solo la propria collezione, e ci
    // trova gia' dentro i dati dell'altro senza doverne leggere il profilo.
    const batch = db.batch();

    batch.set(
      db.collection('users').doc(userId).collection('matches').doc(targetId),
      {
        userId: targetId,
        name: second.name || '',
        age: ageFrom(second.birthDate, now),
        icebreaker: second.icebreaker || '',
        interests: interestsOf(second),
        photoUrl: secondDaily.downloadUrl || '',
        vibe: secondDaily.vibe || '',
        // Serve a sapere quando la foto scade: senza, la scheda non potrebbe
        // distinguere "non c'e'" da "e' scaduta".
        photoCapturedAt: secondDaily.capturedAt || null,
        profilePhotoUrl:
          second.photoStatus === 'active' ? second.photoUrl || '' : '',
        distanceKm: distance,
        message: theirMessage,
        // Anche la propria: la schermata del match apre con le due righe una
        // sotto l'altra, ed e' quello che evita il "ciao" / "ciao".
        myMessage,
        matchedAt,
      },
      { merge: true },
    );

    batch.set(
      db.collection('users').doc(targetId).collection('matches').doc(userId),
      {
        userId,
        name: first.name || '',
        age: ageFrom(first.birthDate, now),
        icebreaker: first.icebreaker || '',
        interests: interestsOf(first),
        photoUrl: firstDaily.downloadUrl || '',
        vibe: firstDaily.vibe || '',
        photoCapturedAt: firstDaily.capturedAt || null,
        profilePhotoUrl:
          first.photoStatus === 'active' ? first.photoUrl || '' : '',
        distanceKm: distance,
        message: myMessage,
        myMessage: theirMessage,
        matchedAt,
      },
      { merge: true },
    );

    for (const id of [userId, targetId]) {
      batch.set(
        dayStatsRef(id, today),
        { dateKey: today, matches: increment(1) },
        { merge: true },
      );
      batch.set(
        lifetimeStatsRef(id),
        { totalMatches: increment(1) },
        { merge: true },
      );
    }

    await batch.commit();

    logger.info('Match creato', { userId, targetId });
  },
);

/**
 * Dopo ventiquattr'ore l'Istantanea sparisce: il file, il documento e tutte le
 * copie finite nei feed altrui.
 *
 * Sparisce **la foto**, non la giornata: i numeri restano nelle statistiche,
 * che vivono in un altro posto proprio per questo. E' il patto dell'app detto
 * fino in fondo — quello che si e' mostrato non resta a giro per sempre, ma
 * quello che e' successo si puo' ancora guardare.
 *
 * Gira ogni ora invece che una volta al giorno: cosi' nessuna foto sopravvive
 * piu' di un'ora oltre il suo termine, e ogni passata ha poco da fare.
 */
exports.cleanupExpiredDailies = onSchedule('every 60 minutes', async () => {
  const cutoff = new Date(Date.now() - DAILY_LIFETIME_MS);
  const bucket = admin.storage().bucket();

  const expired = await db
    .collectionGroup('dailies')
    .where('capturedAt', '<', cutoff)
    .limit(200)
    .get();

  let files = 0;

  for (const doc of expired.docs) {
    const daily = doc.data();

    if (daily.storagePath) {
      await bucket
        .file(daily.storagePath)
        .delete()
        .then(() => {
          files += 1;
        })
        .catch((error) => {
          // Un file gia' sparito non e' un guasto: il documento va tolto lo
          // stesso, altrimenti resterebbe a puntare nel vuoto per sempre.
          logger.warn('Foto scaduta non cancellata', {
            storagePath: daily.storagePath,
            message: error.message,
          });
        });
    }

    await doc.ref.delete();
  }

  // Le copie nei feed altrui si cancellano a parte: non stanno sotto la Daily,
  // stanno sotto ciascuno di quelli che potevano vederla.
  const staleFeed = await db
    .collectionGroup('feed')
    .where('capturedAtMillis', '<', cutoff.getTime())
    .limit(BATCH_LIMIT)
    .get();

  if (!staleFeed.empty) {
    const batch = db.batch();

    for (const doc of staleFeed.docs) {
      batch.delete(doc.ref);
    }

    await batch.commit();
  }

  logger.info('Pulizia delle Istantanee scadute', {
    dailies: expired.size,
    file: files,
    vociDiFeed: staleFeed.size,
  });
});
