'use strict';

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const vision = require('@google-cloud/vision');

admin.initializeApp();

const db = admin.firestore();

// **L'email di conferma la scriviamo e la mandiamo noi.** Vedi `posta.js`:
// l'indirizzo a cui portano i link di Firebase non si puo' cambiare su questo
// progetto, e girandoci intorno si e' arrivati a una soluzione migliore di
// quella che si voleva.
exports.mandaLaConferma = require('./posta').mandaLaConferma;
exports.mandaIlRecupero = require('./posta').mandaIlRecupero;

/**
 * Il suono di CRASY: tre note che salgono, mezzo secondo.
 *
 * **Sono due nomi per la stessa cosa.** Su iPhone il file sta dentro il
 * pacchetto dell'app e si chiama con l'estensione; su Android e' una risorsa e
 * si chiama senza. Sbagliarne uno non da' nessun errore: suona quello di
 * sistema, e non lo si scopre finche' qualcuno non se ne accorge.
 *
 * Il file lo fabbrica `tool/suono_della_notifica.py`. Cambiando le tre note
 * li' dentro cambia il suono qui, senza toccare una riga di questo file.
 */
const SUONO_APPLE = 'crasy.wav';
const SUONO_ANDROID = 'crasy';

/** Il rosso di CRASY, che su Android colora l'icona della notifica. */
const ROSSO = '#FA0000';

/**
 * Il canale su cui ascoltano tutti i telefoni.
 *
 * **Serve a non pagare un annuncio a testa.** Mandare "c'e' una missione
 * nuova" a diecimila persone leggendo diecimila indirizzi vuol dire diecimila
 * letture e diecimila messaggi, ogni volta che qualcuno crea una gara. Su un
 * canale si manda **un messaggio solo**: chi e' iscritto lo riceve, e a tenere
 * l'elenco ci pensa Google.
 *
 * Vale solo per le cose che riguardano tutti — una missione nuova, la sfida
 * del giorno. Una fiamma sulla tua foto riguarda te, e quella continua a
 * viaggiare sul tuo indirizzo.
 */
const CANALE_DI_TUTTI = 'tutti';

/**
 * Manda un annuncio a tutti quanti.
 *
 * Non scrive niente nella campanella di nessuno, ed e' voluto: una riga per
 * persona sarebbe una scrittura per persona — il conto piu' salato che questa
 * app possa farsi — per dire una cosa che sta gia' in prima pagina. Qui
 * l'annuncio serve solo a far accendere lo schermo di chi non ha l'app aperta.
 */
/**
 * Oltre questo numero di telefoni, l'annuncio passa dal canale.
 *
 * **Sotto, si va a bussare a uno per uno.** Il canale costa un messaggio solo a
 * qualunque numero di persone, ma raggiunge **solo chi si e' iscritto** — e
 * iscriversi lo fa l'app, quindi solo chi ha una versione abbastanza nuova.
 * Bussare a uno per uno costa una lettura per telefono, che con dieci telefoni
 * e' niente e con diecimila e' il conto piu' salato dell'app.
 *
 * Finche' siamo in pochi vince il secondo modo, per una ragione che non ha a
 * che fare con i soldi: **funziona su tutte le versioni**, anche su quelle
 * gia' installate. Quando saremo in tanti, saranno tutti su versioni che si
 * iscrivono da sole, e si passera' al canale senza toccare niente.
 */
const TELEFONI_OLTRE_I_QUALI_CONVIENE_IL_CANALE = 2000;

async function annuncia(corpo, dati) {
  const messaggio = {
    notification: { title: 'CRASY', body: corpo },
    data: dati,
    apns: { payload: { aps: { sound: SUONO_APPLE, badge: 1 } } },
    android: {
      priority: 'high',
      notification: { sound: SUONO_ANDROID, color: ROSSO },
    },
  };

  // Uno in piu' del limite: se arrivano tutti, vuol dire che ce n'e' almeno
  // uno oltre, e tanto basta per decidere senza contarli davvero.
  const telefoni = await db
    .collectionGroup('devices')
    .limit(TELEFONI_OLTRE_I_QUALI_CONVIENE_IL_CANALE + 1)
    .get();

  if (telefoni.size > TELEFONI_OLTRE_I_QUALI_CONVIENE_IL_CANALE) {
    await admin.messaging().send({ ...messaggio, topic: CANALE_DI_TUTTI });
    logger.info('annuncio dal canale', { corpo });

    return;
  }

  if (telefoni.empty) {
    logger.warn('annuncio senza nessuno a cui mandarlo', { corpo });

    return;
  }

  // **Lo stesso telefono, una volta sola.**
  //
  // Un indirizzo puo' comparire sotto due persone diverse: chi cambia account
  // senza uscire pulito lascia il proprio telefono scritto anche nella casella
  // di prima, e da quel momento e' registrato due volte. Per le notifiche
  // personali non e' un problema — sono di uno e vanno a uno — ma un annuncio
  // va a tutti, e senza questa riga quel telefono suona due volte per la stessa
  // cosa. E' il difetto che si vede subito e fa pensare che l'impianto sia
  // rotto, mentre sta solo facendo diligentemente quello che gli si era detto.
  //
  // Vince il primo che si incontra: l'altro e' una copia, e cancellare copie
  // che potrebbero essere ancora vive non e' compito di chi manda un annuncio.
  const perIndirizzo = new Map();

  for (const doc of telefoni.docs) {
    if (!perIndirizzo.has(doc.id)) {
      perIndirizzo.set(doc.id, doc);
    }
  }

  const unici = [...perIndirizzo.values()];
  const indirizzi = unici.map((doc) => doc.id);
  let inviate = 0;
  let fallite = 0;

  // A cinquecento per volta: e' il tetto di una spedizione sola.
  for (let inizio = 0; inizio < indirizzi.length; inizio += 500) {
    const pezzo = indirizzi.slice(inizio, inizio + 500);
    const esito = await admin
      .messaging()
      .sendEachForMulticast({ ...messaggio, tokens: pezzo });

    inviate += esito.successCount;
    fallite += esito.failureCount;

    // Gli indirizzi morti si tolgono qui come si tolgono nelle notifiche
    // personali: lasciandoli, ogni annuncio futuro prova a raggiungerli e
    // fallisce, e dopo qualche mese l'elenco e' fatto piu' di morti che di vivi.
    await Promise.all(
      esito.responses.map((risposta, i) => {
        const codice = risposta.error?.code || '';

        if (
          codice === 'messaging/registration-token-not-registered' ||
          codice === 'messaging/invalid-registration-token' ||
          codice === 'messaging/invalid-argument'
        ) {
          return unici[inizio + i].ref.delete();
        }

        return null;
      })
    );
  }

  logger.info('annuncio mandato', {
    corpo,
    inviate,
    fallite,
    // Quanti erano scritti due volte: se questo numero cresce, c'e' gente che
    // cambia account senza uscire pulito.
    doppioni: telefoni.size - unici.length,
  });
}

// I soldi stanno in un file a parte, e le sue funzioni si esportano da qui:
// tutto quello che tocca denaro si legge in un posto solo.
//
// **Restano spente finche' non si accendono di proposito.** Le funzioni dei
// pagamenti dichiarano due segreti di Stripe, e dichiararli obbliga il
// caricamento a interrogare Secret Manager: finche' quel servizio non e'
// attivo e le chiavi non ci sono, il tentativo fallisce — e con lui fallisce
// il caricamento di **tutte** le altre funzioni, comprese quelle che con i
// soldi non c'entrano niente. Una parte non finita che impedisce di pubblicare
// il resto e' una parte che va tenuta fuori.
//
// Si accendono cosi', il giorno in cui i pagamenti partono davvero:
//
//     firebase functions:secrets:set STRIPE_SECRET_KEY
//     firebase deploy --only functions --set-env-vars CRASY_PAYMENTS=on
if (process.env.CRASY_PAYMENTS === 'on') {
  const payments = require('./payments');

  exports.startChallengePayment = payments.startChallengePayment;
  exports.stripeWebhook = payments.stripeWebhook;
  exports.createPayoutOnboarding = payments.createPayoutOnboarding;
  exports.withdrawWallet = payments.withdrawWallet;
}

// Stessa regione del database: una funzione che scrive su Firestore va dove sta
// il database, altrimenti ogni scrittura fa un giro per mezzo mondo.
// **Il tetto alle istanze e' un tetto alla spesa, non alla velocita'.**
//
// Dieci copie in parallelo bastano largamente per il traffico di oggi. Serve
// contro il caso in cui qualcosa vada in circolo — una funzione che scrive un
// documento che risveglia la funzione stessa — dove senza tetto la fattura
// cresce finche' non se ne accorge qualcuno. Con il tetto, il peggio che
// succede e' che le notifiche arrivino qualche secondo dopo.
//
// Anche il tempo massimo e la memoria sono voci di spesa: si paga a
// millisecondi per gigabyte. Nessuna di queste funzioni ha niente da fare per
// mezzo minuto, e mezzo giga e' il doppio di quanto serva a mandare una
// notifica.
setGlobalOptions({
  region: 'europe-west8',
  maxInstances: 10,
  timeoutSeconds: 60,
  memory: '256MiB',
});

/**
 * Manda una notifica ai telefoni di una persona sola.
 *
 * **Stava dentro la funzione delle notifiche, e adesso serve a due.** Le
 * richieste di amicizia hanno bisogno esattamente di questo lavoro — trovare i
 * telefoni, mandare, buttare gli indirizzi morti — e copiarlo avrebbe voluto
 * dire due versioni della stessa cosa che si separano al primo cambiamento: si
 * corregge il suono in una e resta vecchio nell'altra.
 */
async function mandaAUnaPersona(userId, corpo, dati) {
  // Gli indirizzi dei telefoni di questa persona. Senza nessun dispositivo
  // registrato non c'e' niente da fare: la notizia resta nel database e si
  // vedra' riaprendo l'app.
  const dispositivi = await db
    .collection('users')
    .doc(userId)
    .collection('devices')
    .get();

  const indirizzi = dispositivi.docs.map((doc) => doc.id);

  // **Uscire in silenzio qui era un buco nella diagnosi.**
  //
  // Senza questa riga, nei registri "non e' partita" e "e' partita e non aveva
  // nessuno a cui mandare" si assomigliano: in tutti e due i casi non c'e'
  // scritto niente. Sono pero' due problemi opposti — uno sta nell'app che non
  // scrive la notizia, l'altro nel telefono che non si e' registrato — e
  // cercarli alla cieca costa un pomeriggio.
  if (indirizzi.length === 0) {
    logger.warn('nessun dispositivo registrato', { userId, ...dati });

    return;
  }

  const esito = await admin.messaging().sendEachForMulticast({
    tokens: indirizzi,
    notification: { title: 'CRASY', body: corpo },
    // Serve all'app per sapere dove portare chi tocca la notifica.
    data: dati,
    apns: { payload: { aps: { sound: SUONO_APPLE, badge: 1 } } },
    android: {
      priority: 'high',
      notification: { sound: SUONO_ANDROID, color: ROSSO },
    },
  });

  // **Gli indirizzi morti si cancellano subito.**
  //
  // Un telefono formattato, un'app disinstallata, un permesso revocato: da quel
  // momento l'indirizzo non risponde piu'. Lasciandolo li', ogni notifica
  // futura di quella persona prova a raggiungerlo e fallisce — e dopo qualche
  // mese l'elenco e' fatto piu' di morti che di vivi.
  const morti = [];

  esito.responses.forEach((risposta, i) => {
    const codice = risposta.error?.code || '';

    if (
      codice === 'messaging/registration-token-not-registered' ||
      codice === 'messaging/invalid-registration-token' ||
      codice === 'messaging/invalid-argument'
    ) {
      morti.push(indirizzi[i]);
    }
  });

  await Promise.all(
    morti.map((token) =>
      db
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(token)
        .delete()
        .catch(() => {})
    )
  );

  logger.info('notifica mandata', {
    userId,
    ...dati,
    inviate: esito.successCount,
    fallite: esito.failureCount,
    ripulite: morti.length,
  });
}


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

      // **Anche qui l'autore lo deve sapere.** Il silenzio e' lo stesso di
      // quello delle segnalazioni, ed e' anzi peggiore: qui la foto non e'
      // nemmeno mai comparsa, quindi chi l'ha mandata crede di essere in gara e
      // aspetta un risultato che non puo' arrivare.
      await avvisaChiLHaMandata(
        String(snapshot.get('userId') || ''),
        event.params.challengeId,
        String(snapshot.get('challengeTitle') || '')
      );
    }
  }
);

/**
 * Assegna il premio alle challenge scadute.
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
  // **Si chiude appena la gara finisce.**
  //
  // A decidere chi vince sono le fiamme, e le fiamme si fermano alla sirena:
  // non c'e' niente da aspettare. C'e' stato un periodo in cui si aspettavano
  // ventiquattro ore perche' chi aveva messo i soldi potesse scegliere, ed era
  // un giorno intero di silenzio fra la fine e il verdetto.
  const deadline = admin.firestore.Timestamp.now();

  // Le candidate sono le challenge finite a cui non e' stato assegnato nessun
  // vincitore. `winnerEntryId` nullo e' il segno che la proclamazione non e'
  // stata fatta.
  const expired = await db
    .collection('challenges')
    .where('endsAt', '<=', deadline)
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
 * Svuota le gare vecchie: documenti, partecipazioni, file.
 *
 * **Una gara chiusa smette di servire a qualcuno molto prima di smettere di
 * occupare spazio.** Chi voleva sapere chi ha vinto lo ha saputo il giorno
 * stesso; da li' in poi restano soltanto documenti da leggere in ogni query e
 * megabyte da pagare ogni mese. Dopo due giorni si buttano.
 *
 * Le due ore devono essere le stesse dei due giorni scritti nell'app —
 * `Challenge.winnersWindow` — e per un motivo preciso: se qui fosse piu' corto,
 * la schermata dei vincitori mostrerebbe gare i cui file sono gia' spariti,
 * cioe' rettangoli grigi al posto delle foto di chi ha vinto.
 *
 * **Non si tocca una gara con i soldi ancora fermi in cassa.** `held` vuol dire
 * che qualcuno ha pagato e nessuno ha ancora incassato: cancellarla vorrebbe
 * dire perdere le tracce di soldi veri. Restano li' finche' la chiusura non le
 * ha sistemate, e a quel punto il giro dopo se le prende.
 */
const PURGE_AFTER_HOURS = 48;

exports.purgeOldChallenges = onSchedule('every 60 minutes', async () => {
  const cutoff = admin.firestore.Timestamp.fromMillis(
    Date.now() - PURGE_AFTER_HOURS * 60 * 60 * 1000,
  );

  // Poche per volta: cancellare e' l'unica cosa che non si puo' disfare, e un
  // giro che ne prende venti ogni ora sta comodamente dietro a qualunque
  // quantita' di gare che questa app possa ragionevolmente produrre.
  const old = await db
    .collection('challenges')
    .where('purgedAt', '==', null)
    .where('endsAt', '<=', cutoff)
    .limit(20)
    .get();

  if (old.empty) {
    return;
  }

  const bucket = admin.storage().bucket();
  let challenges = 0;
  let files = 0;

  for (const challenge of old.docs) {
    if (challenge.get('prizeStatus') === 'held') {
      logger.warn(
        `Challenge ${challenge.id} scaduta con i soldi ancora in cassa: non la cancello.`,
      );
      continue;
    }

    const entries = await challenge.ref.collection('entries').limit(500).get();

    // **La foto che ha vinto non si tocca.**
    //
    // E' il trofeo: sta nella bacheca di chi ha vinto e in quella di chi ha
    // commissionato la gara, e cancellarla vorrebbe dire togliere a una persona
    // l'unica prova di aver preso dei soldi qui dentro. Si tiene **una foto per
    // gara** invece di quaranta, che e' il novantasette per cento di magazzino
    // risparmiato lo stesso.
    const winnerEntryId = challenge.get('winnerEntryId') || '';

    for (const entry of entries.docs) {
      const path = entry.get('storagePath');

      if (path && entry.id !== winnerEntryId) {
        try {
          await bucket.file(path).delete({ ignoreNotFound: true });
          files++;
        } catch (error) {
          logger.warn(`Non ho potuto cancellare ${path}.`, error);
        }
      }

      await entry.ref.delete();
    }

    // **La gara non si cancella piu': e' diventata il trofeo.**
    //
    // Il documento e' piccolo — poche righe di testo — e dentro ci sono il
    // titolo, il premio, chi ha vinto e l'indirizzo della foto. A pesare erano
    // le foto, e quelle se ne sono andate. Si segna il giro dello spazzino,
    // cosi' la prossima volta non ripassa da qui: senza questa riga il filtro
    // ripescherebbe sempre le stesse venti gare gia' svuotate, e quelle nuove
    // non arriverebbero mai in cima alla fila.
    await challenge.ref.update({
      purgedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    challenges++;
  }

  logger.info(`Svuotate ${challenges} challenge vecchie e ${files} file.`);
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

  await avvisaCheEFinita(challenge, entries.docs);

  // Il premio finisce nel portafoglio del vincitore. Non parte nessun
  // bonifico: i soldi sono suoi da adesso e li preleva quando vuole.
  try {
    await payments.payWinner(challenge.id);
  } catch (error) {
    logger.error(`Challenge ${challenge.id}: premio non accreditato.`, error);
  }

  await dropLosingMedia(challenge, ranked.slice(1));
}

/**
 * Dice a chi era in gara che la missione e' finita. **Senza dire chi ha vinto.**
 *
 * **Prima non lo diceva nessuno.** Le due righe *hai vinto* e *la missione e'
 * finita* non erano scritte da nessuna parte: l'app se le ricavava da sola
 * aprendo la campanella. Funzionava — ma solo per chi apriva la campanella.
 * Fuori dall'app non partiva niente, quindi **vincere non faceva squillare il
 * telefono**: una fiamma si', cinquanta euro no. Il momento piu' importante del
 * prodotto era l'unico silenzioso.
 *
 * **E qui non c'e' scritto chi ha vinto, di proposito.** Il finale si scopre
 * aprendo la missione, con il rullo di tamburi. Metterlo sulla schermata
 * bloccata vorrebbe dire raccontarlo a tutti prima che qualcuno arrivi, e
 * trasformare l'unico momento di attesa dell'app in una notifica gia' letta.
 *
 * **Va anche a chi ha messo i soldi**, che non e' fra i partecipanti: e' la
 * persona che ha pagato il premio, ed era l'unica a non ricevere mai una parola
 * su come fosse andata a finire la cosa che aveva lanciato.
 *
 * Il nome del documento e' sempre lo stesso — `finita_` piu' la gara — e non
 * per ordine: e' cio' che rende innocuo un secondo passaggio. Riscrivendolo non
 * nasce niente di nuovo, e il mestiere di mandare il push sta su **la nascita**
 * di un documento.
 */
async function avvisaCheEFinita(challenge, partecipazioni) {
  const titolo = challenge.get('title') || '';
  const chi = new Set();

  for (const entry of partecipazioni) {
    const userId = entry.get('userId');

    if (userId) {
      chi.add(String(userId));
    }
  }

  const padrone = challenge.get('createdByUserId');

  if (padrone) {
    chi.add(String(padrone));
  }

  if (chi.size === 0) {
    return;
  }

  const scrittura = db.batch();

  for (const userId of chi) {
    scrittura.set(
      db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc('finita_' + challenge.id),
      {
        kind: 'ended',
        // Nessun attore: non l'ha fatto una persona, e' scaduto il tempo.
        actorId: '',
        actorUsername: '',
        challengeId: challenge.id,
        challengeTitle: titolo,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }
    );
  }

  try {
    await scrittura.commit();
    logger.info(`Challenge ${challenge.id}: avvisate ${chi.size} persone.`);
  } catch (error) {
    // **Non si rovescia la chiusura per un avviso.** Il vincitore e' gia'
    // proclamato e i soldi sono gia' suoi: fallire qui e rifare tutto da capo
    // sarebbe scambiare una notifica mancata con una gara da riaprire.
    logger.error(`Challenge ${challenge.id}: avvisi non partiti.`, error);
  }
}

/**
 * Cancella i file delle partecipazioni che non hanno vinto.
 *
 * Una foto pesa qualche decimo di megabyte dopo essere stata rimpicciolita, un
 * video decine di volte tanto. Moltiplicato per venti partecipanti a gara e per
 * qualche gara al giorno, lo spazio diventa il costo piu' alto dell'app —
 * piu' dei premi — per tenere dei file che, passata la gara, non guarda piu'
 * nessuno.
 *
 * **Il documento resta.** Sparisce l'immagine, non la partecipazione: chi ha
 * partecipato, quante fiamme ha preso, chi ha vinto restano scritti per sempre.
 * Nel profilo, al posto della foto, compare il riquadro con il nome — la stessa
 * cosa che succede alle foto piu' vecchie di sei mesi, che il bucket cancella
 * da solo.
 *
 * **Questo lo puo' fare solo il server.** Dare a un telefono il permesso di
 * cancellare i file di altre persone e' una porta che non si richiude piu': qui
 * gira con l'SDK di amministrazione, che le regole non le attraversa, e agisce
 * su una gara che e' gia' finita e gia' proclamata.
 */
async function dropLosingMedia(challenge, losers) {
  if (losers.length === 0) {
    return;
  }

  const bucket = admin.storage().bucket();
  let removed = 0;

  for (const entry of losers) {
    const path = entry.get('storagePath');

    if (!path) {
      continue;
    }

    try {
      await bucket.file(path).delete({ ignoreNotFound: true });
      // Il documento resta, ma senza indirizzo: cosi' chi lo legge sa che la
      // foto non c'e' piu' invece di provare a scaricarla e trovare un errore.
      await entry.ref.update({ mediaUrl: '', mediaRemovedAt: admin.firestore.FieldValue.serverTimestamp() });
      removed++;
    } catch (error) {
      logger.warn(`Non ho potuto cancellare ${path}.`, error);
    }
  }

  logger.info(`Challenge ${challenge.id}: liberati ${removed} file.`);
}

/**
 * Butta gli account rimasti senza conferma dell'email.
 *
 * **Serve a liberare l'indirizzo, non a fare pulizia.** Chi si registra e non
 * riceve il messaggio — spam, indirizzo scritto storto, un fornitore di posta
 * che blocca quella di Firebase — resta con un account che esiste e non entra,
 * e con un indirizzo che da quel momento risulta gia' usato: non puo' rifare la
 * registrazione, non puo' recuperare niente, non puo' fare nient'altro. E' un
 * vicolo cieco che abbiamo costruito noi, e chi ci finisce dentro se ne va.
 *
 * L'app fa gia' la stessa cosa quando quella persona e' ferma sulla schermata
 * della conferma. Questo copre il caso in cui non ci torna piu': l'account
 * resterebbe li' per sempre a tenere occupato un indirizzo.
 *
 * Un'ora, ed e' la stessa scritta nell'app (`_window` in `verify_email_page`):
 * se le due misure divergessero, l'app direbbe che il tempo e' scaduto mentre
 * il server la pensa diversamente, o il contrario.
 *
 * **Non tocca chi ha confermato**, e non tocca chi si e' appena registrato: le
 * due condizioni sono in `and`, e nessuna delle due e' facoltativa.
 */
const UNVERIFIED_WINDOW_HOURS = 1;

/**
 * Quante ore si aspetta chi non ha confermato **il numero di telefono**.
 *
 * **Ventiquattro, e non una come per l'email.** Non e' incoerenza: i due muri
 * costano cose diverse a chi ci resta davanti.
 *
 * L'email si conferma con un tocco su un messaggio che e' gia' arrivato, dallo
 * stesso telefono che si ha in mano. Chi non lo fa entro un'ora non lo fara'
 * mai, e nel frattempo tiene bloccato il proprio indirizzo — che e' il vero
 * danno: non puo' nemmeno rifare la registrazione.
 *
 * Il numero invece vuole un SMS, cioe' qualcosa che dipende da un operatore, da
 * una scheda, dal campo. **Uno che si iscrive alle undici di sera con il
 * telefono di lavoro in mano e finisce la mattina dopo esiste davvero**, e con
 * un'ora sola gli avremmo cancellato l'account mentre dormiva — insieme al nome
 * utente che aveva appena scelto.
 *
 * Ventiquattro ore sono abbastanza perche' nessuno perda niente per un
 * contrattempo, e abbastanza poche perche' un nome utente non resti prenotato
 * per mesi da un account che non puo' fare niente.
 */
const PHONE_WINDOW_HOURS = 24;

/**
 * Butta il profilo e tutto quello che gli sta sotto.
 *
 * **Cancellare l'account non cancella il profilo**, e sono due cose separate:
 * uno sta in Firebase Authentication, l'altro nel database. Chi si ferma al
 * muro del telefono ha gia' fatto l'onboarding, quindi un profilo ce l'ha — e
 * dentro c'e' il nome utente. Buttando solo l'account, quel nome resterebbe
 * prenotato per sempre da qualcuno che non esiste piu'.
 *
 * Le sottoraccolte non se ne vanno con il padre: cancellare `users/pippo`
 * lascia in vita `users/pippo/devices`, che resta li' invisibile e continua a
 * ricevere notifiche. Si chiedono a Firestore invece di elencarle a mano, cosi'
 * il giorno che ne nasce una nuova questa funzione la butta senza che nessuno
 * si ricordi di aggiungerla qui.
 */
async function buttaIlProfilo(userId) {
  const profilo = db.collection('users').doc(userId);

  for (const sotto of await profilo.listCollections()) {
    const righe = await sotto.limit(500).get();

    await Promise.all(righe.docs.map((riga) => riga.ref.delete()));
  }

  await profilo.delete();
}

exports.purgeUnverifiedAccounts = onSchedule('every 60 minutes', async () => {
  const adesso = Date.now();
  const scadenzaEmail = adesso - UNVERIFIED_WINDOW_HOURS * 60 * 60 * 1000;
  const scadenzaTelefono = adesso - PHONE_WINDOW_HOURS * 60 * 60 * 1000;
  const senzaEmail = [];
  const senzaTelefono = [];
  let pagina;

  do {
    const elenco = await admin.auth().listUsers(1000, pagina);

    for (const persona of elenco.users) {
      const nato = Date.parse(persona.metadata.creationTime);

      if (!persona.emailVerified) {
        if (nato < scadenzaEmail) {
          senzaEmail.push(persona.uid);
        }

        continue;
      }

      // **Il numero si legge dall'account, non dal profilo.**
      //
      // Quando si conferma il codice, il numero viene *agganciato* all'account
      // che gia' esiste: da quel momento sta li', accanto all'email. Leggerlo
      // da qui costa zero, mentre andarlo a cercare nel profilo di ognuno
      // vorrebbe dire una lettura del database per ogni iscritto, ogni ora, per
      // sempre — e sarebbe il conto piu' salato dell'app per una funzione che
      // il novanta per cento delle volte non trova niente da fare.
      if (!persona.phoneNumber && nato < scadenzaTelefono) {
        senzaTelefono.push(persona.uid);
      }
    }

    pagina = elenco.pageToken;
  } while (pagina);

  // Chi si e' fermato al telefono ha gia' un profilo con dentro il nome utente:
  // va buttato anche quello, o il nome resta prenotato da nessuno.
  for (const userId of senzaTelefono) {
    await buttaIlProfilo(userId);
  }

  const daButtare = senzaEmail.concat(senzaTelefono);

  if (daButtare.length === 0) {
    return;
  }

  // A blocchi di mille, che e' il massimo che l'API accetta per volta.
  for (let i = 0; i < daButtare.length; i += 1000) {
    await admin.auth().deleteUsers(daButtare.slice(i, i + 1000));
  }

  logger.info('account mai completati, buttati', {
    senzaEmail: senzaEmail.length,
    senzaTelefono: senzaTelefono.length,
  });
});

/**
 * Manda la notifica push quando ne nasce una nella casella di qualcuno.
 *
 * **Perche' serve il server.** L'app scrive gia' la notifica nel database, e chi
 * ha CRASY aperta la vede comparire da sola. Ma il novanta per cento delle
 * volte l'app e' chiusa: senza qualcuno che parli con Apple e con Google, quella
 * notifica la si scopre riaprendo l'app — cioe' quando non serve piu' a niente.
 * Le notifiche non servono a informare chi c'e' gia': servono a far tornare chi
 * se n'e' andato.
 *
 * Il messaggio si costruisce qui e non nell'app perche' e' l'unico posto che
 * sa a chi sta parlando e in che lingua, e perche' quello che arriva sullo
 * schermo bloccato deve essere corto: una riga, un nome, e cosa e' successo.
 */
exports.sendPushOnNotification = onDocumentCreated(
  'users/{userId}/notifications/{notificationId}',
  async (event) => {
    const dati = event.data?.data();

    if (!dati) {
      logger.warn('notifica senza contenuto', { path: event.data?.ref.path });

      return;
    }

    logger.info('notifica ricevuta', {
      kind: dati.kind,
      userId: event.params.userId,
    });

    const userId = event.params.userId;
    const chi = dati.actorUsername || 'qualcuno';
    const gara = dati.challengeTitle || '';

    // Una riga per tipo. Corte apposta: sullo schermo bloccato di un telefono
    // ne entrano due, e la seconda la legge quasi nessuno.
    // **Il titolo e' sempre CRASY, il resto e' una riga sola e generica.**
    //
    // Due ragioni. La prima: sullo schermo bloccato quello che si legge per
    // primo e' il titolo, ed e' li' che deve stare **il nome**, non il tipo di
    // avviso. Chi guarda il telefono da lontano deve capire da chi arriva prima
    // ancora di leggere cosa dice.
    //
    // La seconda: senza il nome di chi ha fatto la cosa, la notifica **non
    // rivela niente a chi ha il telefono in mano** — e uno schermo bloccato lo
    // leggono anche gli altri. Chi vuole sapere chi e' stato apre l'app, dove
    // la campanella lo dice per esteso.
    const testi = {
      win: gara ? `Hai vinto ${gara}` : 'Hai vinto',
      fire: 'Una fiamma nuova sulla tua foto',
      participation: gara
        ? `Qualcuno è sceso in gara: ${gara}`
        : 'Qualcuno è sceso in gara nella tua missione',
      // **Non dice chi ha vinto, e non e' una dimenticanza.** Chi tocca
      // questa notifica atterra sulla missione, dove la vittoria si scopre con
      // il rullo di tamburi. Scriverla qui vorrebbe dire raccontare il finale
      // sulla schermata bloccata e far arrivare tutti a cose fatte.
      ended: gara ? `È finita: ${gara}` : 'La missione è finita',
      // **Non dice perche', e non dice chi.** Le segnalazioni sono anonime
      // per costruzione, e su una schermata bloccata che leggono anche gli
      // altri questa e' comunque una notizia spiacevole: la riga resta secca,
      // e il resto sta in campanella.
      removed: 'La tua foto è stata tolta dalla gara',
      comment: 'Nuovo commento sotto la tua foto',
      mention: 'Ti hanno nominato in un commento',
      friendRequest: 'Hai una richiesta di amicizia',
      comeback: 'Ci sono missioni aperte. Entra e prova a vincere',
    };

    const corpo = testi[dati.kind] || 'Qualcosa di nuovo ti aspetta';

    await mandaAUnaPersona(userId, corpo, {
      kind: String(dati.kind || ''),
      challengeId: String(dati.challengeId || ''),
      // **Quale riga, non solo quale specie.** Senza questo, toccare la
      // notifica apre la campanella e poi tocca a chi guarda ritrovare da solo
      // la cosa per cui era venuto, in mezzo a tutte le altre. Con il nome del
      // documento l'app la trova e la accende.
      notificationId: String(event.params.notificationId || ''),
    });
  }
);

/**
 * Avvisa chi ha ricevuto una richiesta di amicizia.
 *
 * **Perche' ci vuole una funzione a parte.** Le richieste di amicizia non sono
 * scritte come notifiche: la campanella le **ricava** dall'elenco delle
 * richieste, che e' l'unica verita' su chi ha suonato al campanello. E' una
 * scelta giusta — una notifica scritta sarebbe una copia che va fuori sincrono
 * appena qualcuno ritira la richiesta, e in campanella resterebbe l'avviso di
 * una cosa che non c'e' piu'.
 *
 * Il prezzo di quella scelta e' che la funzione che manda le notifiche non si
 * accorge di niente: aspetta che nasca un documento fra le notifiche, e qui non
 * ne nasce nessuno. Percio' si guarda direttamente il posto dove la richiesta
 * arriva.
 *
 * **E' l'unica cosa dell'app che aspetta una risposta.** Tutto il resto e' roba
 * che e' successa e che si guarda quando si vuole; una richiesta lasciata la'
 * tiene qualcun altro ad aspettare, e quel qualcuno non ha modo di sapere se
 * l'hai vista.
 */
exports.sendPushOnFriendRequest = onDocumentCreated(
  'users/{userId}/friendRequests/{fromId}',
  async (event) => {
    // Chi l'ha mandata non si dice: uno schermo bloccato lo leggono anche gli
    // altri, ed e' la stessa regola che vale per le fiamme e i commenti. Il
    // nome sta in campanella, che e' anche il posto dove si accetta.
    await mandaAUnaPersona(event.params.userId, 'Hai una richiesta di amicizia', {
      kind: 'friendRequest',
      challengeId: '',
      // Le richieste non sono documenti della campanella: la riga si ricava
      // dall'elenco delle richieste, e il suo nome e' chi l'ha mandata.
      notificationId: 'amicizia_' + String(event.params.fromId || ''),
    });
  }
);

/**
 * Dopo quante ore di assenza si prova a richiamare qualcuno.
 *
 * **Dieci, ed erano tre giorni.** Il cambio non e' una taratura: e' un cambio
 * di ruolo. Finche' ogni missione nuova faceva squillare i telefoni, questo era
 * un "ci manchi" da spendere con parsimonia; adesso che gli annunci per
 * missione non ci sono piu', **e' l'unica cosa che riporta indietro chi non ha
 * ancora l'abitudine di aprire l'app** — e a tre giorni di distanza quella
 * abitudine non si forma, perche' nel frattempo non e' successo niente.
 *
 * Dieci ore e non ventiquattro perche' il richiamo parte alle sei di sera: con
 * ventiquattro chiedeva di aver saltato un giorno intero, e chi aveva aperto
 * l'app ieri a tarda sera restava fuori dal giro di oggi. Con dieci basta non
 * aver aperto **da stamattina**, che e' la differenza fra un richiamo che
 * arriva mentre la giornata si puo' ancora recuperare e uno che arriva quando
 * e' andata.
 *
 * Su CRASY una giornata e' un'unita' vera: le partecipazioni sono cinque al
 * giorno, la sfida cambia a mezzanotte, le gare scadono. Chi salta un giorno
 * non ha saltato un momento qualunque — ha saltato tutto quello che c'era.
 *
 * Quante volte arriva non lo decide questo numero ma quello qui sotto: dieci
 * ore allarga **chi** viene richiamato, non ogni quanto.
 */
const ORE_DI_ASSENZA = 10;

/**
 * Ogni quante ore si puo' richiamare la stessa persona.
 *
 * **Quarantotto.** Un richiamo al giorno diventa carta da parati: si smette di
 * leggerlo dopo tre volte, e la quarta e' quella in cui uno va nelle
 * impostazioni e spegne tutto — e spente restano spente per sempre, anche per
 * la fiamma sulla sua foto che gli avrebbe fatto piacere ricevere.
 *
 * Un giorno si, un giorno no: si nota ancora, e non stanca.
 */
const ORE_FRA_UN_RICHIAMO_E_L_ALTRO = 48;

/**
 * Richiama chi non si fa vedere da qualche giorno.
 *
 * **E' l'unica notifica che non nasce da un fatto.** Tutte le altre raccontano
 * qualcosa che e' successo a chi le riceve — una fiamma, un commento, una
 * vittoria — e per questo sono sempre benvenute. Questa invece la mandiamo noi
 * perche' ci fa comodo, e quel privilegio va speso con misura: solo dopo un
 * giorno di silenzio, non piu' di una ogni due giorni, e solo se ci sono
 * davvero delle gare aperte da guardare.
 *
 * Quest'ultima condizione e' la piu' importante: promettere "ci sono missioni
 * per te" e far trovare una schermata vuota e' peggio che non scrivere niente.
 */
exports.remindQuietUsers = onSchedule(
  { schedule: '0 18 * * *', timeZone: 'Europe/Rome' },
  async () => {
    const adesso = Date.now();
    const soglia = new Date(adesso - ORE_DI_ASSENZA * 3600000);
    const ultimoRichiamo = new Date(
      adesso - ORE_FRA_UN_RICHIAMO_E_L_ALTRO * 3600000
    );

    // **Prima si guarda se c'e' qualcosa da mostrare.** Senza gare aperte il
    // richiamo sarebbe una bugia, e una bugia sola basta a far spegnere le
    // notifiche a qualcuno per sempre.
    const gare = await db
      .collection('challenges')
      .where('endsAt', '>', new Date())
      .limit(1)
      .get();

    if (gare.empty) {
      logger.info('nessuna gara aperta: nessun richiamo');

      return;
    }

    // Le sei del pomeriggio e' l'ora in cui la gente ha il telefono in mano e
    // il tempo per uscire a fare una foto. Alle nove di mattina no.
    const assenti = await db
      .collection('users')
      .where('lastSeenAt', '<', soglia)
      .limit(200)
      .get();

    let mandati = 0;

    for (const persona of assenti.docs) {
      const dati = persona.data();
      const gia = dati.lastReminderAt?.toDate?.();

      if (gia && gia > ultimoRichiamo) {
        continue;
      }

      await db
        .collection('users')
        .doc(persona.id)
        .collection('notifications')
        .doc(`comeback__${new Date().toISOString().slice(0, 10)}`)
        .set({
          kind: 'comeback',
          actorId: '',
          actorUsername: '',
          challengeId: '',
          challengeTitle: '',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      await db.collection('users').doc(persona.id).set(
        { lastReminderAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );

      mandati += 1;
    }

    logger.info('richiami mandati', { mandati, esaminati: assenti.size });
  }
);


/** Dove il server si segna le cose che ha gia' fatto. */
const MEMORIA = db.collection('system').doc('annunci');

/**
 * Annuncia la sfida del giorno.
 *
 * **E' l'unico annuncio che parte da noi**, ed e' uno al giorno. Gli annunci
 * per ogni missione nuova sono stati tolti: chiunque puo' lanciare una gara, e
 * il giorno in cui l'app va bene sono decine di telefoni che squillano per
 * decine di gare — nessuno le legge, e chi si stufa spegne le notifiche per
 * sempre, comprese quelle che gli servivano. La sfida del giorno invece e'
 * una, e' a un'ora fissa, ed e' la stessa per tutti: si riconosce e si
 * aspetta, invece di sorprendere.
 *
 * **Non a mezzanotte, quando comincia.** La sfida dura ventiquattro ore esatte
 * e si apre allo scoccare, ma una notifica a quell'ora la sente solo chi non
 * stava dormendo, e la sente male. Alle nove il telefono e' in mano a tutti, e
 * restano quindici ore per uscire a fare la foto.
 *
 * Il documento si trova per nome — le sfide si chiamano con la loro data —
 * quindi qui non c'e' nessuna ricerca: una lettura sola, sempre.
 */
exports.announceDailyChallenge = onSchedule(
  { schedule: '0 9 * * *', timeZone: 'Europe/Rome' },
  async () => {
    // `sv-SE` scrive le date come `2026-09-02`, che e' esattamente il nome che
    // hanno le sfide. Il fuso e' quello italiano: la sfida di oggi e' quella
    // di oggi qui, non a Greenwich.
    const oggi = new Date().toLocaleDateString('sv-SE', {
      timeZone: 'Europe/Rome',
    });

    const memoria = await MEMORIA.get();

    // **Una sola volta al giorno, anche se la sveglia suona due volte.** Una
    // funzione programmata puo' essere rieseguita: senza questo, un secondo
    // giro manderebbe lo stesso annuncio a tutti.
    if (memoria.data()?.ultimaSfida === oggi) {
      logger.info('sfida del giorno gia annunciata', { oggi });

      return;
    }

    const sfida = await db.collection('challenges').doc(`daily-${oggi}`).get();

    if (!sfida.exists) {
      // Le sfide si scrivono a mano, un mese o due alla volta: se sono finite,
      // questo e' il posto in cui ce ne si accorge.
      logger.warn('nessuna sfida del giorno per oggi', { oggi });

      return;
    }

    const titolo = String(sfida.data().title || '').trim();

    await annuncia(
      titolo
        ? `Sfida del giorno: ${titolo}. Gratis, hai 24 ore`
        : 'C\'è la sfida del giorno. Gratis, hai 24 ore',
      { kind: 'daily', challengeId: sfida.id }
    );

    await MEMORIA.set({ ultimaSfida: oggi }, { merge: true });

    logger.info('sfida del giorno annunciata', { oggi, titolo });
  }
);

/**
 * Quante persone diverse devono segnalare una foto perche' esca dalla gara.
 *
 * **Trenta persone, non trenta segnalazioni.** La differenza e' tutta qui, e
 * non e' un controllo aggiunto apposta: il nome del documento di una
 * segnalazione mette insieme chi segnala e cosa, quindi la stessa persona che
 * tocca il tasto trenta volte riscrive trenta volte la stessa riga. A contare
 * e' l'elenco `reporters` scritto sulla foto, che e' un insieme.
 *
 * **Perche' un numero alto.** Una foto tolta e' un premio perso da qualcuno che
 * non ha fatto niente di male, se il numero e' sbagliato. Con una soglia bassa
 * bastano tre amici d'accordo per togliere di mezzo chi sta vincendo — e in una
 * gara con dei soldi in palio quel movente c'e' eccome. Trenta persone che si
 * mettono d'accordo sono un'organizzazione, non un dispetto.
 *
 * **Il rovescio, detto adesso.** Con pochi utenti trenta non si raggiunge mai:
 * di fatto questo controllo e' spento finche' CRASY non e' grande. E' voluto —
 * finche' le segnalazioni sono due al giorno si guardano a mano, ed e' meglio —
 * ma va ricordato, perche' un impianto che non e' mai scattato sembra rotto
 * quando serve. Il numero sta scritto qui e si cambia in una riga.
 */
const SEGNALAZIONI_PER_TOGLIERE = 30;

/**
 * Toglie dalla gara una foto che troppe persone hanno segnalato.
 *
 * **Non la cancella: la mette da parte.** `rejected` e' lo stesso stato che usa
 * il controllo automatico delle immagini — la foto sparisce dalla gara, non
 * prende piu' fiamme e non puo' vincere (`closeChallenge` salta le rifiutate),
 * ma il documento resta. Cancellare vorrebbe dire non poter piu' tornare
 * indietro su una decisione presa da un contatore, e un contatore non ha mai
 * guardato la foto.
 *
 * Si attacca alle segnalazioni e non alle foto di proposito: una foto viene
 * riscritta a ogni fiamma, e una funzione attaccata li' girerebbe a ogni voto
 * di ogni gara per non fare niente novecentonovantanove volte su mille.
 */
/**
 * Dice a chi ha mandato una foto che gliel'hanno tolta.
 *
 * **Prima non lo diceva nessuno.** La foto spariva dalla griglia e basta. Chi
 * l'aveva mandata restava dentro una gara con dei soldi in palio senza piu'
 * esserci davvero, e se ne accorgeva solo tornando a guardare — oppure non se
 * ne accorgeva affatto, e continuava ad aspettare un risultato che non poteva
 * arrivare. E' il tipo di silenzio che fa disinstallare un'app: uno non capisce
 * cos'e' successo, e la spiegazione piu' facile che si da' e' che sia rotta.
 *
 * **Non si dice chi ha segnalato, e non si dira' mai.** Le segnalazioni sono
 * anonime per costruzione: dirlo trasformerebbe una moderazione in una lite fra
 * due persone, e la segnalazione dopo non la manderebbe piu' nessuno.
 *
 * Il nome del documento porta dentro la gara e la foto, quindi due passaggi
 * sulla stessa rimozione non fanno due avvisi.
 */
async function avvisaChiLHaMandata(autore, challengeId, titolo) {
  if (!autore) {
    return;
  }

  try {
    await db
      .collection('users')
      .doc(autore)
      .collection('notifications')
      .doc('tolta_' + challengeId)
      .set({
        kind: 'removed',
        // Nessun attore: non e' stata una persona, sono state trenta.
        actorId: '',
        actorUsername: '',
        challengeId,
        challengeTitle: titolo,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  } catch (error) {
    // **Non si rovescia la rimozione per un avviso.** La foto e' gia' fuori
    // dalla gara, ed e' quella la cosa che doveva succedere: fallire qui e
    // rifare tutto vorrebbe dire rimetterla dentro.
    logger.error('avviso di rimozione non partito', { autore, challengeId, error });
  }
}

exports.hideHeavilyReportedEntry = onDocumentCreated(
  'reports/{reportId}',
  async (event) => {
    const dati = event.data?.data();

    if (!dati || dati.kind !== 'entry') {
      return;
    }

    const challengeId = String(dati.challengeId || '');
    const entryId = String(dati.entryId || '');

    if (!challengeId || !entryId) {
      return;
    }

    const foto = db
      .collection('challenges')
      .doc(challengeId)
      .collection('entries')
      .doc(entryId);

    const adesso = await foto.get();

    if (!adesso.exists) {
      return;
    }

    // L'elenco lo scrive l'app dentro la stessa scrittura della segnalazione:
    // quando questa funzione parte, chi ha appena segnalato e' gia' dentro.
    const chiHaSegnalato = adesso.get('reporters');
    const quanti = Array.isArray(chiHaSegnalato) ? chiHaSegnalato.length : 0;

    if (quanti < SEGNALAZIONI_PER_TOGLIERE) {
      return;
    }

    // Gia' fuori: non si riscrive. Serve a non rifare la stessa scrittura a
    // ogni segnalazione che arriva dopo la trentesima.
    if (adesso.get('moderation') === 'rejected') {
      return;
    }

    await foto.update({
      moderation: 'rejected',
      // **Perche' e' uscita, scritto sulla foto stessa.** Fra una tolta dal
      // riconoscimento immagini e una tolta dalle persone c'e' una differenza
      // enorme il giorno in cui qualcuno chiede spiegazioni, e senza questo
      // campo le due sono identiche.
      moderationReason: 'reports',
      moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.warn('foto tolta dalla gara per segnalazioni', {
      challengeId,
      entryId,
      quanti,
      autore: String(dati.reportedUserId || ''),
    });

    await avvisaChiLHaMandata(
      String(dati.reportedUserId || adesso.get('userId') || ''),
      challengeId,
      String(adesso.get('challengeTitle') || '')
    );
  }
);

/**
 * Un telefono appartiene a un account alla volta.
 *
 * **E' il difetto che faceva arrivare a uno le notifiche di un altro.** Chi
 * prova l'app con due account sullo stesso telefono — cosa normalissima mentre
 * si sviluppa, e non rara fra chi ha un profilo personale e uno di lavoro —
 * lasciava lo stesso indirizzo scritto in tutte e due le caselle. Da quel
 * momento il telefono riceveva **le notifiche di entrambi**: si metteva una
 * fiamma con un account e squillava per l'altro, come se ci si fosse avvisati
 * da soli.
 *
 * L'app toglie il proprio indirizzo quando qualcuno esce davvero, ma chi cambia
 * account senza uscire — o chi esce mentre la rete non va — lo lascia li'. E
 * dall'app non si puo' rimediare: le regole non lasciano a nessuno il permesso
 * di scrivere dentro la casella di qualcun altro, ed e' giusto cosi'.
 *
 * Quindi lo fa il server, appena l'indirizzo compare da qualche parte: lo cerca
 * ovunque e lo lascia **solo dove e' arrivato per ultimo**.
 */
exports.oneDevicePerAccount = onDocumentCreated(
  'users/{userId}/devices/{token}',
  async (event) => {
    const userId = event.params.userId;
    const token = event.params.token;

    // Si cerca per campo e non per nome del documento: il nome, in una query
    // sul gruppo di collezioni, vuole il percorso intero — che e' proprio
    // quello che non si conosce.
    const copie = await db
      .collectionGroup('devices')
      .where('token', '==', token)
      .get();

    const altrove = copie.docs.filter(
      (doc) => doc.ref.parent.parent.id !== userId
    );

    if (altrove.length === 0) {
      return;
    }

    await Promise.all(altrove.map((doc) => doc.ref.delete()));

    logger.info('telefono tolto dagli account vecchi', {
      userId,
      tolti: altrove.length,
    });
  }
);

/**
 * Un amico nuovo entra anche nelle gare fra amici gia' aperte.
 *
 * **Chi la puo' vedere e' scritto dentro la gara**, in `audience`, e quella
 * lista si scrive una volta sola: al lancio, con gli amici di quel momento. E'
 * la scelta giusta per come si leggono le gare — le regole non devono andare a
 * leggere l'elenco degli amici per ogni gara di ogni schermata, che vorrebbe
 * dire pagare una lettura in piu' a testa e, oltre una certa quantita', vedersi
 * rifiutare la query da Firestore.
 *
 * Il prezzo pero' e' che quella lista **invecchia**: chi diventa amico un'ora
 * dopo il lancio non vede una gara che dura sei ore, e non c'e' niente
 * nell'app che glielo spieghi. Non e' un dettaglio di poco conto: uno aggiunge
 * un amico **proprio perche'** gli ha detto di quella gara, apre la scheda
 * degli amici, e la trova vuota.
 *
 * Qui la lista si tiene aggiornata. L'amicizia sono due documenti — uno per
 * parte — e questa funzione scatta su tutti e due: quello di A aggiunge A alle
 * gare di B, quello di B aggiunge B alle gare di A. Nessuno dei due caso va
 * scritto a mano, la simmetria viene da sola.
 *
 * **Solo le gare ancora aperte.** Una finita non si puo' piu' giocare, e
 * infilarcisi dentro vorrebbe dire comparire fra i destinatari di una cosa che
 * si e' persa per definizione. `arrayUnion` non aggiunge due volte, quindi
 * un'amicizia disfatta e rifatta non gonfia niente.
 */
exports.openFriendChallengesToNewFriend = onDocumentCreated(
  'users/{userId}/friends/{friendId}',
  async (event) => {
    const nuovo = String(event.params.userId || '');
    const padrone = String(event.params.friendId || '');

    if (!nuovo || !padrone || nuovo === padrone) {
      return;
    }

    const adesso = admin.firestore.Timestamp.now();

    // Le gare **sue**, riservate agli amici, non ancora scadute. Il tetto e'
    // basso di proposito: sono le gare aperte di una persona sola, e se
    // qualcuno ne avesse lanciate cinquanta insieme il problema sarebbe
    // quello, non questa funzione.
    const aperte = await admin
      .firestore()
      .collection('challenges')
      .where('createdByUserId', '==', padrone)
      .where('endsAt', '>', adesso)
      .limit(50)
      .get();

    const daAprire = aperte.docs.filter((doc) => {
      const dati = doc.data() || {};
      const pubblica = (dati.audience || ['*']).includes('*');

      // **Le pubbliche si saltano.** Hanno `*` dentro `audience`: aggiungerci
      // un identificativo non cambierebbe chi le vede, e allungherebbe una
      // lista che ha un tetto di trecento nelle regole.
      if (pubblica || dati.scope !== 'friends') {
        return false;
      }

      const quanti = (dati.audience || []).length;

      // Il tetto delle regole e' trecento. Superarlo qui vorrebbe dire scrivere
      // un documento che poi **nessuno puo' piu' aggiornare**, nemmeno per
      // correggerlo: la regola guarda la dimensione a ogni scrittura.
      return quanti < 300 && !(dati.audience || []).includes(nuovo);
    });

    if (daAprire.length === 0) {
      return;
    }

    const scrittura = admin.firestore().batch();

    for (const doc of daAprire) {
      scrittura.update(doc.ref, {
        audience: admin.firestore.FieldValue.arrayUnion(nuovo),
      });
    }

    await scrittura.commit();

    logger.info('Gare fra amici aperte a chi e\' arrivato dopo', {
      nuovo,
      padrone,
      quante: daAprire.length,
    });
  }
);
