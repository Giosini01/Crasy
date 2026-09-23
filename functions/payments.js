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

/** Dove torna la gente dopo aver pagato.
 *
 * **Il valore di ripiego e' l'indirizzo vero, non un segnaposto.** Stripe
 * rimanda qui a pagamento fatto, e un indirizzo che non esiste manda chi ha
 * appena messo dei soldi su una pagina bianca — nel momento peggiore
 * possibile. Si sovrascrive con `CRASY_APP_URL`, che e' anche il modo di
 * cambiare dominio senza toccare il codice.
 *
 * **Non e' `crasyapp.com/app`, e c'e' un motivo.** Quell'indirizzo risponde e
 * ha pure il titolo giusto, ma sta su un altro hosting che per ogni file
 * sconosciuto rimanda alla pagina vetrina: il browser chiede `main.dart.js` e
 * si prende dell'HTML, quindi l'app non parte e resta una schermata bianca.
 * Mandarci chi ha appena pagato sarebbe il peggior momento possibile per
 * mostrargli una pagina rotta. Il giorno in cui quel dominio sara' collegato a
 * questo hosting, si cambia una riga nel `.env` e basta.
 *
 * **E c'e' `/app` in fondo.** Alla radice di `crasy.web.app` adesso c'e' la
 * vetrina — vedi `tool/prepara_il_sito.py` — e l'app sta sotto `/app`. Senza,
 * chi aveva appena pagato tornava sulla pagina di presentazione invece che
 * sulla sua missione. */
const APP_URL = process.env.CRASY_APP_URL || 'https://crasy.web.app/app';

/**
 * **Si torna nella pagina da cui si e' partiti, non in una fissa.**
 *
 * Chi paga dal sito lo fa da `crasyapp.com/app`, oppure da `crasy.web.app/app`:
 * rimandarlo sempre allo stesso indirizzo scritto nel `.env` voleva dire, con
 * un valore sbagliato, farlo atterrare sulla vetrina subito dopo aver pagato.
 * Adesso l'app dice da dove chiama — l'indirizzo dell'app e la schermata in cui
 * stava prima di aprire il modulo — e Stripe riporta li'.
 *
 * **Ma non si riporta dovunque.** Un indirizzo che arriva dal client e finisce
 * in un redirect e' il modo classico di usare una pagina di pagamento vera per
 * mandare qualcuno su un sito finto: si accettano solo i domini di CRASY, e
 * tutto il resto ripiega su `APP_URL`.
 */
const DOMINI_DI_RITORNO = new Set([
  'crasyapp.com',
  'www.crasyapp.com',
  'crasy.web.app',
  'crasy.firebaseapp.com',
]);

function indirizzoDiRitorno(appUrl, rotta) {
  let base = APP_URL;

  try {
    const url = new URL(String(appUrl || ''));
    const locale = url.hostname === 'localhost' || url.hostname === '127.0.0.1';

    if ((url.protocol === 'https:' && DOMINI_DI_RITORNO.has(url.hostname)) || locale) {
      base = `${url.origin}${url.pathname}`;
    }
  } catch (_) {
    // Indirizzo storto: si usa quello di sempre.
  }

  // La schermata e' una rotta dell'app, niente di piu': lettere, numeri,
  // trattini e barre. Niente `//`, niente punti, niente query.
  const schermata =
    typeof rotta === 'string' && /^\/[A-Za-z0-9\-_/]*$/.test(rotta) && !rotta.includes('//')
      ? rotta
      : '/challenges';

  return `${base.replace(/\/+$/, '')}/#${schermata}`;
}

/** La chiave pubblica di Stripe: non e\' un segreto, la vede chiunque apra l\'app. */
const PUBLISHABLE_KEY = process.env.CRASY_STRIPE_PUBLISHABLE_KEY || '';

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
    const ritorno = indirizzoDiRitorno(
      request.data && request.data.appUrl,
      request.data && request.data.returnRoute
    );

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
        // Pagato o annullato, si torna dove si era prima di aprire il modulo:
        // e' li' che la gara comparira' appena Stripe conferma.
        success_url: ritorno,
        cancel_url: ritorno,
      },
      // Due tocchi sul bottone non devono aprire due pagamenti. L'indirizzo di
      // ritorno sta nella chiave perche' Stripe rifiuta la stessa chiave con
      // parametri diversi: riprovare da un'altra schermata non deve fallire.
      {
        idempotencyKey: `challenge-checkout-${challengeId}-${require('crypto')
          .createHash('sha1')
          .update(ritorno)
          .digest('hex')
          .slice(0, 12)}`,
      }
    );

    await ref.update({
      stripeCheckoutSessionId: session.id,
      paymentStartedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { url: session.url, chargeCents: chargeCents(prize) };
  }
);

/**
 * **Lo stesso pagamento, ma senza uscire dall'app.**
 *
 * La pagina di Stripe funziona e resta li' per il sito, dove non c'e'
 * alternativa. Sul telefono pero' costringe a uscire: si apre il browser, si
 * perde la schermata, si torna indietro a mano. Chi stava lanciando una
 * missione per gioco, a meta' strada, si ferma.
 *
 * \'ui non si torna un indirizzo: si torna **il permesso di incassare una cifra
 * decisa dal server**. L'app lo consegna al foglio di Stripe, che si alza dal
 * basso dentro CRASY con Apple Pay in cima e la carta sotto. Il numero della
 * carta continua a non passare da noi — lo prende quel foglio, che e' codice
 * di Stripe dentro l'app — quindi non cambia niente di cio' che ci tiene fuori
 * dallo standard PCI.
 *
 * **Chi paga diventa un cliente di Stripe, e la seconda volta e' un tocco.**
 * La carta resta salvata da loro, non da noi: la volta dopo il foglio si apre
 * con quella gia' dentro. E' la differenza fra lanciare una missione in dieci
 * secondi e doverla lanciare col portafoglio in mano.
 */
exports.createChallengePaymentIntent = onCall(
  {
    secrets: [STRIPE_SECRET_KEY],
    // **Mezzo giga di memoria, e si paga solo quando gira.**
    //
    // Non serve per la memoria: su Cloud Run la potenza del processore va
    // insieme a quella, e il doppio di memoria vuol dire meta' del tempo per
    // gli stessi conti. Su una funzione che qualcuno aspetta guardando lo
    // schermo, sono decimi di secondo che si sentono.
    //
    // **Quello che non si fa e' tenerne una sempre accesa** (`minInstances`).
    // Toglierebbe i due o tre secondi della prima chiamata dopo una pausa —
    // il momento in cui la funzione deve nascere da zero — ma si paga a mese
    // anche nelle notti in cui non paga nessuno. Con i numeri di adesso non
    // vale; il giorno in cui si lanciano missioni tutto il giorno, si'.
    memory: '512MiB',
  },
  async (request) => {
    const userId = request.auth && request.auth.uid;

    if (!userId) {
      throw new HttpsError('unauthenticated', 'Serve un account.');
    }

    if (!PUBLISHABLE_KEY) {
      // Senza, il foglio non si apre nemmeno: meglio dirlo qui che lasciare
      // l'app davanti a un errore che non vuol dire niente.
      throw new HttpsError('failed-precondition', 'Pagamenti non configurati.');
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
    const userRef = db.collection('users').doc(userId);
    const user = await userRef.get();

    // Il cliente di Stripe e' quello che tiene le carte salvate. Si crea una
    // volta per persona e si riusa: crearne uno nuovo a ogni pagamento vuol
    // dire un elenco di carte vuoto tutte le volte.
    const customerId = await clienteDi(stripe, userId, userRef, user);

    const intent = await stripe.paymentIntents.create(
      {
        amount: chargeCents(prize),
        currency: 'eur',
        customer: customerId,
        // La carta resta a Stripe per la prossima volta: e\' il motivo per cui
        // la seconda missione si paga con un tocco.
        setup_future_usage: 'off_session',
        // **Solo i metodi che si concludono dentro l'app.**
        //
        // Lasciando entrare anche quelli che passano da una pagina esterna —
        // i bonifici istantanei, certi portafogli — il foglio di Stripe
        // pretende di sapere dove riportare la gente dopo quel giro, e se non
        // gliel'hai detto **non si apre affatto**. Non da' errore: resta
        // chiuso. Da fuori e' un bottone che non fa niente.
        //
        // Qui non servono: si paga una missione da pochi euro con la carta, e
        // il giro piu' corto e' anche quello che si conclude piu' spesso.
        automatic_payment_methods: { enabled: true, allow_redirects: 'never' },
        description: `Premio: ${snapshot.get('title') || 'challenge CRASY'}`,
        // Come per la pagina: nel metadato solo il nome della gara. L\'importo
        // lo rilegge il webhook dal database, cosi\' non lo decide chi
        // intercetta la chiamata.
        metadata: { challengeId, userId },
      },
      { idempotencyKey: `challenge-intent-${challengeId}` }
    );

    // **La chiave temporanea: e' quella che fa ritrovare la carta.**
    //
    // Senza, il foglio non sa chi sta pagando e chiede la carta ogni volta.
    // Con questa, la seconda missione si apre con la carta gia' dentro. Le
    // carte restano da Stripe, non da noi.
    //
    // **Se non nasce, si paga lo stesso.** Una volta questa strada aveva
    // lasciato il foglio chiuso: per questo un errore qui non ferma niente, e
    // l'app — se il foglio con la carta salvata non parte — riprova senza.
    let ephemeralKeySecret = null;

    try {
      const ephemeralKey = await stripe.ephemeralKeys.create(
        { customer: customerId },
        { apiVersion: require('stripe').API_VERSION }
      );

      ephemeralKeySecret = ephemeralKey.secret;
    } catch (errore) {
      logger.warn('Chiave temporanea non creata: si paga senza carte salvate.', errore);
    }

    await ref.update({
      stripePaymentIntentId: intent.id,
      paymentStartedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      clientSecret: intent.client_secret,
      customerId,
      ephemeralKeySecret,
      // **La chiave pubblica la manda il server**, invece di stare dentro
      // l\'app. Cosi\' il giorno in cui si passa dalle chiavi di prova a quelle
      // vere non serve ricompilare niente: cambia una riga sul server, e anche
      // i telefoni gia\' installati pagano sul serio.
      publishableKey: PUBLISHABLE_KEY,
      chargeCents: chargeCents(prize),
    };
  }
);

/**
 * **Il cliente su Stripe di una persona: uno solo, per sempre.**
 *
 * E' la riga da cui dipende la promessa piu' concreta che l'app fa a chi paga:
 * **la carta si mette una volta.** La carta non sta su CRASY e non sta sul
 * telefono — sta attaccata a un cliente su Stripe — quindi ritrovare quel
 * cliente e ritrovare la carta sono la stessa cosa. Sbagliato quello, il foglio
 * di pagamento si apre vuoto e chiede di nuovo sedici cifre a chi le ha gia'
 * date.
 *
 * Ed e' quello che succedeva: si leggeva l'identificativo dal profilo e, non
 * trovandolo, se ne creava uno nuovo. Due tocchi ravvicinati sul bottone — cioe'
 * la normalita' quando una schermata sembra non rispondere — passavano tutti e
 * due da quel "non c'e'", creavano due clienti, e l'ultimo a scrivere vinceva.
 * Nel database restava il cliente vuoto; le carte erano attaccate all'altro, e
 * non le ha piu' viste nessuno.
 *
 * Adesso ci sono tre difese in fila, e la prima che trova qualcosa vince:
 *
 * 1. **Quello scritto nel profilo**, controllando che esista ancora davvero.
 *    Un identificativo che punta a un cliente cancellato e' peggio di nessun
 *    identificativo, perche' fa fallire il pagamento invece di ricominciare.
 *
 * 2. **La ricerca su Stripe per nome dell'utente.** Copre i casi gia' rotti —
 *    come i due clienti che abbiamo davvero trovato — e si prende quello con
 *    piu' carte: fra un cliente vuoto e uno con sei carte, quello giusto e'
 *    quello che ha le carte.
 *
 * 3. **La creazione, con una chiave di non ripetizione.** Se due chiamate
 *    arrivano insieme, Stripe risponde a tutte e due con lo **stesso** cliente
 *    invece di crearne due. E' la difesa che impedisce al problema di
 *    ripresentarsi.
 */
async function clienteDi(stripe, userId, userRef, user) {
  const scritto = user.get('stripeCustomerId');

  if (scritto) {
    const trovato = await stripe.customers
      .retrieve(scritto)
      .catch(() => null);

    if (trovato && !trovato.deleted) {
      return scritto;
    }

    logger.warn(`Cliente ${scritto} non esiste piu': se ne cerca un altro.`);
  }

  // **Chi ha piu' carte vince.** Non il piu' recente: il piu' recente e'
  // proprio quello nato per sbaglio, e quello vuoto.
  const cercati = await stripe.customers
    .search({ query: `metadata['userId']:'${userId}'`, limit: 10 })
    .catch(() => null);

  if (cercati && cercati.data.length > 0) {
    let migliore = cercati.data[0];
    let quante = -1;

    for (const candidato of cercati.data) {
      const carte = await stripe.paymentMethods
        .list({ customer: candidato.id, type: 'card', limit: 10 })
        .catch(() => ({ data: [] }));

      if (carte.data.length > quante) {
        quante = carte.data.length;
        migliore = candidato;
      }
    }

    await userRef.set({ stripeCustomerId: migliore.id }, { merge: true });

    return migliore.id;
  }

  const creato = await stripe.customers.create(
    { metadata: { userId }, name: user.get('username') || undefined },
    // La chiave e' il nome della persona: due chiamate insieme ottengono lo
    // stesso cliente, non due.
    { idempotencyKey: `crasy-cliente-${userId}` }
  );

  await userRef.set({ stripeCustomerId: creato.id }, { merge: true });

  return creato.id;
}

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

        // Il pagamento fatto dentro l'app: non c'e' nessuna pagina e nessuna
        // sessione, solo il pagamento.
        case 'payment_intent.succeeded':
          await accendiLaGara(
            event.data.object.metadata &&
              event.data.object.metadata.challengeId,
            event.data.object.id
          );
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
  await accendiLaGara(
    session.metadata && session.metadata.challengeId,
    session.payment_intent
  );
}

/**
 * **Il premio e' arrivato: la gara si accende.**
 *
 * Ci si passa da due strade — la pagina di Stripe sul sito e il foglio nativo
 * dentro l'app — e arrivano come due eventi diversi. Il lavoro pero' e' lo
 * stesso e sta scritto una volta sola: due copie di questa funzione vorrebbero
 * dire che un giorno una delle due dimentica di far ripartire il cronometro, e
 * nessuno se ne accorge finche' non e' su una gara vera.
 */
async function accendiLaGara(challengeId, paymentIntentId) {
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

    // **La durata e' quella scelta, anche se e' di un minuto.** Qui c'era un
    // minimo di un'ora, e le gare da 1 e 5 minuti ripartivano da 59:59. L'ora
    // resta solo come ripiego per una gara senza date leggibili.
    const durataScelta =
      durationMs >= 60 * 1000 ? durationMs : 60 * 60 * 1000;

    transaction.update(ref, {
      prizeStatus: 'held',
      stripePaymentIntentId: paymentIntentId || null,
      paidAt: now,
      startsAt: now,
      endsAt: admin.firestore.Timestamp.fromMillis(
        now.toMillis() + durataScelta
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
  // **Utile, non necessaria.** Chi preleva controlla comunque da se' com'e'
  // messo il proprio account (vedi `withdrawWallet`): questa riga serve solo a
  // risparmiargli quella domanda, quando l'avviso arriva. Se il webhook degli
  // account collegati non e' registrato, non succede niente di male — nessuno
  // resta con i soldi bloccati.
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

    // **I dati li ha gia' messi l'app, e qui si controlla che ci siano.**
    //
    // L'app li chiede prima di arrivare fin qui, con i suoi controlli: la
    // prova del nove dell'IBAN, la lettera finale del codice fiscale, la
    // maggiore eta'. Ricontrollare che ci siano non e' sfiducia verso quella
    // schermata — e' che questa funzione si puo' chiamare anche senza passarci,
    // e un conto collegato nato senza nome e senza IBAN e' un conto che poi
    // nessuno riesce piu' a registrare.
    const dati = (
      await userRef.collection('private').doc('payout').get()
    ).data();

    if (!dati || !dati.iban || !dati.firstName || !dati.lastName) {
      throw new HttpsError('failed-precondition', 'dati-mancanti');
    }

    let accountId = user.get('stripeAccountId');

    if (!accountId) {
      // **Questa riga oggi fallisce, e non per colpa sua.**
      //
      // Stripe ha chiuso la creazione di conti collegati "v1" alle
      // integrazioni nuove: risponde che bisogna usare la v2. E la v2, per
      // quello che serve a noi — un conto che *riceve* soldi — vuole una
      // capacita' che al momento e' ancora in anteprima, cioe' raggiungibile
      // solo dichiarando una versione delle interfacce che Stripe puo'
      // cambiare quando vuole. Provata: senza quella capacita' il conto nasce
      // ma non si puo' ne' registrare ne' pagare.
      //
      // La via d'uscita e' un interruttore nella dashboard — "Assistenza
      // Accounts v1" — che riapre questa strada a chi l'integrazione ce l'ha
      // gia' scritta. Finche' non e' acceso, il prelievo non parte per
      // nessuno.
      //
      // **Il resto dei soldi funziona:** incassare il premio, tenerlo, girarlo
      // nel portafoglio di chi vince. E' solo l'ultimo passo — farlo uscire da
      // CRASY — a essere fermo, e i soldi nel frattempo non si perdono: stanno
      // sul conto Stripe di CRASY, contati uno per uno.
      //
      // **Se Stripe rifiuta, lo si dice.**
      //
      // Rifiuta davvero, e non per un guasto: le integrazioni nuove non
      // possono piu' creare conti collegati nel modo in cui li chiede questa
      // riga, e va riacceso un interruttore nella dashboard. Senza questo
      // controllo l'errore arrivava all'app come "non ci siamo riusciti,
      // riprova" — e riprovare non serviva a niente, perche' non era un
      // problema di quel momento.
      const account = await stripe.accounts
        .create({
          type: 'express',
          country: 'IT',
          email: request.auth.token.email,
          capabilities: { transfers: { requested: true } },
          business_type: 'individual',
          metadata: { userId },
          // **Quello che sappiamo gia', Stripe non lo richiede.**
          //
          // Sono gli stessi dati che la persona ha appena scritto nell'app:
          // passarglieli vuol dire trovare quella pagina in buona parte
          // compilata invece che vuota. Il documento resta a loro — verificarlo
          // e' un mestiere, e le carte d'identita' non passano da CRASY — ma
          // tutto il resto e' gia' fatto.
          individual: {
            first_name: dati.firstName,
            last_name: dati.lastName,
            email: request.auth.token.email,
            ...(dati.birthDate
              ? {
                  dob: {
                    day: dati.birthDate.toDate().getUTCDate(),
                    month: dati.birthDate.toDate().getUTCMonth() + 1,
                    year: dati.birthDate.toDate().getUTCFullYear(),
                  },
                }
              : {}),
          },
          external_account: {
            object: 'bank_account',
            country: 'IT',
            currency: 'eur',
            account_number: dati.iban,
            account_holder_name: `${dati.firstName} ${dati.lastName}`,
            account_holder_type: 'individual',
          },
        })
        .catch((errore) => {
          logger.error('Conto per incassare non creato.', errore);

          throw new HttpsError(
            'failed-precondition',
            'incasso-non-configurato'
          );
        });

      accountId = account.id;
      await userRef.set({ stripeAccountId: accountId }, { merge: true });
    }

    const link = await stripe.accountLinks.create({
      account: accountId,
      type: 'account_onboarding',
      // Si torna da dove si era partiti, come per il pagamento: l'app manda
      // il proprio indirizzo, e chi non lo manda — il telefono — ripiega sul
      // sito. Vedi `indirizzoDiRitorno`.
      refresh_url: indirizzoDiRitorno(request.data && request.data.appUrl, '/profile'),
      return_url: indirizzoDiRitorno(request.data && request.data.appUrl, '/profile'),
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

    if (!accountId) {
      // Non e' un errore: e' la prima volta. Chi chiama apre la registrazione.
      return { paid: false, reason: 'account-mancante' };
    }

    // **Se non risulta pronto, si chiede a Stripe invece di crederci.**
    //
    // `payoutReady` e' una copia: la scrive il webhook quando Stripe avvisa che
    // quella registrazione e' andata a buon fine. Ma quell'avviso riguarda un
    // account *collegato*, e Stripe lo manda solo a una destinazione di tipo
    // "account connessi" — un secondo indirizzo, con un secondo segreto, da
    // tenere in piedi per una riga di copia.
    //
    // Qui si evita tutto: **al momento del prelievo si domanda a Stripe com'e'
    // messo quell'account**, che e' l'unico momento in cui la risposta serve
    // davvero. Una chiamata sola, fatta da una persona che sta gia' aspettando
    // dei soldi, e la risposta non puo' essere vecchia — cosa che una copia
    // scritta giorni prima invece puo'.
    if (user.get('payoutReady') !== true) {
      const account = await stripe.accounts.retrieve(accountId);

      if (account.payouts_enabled !== true) {
        return { paid: false, reason: 'account-mancante' };
      }

      await userRef.update({ payoutReady: true });
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
async function refundChallenge(challengeId, { soloIlPremio = false } = {}) {
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

  // **Chi cancella si tiene il costo della sua decisione; chi resta a mani
  // vuote no.**
  //
  // Sono due rimborsi diversi perche' sono due situazioni diverse, e
  // trattarle uguali sarebbe ingiusto in un verso o nell'altro.
  //
  // *Nessuno ha partecipato*: chi ha lanciato non ha fatto niente di male. Ha
  // messo dei soldi e non si e' presentato nessuno — non e' merito ne' colpa
  // sua, ed e' proprio il rischio che si prende chi fa giocare gli altri.
  // Torna tutto, commissioni comprese: trattenergli qualcosa e' il modo piu'
  // rapido di non fargli lanciare mai piu' una missione.
  //
  // *Ha cancellato lui*: torna **il premio**, e restano fuori le spese. Quelle
  // di Stripe perche' sono uscite davvero e non si recuperano — Stripe non le
  // restituisce sui rimborsi — e la parte di CRASY perche' il lavoro e' stato
  // fatto: la gara e' nata, e' stata annunciata, e a chiuderla e' stata una
  // scelta. Senza questa riga, aprire e cancellare in continuazione svuotava
  // il conto di CRASY qualche centesimo alla volta.
  const quanto = soloIlPremio ? snapshot.get('prizeCents') || 0 : undefined;

  await stripe.refunds.create(
    {
      payment_intent: paymentIntentId,
      ...(quanto ? { amount: quanto } : {}),
    },
    { idempotencyKey: `challenge-refund-${challengeId}` }
  );

  await ref.update({ prizeStatus: 'refunded' });

  logger.info(
    `Challenge ${challengeId}: ` +
      (soloIlPremio ? 'cancellata, premio reso.' : 'nessun partecipante, reso tutto.')
  );
}

/**
 * **Annulla una missione pagata, e restituisce i soldi.**
 *
 * Le regole del database non lasciano cancellare una gara il cui premio e'
 * gia' in cassa, ed e' giusto: cancellarla dal telefono vorrebbe dire far
 * sparire il documento e lasciare dei soldi su Stripe senza piu' niente che
 * dica a chi tornano. Ma il risultato, visto da chi ha appena sbagliato a
 * scrivere il titolo di una prova, era un tasto che non funzionava e non
 * spiegava perche'.
 *
 * Quindi la strada c'e', e passa da qui: **prima i soldi tornano indietro,
 * poi la gara sparisce.** In quest'ordine e non nell'altro — se il rimborso
 * non riesce, la gara resta dov'e' ed e' recuperabile; cancellandola prima,
 * quei soldi non avrebbero piu' un padrone.
 *
 * Le condizioni sono le stesse della regola che vale per le gare non pagate:
 * solo chi l'ha lanciata, e solo finche' non ha partecipato nessuno. Dalla
 * prima foto in poi la gara non e' piu' soltanto sua.
 */
exports.cancelChallenge = onCall(
  { secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    const userId = request.auth && request.auth.uid;

    if (!userId) {
      throw new HttpsError('unauthenticated', 'Serve un account.');
    }

    const challengeId = String(request.data && request.data.challengeId);
    const ref = db.collection('challenges').doc(challengeId);
    const snapshot = await ref.get();

    if (!snapshot.exists) {
      return { cancellata: true };
    }

    if (snapshot.get('createdByUserId') !== userId) {
      throw new HttpsError('permission-denied', 'Non e\' tua.');
    }

    if ((snapshot.get('participantsCount') || 0) > 0) {
      throw new HttpsError(
        'failed-precondition',
        'Qualcuno ha gia\' partecipato.'
      );
    }

    if (snapshot.get('prizeStatus') === 'held') {
      await refundChallenge(challengeId, { soloIlPremio: true });
    }

    await ref.delete();

    logger.info(`Challenge ${challengeId} annullata da ${userId}.`);

    return { cancellata: true };
  }
);

module.exports.payWinner = payWinner;
module.exports.refundChallenge = refundChallenge;
module.exports.commissionCents = commissionCents;
module.exports.payoutCents = payoutCents;
module.exports.chargeCents = chargeCents;

// ---------------------------------------------------------------------------
// 4. Il prelievo a mano, finche' Stripe non apre i conti
// ---------------------------------------------------------------------------

/**
 * **Chiedere i propri soldi, quando la macchina non puo' ancora mandarli.**
 *
 * Il bonifico automatico ha bisogno di un conto collegato su Stripe, e quei
 * conti oggi non si possono creare: non e' un guasto nostro ed e' documentato
 * poco piu' sopra. Restava una scelta sola, e nessuna delle due strade ovvie
 * andava bene: dire "non si puo' prelevare" a chi ha vinto dei soldi veri e'
 * una promessa rotta, e fingere che il bonifico sia partito e' peggio.
 *
 * Quindi si fa la cosa che si faceva prima che esistessero le macchine: **la
 * richiesta si mette in fila, e il bonifico lo fa una persona.** I dati per
 * farlo ci sono gia' tutti — nome, codice fiscale, IBAN controllato — e chi
 * tiene CRASY li vede in un elenco con accanto quanto deve mandare.
 *
 * **I soldi escono dal saldo nell'istante in cui si chiede.** Non restano
 * disponibili "tanto poi glieli mando": finiscono in `withdrawingCents`, che
 * vuol dire *sono tuoi, sono in viaggio, non li puoi chiedere due volte*. E'
 * la stessa riga che impedisce a chi preme due volte di farsi pagare due volte.
 */
exports.requestPayout = onCall(async (request) => {
  const userId = request.auth && request.auth.uid;

  if (!userId) {
    throw new HttpsError('unauthenticated', 'Serve un account.');
  }

  const userRef = db.collection('users').doc(userId);
  const dati = (await userRef.collection('private').doc('payout').get()).data();

  if (!dati || !dati.iban || !dati.firstName || !dati.lastName) {
    throw new HttpsError('failed-precondition', 'dati-mancanti');
  }

  const richiestaRef = db.collection('payoutRequests').doc();

  const quanto = await db.runTransaction(async (transaction) => {
    const fresco = await transaction.get(userRef);
    const saldo = fresco.get('walletCents') || 0;

    if (saldo < MIN_WITHDRAWAL_CENTS) {
      return 0;
    }

    // **Una richiesta alla volta.** Due in fila per la stessa persona vorrebbe
    // dire due bonifici da fare a mano, e il secondo per dei soldi che il
    // primo aveva gia' portato via.
    if ((fresco.get('withdrawingCents') || 0) > 0) {
      return -1;
    }

    transaction.update(userRef, {
      walletCents: 0,
      withdrawingCents: saldo,
    });

    transaction.set(richiestaRef, {
      userId,
      username: fresco.get('username') || '',
      amountCents: saldo,
      status: 'pending',
      // **I dati si copiano qui dentro, non si leggono al momento del
      // bonifico.** Se qualcuno cambia IBAN dopo aver chiesto il prelievo, i
      // soldi devono andare dove aveva detto quando li ha chiesti — e chi fa
      // il bonifico deve poter dimostrare su quale IBAN glieli ha mandati.
      firstName: dati.firstName,
      lastName: dati.lastName,
      fiscalCode: dati.fiscalCode || '',
      iban: dati.iban,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return saldo;
  });

  if (quanto === 0) {
    return { ok: false, reason: 'saldo-basso', minimumCents: MIN_WITHDRAWAL_CENTS };
  }

  if (quanto < 0) {
    return { ok: false, reason: 'gia-in-corso' };
  }

  logger.info(`Prelievo chiesto da ${userId}: ${quanto} centesimi.`);

  return { ok: true, amountCents: quanto };
});

/** L'elenco dei bonifici da fare. Solo per chi tiene CRASY. */
exports.adminListPayouts = onCall(async (request) => {
  if (!request.auth || request.auth.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Non sei un amministratore.');
  }

  const richieste = await db
    .collection('payoutRequests')
    .where('status', '==', 'pending')
    .limit(100)
    .get();

  const righe = richieste.docs.map((d) => ({
    id: d.id,
    userId: d.get('userId'),
    username: d.get('username') || '',
    amountCents: d.get('amountCents') || 0,
    firstName: d.get('firstName') || '',
    lastName: d.get('lastName') || '',
    fiscalCode: d.get('fiscalCode') || '',
    iban: d.get('iban') || '',
    createdAt: d.get('createdAt') ? d.get('createdAt').toMillis() : null,
  }));

  // Prima i piu' vecchi: chi aspetta da piu' tempo viene pagato per primo.
  righe.sort((a, b) => (a.createdAt || 0) - (b.createdAt || 0));

  return { richieste: righe };
});

/**
 * **Il bonifico e' partito: si segna, e il conto torna a posto.**
 *
 * Si chiama dopo aver mandato i soldi davvero, non prima. E' l'unico passo di
 * tutto il giro che una macchina non puo' verificare: nessuno qui dentro puo'
 * sapere se quel bonifico e' stato fatto, quindi lo dice una persona e resta
 * scritto chi l'ha detto e quando.
 */
exports.adminMarkPayoutPaid = onCall(async (request) => {
  if (!request.auth || request.auth.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Non sei un amministratore.');
  }

  const id = String(request.data && request.data.id);
  const rimborsa = Boolean(request.data && request.data.rimborsa);
  const richiestaRef = db.collection('payoutRequests').doc(id);

  await db.runTransaction(async (transaction) => {
    const richiesta = await transaction.get(richiestaRef);

    if (!richiesta.exists || richiesta.get('status') !== 'pending') {
      throw new HttpsError('failed-precondition', 'Gia\' decisa.');
    }

    const userRef = db.collection('users').doc(richiesta.get('userId'));
    const quanto = richiesta.get('amountCents') || 0;

    if (rimborsa) {
      // **Il bonifico non si e' potuto fare: i soldi tornano disponibili.**
      // Non spariscono e non restano appesi: chi li ha vinti li rivede nel
      // portafoglio e puo' richiederli, magari con un IBAN corretto.
      transaction.update(userRef, {
        walletCents: admin.firestore.FieldValue.increment(quanto),
        withdrawingCents: 0,
      });

      transaction.update(richiestaRef, {
        status: 'failed',
        decidedBy: request.auth.uid,
        decidedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return;
    }

    transaction.update(userRef, { withdrawingCents: 0 });

    transaction.set(userRef.collection('wallet').doc(), {
      kind: 'withdrawal',
      amountCents: -quanto,
      challengeTitle: '',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.update(richiestaRef, {
      status: 'paid',
      decidedBy: request.auth.uid,
      decidedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  logger.info(`Prelievo ${id}: ${rimborsa ? 'non riuscito' : 'pagato'}.`);

  return { ok: true };
});
