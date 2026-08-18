'use strict';

/**
 * I soldi.
 *
 * Tutto quello che tocca denaro sta qui dentro, e sta **sul server**. Non e' una
 * scelta di ordine: un importo calcolato sul telefono e' un importo che chi
 * possiede il telefono puo' cambiare, e qui gli importi diventano addebiti su
 * carte vere. Dal client arriva un identificativo di challenge e nient'altro —
 * mai una cifra.
 *
 * ## Il giro completo
 *
 * 1. **Si crea la challenge.** Nasce `prizeStatus: 'unpaid'` e non si vede da
 *    nessuna parte. Non e' una bozza: e' una challenge che non esiste.
 * 2. **Si paga.** `startChallengePayment` apre una pagina di pagamento Stripe
 *    per il premio piu' le commissioni. I soldi finiscono sul conto CRASY.
 * 3. **Stripe ci richiama.** Il webhook porta la challenge a `'held'` e fa
 *    partire il cronometro **da adesso**: sarebbe ingiusto far scadere il tempo
 *    mentre uno cercava la carta.
 * 4. **La challenge chiude, il server proclama il vincitore.** Se non ha
 *    partecipato nessuno, il premio torna indietro intero. Se qualcuno ha vinto,
 *    parte verso di lui il premio meno la percentuale di CRASY.
 * 5. **Il vincitore incassa.** La prima volta deve registrarsi su Stripe con
 *    documento e IBAN. Non e' una nostra pignoleria: pagare qualcuno senza
 *    sapere chi e' e' vietato per legge, e non c'e' modo di saltarlo.
 *
 * ## Perche' Stripe Connect e non dei bonifici
 *
 * Tenere i soldi di altre persone in attesa di darli a terzi e' un'attivita'
 * regolamentata. Con Connect **l'istituto di pagamento e' Stripe**, non noi:
 * CRASY resta una piattaforma che incassa una commissione. Facendolo a mano,
 * con un conto corrente e dei bonifici, servirebbe una licenza.
 */

const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

const db = admin.firestore();

// I due segreti stanno in Secret Manager e non nel codice, e non finiscono nel
// repository nemmeno per sbaglio:
//
//     firebase functions:secrets:set STRIPE_SECRET_KEY
//     firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY');
const STRIPE_WEBHOOK_SECRET = defineSecret('STRIPE_WEBHOOK_SECRET');

/** Dove torna la gente dopo aver pagato. */
const APP_URL = process.env.CRASY_APP_URL || 'https://crasy.app';

// ---------------------------------------------------------------------------
// I conti
// ---------------------------------------------------------------------------

/**
 * Le stesse costanti che l'app usa per **mostrare** i numeri, qui usate per
 * **addebitarli**.
 *
 * Sono scritte due volte, in due linguaggi, e non e' una svista: il telefono
 * deve poter dire "paghi 507,75" senza chiamare il server a ogni tasto, e il
 * server non deve fidarsi di quello che dice il telefono. Se un giorno divergono
 * il danno e' visibile subito — la cifra mostrata e quella addebitata non
 * coincidono — ed e' meglio di un server che si fida.
 *
 * L'originale sta in `lib/features/payments/domain/prize_ledger.dart`, con le
 * spiegazioni per esteso.
 */
const COMMISSION_BASIS_POINTS = 1000; // 10% a CRASY
const PROCESSING_BASIS_POINTS = 150; // 1,5% a Stripe
const PROCESSING_FIXED_CENTS = 25;

/** Quanto trattiene CRASY. Arrotondato per difetto: il resto va al vincitore. */
function commissionCents(prizeCents) {
  return Math.floor((prizeCents * COMMISSION_BASIS_POINTS) / 10000);
}

/** Quanto incassa il vincitore. */
function payoutCents(prizeCents) {
  return prizeCents - commissionCents(prizeCents);
}

/**
 * Quanto paga chi lancia la challenge: il premio **piu'** le commissioni.
 *
 * Stripe prende la sua percentuale sull'importo addebitato, che contiene la
 * commissione stessa: sommare l'1,5% del premio lascerebbe scoperto l'1,5%
 * dell'1,5%. Si cerca l'addebito il cui netto e' esattamente il premio, e si
 * arrotonda per eccesso — un centesimo in meno lo pagherebbe il vincitore.
 */
function chargeCents(prizeCents) {
  const numerator = (prizeCents + PROCESSING_FIXED_CENTS) * 10000;
  const denominator = 10000 - PROCESSING_BASIS_POINTS;

  return Math.ceil(numerator / denominator);
}

function stripeClient() {
  // Il pacchetto si carica qui e non in cima al file: senza la chiave impostata
  // il `require` andrebbe comunque a buon fine, ma tenerlo dentro rende
  // evidente che nessuna funzione che non tocca denaro lo carica.
  const Stripe = require('stripe');

  // Nessuna versione di API bloccata: si usa quella predefinita del pacchetto
  // installato. Un numero scritto qui e non aggiornato insieme al pacchetto e'
  // il modo piu' silenzioso di rompere i pagamenti dopo un aggiornamento.
  return new Stripe(STRIPE_SECRET_KEY.value());
}

// ---------------------------------------------------------------------------
// 1. Pagare una challenge
// ---------------------------------------------------------------------------

/**
 * Apre la pagina di pagamento per una challenge appena creata.
 *
 * Torna un indirizzo, non un modulo: la pagina e' quella ospitata da Stripe, e
 * questo significa che **i numeri di carta non passano mai da CRASY**. Non e'
 * pigrizia: e' la differenza fra dover rispettare lo standard PCI e non doverlo
 * fare, e vale anche per l'autenticazione a due fattori delle banche europee,
 * che quella pagina sa gia' gestire.
 */
exports.startChallengePayment = onCall(
  { secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    const userId = request.auth && request.auth.uid;

    if (!userId) {
      throw new HttpsError('unauthenticated', 'Serve un account.');
    }

    const challengeId = request.data && request.data.challengeId;

    if (typeof challengeId !== 'string' || challengeId.length === 0) {
      throw new HttpsError('invalid-argument', 'Manca la challenge.');
    }

    const ref = db.collection('challenges').doc(challengeId);
    const snapshot = await ref.get();

    if (!snapshot.exists) {
      throw new HttpsError('not-found', 'Challenge inesistente.');
    }

    // Paga chi l'ha lanciata, e nessun altro. Senza questo controllo chiunque
    // potrebbe pagare le challenge altrui — che sembra un problema teorico
    // finche' non si pensa a chi paga la propria con la carta di un altro.
    if (snapshot.get('createdByUserId') !== userId) {
      throw new HttpsError('permission-denied', 'Non e\' tua.');
    }

    const status = snapshot.get('prizeStatus');

    if (status && status !== 'unpaid') {
      throw new HttpsError('failed-precondition', 'Gia\' pagata.');
    }

    const prize = snapshot.get('prizeCents');

    if (!Number.isInteger(prize) || prize <= 0 || prize > 100000000) {
      throw new HttpsError('invalid-argument', 'Premio non valido.');
    }

    const stripe = stripeClient();

    const session = await stripe.checkout.sessions.create(
      {
        mode: 'payment',
        // Il pagamento e' in euro perche' il premio e' in euro: convertire la
        // valuta fra l'incasso e il pagamento al vincitore farebbe arrivare al
        // vincitore una cifra diversa da quella scritta sulla challenge.
        line_items: [
          {
            quantity: 1,
            price_data: {
              currency: 'eur',
              unit_amount: chargeCents(prize),
              product_data: {
                name: `Premio: ${snapshot.get('title') || 'challenge CRASY'}`,
                description:
                  'CRASY trattiene il premio fino alla fine della challenge, ' +
                  'poi lo gira a chi vince.',
              },
            },
          },
        ],
        // Nel metadato ci va solo l'identificativo. L'importo lo rilegge il
        // webhook dal database: se viaggiasse di qua, chi intercetta la
        // chiamata deciderebbe quanto vale la challenge.
        metadata: { challengeId, userId },
        success_url: `${APP_URL}/#/challenge/${challengeId}?pagato=1`,
        cancel_url: `${APP_URL}/#/crea?annullato=1`,
      },
      // Due tocchi sul bottone non devono aprire due pagamenti.
      { idempotencyKey: `challenge-checkout-${challengeId}` }
    );

    await ref.update({
      stripeCheckoutSessionId: session.id,
      paymentStartedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { url: session.url, chargeCents: chargeCents(prize) };
  }
);

// ---------------------------------------------------------------------------
// 2. Stripe ci richiama
// ---------------------------------------------------------------------------

/**
 * Il webhook: e' qui che una challenge diventa vera.
 *
 * **La firma si verifica sempre**, ed e' la riga piu' importante del file:
 * questo indirizzo e' pubblico, e senza la verifica chiunque potrebbe mandarci
 * un finto "pagamento riuscito" e pubblicare challenge da mille euro senza
 * tirare fuori un centesimo. Il corpo va letto grezzo — `request.rawBody` — che
 * e' il motivo per cui non si usa `onCall`: se qualcuno lo trasforma in JSON
 * prima, la firma non torna piu'.
 */
exports.stripeWebhook = onRequest(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (request, response) => {
    const stripe = stripeClient();

    let event;

    try {
      event = stripe.webhooks.constructEvent(
        request.rawBody,
        request.headers['stripe-signature'],
        STRIPE_WEBHOOK_SECRET.value()
      );
    } catch (error) {
      logger.error('Webhook con firma non valida.', error);
      response.status(400).send('firma non valida');

      return;
    }

    try {
      switch (event.type) {
        case 'checkout.session.completed':
          await onCheckoutCompleted(event.data.object);
          break;

        case 'charge.refunded':
          await onChargeRefunded(event.data.object);
          break;

        case 'account.updated':
          await onAccountUpdated(event.data.object);
          break;

        default:
          break;
      }
    } catch (error) {
      // Rispondere con un errore fa riprovare Stripe, che e' quello che si
      // vuole: un pagamento riuscito che non e' stato registrato e' un cliente
      // che ha pagato e non vede la sua challenge.
      logger.error(`Webhook ${event.type} fallito.`, error);
      response.status(500).send('riprova');

      return;
    }

    response.json({ received: true });
  }
);

/**
 * Il pagamento e' andato: la challenge si accende.
 *
 * Il cronometro riparte **da adesso** e non da quando la challenge e' stata
 * scritta. Chi ha impiegato dieci minuti a trovare la carta non deve trovarsi
 * una gara di ventiquattro ore che ne dura ventitre e cinquanta: la durata e'
 * quella che ha scelto, e comincia quando la challenge diventa visibile.
 */
async function onCheckoutCompleted(session) {
  const challengeId = session.metadata && session.metadata.challengeId;

  if (!challengeId) {
    return;
  }

  const ref = db.collection('challenges').doc(challengeId);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);

    if (!snapshot.exists) {
      return;
    }

    // Stripe puo' mandare lo stesso evento piu' volte, ed e' documentato che lo
    // faccia. Senza questo controllo, il secondo invio allungherebbe la
    // challenge di un'altra durata intera.
    if (snapshot.get('prizeStatus') === 'held') {
      return;
    }

    const now = admin.firestore.Timestamp.now();
    const startsAt = snapshot.get('startsAt');
    const endsAt = snapshot.get('endsAt');
    const durationMs =
      startsAt && endsAt ? endsAt.toMillis() - startsAt.toMillis() : 0;

    transaction.update(ref, {
      prizeStatus: 'held',
      stripePaymentIntentId: session.payment_intent || null,
      paidAt: now,
      startsAt: now,
      endsAt: admin.firestore.Timestamp.fromMillis(
        now.toMillis() + Math.max(durationMs, 60 * 60 * 1000)
      ),
    });
  });

  logger.info(`Challenge ${challengeId}: premio incassato, gara aperta.`);
}

async function onChargeRefunded(charge) {
  const challenges = await db
    .collection('challenges')
    .where('stripePaymentIntentId', '==', charge.payment_intent)
    .limit(1)
    .get();

  if (challenges.empty) {
    return;
  }

  await challenges.docs[0].ref.update({ prizeStatus: 'refunded' });
}

/**
 * Il vincitore ha finito di registrarsi su Stripe: si prova a pagarlo.
 *
 * E' il pezzo che chiude il caso piu' probabile di tutti — uno vince, scopre di
 * dover mettere il documento e l'IBAN, e lo fa il giorno dopo. Senza questo, il
 * premio resterebbe fermo finche' non torna a premere un bottone.
 */
async function onAccountUpdated(account) {
  const ready = account.payouts_enabled === true;
  const users = await db
    .collection('users')
    .where('stripeAccountId', '==', account.id)
    .limit(1)
    .get();

  if (users.empty) {
    return;
  }

  const userId = users.docs[0].id;
  await users.docs[0].ref.update({ payoutReady: ready });

  if (!ready) {
    return;
  }

  // Non c'e' nient'altro da fare: i premi sono gia' nel portafoglio da quando
  // la gara si e' chiusa. Questa registrazione serve solo a poterli prelevare,
  // ed e' il prelievo che la usa.
}

// ---------------------------------------------------------------------------
// 3. Incassare
// ---------------------------------------------------------------------------

/**
 * Apre la registrazione di chi deve incassare.
 *
 * Serve nome, documento e IBAN, una volta sola. Va detto per intero a chi lo
 * fa, invece di presentarlo come un modulo in piu': **e' la legge sul
 * riciclaggio**, vale per chiunque paghi qualcuno, e nessuna app la puo'
 * saltare. Un utente che capisce perche' lo sta facendo lo fa; uno a cui
 * compare un modulo di documenti senza spiegazioni se ne va.
 */
exports.createPayoutOnboarding = onCall(
  { secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    const userId = request.auth && request.auth.uid;

    if (!userId) {
      throw new HttpsError('unauthenticated', 'Serve un account.');
    }

    const stripe = stripeClient();
    const userRef = db.collection('users').doc(userId);
    const user = await userRef.get();

    let accountId = user.get('stripeAccountId');

    if (!accountId) {
      const account = await stripe.accounts.create({
        type: 'express',
        country: 'IT',
        email: request.auth.token.email,
        capabilities: { transfers: { requested: true } },
        business_type: 'individual',
        metadata: { userId },
      });

      accountId = account.id;
      await userRef.set({ stripeAccountId: accountId }, { merge: true });
    }

    const link = await stripe.accountLinks.create({
      account: accountId,
      type: 'account_onboarding',
      refresh_url: `${APP_URL}/#/profile?incasso=riprova`,
      return_url: `${APP_URL}/#/profile?incasso=fatto`,
    });

    return { url: link.url };
  }
);

/**
 * Il premio finisce nel portafoglio del vincitore.
 *
 * **Non parte un bonifico**, e la differenza e' tutta a favore di chi vince.
 * Bonificando subito servirebbe che il vincitore fosse gia' registrato con
 * documento e IBAN nel momento esatto in cui la gara si chiude — cioe' quasi
 * mai — e il premio resterebbe fermo in attesa di lui, con la challenge in uno
 * stato a meta'. Accreditandolo, **i soldi sono suoi dall'istante in cui
 * vince**: li vede nel profilo, e la registrazione la fa il giorno che decide
 * di prelevare.
 *
 * I soldi restano fisicamente su CRASY finche' non li preleva, ed e' scritto
 * chiaramente nel profilo: un portafoglio che non dice dove sono i soldi e' la
 * cosa piu' vicina a una truffa che si possa costruire in buona fede.
 *
 * Le due protezioni contro il doppio accredito sono diverse e servono entrambe:
 * la transazione impedisce a due chiamate simultanee di partire insieme, e il
 * cambio di stato della challenge — che avviene **dentro** la stessa
 * transazione dell'accredito — fa si' che la seconda non trovi piu' niente da
 * pagare. Un premio accreditato due volte e' denaro creato dal nulla.
 */
async function payWinner(challengeId) {
  const ref = db.collection('challenges').doc(challengeId);

  const paid = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);

    if (!snapshot.exists || snapshot.get('prizeStatus') !== 'held') {
      return null;
    }

    const winnerUserId = snapshot.get('winnerUserId');

    if (!winnerUserId) {
      return null;
    }

    const amount = payoutCents(snapshot.get('prizeCents') || 0);

    if (amount <= 0) {
      return null;
    }

    const userRef = db.collection('users').doc(winnerUserId);
    const movementRef = userRef.collection('wallet').doc(`premio_${challengeId}`);

    transaction.set(
      userRef,
      { walletCents: admin.firestore.FieldValue.increment(amount) },
      { merge: true }
    );

    // Il movimento accanto al saldo, sempre. Un numero che cambia senza una
    // riga che dica da dove viene e' un numero di cui non ci si fida.
    transaction.set(movementRef, {
      kind: 'prize',
      amountCents: amount,
      challengeId,
      challengeTitle: snapshot.get('title') || '',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.update(ref, {
      prizeStatus: 'paidOut',
      paidOutAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { winnerUserId, amount };
  });

  if (!paid) {
    return { paid: false, reason: 'non-pagabile' };
  }

  logger.info(
    `Challenge ${challengeId}: ${paid.amount} centesimi nel portafoglio di ` +
      `${paid.winnerUserId}.`
  );

  return { paid: true, amountCents: paid.amount };
}

/** Sotto questa cifra non si preleva: dieci euro. */
const MIN_WITHDRAWAL_CENTS = 1000;

/**
 * Prelevare quello che si ha nel portafoglio.
 *
 * L'ordine delle operazioni e' l'unica cosa che conta qui, ed e' questo: prima
 * si **sposta** il saldo in una casella "in uscita", poi si bonifica, poi si
 * chiude. Non e' pignoleria contabile — se si bonificasse prima di segnare, una
 * funzione che muore in mezzo lascerebbe dei soldi usciti e un saldo intatto, e
 * il prelievo successivo li farebbe uscire di nuovo.
 *
 * Se il bonifico fallisce, il saldo torna dov'era. Il caso peggiore e' un
 * prelievo che non funziona e va rifatto; quello che non puo' succedere e' che
 * spariscano dei soldi.
 */
exports.withdrawWallet = onCall(
  { secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    const userId = request.auth && request.auth.uid;

    if (!userId) {
      throw new HttpsError('unauthenticated', 'Serve un account.');
    }

    const stripe = stripeClient();
    const userRef = db.collection('users').doc(userId);
    const user = await userRef.get();
    const balance = user.get('walletCents') || 0;

    if (balance < MIN_WITHDRAWAL_CENTS) {
      return { paid: false, reason: 'saldo-basso', minimumCents: MIN_WITHDRAWAL_CENTS };
    }

    const accountId = user.get('stripeAccountId');

    if (!accountId || user.get('payoutReady') !== true) {
      // Non e' un errore: e' la prima volta. Chi chiama apre la registrazione.
      return { paid: false, reason: 'account-mancante' };
    }

    const movementRef = userRef.collection('wallet').doc();

    const amount = await db.runTransaction(async (transaction) => {
      const fresh = await transaction.get(userRef);
      const current = fresh.get('walletCents') || 0;

      if (current < MIN_WITHDRAWAL_CENTS) {
        return 0;
      }

      transaction.update(userRef, {
        walletCents: 0,
        withdrawingCents: current,
      });

      return current;
    });

    if (amount <= 0) {
      return { paid: false, reason: 'saldo-basso' };
    }

    try {
      await stripe.transfers.create(
        {
          amount,
          currency: 'eur',
          destination: accountId,
          description: 'Prelievo CRASY',
          metadata: { userId, movementId: movementRef.id },
        },
        { idempotencyKey: `wallet-withdrawal-${movementRef.id}` }
      );
    } catch (error) {
      // Il saldo torna dov'era: i soldi non sono usciti.
      await userRef.update({
        walletCents: admin.firestore.FieldValue.increment(amount),
        withdrawingCents: 0,
      });

      logger.error(`Prelievo di ${userId} fallito: saldo ripristinato.`, error);

      throw new HttpsError('unavailable', 'Prelievo non riuscito.');
    }

    await userRef.update({ withdrawingCents: 0 });
    await movementRef.set({
      kind: 'withdrawal',
      amountCents: -amount,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`${userId} ha prelevato ${amount} centesimi.`);

    return { paid: true, amountCents: amount };
  }
);

/**
 * Nessuno ha partecipato: i soldi tornano indietro interi.
 *
 * Interi, comprese le commissioni di Stripe che restano a carico di CRASY. Sono
 * pochi euro e sono la differenza fra "non e' andata" e "mi hanno tenuto dei
 * soldi per niente": la seconda e' la storia che uno racconta agli amici.
 */
async function refundChallenge(challengeId) {
  const stripe = stripeClient();
  const ref = db.collection('challenges').doc(challengeId);
  const snapshot = await ref.get();

  if (!snapshot.exists || snapshot.get('prizeStatus') !== 'held') {
    return;
  }

  const paymentIntentId = snapshot.get('stripePaymentIntentId');

  if (!paymentIntentId) {
    return;
  }

  await stripe.refunds.create(
    { payment_intent: paymentIntentId },
    { idempotencyKey: `challenge-refund-${challengeId}` }
  );

  await ref.update({ prizeStatus: 'refunded' });

  logger.info(`Challenge ${challengeId}: nessun partecipante, premio reso.`);
}

module.exports.payWinner = payWinner;
module.exports.refundChallenge = refundChallenge;
module.exports.commissionCents = commissionCents;
module.exports.payoutCents = payoutCents;
module.exports.chargeCents = chargeCents;
