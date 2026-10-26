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
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { autoreDi } = require('./autori');
const posta = require('./posta');
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

/**
 * **La chiave che paga i vincitori, separata da quella che incassa.**
 *
 * Sono due poteri molto diversi. Incassare vuol dire far entrare soldi: se
 * qualcuno rubasse quella chiave, il peggio che puo' fare e' creare dei
 * pagamenti che nessuno conferma. Pagare vuol dire **far uscire** soldi dal
 * conto, ed e' il danno vero.
 *
 * Tenerle separate non impedisce il furto, ma dimezza cio' che si perde: la
 * chiave dei pagamenti — quella che gira a ogni missione, in tutte le
 * funzioni — non sa mandare via un centesimo, e quella che lo sa fare la
 * leggono due funzioni sole.
 */
const STRIPE_PAYOUT_KEY = defineSecret('STRIPE_PAYOUT_KEY');
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

/**
 * **Una rotta dell'app, niente di piu'**: lettere, numeri, trattini e barre.
 * Niente `//`, niente punti, niente query. Tutto il resto ripiega su
 * `ripiego`: un indirizzo che arriva dal telefono e finisce in un redirect non
 * deve poter portare da nessun'altra parte.
 */
function rottaSicura(rotta, ripiego) {
  return typeof rotta === 'string' && /^\/[A-Za-z0-9\-_/]*$/.test(rotta) && !rotta.includes('//')
    ? rotta
    : ripiego;
}

/**
 * **Dal telefono si torna nell'app, non sul sito.**
 *
 * Il conto Stripe si apre nel browser del telefono, e finito il modulo Stripe
 * rimanda a un indirizzo web. Prima era l'app sul sito: chi aveva appena
 * messo l'IBAN si ritrovava a giocare dal browser invece che nell'app. Adesso
 * torna su una pagina nostra (`web/torna`) che riapre CRASY con `crasy://`
 * nella schermata da cui era partito — la missione a cui stava partecipando,
 * o il portafoglio.
 *
 * Sta su `crasy.web.app` e non su `crasyapp.com` perche' quel dominio e' su un
 * altro hosting (vedi `APP_URL`). `scaduto` e' per il `refresh_url`: il
 * collegamento di Stripe e' scaduto prima di finire, e si riprova dall'app.
 */
const PAGINA_DEL_RITORNO = 'https://crasy.web.app/torna/';

function paginaPerTornareNellApp(rotta, scaduto = false) {
  const indirizzo = new URL(PAGINA_DEL_RITORNO);
  indirizzo.searchParams.set('a', rottaSicura(rotta, '/portafoglio'));

  if (scaduto) {
    indirizzo.searchParams.set('e', 'scaduto');
  }

  return indirizzo.toString();
}

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

  const schermata = rottaSicura(rotta, '/challenges');

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

/**
 * **Cinque centesimi di servizio su ogni missione pagata con la carta**, in
 * aggiunta al premio e alle spese del pagamento, e tutti di CRASY.
 *
 * Esistono per un motivo solo: su una missione da un euro CRASY tratteneva
 * dieci centesimi, e di quelli cinque se ne andavano subito in Radar, l'antifrode
 * di Stripe. Restano gli stessi cinque centesimi per ogni missione, grande o
 * piccola, cosi' non c'e' nessun caso speciale da spiegare. Con il portafoglio
 * non si applicano: li' non passa nessun pagamento da coprire.
 */
const SERVIZIO_CENTS = 5;

/**
 * **Le spese di un prelievo: un euro, a carico di chi preleva.**
 *
 * Stripe fa pagare a CRASY ogni conto che riceve un bonifico nel mese (due
 * euro) piu' una piccola parte del bonifico. Un euro a prelievo ne copre circa
 * la meta' e il resto si recupera con il dieci per cento sui premi. Si prende
 * dal conto del vincitore subito prima del bonifico (vedi `prendiLeSpese`).
 */
const SPESE_PRELIEVO_CENTS = 100;

/**
 * **Il premio massimo di una missione: cento euro.** Lo stesso tetto sta nelle
 * regole del database e nel modulo dell'app. Prima era un milione, scritto
 * come argine contro le dita che scivolano; ma un tetto e' anche una promessa
 * a chi controlla i pagamenti, e i premi veri stanno fra uno e cinquanta euro.
 * Si alza quando servira', insieme agli altri due.
 */
const PREMIO_MASSIMO_CENTS = 10000;

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
  const numerator =
    (prizeCents + SERVIZIO_CENTS + PROCESSING_FIXED_CENTS) * 10000;
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

/**
 * Il cliente di Stripe per i soldi che escono.
 *
 * Se la chiave dei prelievi non c'e', si ripiega su quella normale: cosi' il
 * giorno in cui esiste basta metterla, senza toccare il codice, e fino a
 * quel giorno il comportamento e' quello di prima.
 */
function stripePayoutClient() {
  const chiave = STRIPE_PAYOUT_KEY.value();

  // Il segnaposto vale come "non c'e' ancora": un segreto su Secret Manager
  // non puo' essere vuoto, quindi l'assenza si scrive cosi'.
  // `Stripe` va caricato anche qui: era definito solo dentro `stripeClient`,
  // e il giorno in cui la chiave dei prelievi fosse arrivata questa riga
  // sarebbe esplosa al primo prelievo.
  if (chiave && chiave !== 'da-sostituire') {
    const Stripe = require('stripe');

    return new Stripe(chiave);
  }

  return stripeClient();
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
    // Anche in anonimo: chi l'ha lanciata sta nel foglio a parte (`autori.js`).
    if ((await autoreDi(snapshot)) !== userId) {
      throw new HttpsError('permission-denied', 'Non e\' tua.');
    }

    const status = snapshot.get('prizeStatus');

    if (status && status !== 'unpaid') {
      throw new HttpsError('failed-precondition', 'Gia\' pagata.');
    }

    const prize = snapshot.get('prizeCents');

    if (!Number.isInteger(prize) || prize <= 0 || prize > PREMIO_MASSIMO_CENTS) {
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
        // **Nel metadato anche quanto vale il premio.**
        //
        // Non per farlo decidere a chi intercetta la chiamata — a quello serve
        // il database, ed e' li' che il webhook lo rilegge — ma perche' il
        // pagamento deve restare leggibile anche quando la gara non c'e' piu'.
        // Una missione cancellata sparisce, e con lei l'unico modo di sapere
        // quanta parte di quell'incasso era premio di qualcun altro e quanta
        // era il compenso di CRASY: senza, mesi dopo, in contabilita' quel
        // movimento diventa un numero che non si sa piu' dividere.
        metadata: { challengeId, userId, prizeCents: String(prize) },
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

    // Anche in anonimo: chi l'ha lanciata sta nel foglio a parte (`autori.js`).
    if ((await autoreDi(snapshot)) !== userId) {
      throw new HttpsError('permission-denied', 'Non e\' tua.');
    }

    const status = snapshot.get('prizeStatus');

    if (status && status !== 'unpaid') {
      throw new HttpsError('failed-precondition', 'Gia\' pagata.');
    }

    const prize = snapshot.get('prizeCents');

    if (!Number.isInteger(prize) || prize <= 0 || prize > PREMIO_MASSIMO_CENTS) {
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
        // **Nel metadato anche quanto vale il premio.**
        //
        // Non per farlo decidere a chi intercetta la chiamata — a quello serve
        // il database, ed e' li' che il webhook lo rilegge — ma perche' il
        // pagamento deve restare leggibile anche quando la gara non c'e' piu'.
        // Una missione cancellata sparisce, e con lei l'unico modo di sapere
        // quanta parte di quell'incasso era premio di qualcun altro e quanta
        // era il compenso di CRASY: senza, mesi dopo, in contabilita' quel
        // movimento diventa un numero che non si sa piu' dividere.
        metadata: { challengeId, userId, prizeCents: String(prize) },
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
  {
    secrets: [
      STRIPE_SECRET_KEY,
      STRIPE_WEBHOOK_SECRET,
      // Per l'email delle contestazioni: vedi `onContestazione`.
      posta.SMTP_PASSWORD,
      posta.RESEND_API_KEY,
    ],
  },
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
          if (event.data.object.metadata && event.data.object.metadata.kind === 'mancia') {
            await registraMancia(event.data.object.metadata, event.data.object.id);
            break;
          }

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

        // **Le contestazioni.** Chi ha pagato ha chiesto alla sua banca di
        // riavere i soldi: si ferma il premio e si avvisa chi gestisce CRASY.
        case 'charge.dispute.created':
          await onContestazione(event.data.object, 'aperta');
          break;

        case 'charge.dispute.closed':
          await onContestazione(
            event.data.object,
            event.data.object.status === 'won' ? 'vinta' : 'persa'
          );
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
  if (session.metadata && session.metadata.kind === 'mancia') {
    await registraMancia(session.metadata, session.payment_intent);

    return;
  }

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

    // **Quanto ha messo in palio, da sempre.** Il gemello di `totalWonCents`,
    // per l'altra meta' dell'app: si conta nell'istante in cui il premio e'
    // davvero incassato, non quando la gara viene scritta. Una gara dichiarata
    // e mai pagata non ha fatto giocare nessuno.
    //
    // **In anonimo non si conta.** La classifica e' un modo di farsi vedere,
    // e il nome accanto ai soldi di quella gara svelerebbe chi si e' nascosto.
    const diChi = snapshot.get('createdByUserId');

    if (diChi && snapshot.get('anonimo') !== true) {
      transaction.set(
        db.collection('users').doc(diChi),
        {
          totalStakedCents: admin.firestore.FieldValue.increment(
            snapshot.get('prizeCents') || 0
          ),
          totalStakedCount: admin.firestore.FieldValue.increment(1),
        },
        { merge: true }
      );
    }

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

  // Il registro si scrive **dopo** la transazione, non dentro: una
  // transazione tocca solo il database e deve restare la piu' corta possibile,
  // e questa riga ha un identificativo fisso — riscriverla non crea doppioni.
  const dopo = await ref.get();

  await scriviNelRegistro(
    // Il registro e' di chi ha pagato, anche se si e' nascosto.
    await autoreDi(dopo),
    `pagamento_${challengeId}`,
    {
      kind: 'challengePayment',
      amountCents: -(dopo.get('prizeCents') || 0),
      challengeId,
      challengeTitle: dopo.get('title') || '',
      source: dopo.get('paidFromWallet') === true ? 'wallet' : 'card',
      note: 'Premio messo in palio',
    }
  );

  logger.info(`Challenge ${challengeId}: premio incassato, gara aperta.`);
}

/**
 * Di quale fondo e' una missione: quello che la tiene fra le sue `lanciate`.
 * I fondi sono pochissimi — uno per padrone — e si guardano tutti.
 */
async function fondoDi(challengeId) {
  const fondi = await db.collection('salvadanai').get();

  for (const fondo of fondi.docs) {
    const traccia = await fondo.ref.collection('lanciate').doc(challengeId).get();

    if (traccia.exists) {
      return fondo.id;
    }
  }

  return null;
}

/** Dove arrivano gli avvisi per chi gestisce CRASY. */
const CASELLA_DEL_TEAM = 'info@crasyapp.com';

/**
 * **Una contestazione: si ferma il premio, e lo si dice a una persona.**
 *
 * Chi ha pagato un premio puo' chiedere alla propria banca di riavere i
 * soldi. Prima non succedeva niente: la gara andava avanti, il vincitore
 * veniva pagato, e i soldi uscivano due volte — al vincitore e alla banca.
 *
 * Adesso la contestazione si scrive sulla gara (`contestazione`), e
 * `payWinner` non paga finche' e' aperta. Se si chiude **a nostro favore**, il
 * premio riparte da solo; se si chiude **contro**, resta fermo e decide una
 * persona. Un premio gia' pagato non si va a riprendere dal vincitore: la
 * perdita e' di CRASY, come scritto nel profilo della piattaforma su Stripe.
 *
 * In ogni caso parte un'email al team: una contestazione ha una scadenza per
 * rispondere, e va guardata dal pannello di Stripe.
 */
async function onContestazione(contestazione, stato) {
  const intento = contestazione.payment_intent;
  const scheda = {
    id: contestazione.id,
    stato,
    motivo: contestazione.reason || '',
    importoCents: contestazione.amount || 0,
    aggiornataIl: admin.firestore.FieldValue.serverTimestamp(),
  };

  const gare = intento ?
    await db
      .collection('challenges')
      .where('stripePaymentIntentId', '==', intento)
      .limit(1)
      .get() :
    null;
  let cosa = 'un pagamento che non troviamo fra le missioni';

  if (gare && !gare.empty) {
    const gara = gare.docs[0];

    await gara.ref.update({ contestazione: scheda });
    cosa = `la missione "${gara.get('title') || ''}" (${gara.id}), ` +
      `premio ${gara.get('prizeStatus') || ''}`;

    if (stato === 'vinta' && gara.get('winnerUserId')) {
      await payWinner(gara.id);
    }
  } else if (intento) {
    const mancia = db.collection('mance').doc(String(intento));

    if ((await mancia.get()).exists) {
      await mancia.set({ contestazione: scheda }, { merge: true });
      cosa = 'una mancia';
    }
  }

  logger.warn(`Contestazione ${contestazione.id} ${stato}: ${cosa}.`);

  // L'email non deve far fallire il webhook: la contestazione e' gia' scritta,
  // e Stripe riproverebbe tutto da capo.
  try {
    const euro = ((contestazione.amount || 0) / 100).toFixed(2).replace('.', ',');

    await posta.spedisci({
      from: '"CRASY" <' + posta.CASELLA + '>',
      to: CASELLA_DEL_TEAM,
      subject: `Contestazione ${stato} — ${euro} € — CRASY`,
      text:
        `Contestazione ${stato} su ${cosa}. Importo ${euro} euro, motivo ` +
        `"${contestazione.reason || ''}". Rispondi dal pannello di Stripe: ` +
        `https://dashboard.stripe.com/disputes/${contestazione.id}`,
    });
  } catch (guaio) {
    logger.error('Email della contestazione non partita.', guaio);
  }
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
  // **Utile, non necessaria.** Chi gioca o preleva controlla comunque da se'
  // com'e' messo il proprio conto (vedi `statoConto`): questa riga serve solo a
  // risparmiargli quella domanda, quando l'avviso arriva. Se il webhook degli
  // account collegati non e' registrato, non succede niente di male — nessuno
  // resta con i soldi bloccati.
  const ready = Boolean(
    account.capabilities && account.capabilities.transfers === 'active'
  );
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

  // Il conto e' pronto: quello che aveva vinto prima di collegarlo passa li'.
  await spostaSuStripe(userId);
}

// ---------------------------------------------------------------------------
// I soldi dei vincitori stanno a nome loro
// ---------------------------------------------------------------------------
//
// **CRASY non tiene i soldi di chi vince.** Il premio di una gara aperta sta
// sul saldo di CRASY finche' la gara non si chiude — prima non si sa di chi
// sia. Appena c'e' un vincitore va sul **suo** conto Stripe: un conto
// collegato, intestato a lui, che custodisce Stripe. Da li' lo preleva verso
// la sua banca, o lo usa per lanciare una missione.
//
// `walletCents` resta, e vuol dire una cosa sola: **soldi di qualcuno che sono
// ancora su CRASY**. Premi vinti prima di collegare il conto, o un
// trasferimento che Stripe non ha accettato in quel momento. Non e' uno stato
// normale: e' una custodia che aspetta di essere spostata, e la sposta
// `spostaSuStripe` appena puo' — alla vittoria, al collegamento del conto, al
// prelievo, e una volta al giorno per quelli rimasti indietro.
//
// `stripeCents` e' la nostra copia di quanto c'e' sul conto Stripe di quella
// persona grazie a CRASY: serve all'app per mostrare il saldo senza chiederlo a
// Stripe a ogni apertura. **Per pagare o prelevare non ci si fida della copia**:
// si chiede a Stripe il saldo vero.

/** Il consenso a usare il saldo Stripe per pagare le missioni. */
const CONSENSO_ADDEBITO = 'addebito_saldo';

/**
 * **Com'e' messo il conto Stripe di una persona, chiesto a Stripe.**
 *
 * Pronto vuol dire che puo' ricevere i premi (`transfers` attivo). I prelievi
 * verso la banca sono un passo in piu' (`payouts_enabled`): Stripe puo'
 * chiedere un documento dopo, quando le cifre crescono.
 *
 * **I prelievi del vincitore li decide lui, non un calendario.** Lasciati
 * automatici, Stripe manderebbe in banca ogni premio appena disponibile — anche
 * novanta centesimi — e ogni mese con un prelievo costa due euro a CRASY. Si
 * mettono su manuale: partono quando la persona preme "Preleva".
 */
async function statoDelConto(stripe, userRef, accountId) {
  const account = await stripe.accounts.retrieve(accountId);
  const pronto = Boolean(
    account.capabilities && account.capabilities.transfers === 'active'
  );
  const prelievi = account.payouts_enabled === true;
  // Il modulo di Stripe e' stato mandato: la verifica puo' essere ancora in
  // corso, ma la persona ha fatto la sua parte. Vedi `assicuratiIlConto`.
  const compilato = account.details_submitted === true;
  const giro =
    account.settings &&
    account.settings.payouts &&
    account.settings.payouts.schedule &&
    account.settings.payouts.schedule.interval;

  if (pronto && giro && giro !== 'manual') {
    try {
      await stripe.accounts.update(accountId, {
        settings: { payouts: { schedule: { interval: 'manual' } } },
      });
    } catch (errore) {
      logger.warn('Calendario dei prelievi non messo su manuale.', {
        accountId,
        errore: String((errore && errore.message) || errore).slice(0, 300),
      });
    }
  }

  await userRef.set({ payoutReady: pronto }, { merge: true });

  return { pronto, prelievi, compilato };
}

/** Il saldo vero sul conto Stripe di una persona, in euro: disponibile e in arrivo. */
async function saldoDelConto(stripe, accountId) {
  const saldo = await stripe.balance.retrieve({}, { stripeAccount: accountId });
  const somma = (righe) =>
    (righe || [])
      .filter((riga) => riga.currency === 'eur')
      .reduce((totale, riga) => totale + (riga.amount || 0), 0);

  return {
    disponibile: Math.max(0, somma(saldo.available)),
    inArrivo: Math.max(0, somma(saldo.pending)),
  };
}

/**
 * Il pagamento con cui e' stato messo in palio il premio di una gara, se e'
 * passato da una carta. Le gare pagate col fondo o col saldo non ne hanno uno.
 */
async function caricoDellaGara(stripe, challengeId) {
  const gara = await db.collection('challenges').doc(challengeId).get();

  if (
    !gara.exists ||
    gara.get('paidFromWallet') === true ||
    gara.get('pagataDalFondo') === true
  ) {
    return null;
  }

  const pagamento = gara.get('stripePaymentIntentId');

  if (!pagamento) {
    return null;
  }

  const intent = await stripe.paymentIntents.retrieve(pagamento);
  const carico = intent.latest_charge;

  return typeof carico === 'string' ? carico : (carico && carico.id) || null;
}

/**
 * Un errore di Stripe che dice "no" e non "riprova": i 4xx, tranne due.
 *
 * Il 409 vuol dire che la stessa richiesta e' ancora in corso, e il 429 che ne
 * sono arrivate troppe: in tutti e due i casi il trasferimento **potrebbe**
 * partire, e rimettere i soldi in custodia vorrebbe dire rischiare di pagarli
 * due volte. Restano in viaggio, e si chiariscono dopo.
 */
function eUnNoDefinitivo(errore) {
  const codice = errore && errore.statusCode;

  return (
    typeof codice === 'number' &&
    codice >= 400 &&
    codice < 500 &&
    codice !== 409 &&
    codice !== 429
  );
}

/**
 * **Sposta la custodia di una persona sul suo conto Stripe.**
 *
 * `importo` limita quanto spostare (un premio appena vinto); senza, si sposta
 * tutta la custodia. `sorgente` e' il pagamento da cui viene il premio: con
 * quello Stripe accetta il trasferimento anche se il saldo di CRASY in quel
 * momento e' basso, e lo esegue quando i soldi di quel pagamento sono
 * disponibili.
 *
 * ## Mai due volte, mai zero volte
 *
 * L'ordine e' quello del prelievo a mano: prima la custodia passa in una
 * casella "in viaggio" (`spostandoCents`), poi si chiede a Stripe, poi si
 * chiude. Se Stripe dice di no, la custodia torna dov'era. Se invece non si sa
 * — la rete e' caduta a meta' — lo spostamento resta in viaggio e non si
 * rifa' niente finche' non si e' capito com'e' andata: rifarlo alla cieca
 * vorrebbe dire pagare due volte. Vedi `chiudiLoSpostamentoAppeso`.
 *
 * Non lancia: torna quanto ha spostato, anche zero.
 */
async function spostaSuStripe(userId, { importo = null, sorgente = null } = {}) {
  const userRef = db.collection('users').doc(userId);
  const utente = await userRef.get();
  const accountId = utente.get('stripeAccountId');

  if (!accountId || utente.get('payoutReady') !== true) {
    return 0;
  }

  const stripe = stripePayoutClient();

  if ((utente.get('spostandoCents') || 0) > 0) {
    const chiuso = await chiudiLoSpostamentoAppeso(stripe, userRef, accountId);

    if (!chiuso) {
      return 0;
    }
  }

  const spostamentoRef = userRef.collection('spostamenti').doc();

  const quanto = await db.runTransaction(async (transaction) => {
    const fresco = await transaction.get(userRef);

    if ((fresco.get('spostandoCents') || 0) > 0) {
      return 0;
    }

    const custodia = fresco.get('walletCents') || 0;
    const q = importo === null ? custodia : Math.min(importo, custodia);

    if (q <= 0) {
      return 0;
    }

    transaction.update(userRef, {
      walletCents: admin.firestore.FieldValue.increment(-q),
      spostandoCents: q,
      spostamentoId: spostamentoRef.id,
    });
    transaction.set(spostamentoRef, {
      amountCents: q,
      sorgente: sorgente || null,
      stato: 'in-viaggio',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return q;
  });

  if (quanto <= 0) {
    return 0;
  }

  return eseguiLoSpostamento(stripe, userRef, accountId, spostamentoRef, {
    amountCents: quanto,
    sorgente,
  });
}

/** Chiede a Stripe il trasferimento di uno spostamento, e lo chiude. */
async function eseguiLoSpostamento(stripe, userRef, accountId, spostamentoRef, { amountCents, sorgente }) {
  try {
    const trasferimento = await stripe.transfers.create(
      {
        amount: amountCents,
        currency: 'eur',
        destination: accountId,
        description: 'Premi vinti su CRASY',
        metadata: { userId: userRef.id, spostamentoId: spostamentoRef.id },
        ...(sorgente ? { source_transaction: sorgente } : {}),
      },
      // La chiave e' lo spostamento: ripetere la stessa richiesta restituisce
      // lo stesso trasferimento, non ne fa un secondo.
      { idempotencyKey: `sposta-${spostamentoRef.id}` }
    );

    await chiudiLoSpostamento(userRef, spostamentoRef, amountCents, trasferimento.id);

    logger.info('premi spostati sul conto Stripe', {
      userId: userRef.id,
      amountCents,
      transferId: trasferimento.id,
    });

    return amountCents;
  } catch (errore) {
    if (eUnNoDefinitivo(errore)) {
      // Stripe ha detto di no — di solito il saldo di CRASY non basta ancora.
      // La custodia torna dov'era e si riprova piu' tardi.
      await annullaLoSpostamento(userRef, spostamentoRef, amountCents, errore);

      return 0;
    }

    // Non si sa com'e' andata: resta in viaggio, e la prossima volta si
    // ripete la stessa richiesta con la stessa chiave.
    logger.error('Spostamento rimasto in viaggio.', {
      userId: userRef.id,
      spostamentoId: spostamentoRef.id,
      errore: String((errore && errore.message) || errore).slice(0, 300),
    });

    return 0;
  }
}

async function chiudiLoSpostamento(userRef, spostamentoRef, amountCents, transferId) {
  await db.runTransaction(async (transaction) => {
    const fresco = await transaction.get(userRef);

    if (fresco.get('spostamentoId') !== spostamentoRef.id) {
      return;
    }

    transaction.update(userRef, {
      spostandoCents: 0,
      spostamentoId: admin.firestore.FieldValue.delete(),
      stripeCents: admin.firestore.FieldValue.increment(amountCents),
    });
    transaction.update(spostamentoRef, {
      stato: 'fatto',
      transferId,
      chiusoAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

async function annullaLoSpostamento(userRef, spostamentoRef, amountCents, errore) {
  await db.runTransaction(async (transaction) => {
    const fresco = await transaction.get(userRef);

    if (fresco.get('spostamentoId') !== spostamentoRef.id) {
      return;
    }

    transaction.update(userRef, {
      walletCents: admin.firestore.FieldValue.increment(amountCents),
      spostandoCents: 0,
      spostamentoId: admin.firestore.FieldValue.delete(),
    });
    transaction.update(spostamentoRef, {
      stato: 'annullato',
      errore: String((errore && (errore.code || errore.message)) || errore).slice(0, 300),
      chiusoAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  logger.warn('Spostamento annullato: i premi restano in custodia.', {
    userId: userRef.id,
    amountCents,
    errore: String((errore && (errore.code || errore.message)) || errore).slice(0, 300),
  });
}

/**
 * **Uno spostamento rimasto a meta': si capisce com'e' andata, poi si chiude.**
 *
 * Nei primi dieci minuti non si tocca — la richiesta potrebbe essere ancora in
 * corso. Dopo, entro il giorno, si ripete la stessa richiesta con la stessa
 * chiave: se era arrivata Stripe restituisce lo stesso trasferimento, se non
 * era arrivata la esegue adesso. Oltre il giorno la chiave non vale piu', e si
 * cerca il trasferimento fra quelli fatti verso quel conto.
 *
 * Torna `true` se lo spostamento e' chiuso (fatto o annullato).
 */
async function chiudiLoSpostamentoAppeso(stripe, userRef, accountId) {
  const utente = await userRef.get();
  const id = utente.get('spostamentoId');

  if (!id) {
    return (utente.get('spostandoCents') || 0) === 0;
  }

  const spostamentoRef = userRef.collection('spostamenti').doc(id);
  const spostamento = await spostamentoRef.get();

  if (!spostamento.exists) {
    logger.error('Spostamento in viaggio senza traccia: serve un controllo a mano.', {
      userId: userRef.id,
      spostamentoId: id,
    });

    return false;
  }

  const nato = spostamento.get('createdAt');
  const eta = nato ? Date.now() - nato.toMillis() : 0;
  const amountCents = spostamento.get('amountCents') || 0;

  if (eta < 10 * 60 * 1000) {
    return false;
  }

  if (eta < 23 * 60 * 60 * 1000) {
    const fatti = await eseguiLoSpostamento(stripe, userRef, accountId, spostamentoRef, {
      amountCents,
      sorgente: spostamento.get('sorgente') || null,
    });
    const dopo = await userRef.get();

    return fatti > 0 || !dopo.get('spostamentoId');
  }

  const elenco = await stripe.transfers.list({ destination: accountId, limit: 100 });
  const trovato = elenco.data.find(
    (trasferimento) =>
      trasferimento.metadata && trasferimento.metadata.spostamentoId === id
  );

  if (trovato) {
    await chiudiLoSpostamento(userRef, spostamentoRef, amountCents, trovato.id);
  } else {
    await annullaLoSpostamento(userRef, spostamentoRef, amountCents, 'non trovato su Stripe');
  }

  return true;
}

/**
 * **Una volta al giorno, la custodia rimasta indietro passa sui conti.**
 *
 * Succede quando il saldo di CRASY non bastava al momento della vittoria, o
 * quando uno spostamento e' rimasto a meta'. Senza questo giro quei soldi
 * resterebbero su CRASY finche' la persona non torna a premere qualcosa.
 */
exports.spostaLeCustodie = onSchedule(
  {
    schedule: 'every day 07:00',
    timeZone: 'Europe/Rome',
    secrets: [STRIPE_SECRET_KEY, STRIPE_PAYOUT_KEY],
    timeoutSeconds: 300,
  },
  async () => {
    const [conCustodia, inViaggio] = await Promise.all([
      db.collection('users').where('walletCents', '>', 0).limit(200).get(),
      db.collection('users').where('spostandoCents', '>', 0).limit(50).get(),
    ]);

    const chi = new Set(
      [...conCustodia.docs, ...inViaggio.docs]
        .filter((utente) => utente.get('payoutReady') === true && utente.get('stripeAccountId'))
        .map((utente) => utente.id)
    );

    let spostati = 0;

    for (const userId of chi) {
      try {
        spostati += await spostaSuStripe(userId);
      } catch (errore) {
        logger.warn('Custodia non spostata.', {
          userId,
          errore: String((errore && errore.message) || errore).slice(0, 300),
        });
      }
    }

    logger.info('giro delle custodie', { persone: chi.size, spostatiCents: spostati });
  }
);

/**
 * **A che punto e' il conto per ricevere i premi.** Lo chiede l'app prima di
 * far entrare qualcuno in una gara con dei soldi, e quando torna dalla pagina
 * di Stripe. Se il conto e' pronto, intanto ci sposta la custodia.
 */
exports.statoConto = onCall(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_PAYOUT_KEY] },
  async (request) => {
    const userId = request.auth && request.auth.uid;

    if (!userId) {
      throw new HttpsError('unauthenticated', 'Serve un account.');
    }

    const userRef = db.collection('users').doc(userId);
    const utente = await userRef.get();
    const accountId = utente.get('stripeAccountId');

    if (!accountId) {
      return { collegato: false, pronto: false, compilato: false, prelievi: false };
    }

    const stripe = stripePayoutClient();
    const conto = await statoDelConto(stripe, userRef, accountId);

    if (!conto.pronto) {
      return {
        collegato: true,
        pronto: false,
        compilato: conto.compilato,
        prelievi: conto.prelievi,
      };
    }

    await spostaSuStripe(userId);

    // **Il saldo e' un di piu'.** Se Stripe non lo da' — la chiave senza il
    // permesso di leggerlo, un attimo di rete — il conto resta pronto lo
    // stesso: chi deve solo entrare in gara non deve restare fuori per un
    // numero da mostrare.
    let saldo = { disponibile: 0, inArrivo: 0 };

    try {
      saldo = await saldoDelConto(stripe, accountId);
    } catch (errore) {
      logger.warn('Saldo del conto non letto.', {
        userId,
        errore: String((errore && errore.message) || errore).slice(0, 300),
      });
    }

    return {
      collegato: true,
      pronto: true,
      compilato: true,
      prelievi: conto.prelievi,
      disponibileCents: saldo.disponibile,
      inArrivoCents: saldo.inArrivo,
    };
  }
);

/** Dove chi ha un conto Express entra da solo, con email e codice. */
const INGRESSO_STRIPE_EXPRESS = 'https://connect.stripe.com/express_login';

/**
 * **L'ingresso al proprio conto Stripe.** Li' si vede quanto c'e', cosa e'
 * arrivato e cosa e' partito, e si cambia la banca: e' un conto a nome suo, e
 * deve poterlo guardare senza chiedere a CRASY.
 */
exports.linkContoStripe = onCall(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_PAYOUT_KEY] },
  async (request) => {
    const userId = request.auth && request.auth.uid;

    if (!userId) {
      throw new HttpsError('unauthenticated', 'Serve un account.');
    }

    const utente = await db.collection('users').doc(userId).get();
    const accountId = utente.get('stripeAccountId');

    if (!accountId) {
      throw new HttpsError('failed-precondition', 'account-mancante');
    }

    // **Il link personale non lo puo' fare una chiave limitata**, qualunque
    // permesso abbia: Stripe lo riserva alla chiave segreta intera, e qui ci
    // sono solo chiavi limitate. Si prova lo stesso — il giorno in cui la
    // chiave cambia funziona da solo — e altrimenti si manda all'ingresso
    // generale di Stripe Express, dove si entra con l'email del conto e un
    // codice: stesso posto, un passaggio in piu'.
    //
    // **Si provano tutte e due le chiavi.** L'ingresso generale chiede di
    // accedere, e Stripe li' propone passkey o un codice QR da un computer:
    // per chi ha appena vinto due euro dal telefono e' un muro. Il link
    // personale invece porta dentro il conto direttamente. Basta che una delle
    // due chiavi abbia il permesso "Login links" su Stripe.
    for (const [nome, cliente] of [
      ['prelievi', stripePayoutClient],
      ['principale', stripeClient],
    ]) {
      try {
        const link = await cliente().accounts.createLoginLink(accountId);

        return { url: link.url };
      } catch (errore) {
        logger.info(`Link personale al conto non creato con la chiave ${nome}.`, {
          codice: errore.code || errore.type,
        });
      }
    }

    return { url: INGRESSO_STRIPE_EXPRESS };
  }
);

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
  { secrets: [STRIPE_SECRET_KEY, STRIPE_PAYOUT_KEY] },
  async (request) => {
    const userId = request.auth && request.auth.uid;

    if (!userId) {
      throw new HttpsError('unauthenticated', 'Serve un account.');
    }

    const stripe = stripePayoutClient();
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

    // **Gia' pronto: non c'e' nessuna pagina da aprire.** Chi torna qui con il
    // conto a posto — dal portafoglio, o entrando in una gara — non deve
    // ritrovarsi su Stripe per niente.
    if (accountId) {
      const conto = await statoDelConto(stripe, userRef, accountId);

      if (conto.pronto && conto.prelievi) {
        await spostaSuStripe(userId);

        return { pronto: true };
      }
    }

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
          // **I prelievi partono quando li chiede lui**, non da soli: vedi
          // `statoDelConto`.
          settings: { payouts: { schedule: { interval: 'manual' } } },
          // Stripe chiede a cosa serve il conto: lo diciamo noi, cosi' non
          // deve inventarselo chi ha appena vinto un euro.
          business_profile: {
            product_description: 'Premi vinti nelle sfide fotografiche di CRASY',
          },
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

    const dalTelefono = Boolean(request.data && request.data.telefono === true);
    const schermata = request.data && request.data.schermata;
    const link = await stripe.accountLinks.create({
      account: accountId,
      type: 'account_onboarding',
      // **A piccoli passi.** Adesso si chiede solo quello che serve adesso;
      // il resto — un documento, quando le cifre crescono — Stripe lo chiede
      // quando servira', e l'app lo dira'.
      collection_options: { fields: 'currently_due' },
      // Si torna da dove si era partiti. Dal sito: l'app manda il proprio
      // indirizzo (vedi `indirizzoDiRitorno`). Dal telefono: si torna
      // nell'app, nella schermata da cui era partito (vedi
      // `paginaPerTornareNellApp`). Le app vecchie, che non lo dicono,
      // ripiegano sul sito come prima.
      refresh_url: dalTelefono
        ? paginaPerTornareNellApp(schermata, true)
        : indirizzoDiRitorno(request.data && request.data.appUrl, '/profile'),
      return_url: dalTelefono
        ? paginaPerTornareNellApp(schermata)
        : indirizzoDiRitorno(request.data && request.data.appUrl, '/profile'),
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
  let contestata = false;

  const paid = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);

    if (!snapshot.exists || snapshot.get('prizeStatus') !== 'held') {
      return null;
    }

    // **Un pagamento contestato non paga nessuno.** Finche' la banca di chi ha
    // messo il premio non ha deciso, quei soldi possono tornare indietro: il
    // premio resta fermo, e riparte da solo se la contestazione si chiude a
    // nostro favore. Vedi `onContestazione`.
    const contestazione = snapshot.get('contestazione');

    if (contestazione && contestazione.stato !== 'vinta') {
      contestata = true;

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
      {
        walletCents: admin.firestore.FieldValue.increment(amount),
        // **Quanto ha vinto in tutto, da sempre. Non scende mai.**
        //
        // Il saldo dice quanto ha **adesso**, e cala quando preleva o quando
        // paga una missione con quei soldi: non puo' dire quanto ha vinto. Le
        // gare nemmeno — vengono svuotate quarantotto ore dopo la fine, e una
        // classifica costruita su quelle fa sparire i premi vecchi mentre la
        // gente guarda. E' il motivo per cui il profilo diceva 6,75 e la
        // classifica 5,85 sulla stessa persona.
        //
        // Questo numero si scrive una volta, qui, nello stesso istante in cui
        // il premio entra nel portafoglio, e da li' non si tocca piu'.
        totalWonCents: admin.firestore.FieldValue.increment(amount),
        // Quante gare, non solo quanti soldi: la classifica lo scrive sotto il
        // nome, e serve a sciogliere i pari — a parita' di soldi sta sopra chi
        // l'ha fatto piu' volte.
        totalWonCount: admin.firestore.FieldValue.increment(1),
      },
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

    return { winnerUserId, amount, title: snapshot.get("title") || "" };
  });

  if (!paid) {
    return { paid: false, reason: contestata ? 'contestata' : 'non-pagabile' };
  }

  await scriviNelRegistro(paid.winnerUserId, `premio_${challengeId}`, {
    kind: 'prize',
    amountCents: paid.amount,
    challengeId,
    challengeTitle: paid.title || '',
    source: 'crasy',
    note: 'Premio vinto',
  });

  logger.info(
    `Challenge ${challengeId}: ${paid.amount} centesimi nel portafoglio di ` +
      `${paid.winnerUserId}.`
  );

  // **Il premio non resta su CRASY: va sul conto Stripe di chi ha vinto.**
  //
  // L'accredito qui sopra e' la rete di sicurezza — se il vincitore non ha
  // ancora un conto collegato, o Stripe non risponde, i soldi sono comunque
  // suoi e scritti. Ma appena si puo' escono dal saldo di CRASY: i soldi dei
  // vincitori li tiene Stripe a nome loro, non noi.
  //
  // **Legato al pagamento di chi l'ha lanciata**, quando c'e': cosi' il
  // trasferimento parte anche se il saldo di CRASY in quel momento e' basso,
  // e i soldi diventano disponibili al vincitore quando lo diventano quelli
  // del pagamento. Vedi `spostaSuStripe`.
  try {
    // **Il pagamento si legge con la chiave che incassa**, che i pagamenti
    // li crea e quindi li sa leggere: la chiave dei prelievi e' fatta per far
    // uscire soldi, e leggere un pagamento non e' fra i suoi permessi. E se
    // non si riesce, il trasferimento parte lo stesso, dal saldo di CRASY.
    let sorgente = null;

    try {
      sorgente = await caricoDellaGara(stripeClient(), challengeId);
    } catch (errore) {
      logger.warn('Pagamento della gara non letto: si trasferisce dal saldo.', {
        challengeId,
        errore: String((errore && errore.message) || errore).slice(0, 300),
      });
    }

    await spostaSuStripe(paid.winnerUserId, { importo: paid.amount, sorgente });
    // Quello che c'era gia' in custodia prima di questo premio, se c'era.
    await spostaSuStripe(paid.winnerUserId);
  } catch (errore) {
    logger.warn(`Premio di ${challengeId} rimasto in custodia: si riprova.`, {
      errore: String((errore && errore.message) || errore).slice(0, 300),
    });
  }

  return { paid: true, amountCents: paid.amount };
}

/**
 * **Il registro: ogni movimento di denaro, scritto una volta e mai toccato.**
 *
 * ## Perche' non bastava il portafoglio
 *
 * `users/{uid}/wallet` racconta solo i soldi che passano **dentro** CRASY: i
 * premi vinti, i prelievi, le missioni pagate col saldo. Chi paga con la carta
 * non ci compare — quei soldi dalla carta vanno a Stripe e non toccano il
 * portafoglio — e infatti undici pagamenti parzialmente rimborsati erano
 * visibili solo a noi, sulla dashboard di Stripe. Per chi li aveva fatti non
 * esisteva nessun posto dove leggerli.
 *
 * E le gare non possono farne le veci: annullandole si cancellano, e con loro
 * la prova di cosa era stato pagato.
 *
 * ## Append-only, e non e' una parola grossa
 *
 * Una riga non si modifica e non si cancella mai. Un estratto conto in cui una
 * riga di ieri puo' cambiare oggi non e' un estratto conto: e' uno schermo. Se
 * un movimento era sbagliato si scrive quello che lo corregge, come si fa in
 * contabilita' da seicento anni.
 *
 * Il segno e' sempre **dal punto di vista di chi legge**: positivo quello che
 * entra, negativo quello che esce. Senza questa regola scritta qui, ogni
 * chiamante la indovina a modo suo e l'estratto conto non torna.
 *
 * L'identificativo e' prevedibile — `tipo_gara` — perche' queste funzioni
 * possono girare due volte: Stripe rimanda gli eventi, e una chiusura si puo'
 * riprovare. Con un nome fisso la seconda scrittura sovrascrive la prima
 * invece di diventare una riga doppia su un estratto conto.
 */
async function scriviNelRegistro(userId, id, riga) {
  if (!userId) {
    return;
  }

  try {
    await db
      .collection('users')
      .doc(userId)
      .collection('ledger')
      .doc(id)
      .set(
        {
          ...riga,
          at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
  } catch (error) {
    logger.error(`Registro non scritto per ${userId}/${id}.`, error);
  }
}

/** Sotto questa cifra non si preleva: dieci euro. */
const MIN_WITHDRAWAL_CENTS = 1000;

/**
 * Riprende dal conto del vincitore le spese del prelievo, annullando in parte i
 * suoi trasferimenti piu' recenti (uno solo puo' essere piu' piccolo delle
 * spese: i premi da un euro sono trasferimenti da novanta centesimi).
 *
 * Torna quanto ha ripreso davvero, anche zero, e **non lancia mai**: chi chiama
 * fa partire il bonifico comunque, per la cifra che resta.
 */
async function prendiLeSpese(stripe, userId, accountId, movimentoId, quanto) {
  let preso = 0;

  try {
    const trasferimenti = await db
      .collection('users')
      .doc(userId)
      .collection('spostamenti')
      .orderBy('createdAt', 'desc')
      .limit(30)
      .get();

    for (const doc of trasferimenti.docs) {
      if (preso >= quanto) {
        break;
      }

      const transferId = doc.get('transferId');

      if (doc.get('stato') !== 'fatto' || !transferId) {
        continue;
      }

      const trasferimento = await stripe.transfers.retrieve(transferId);
      const restano =
        trasferimento.amount - (trasferimento.amount_reversed || 0);
      const prendi = Math.min(restano, quanto - preso);

      if (prendi <= 0) {
        continue;
      }

      await stripe.transfers.createReversal(
        transferId,
        {
          amount: prendi,
          description: 'Spese di prelievo CRASY',
          metadata: { userId, movimentoId },
        },
        { idempotencyKey: `spese-${movimentoId}-${transferId}` }
      );

      preso += prendi;
    }
  } catch (errore) {
    logger.error('Spese di prelievo non riprese per intero.', {
      userId,
      preso,
      quanto,
      errore: String((errore && errore.message) || errore).slice(0, 300),
    });
  }

  return preso;
}

/**
 * **Prelevare: dal conto Stripe del vincitore alla sua banca.**
 *
 * I premi stanno gia' sul suo conto Stripe (vedi `spostaSuStripe`): prelevare
 * vuol dire chiedere a Stripe di mandarli sul suo IBAN. CRASY non tocca quei
 * soldi — da' solo il via.
 *
 * Prima si sposta sul conto anche la custodia rimasta su CRASY, se c'e'. Quella
 * che non si riesce a spostare — soldi vecchi, o il saldo di CRASY
 * momentaneamente scoperto — **non resta ferma**: va nella fila dei bonifici a
 * mano, come si faceva prima. Nessuno deve sentirsi dire "i tuoi soldi ci sono
 * ma non li puoi avere".
 *
 * **Si preleva solo il disponibile.** Un premio appena vinto con la carta di
 * qualcun altro arriva sul conto "in arrivo" e diventa disponibile qualche
 * giorno dopo, quando Stripe ha incassato davvero quel pagamento: lo si dice,
 * con la cifra.
 */
exports.withdrawWallet = onCall(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_PAYOUT_KEY] },
  async (request) => {
    const userId = request.auth && request.auth.uid;

    if (!userId) {
      throw new HttpsError('unauthenticated', 'Serve un account.');
    }

    const stripe = stripePayoutClient();
    const userRef = db.collection('users').doc(userId);
    const user = await userRef.get();
    const accountId = user.get('stripeAccountId');

    if (!accountId) {
      // Non e' un errore: e' la prima volta. Chi chiama apre la registrazione.
      return { ok: false, reason: 'account-mancante' };
    }

    // **Si chiede a Stripe, non alla copia.** `payoutReady` la scrive un
    // avviso che puo' non arrivare: al momento del prelievo si domanda com'e'
    // messo il conto, che e' l'unico momento in cui la risposta serve davvero.
    const conto = await statoDelConto(stripe, userRef, accountId);

    if (!conto.pronto) {
      return { ok: false, reason: 'account-mancante' };
    }

    await spostaSuStripe(userId);

    const saldo = await saldoDelConto(stripe, accountId);
    let suStripe = 0;
    let speseCents = 0;

    if (saldo.disponibile >= MIN_WITHDRAWAL_CENTS) {
      // Il conto riceve i premi ma non puo' ancora mandarli in banca: Stripe
      // vuole un dato in piu'. Chi chiama riapre la pagina di Stripe.
      if (!conto.prelievi) {
        return { ok: false, reason: 'account-incompleto' };
      }

      const movementRef = userRef.collection('wallet').doc();

      // **Prima le spese, poi il bonifico.** Se non si riesce a prenderle il
      // bonifico parte lo stesso e per intero: nessuno deve perdere un premio
      // per un nostro problema con Stripe. Quello che manca lo si vede nei log.
      const spese = await prendiLeSpese(
        stripe,
        userId,
        accountId,
        movementRef.id,
        Math.min(SPESE_PRELIEVO_CENTS, saldo.disponibile)
      );

      await stripe.payouts.create(
        {
          amount: saldo.disponibile - spese,
          currency: 'eur',
          description: 'Premi vinti su CRASY',
          metadata: { userId, movementId: movementRef.id },
        },
        { stripeAccount: accountId, idempotencyKey: `prelievo-${movementRef.id}` }
      );

      speseCents = spese;
      suStripe = saldo.disponibile;

      await db.runTransaction(async (transaction) => {
        const fresco = await transaction.get(userRef);

        transaction.update(userRef, {
          stripeCents: Math.max(0, (fresco.get('stripeCents') || 0) - suStripe),
        });
        transaction.set(movementRef, {
          kind: 'withdrawal',
          amountCents: -suStripe,
          feeCents: speseCents,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await scriviNelRegistro(userId, `prelievo_${movementRef.id}`, {
        kind: 'withdrawal',
        amountCents: -suStripe,
        feeCents: speseCents,
        source: 'bank',
        note:
          speseCents > 0
            ? `Prelievo: dal tuo conto Stripe alla tua banca (di cui ${(speseCents / 100).toFixed(2).replace('.', ',')} € di spese di prelievo)`
            : 'Prelievo: dal tuo conto Stripe alla tua banca',
      });

      logger.info(`${userId} ha prelevato ${suStripe} centesimi dal suo conto Stripe.`);
    }

    // La custodia che non e' potuta passare sul conto: bonifico a mano.
    const aMano = await mettiInFilaIlBonifico(userId);

    if (suStripe === 0 && aMano.quanto <= 0) {
      return {
        ok: false,
        reason:
          aMano.reason === 'gia-in-corso'
            ? 'gia-in-corso'
            : saldo.inArrivo > 0
            ? 'in-arrivo'
            : 'saldo-basso',
        disponibileCents: saldo.disponibile,
        inArrivoCents: saldo.inArrivo,
        minimumCents: MIN_WITHDRAWAL_CENTS,
      };
    }

    return {
      ok: true,
      stripeCents: suStripe,
      speseCents,
      manualeCents: Math.max(0, aMano.quanto),
      inArrivoCents: saldo.inArrivo,
    };
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
  const dalPortafoglio = snapshot.get('paidFromWallet') === true;

  // **Una gara pagata col portafoglio non ha nessun pagamento su Stripe**, e
  // qui si usciva senza fare niente. Annullandola, i soldi non tornavano ne'
  // sulla carta ne' nel portafoglio: restavano scritti da nessuna parte,
  // perche' subito dopo la gara viene cancellata. Erano soldi persi, e
  // l'unico a saperlo era chi li aveva messi.
  // **Una gara del fondo torna al fondo.** Stesso buco del portafoglio, e
  // ci sono gia' caduto: due missioni annullate hanno portato via due euro
  // che non sono tornati da nessuna parte. Su Stripe quei soldi ci sono
  // ancora — il fondo e' un prepagato, non un addebito per gara — quindi
  // l'unica cosa giusta e' rimetterli dove stavano.
  const dalFondo = snapshot.get('pagataDalFondo') === true;

  if (dalFondo) {
    const chi = snapshot.get('createdByUserId');
    const premio = snapshot.get('prizeCents') || 0;
    // **Il fondo non e' per forza di chi compare come autore**: le missioni
    // del fondo si lanciano a turno a nome dei padroni. Il fondo giusto e'
    // quello che la ricorda fra le sue `lanciate`.
    const padrone = (await fondoDi(challengeId)) || chi;

    if (chi && premio > 0) {
      await db
        .collection('salvadanai')
        .doc(padrone)
        .update({
          fondoCents: admin.firestore.FieldValue.increment(premio),
          spesiCents: admin.firestore.FieldValue.increment(-premio),
        });

      // E la classifica di chi fa giocare: una gara annullata non ha fatto
      // giocare nessuno. Quella anonima non c'era mai entrata.
      if (snapshot.get('anonimo') !== true) {
        await db
          .collection('users')
          .doc(chi)
          .update({
            totalStakedCents: admin.firestore.FieldValue.increment(-premio),
            totalStakedCount: admin.firestore.FieldValue.increment(-1),
          });
      }

      await scriviNelRegistro(padrone, `rimborso_${challengeId}`, {
        kind: 'refund',
        amountCents: premio,
        challengeId,
        challengeTitle: snapshot.get('title') || '',
        source: 'card',
        note: 'Missione annullata, premio tornato nel fondo',
      });
    }

    await ref.update({ prizeStatus: 'refunded' });
    logger.info('premio tornato nel fondo', { challengeId, chi });

    return;
  }

  if (!paymentIntentId && !dalPortafoglio) {
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
  const premio = snapshot.get('prizeCents') || 0;
  const quanto = soloIlPremio ? premio : undefined;
  // Chi ha pagato, anche in anonimo: i soldi tornano a lui. Vedi `autori.js`.
  const haPagato = await autoreDi(snapshot);

  // **Dal portafoglio torna nel portafoglio, e torna intero.**
  //
  // Le spese si trattengono perche' sono uscite davvero: su un pagamento col
  // portafoglio non ne e' uscita nessuna — nessun incasso, nessuna commissione
  // — quindi non c'e' niente da trattenere, nemmeno quando a cancellare e'
  // stato lui.
  let restituito = 0;
  let dove = '';

  if (dalPortafoglio) {
    restituito = premio;
    dove = 'portafoglio';

    if (haPagato) {
      await db
        .collection('users')
        .doc(haPagato)
        .update({
          walletCents: admin.firestore.FieldValue.increment(premio),
        });

      await db
        .collection('users')
        .doc(haPagato)
        .collection('wallet')
        .doc(`rimborso_${challengeId}`)
        .set({
          kind: 'refund',
          amountCents: premio,
          challengeId,
          challengeTitle: snapshot.get('title') || '',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      // Il premio tornato non resta su CRASY: va sul suo conto Stripe, se ce
      // l'ha. Se no resta in custodia, e passa quando lo collega.
      try {
        await spostaSuStripe(haPagato);
      } catch (errore) {
        logger.warn('Rimborso rimasto in custodia.', {
          userId: haPagato,
          errore: String((errore && errore.message) || errore).slice(0, 300),
        });
      }
    }
  } else {
    const rimborso = await stripe.refunds.create(
      {
        payment_intent: paymentIntentId,
        ...(quanto ? { amount: quanto } : {}),
      },
      { idempotencyKey: `challenge-refund-${challengeId}` }
    );

    restituito = rimborso.amount || quanto || 0;
    dove = 'carta';
  }

  await ref.update({ prizeStatus: 'refunded' });

  // **La prova resta anche quando la gara non c'e' piu'.**
  //
  // Annullare una missione la cancella subito dopo questo rimborso: senza
  // questa riga, dell'intera operazione non restava **niente** nel database.
  // Per sapere cosa era stato restituito bisognava andare su Stripe — e il
  // giorno che qualcuno scrive "mi avete tenuto dei soldi", non c'era niente
  // da mostrargli.
  //
  // Sta sotto l'utente e non sotto la gara, proprio perche' la gara sparisce.
  if (haPagato) {
    try {
      await db
        .collection('users')
        .doc(haPagato)
        .collection('refunds')
        .doc(challengeId)
        .set({
          challengeId,
          challengeTitle: snapshot.get('title') || '',
          // Quanto aveva messo in palio, quanto gli e' tornato, e dove.
          prizeCents: premio,
          refundedCents: restituito,
          destinazione: dove,
          // Perche': cancellata da lui, o nessuno ha partecipato.
          motivo: soloIlPremio ? 'annullata' : 'nessun-partecipante',
          stripePaymentIntentId: paymentIntentId || null,
          at: admin.firestore.FieldValue.serverTimestamp(),
        });
    } catch (error) {
      logger.error(`Prova del rimborso non scritta per ${challengeId}.`, error);
    }

    await scriviNelRegistro(haPagato, `rimborso_${challengeId}`, {
      kind: 'refund',
      amountCents: restituito,
      challengeId,
      challengeTitle: snapshot.get('title') || '',
      source: dove === 'portafoglio' ? 'wallet' : 'card',
      note: soloIlPremio
        ? 'Rimborso: hai annullato la missione'
        : 'Rimborso: non ha partecipato nessuno',
    });
  }

  // **Un premio restituito non conta fra quelli messi in palio.**
  //
  // E' l'unica sottrazione che questi due contatori ammettono, e non e' una
  // contraddizione: `totalStakedCents` dice quanti soldi uno ha messo a
  // disposizione degli altri, e dei soldi tornati in tasca non sono stati
  // messi a disposizione di nessuno.
  //
  // Senza, scalare la classifica di chi fa giocare sarebbe gratis: si lancia
  // una gara da cento euro, non partecipa nessuno, il rimborso torna indietro
  // intero e in cima all'elenco resta scritto che hai fatto giocare la gente.
  //
  // Una gara anonima non era mai stata contata, e non si scala.
  if (haPagato && snapshot.get('anonimo') !== true) {
    try {
      await db
        .collection('users')
        .doc(haPagato)
        .update({
          totalStakedCents: admin.firestore.FieldValue.increment(
            -(snapshot.get('prizeCents') || 0)
          ),
          totalStakedCount: admin.firestore.FieldValue.increment(-1),
        });
    } catch (error) {
      logger.warn(`Messo in palio non scalato per ${haPagato}.`, error);
    }
  }

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

    // Anche in anonimo: chi l'ha lanciata sta nel foglio a parte (`autori.js`).
    if ((await autoreDi(snapshot)) !== userId) {
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

module.exports.scriviNelRegistro = scriviNelRegistro;
// Le chiavi servono anche alle funzioni che chiudono le gare: pagano il
// vincitore e rimborsano, e senza chiave Stripe non risponde.
module.exports.STRIPE_SECRET_KEY = STRIPE_SECRET_KEY;
module.exports.STRIPE_PAYOUT_KEY = STRIPE_PAYOUT_KEY;
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
/**
 * **Pagare il premio con i soldi che si hanno gia' su CRASY.**
 *
 * Chi ha vinto qualcosa ha un saldo nel portafoglio, e finora quel saldo sapeva
 * fare una cosa sola: uscire con un bonifico. Ma la cosa piu' naturale da fare
 * con dei soldi vinti su CRASY e' rimetterli in gioco su CRASY — e per farlo
 * bisognava prelevarli, aspettare giorni, e poi ripagare con la carta. Per un
 * euro.
 *
 * **Costa meno che pagare con la carta, e non e' uno sconto.** Con Stripe chi
 * lancia paga `chargeCents` — il premio piu' le commissioni dell'incasso, che
 * esistono perche' del denaro entra davvero. Qui non entra niente: quei soldi
 * sono gia' nostri, fermi nello stesso conto da cui usciranno per il vincitore.
 * Non c'e' nessuna commissione da coprire, quindi si addebita il premio e
 * basta. La trattenuta del dieci per cento sul premio resta: quella sta
 * dall'altra parte, al momento della vittoria, e non cambia da dove arrivano i
 * soldi.
 *
 * ## Una transazione sola, e deve esserlo
 *
 * Scalare il portafoglio e accendere la gara sono due scritture, e in mezzo c'e'
 * tutto quello che puo' andare storto: una funzione che muore, la rete che
 * cade. Fatte separatamente, il caso peggiore non e' un errore — e' **soldi
 * tolti a qualcuno per una gara che non si e' mai aperta**, e nessuno se ne
 * accorgerebbe se non lui.
 *
 * Dentro una transazione le due cose succedono tutte e due o nessuna delle due.
 *
 * ## E non si paga due volte
 *
 * Il controllo su `prizeStatus` sta **dentro** la transazione, dopo aver riletto
 * la gara: due tocchi rapidi sul tasto leggerebbero entrambi un saldo buono
 * prima che l'altro scriva, e scalerebbero il premio due volte per una gara
 * sola. Riletta li' dentro, la seconda trova `held` e si ferma.
 */
exports.payChallengeFromWallet = onCall(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_PAYOUT_KEY] },
  async (request) => {
  const userId = request.auth && request.auth.uid;

  if (!userId) {
    throw new HttpsError('unauthenticated', 'Serve un account.');
  }

  const challengeId = String((request.data && request.data.challengeId) || '');

  if (!challengeId) {
    throw new HttpsError('invalid-argument', 'Manca la challenge.');
  }

  const userRef = db.collection('users').doc(userId);
  const challengeRef = db.collection('challenges').doc(challengeId);
  const movimentoRef = userRef.collection('wallet').doc();

  const esito = await db.runTransaction(async (transaction) => {
    const [gara, utente] = await Promise.all([
      transaction.get(challengeRef),
      transaction.get(userRef),
    ]);

    if (!gara.exists) {
      return { ok: false, reason: 'gara-sparita' };
    }

    // **Paga chi l'ha lanciata, e nessun altro.** Senza questo, chiunque
    // conosca l'identificativo di una gara potrebbe pagarla col proprio
    // portafoglio — che sembra un regalo, ed e' invece il modo di svuotare il
    // saldo di qualcuno con una chiamata.
    if ((await autoreDi(gara)) !== userId) {
      return { ok: false, reason: 'non-tua' };
    }

    const premio = gara.get('prizeCents') || 0;

    if (premio <= 0) {
      return { ok: false, reason: 'gratis' };
    }

    const stato = gara.get('prizeStatus');

    if (stato === 'held' || stato === 'paidOut') {
      // Gia' pagata: si risponde di si' senza toccare niente. E' il secondo
      // tocco sul tasto, e deve finire bene — non con un errore su una cosa
      // che e' andata a buon fine.
      return { ok: true, giaPagata: true };
    }

    const saldo = utente.get('walletCents') || 0;

    if (saldo < premio) {
      return { ok: false, reason: 'saldo-basso', walletCents: saldo };
    }

    // L'orologio della gara riparte adesso, come fa il webhook di Stripe: una
    // gara comincia quando il premio c'e', non quando e' stata scritta.
    const adesso = admin.firestore.Timestamp.now();
    const startsAt = gara.get('startsAt');
    const endsAt = gara.get('endsAt');
    const durataMs =
      startsAt && endsAt ? endsAt.toMillis() - startsAt.toMillis() : 0;
    const durata = durataMs >= 60 * 1000 ? durataMs : 60 * 60 * 1000;

    transaction.update(userRef, {
      walletCents: admin.firestore.FieldValue.increment(-premio),
      // Lo stesso conteggio del webhook di Stripe: il premio e' incassato,
      // anche se i soldi non sono entrati da fuori ma erano gia' dentro.
      //
      // **In una scrittura sola con il saldo**, non in due sullo stesso
      // documento: due mutazioni sulla stessa riga dentro una transazione
      // funzionano, ma chi legge questo codice fra sei mesi deve poter vedere
      // in un colpo tutto quello che succede a questo utente.
      //
      // In anonimo la classifica non si muove: vedi il webhook di Stripe.
      ...(gara.get('anonimo') === true
        ? {}
        : {
            totalStakedCents: admin.firestore.FieldValue.increment(premio),
            totalStakedCount: admin.firestore.FieldValue.increment(1),
          }),
    });

    transaction.update(challengeRef, {
      prizeStatus: 'held',
      paidAt: adesso,
      // **Scritto dentro la gara che e' stata pagata col portafoglio.** Non
      // serve all'app: serve a chi un giorno dovra' far tornare i conti, e
      // trovera' una gara pagata senza nessun incasso corrispondente su Stripe.
      paidFromWallet: true,
      startsAt: adesso,
      endsAt: admin.firestore.Timestamp.fromMillis(
        adesso.toMillis() + durata
      ),
    });

    // La riga nel portafoglio: senza, il saldo cala e non c'e' scritto perche'.
    transaction.set(movimentoRef, {
      kind: 'challengePayment',
      amountCents: -premio,
      challengeId,
      challengeTitle: gara.get('title') || '',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { ok: true, amountCents: premio };
  });

  // **La custodia non basta: si paga con il saldo del suo conto Stripe.** E'
  // dove stanno i premi da quando vanno a nome di chi vince. Vedi
  // `pagaDalContoStripe`.
  if (esito.reason === 'saldo-basso') {
    return pagaDalContoStripe(userId, challengeId);
  }

  if (esito.ok && !esito.giaPagata) {
    // **Il registro anche di qui.** Una gara pagata col portafoglio non passa
    // dal webhook di Stripe — e' quello a scrivere la riga per i pagamenti con
    // la carta — quindi senza questa chiamata l'estratto conto avrebbe avuto un
    // buco proprio sul modo di pagare piu' nuovo.
    //
    // `giaPagata` la esclude: quella e' la seconda pressione del tasto su una
    // gara gia' aperta, e non e' un movimento nuovo.
    const gara = await challengeRef.get();

    await scriviNelRegistro(userId, `pagamento_${challengeId}`, {
      kind: 'challengePayment',
      amountCents: -(esito.amountCents || 0),
      challengeId,
      challengeTitle: gara.get('title') || '',
      source: 'wallet',
      note: 'Premio messo in palio, pagato col portafoglio',
    });

    logger.info(
      `${userId} ha pagato la challenge ${challengeId} col portafoglio.`
    );
  }

  return esito;
  }
);

/**
 * **Pagare una missione con i premi che stanno sul proprio conto Stripe.**
 *
 * I premi vinti sono sul conto Stripe di chi ha vinto, non su CRASY: per
 * metterli in palio CRASY li preleva da li' con un addebito sul conto
 * collegato. Stripe lo consente per pagare un servizio della piattaforma — e
 * lanciare una missione lo e' — a tre condizioni, tutte rispettate qui:
 *
 * - **il consenso**, dato una volta, esplicito, e scritto con la data
 *   (`consents/addebito_saldo`). Senza, non si tocca niente;
 * - **i soldi disponibili**, non quelli in arrivo: un premio appena vinto
 *   diventa spendibile quando Stripe ha incassato il pagamento da cui viene;
 * - **solo quando lo chiede lui**, toccando "paga col portafoglio".
 *
 * Costa a CRASY l'1,4% dell'importo: meno della carta, ed e' gia' compreso nel
 * dieci per cento che resta a CRASY quando la gara si chiude.
 *
 * Se la gara intanto si e' gia' pagata in un altro modo, l'addebito torna
 * indietro sul suo conto: e' la correzione di un errore, che Stripe consente.
 */
async function pagaDalContoStripe(userId, challengeId) {
  const userRef = db.collection('users').doc(userId);
  const challengeRef = db.collection('challenges').doc(challengeId);
  const [utente, gara] = await Promise.all([userRef.get(), challengeRef.get()]);
  const premio = gara.get('prizeCents') || 0;
  const custodia = utente.get('walletCents') || 0;
  const accountId = utente.get('stripeAccountId');

  if (!accountId || utente.get('payoutReady') !== true) {
    return { ok: false, reason: 'saldo-basso', walletCents: custodia };
  }

  const consenso = await userRef.collection('consents').doc(CONSENSO_ADDEBITO).get();

  if (!consenso.exists || consenso.get('accepted') !== true) {
    return { ok: false, reason: 'consenso-mancante' };
  }

  const stripe = stripePayoutClient();

  // La custodia rimasta raggiunge il resto sul conto: si paga da un posto solo.
  if (custodia > 0) {
    await spostaSuStripe(userId);
  }

  const saldo = await saldoDelConto(stripe, accountId);

  if (saldo.disponibile < premio) {
    return {
      ok: false,
      reason:
        saldo.disponibile + saldo.inArrivo >= premio ? 'saldo-in-arrivo' : 'saldo-basso',
      disponibileCents: saldo.disponibile,
      inArrivoCents: saldo.inArrivo,
    };
  }

  // **Quante volte un addebito per questa gara e' gia' tornato indietro.**
  // Entra nella chiave: dopo una restituzione, riprovando, Stripe deve fare un
  // addebito nuovo — con la chiave di prima restituirebbe quello vecchio, i
  // cui soldi sono gia' tornati, e la gara risulterebbe pagata gratis.
  const restituzioniRef = db
    .collection('addebitiRestituiti')
    .doc(`${challengeId}_${userId}`);
  const restituzioni = (await restituzioniRef.get()).get('volte') || 0;

  const addebito = await stripe.charges.create(
    {
      amount: premio,
      currency: 'eur',
      source: accountId,
      description: `Premio: ${gara.get('title') || 'missione CRASY'}`,
      // Nel metadato la gara e il premio: il riquadro dei guadagni lo legge
      // come il pagamento di una missione, e divide fra vincitore e CRASY.
      metadata: {
        kind: 'addebitoSaldo',
        challengeId,
        userId,
        prizeCents: String(premio),
      },
    },
    // Un addebito per gara: il secondo tocco riceve lo stesso, non un altro.
    {
      idempotencyKey: restituzioni
        ? `addebito-${challengeId}-${restituzioni}`
        : `addebito-${challengeId}`,
    }
  );

  const movimentoRef = userRef.collection('wallet').doc(`addebito_${challengeId}`);

  const restituisci = async (motivo) => {
    await stripe.transfers.create(
      {
        amount: premio,
        currency: 'eur',
        destination: accountId,
        description: 'Restituzione: la missione non e\' stata pagata con il saldo',
        metadata: { userId, challengeId, addebitoId: addebito.id },
      },
      { idempotencyKey: `restituisci-${addebito.id}` }
    );

    await restituzioniRef.set(
      { volte: admin.firestore.FieldValue.increment(1), ultimo: addebito.id },
      { merge: true }
    );

    logger.warn(`Addebito restituito: ${motivo}.`, { userId, challengeId });
  };

  // **L'addebito e' gia' fatto: se la scrittura non va, i soldi tornano.**
  // Prima restavano a CRASY senza che la gara risultasse pagata, e senza
  // nessuno che se ne accorgesse.
  let esito;

  try {
    esito = await db.runTransaction(async (transaction) => {
      const [fresca, fresco] = await Promise.all([
        transaction.get(challengeRef),
        transaction.get(userRef),
      ]);

      if (!fresca.exists) {
        return { ok: false, reason: 'gara-sparita', restituisci: true };
      }

      const stato = fresca.get('prizeStatus');

      if (stato === 'held' || stato === 'paidOut') {
        // Pagata da questo stesso addebito: e' il secondo tocco, va bene cosi'.
        // Pagata in un altro modo: l'addebito non ha pagato niente e torna.
        return fresca.get('addebitoId') === addebito.id
          ? { ok: true, giaPagata: true }
          : { ok: true, giaPagata: true, restituisci: true };
      }

      const adesso = admin.firestore.Timestamp.now();
      const startsAt = fresca.get('startsAt');
      const endsAt = fresca.get('endsAt');
      const durataMs =
        startsAt && endsAt ? endsAt.toMillis() - startsAt.toMillis() : 0;
      const durata = durataMs >= 60 * 1000 ? durataMs : 60 * 60 * 1000;

      transaction.update(userRef, {
        stripeCents: Math.max(0, (fresco.get('stripeCents') || 0) - premio),
        ...(fresca.get('anonimo') === true
          ? {}
          : {
              totalStakedCents: admin.firestore.FieldValue.increment(premio),
              totalStakedCount: admin.firestore.FieldValue.increment(1),
            }),
      });

      transaction.update(challengeRef, {
        prizeStatus: 'held',
        paidAt: adesso,
        // Come le gare pagate dalla custodia: se si annulla, il premio torna nel
        // portafoglio — e da li' sul conto Stripe.
        paidFromWallet: true,
        addebitoId: addebito.id,
        startsAt: adesso,
        endsAt: admin.firestore.Timestamp.fromMillis(adesso.toMillis() + durata),
      });

      transaction.set(movimentoRef, {
        kind: 'challengePayment',
        amountCents: -premio,
        challengeId,
        challengeTitle: fresca.get('title') || '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { ok: true, amountCents: premio };
    });
  } catch (errore) {
    // Puo' essere andata a buon fine e aver risposto male: si guarda.
    const dopo = await challengeRef.get();

    if (dopo.get('addebitoId') !== addebito.id) {
      await restituisci('la scrittura della gara non e\' andata');

      throw new HttpsError('aborted', 'Non siamo riusciti a pagare: riprova.');
    }

    logger.warn('Transazione con errore ma gara pagata da questo addebito.', {
      challengeId,
      errore: String((errore && errore.message) || errore).slice(0, 300),
    });
    esito = { ok: true, amountCents: premio };
  }

  if (esito.restituisci) {
    await restituisci('la missione era gia\' pagata o sparita');

    const { restituisci: _restituita, ...risposta } = esito;

    return risposta;
  }

  if (esito.ok && !esito.giaPagata) {
    await scriviNelRegistro(userId, `pagamento_${challengeId}`, {
      kind: 'challengePayment',
      amountCents: -premio,
      challengeId,
      challengeTitle: gara.get('title') || '',
      source: 'wallet',
      note: 'Premio messo in palio, pagato con il tuo saldo Stripe',
    });

    logger.info(`${userId} ha pagato ${challengeId} con il saldo Stripe.`);
  }

  return esito;
}

exports.requestPayout = onCall(async (request) => {
  const userId = request.auth && request.auth.uid;

  if (!userId) {
    throw new HttpsError('unauthenticated', 'Serve un account.');
  }

  const esito = await mettiInFilaIlBonifico(userId);

  if (esito.reason === 'dati-mancanti') {
    throw new HttpsError('failed-precondition', 'dati-mancanti');
  }

  if (esito.quanto <= 0) {
    return esito.reason === 'gia-in-corso'
      ? { ok: false, reason: 'gia-in-corso' }
      : { ok: false, reason: 'saldo-basso', minimumCents: MIN_WITHDRAWAL_CENTS };
  }

  return { ok: true, amountCents: esito.quanto };
});

/**
 * **La custodia che va pagata a mano: un bonifico in fila.**
 *
 * E' la strada di prima, e resta per quello che non puo' passare dal conto
 * Stripe: le versioni vecchie dell'app, e i soldi rimasti su CRASY quando il
 * suo saldo non bastava a spostarli. Torna quanto e' entrato in fila, oppure
 * zero con il motivo.
 */
async function mettiInFilaIlBonifico(userId) {
  const userRef = db.collection('users').doc(userId);
  const dati = (await userRef.collection('private').doc('payout').get()).data();

  if (!dati || !dati.iban || !dati.firstName || !dati.lastName) {
    return { quanto: 0, reason: 'dati-mancanti' };
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
    return { quanto: 0, reason: 'saldo-basso' };
  }

  if (quanto < 0) {
    return { quanto: 0, reason: 'gia-in-corso' };
  }

  await scriviNelRegistro(userId, `prelievo_${richiestaRef.id}`, {
    kind: 'withdrawal',
    amountCents: -quanto,
    source: 'bank',
    note: 'Prelievo chiesto: in arrivo sul tuo conto',
  });

  logger.info(`Prelievo chiesto da ${userId}: ${quanto} centesimi.`);

  return { quanto };
}

/** L'elenco dei bonifici da fare. Solo per chi tiene CRASY. */
/**
 * **Le mance, e si vedono solo da qui.**
 *
 * Sono soldi che arrivano a CRASY, non agli utenti: in app non hanno nessun
 * posto dove stare — una classifica dei piu' generosi sarebbe una gara a parte
 * che nessuno ha chiesto, e il saldo di chi le manda non le riguarda.
 *
 * Chi le manda le ritrova nel proprio estratto conto, perche' sono soldi
 * usciti dalla sua carta. Qui invece ci sono **tutte**, ed e' l'unico posto da
 * cui si vede quanto entra da questa strada.
 */
exports.adminListMance = onCall(async (request) => {
  if (!request.auth || request.auth.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Non sei un amministratore.');
  }

  const mance = await db.collection('mance').limit(200).get();

  const righe = mance.docs.map((d) => ({
    id: d.id,
    userId: d.get('userId') || '',
    username: d.get('username') || '',
    beneficiarioUsername: d.get('beneficiarioUsername') || '',
    amountCents: d.get('amountCents') || 0,
    verificato: d.get('verificato') === true,
    createdAt: d.get('createdAt') ? d.get('createdAt').toMillis() : null,
  }));

  // Le piu' recenti in cima: al contrario dei prelievi, qui non c'e' niente da
  // fare — si guarda, e cio' che si guarda per primo e' cosa e' appena entrato.
  righe.sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));

  const totale = righe.reduce((somma, riga) => somma + riga.amountCents, 0);

  return { mance: righe, totaleCents: totale };
});

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

// ---------------------------------------------------------------------------
// La mancia
// ---------------------------------------------------------------------------

/** Da questa cifra in su, la mancia porta il verificato a vita. */
const MANCIA_PER_IL_VERIFICATO = 1000;

/** Quanto puo' valere una mancia: da un euro a cinquecento. */
const MANCIA_MINIMA = 100;
const MANCIA_MASSIMA = 50000;

/**
 * Chi riceve il verificato: l'username scritto da chi dona, anche il suo.
 * Torna `{ id, username }` o lancia se non c'e'.
 */
async function beneficiarioDi(username) {
  const nome = String(username || '').trim().toLowerCase().replace(/^@/, '');

  if (!nome) {
    throw new HttpsError('invalid-argument', 'Scrivi un nome utente.');
  }

  const trovati = await db.collection('users').where('username', '==', nome).limit(1).get();

  if (trovati.empty) {
    throw new HttpsError('not-found', `Non c'e' nessuno che si chiama @${nome}.`);
  }

  return { id: trovati.docs[0].id, username: nome };
}

function importoDellaMancia(valore) {
  const cents = Number(valore);

  if (!Number.isInteger(cents) || cents < MANCIA_MINIMA || cents > MANCIA_MASSIMA) {
    throw new HttpsError('invalid-argument', 'La mancia va da 1 a 500 euro.');
  }

  return cents;
}

/**
 * **La mancia dal sito**: la pagina di Stripe, come per i premi.
 */
exports.startTipPayment = onCall(
  { secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    const userId = request.auth && request.auth.uid;

    if (!userId) {
      throw new HttpsError('unauthenticated', 'Serve un account.');
    }

    const cents = importoDellaMancia(request.data && request.data.amountCents);
    const chi = await beneficiarioDi(request.data && request.data.username);
    const stripe = stripeClient();
    const ritorno = indirizzoDiRitorno(
      request.data && request.data.appUrl,
      request.data && request.data.returnRoute
    );

    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      line_items: [
        {
          quantity: 1,
          price_data: {
            currency: 'eur',
            unit_amount: cents,
            product_data: {
              name: 'Mancia a CRASY',
              description: cents >= MANCIA_PER_IL_VERIFICATO
                ? `Grazie! @${chi.username} diventa Sostenitore di CRASY per sempre.`
                : 'Grazie per sostenere CRASY.',
            },
          },
        },
      ],
      metadata: {
        kind: 'mancia',
        userId,
        beneficiarioId: chi.id,
        beneficiarioUsername: chi.username,
        amountCents: String(cents),
      },
      success_url: ritorno,
      cancel_url: ritorno,
    });

    return { url: session.url };
  }
);

/**
 * **La mancia dal telefono**: il foglio di Stripe dentro l'app, come per i
 * premi, con la carta gia' salvata se c'e'.
 */
exports.createTipPaymentIntent = onCall(
  { secrets: [STRIPE_SECRET_KEY], memory: '512MiB' },
  async (request) => {
    const userId = request.auth && request.auth.uid;

    if (!userId) {
      throw new HttpsError('unauthenticated', 'Serve un account.');
    }

    if (!PUBLISHABLE_KEY) {
      throw new HttpsError('failed-precondition', 'Pagamenti non configurati.');
    }

    const cents = importoDellaMancia(request.data && request.data.amountCents);
    const chi = await beneficiarioDi(request.data && request.data.username);
    const stripe = stripeClient();
    const userRef = db.collection('users').doc(userId);
    const user = await userRef.get();
    const customerId = await clienteDi(stripe, userId, userRef, user);

    const intent = await stripe.paymentIntents.create({
      amount: cents,
      currency: 'eur',
      customer: customerId,
      setup_future_usage: 'off_session',
      automatic_payment_methods: { enabled: true, allow_redirects: 'never' },
      description: 'Mancia a CRASY',
      metadata: {
        kind: 'mancia',
        userId,
        beneficiarioId: chi.id,
        beneficiarioUsername: chi.username,
        amountCents: String(cents),
      },
    });

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

    return {
      clientSecret: intent.client_secret,
      customerId,
      ephemeralKeySecret,
      publishableKey: PUBLISHABLE_KEY,
    };
  }
);

/**
 * **La mancia e' arrivata.** Si scrive una volta sola (Stripe puo' mandare lo
 * stesso evento piu' volte), e da dieci euro in su il beneficiario diventa
 * verificato per sempre.
 */
async function registraMancia(metadata, paymentIntentId) {
  if (!paymentIntentId) {
    return;
  }

  const cents = Number(metadata.amountCents) || 0;
  const beneficiario = metadata.beneficiarioId || '';
  const ref = db.collection('mance').doc(String(paymentIntentId));

  const nuova = await db.runTransaction(async (transaction) => {
    const gia = await transaction.get(ref);

    if (gia.exists) {
      return false;
    }

    transaction.set(ref, {
      userId: metadata.userId || '',
      beneficiarioId: beneficiario,
      beneficiarioUsername: metadata.beneficiarioUsername || '',
      amountCents: cents,
      verificato: cents >= MANCIA_PER_IL_VERIFICATO,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (beneficiario && cents >= MANCIA_PER_IL_VERIFICATO) {
      transaction.update(db.collection('users').doc(beneficiario), {
        verificato: true,
        verificatoDa: 'mancia',
        verificatoIl: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return true;
  });

  if (nuova) {
    // **La mancia nell'estratto conto di chi l'ha data.** Sono soldi usciti
    // dalla sua carta come quelli di una missione, e un estratto conto che
    // salta una voce e' un estratto conto che non si puo' usare per far
    // tornare i conti — cioe' l'unica cosa per cui serve.
    await scriviNelRegistro(
      metadata.userId || '',
      `mancia_${paymentIntentId}`,
      {
        kind: 'tip',
        amountCents: -cents,
        source: 'card',
        note: metadata.beneficiarioUsername
          ? `Mancia a CRASY per @${metadata.beneficiarioUsername}`
          : 'Mancia a CRASY',
      }
    );

    logger.info(`Mancia di ${cents} centesimi per @${metadata.beneficiarioUsername}.`);
  }
}

