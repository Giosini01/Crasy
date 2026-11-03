'use strict';

/**
 * **Il percorso intero, contro un database finto.** Non e' fra le prove di `npm test`
 * perche' vuole gli emulatori di Firebase, che partono con:
 *
 *     npm run test:server
 *
 * Il modello non si chiama: si sostituisce `giudice.giudica`, cosi' si provano anche
 * i guasti, e nessuna prova costa niente.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');

const PROGETTO = process.env.GCLOUD_PROJECT || 'demo-crasy';

process.env.GCLOUD_PROJECT = PROGETTO;
process.env.OPENAI_API_KEY = 'spenta';
process.env.STRIPE_SECRET_KEY = 'sk_test_finta';
process.env.STRIPE_PAYOUT_KEY = 'da-sostituire';

// Il pacchetto di Stripe, per le funzioni che se lo creano da sole.
let stripeFinto = {};

require('stripe');
require.cache[require.resolve('stripe')].exports = function StripeFinto() {
  return stripeFinto;
};

// Come in produzione: e' `index.js` che accende Firebase e carica tutto il resto.
const funzioni = require('../index');
const giudice = require('../giudice');
const missioni = require('../missioni');
const payments = require('../payments');
const pannello = require('../pannello');
const posta = require('../posta');

const db = admin.firestore();

const CHI = 'lancia1';
const AMICO = 'amico1';
const CHI_MODERA = 'admin1';

let prossimoVoto = null;
let chiamate = 0;

// Niente rete: quello che direbbe il modello lo decide ogni prova.
let ultimeOpzioni = null;

giudice.giudica = async (_testi, opzioni) => {
  chiamate += 1;
  ultimeOpzioni = opzioni;

  return prossimoVoto;
};

// Niente Stripe vero.
payments.stripeClient = () => ({
  balance: {
    retrieve: async () => ({
      available: [{ currency: 'eur', amount: 12345 }],
      pending: [{ currency: 'eur', amount: 100 }],
    }),
  },
  balanceTransactions: {
    // Un incasso, che qui non conta: e' di `adminGuadagni`. Poi tutto il resto.
    list: async function* () {
      yield { type: 'charge', amount: 1000, fee: 50 };
      yield { type: 'stripe_fee', amount: -200, fee: 0, reporting_category: 'fee' };
      yield { type: 'refund', amount: -300, fee: 0, reporting_category: 'refund' };
      yield { type: 'transfer', amount: -400, fee: 0, reporting_category: 'transfer' };
      yield { type: 'payout', amount: -500, fee: 25, reporting_category: 'payout' };
    },
  },
});

function voto(punteggio, altro = {}) {
  return {
    esito: 'fatto',
    punteggio,
    categoria: 'nessuna',
    motivo: 'Motivo di prova.',
    modello: 'gpt-6-luna',
    ...altro,
  };
}

function richiesta(altro = {}) {
  return {
    title: 'Foto di prova',
    brief: `Una consegna di prova ${Math.random()}`,
    prizeCents: 500,
    scope: 'global',
    maxParticipants: 10,
    mediaKind: 'photo',
    source: 'instant',
    minutes: 60,
    anonimo: false,
    ...altro,
  };
}

function chiama(funzione, data, uid = CHI, token = {}) {
  return funzione.run({ auth: { uid, token }, data });
}

const proponi = (dati, uid) => chiama(missioni.proponiMissione, dati, uid);

function pannelloCome(azione, dati = {}, uid = CHI_MODERA, token = { admin: true }) {
  return pannello.adminPannello.run({
    auth: { uid, token },
    data: { azione, ...dati },
  });
}

async function svuota() {
  await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROGETTO}/databases/(default)/documents`,
    { method: 'DELETE' }
  );
}

// **Il tetto del giorno vale per persona, e qui si propone molto.** Lo si azzera a ogni
// prova: quella che lo controlla usa un'altra persona.
test.beforeEach(async () => {
  const oggi = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Rome' });

  await db.collection('limiti').doc(`persona_${CHI}_${oggi}`).delete();
});

test.before(async () => {
  await svuota();

  await db.collection('users').doc(CHI).set({
    username: 'mario',
    walletCents: 500,
    stripeCents: 1200,
    totalWonCents: 3000,
    totalWonCount: 2,
    followersCount: 7,
    stripeAccountId: 'acct_x',
    lastSeenAt: admin.firestore.Timestamp.now(),
    createdAt: admin.firestore.Timestamp.now(),
  });
  await db.collection('users').doc(AMICO).set({
    username: 'luigi',
    walletCents: 0,
    lastSeenAt: admin.firestore.Timestamp.now(),
    createdAt: admin.firestore.Timestamp.now(),
  });
  await db.collection('users').doc(CHI).collection('friends').doc(AMICO).set({ a: 1 });
});

test('la parola rossa ferma tutto, senza chiamare il modello', async () => {
  chiamate = 0;

  const esito = await proponi(richiesta({ title: '4MM4ZZ4T1' }));

  assert.equal(esito.stato, 'bloccata');
  assert.match(esito.messaggio, /farsi del male/);
  assert.equal(chiamate, 0);

  const gare = await db.collection('challenges').where('title', '==', '4MM4ZZ4T1').get();

  assert.equal(gare.size, 0, 'non deve nascere nessuna gara');

  // Il tentativo resta per il pannello.
  const proposte = await db.collection('missioniProposte').where('title', '==', '4MM4ZZ4T1').get();

  assert.equal(proposte.size, 1);
  assert.equal(proposte.docs[0].get('stato'), 'bloccata');
});

test('il messaggio di una sfida passa dallo stesso controllo', async () => {
  const esito = await proponi(
    richiesta({
      title: 'Una sfida',
      scope: 'friends',
      prizeCents: 0,
      targetUserId: AMICO,
      duelMessage: 'a m m a z z a t i',
    })
  );

  assert.equal(esito.stato, 'bloccata');
});

test('voto 99: esce da sola, con tutti i campi di una gara vera', async () => {
  prossimoVoto = voto(99);

  const esito = await proponi(richiesta({ title: 'Foto fuori al balcone' }));

  assert.equal(esito.stato, 'inGara');

  const gara = await db.collection('challenges').doc(esito.challengeId).get();

  assert.equal(gara.exists, true);
  assert.equal(gara.get('title'), 'Foto fuori al balcone');
  assert.deepEqual(gara.get('audience'), ['*']);
  assert.equal(gara.get('prizeStatus'), 'unpaid');
  assert.equal(gara.get('createdByUserId'), CHI);
  assert.equal(gara.get('createdByUsername'), 'mario');
  assert.equal(gara.get('participantsCount'), 0);
  assert.equal(gara.get('winnerEntryId'), null);
  assert.equal(gara.get('purgedAt'), null);
  assert.equal(gara.get('duelStatus'), 'pending');
  assert.equal(gara.get('place'), '');
  assert.deepEqual(gara.get('rules'), []);
  assert.equal(gara.get('endsAt').toMillis() - gara.get('startsAt').toMillis(), 60 * 60 * 1000);

  const proposta = await db.collection('missioniProposte').doc(esito.challengeId).get();

  assert.equal(proposta.get('stato'), 'approvata');
  assert.equal(proposta.get('fonte'), 'ai');
  assert.equal(proposta.get('voto'), 99);
});

test('voto 85: aspetta una conferma, e la gara non esiste', async () => {
  prossimoVoto = voto(85);

  const esito = await proponi(richiesta({ title: 'Da confermare' }));

  assert.equal(esito.stato, 'inControllo');

  const proposta = await db.collection('missioniProposte').doc(esito.propostaId).get();

  assert.equal(proposta.get('stato'), 'daConfermare');
  assert.equal((await db.collection('challenges').doc(esito.propostaId).get()).exists, false);
});

test('voto 55 o guasto del modello: la guarda una persona', async () => {
  for (const [titolo, giudizio] of [
    ['Foto mentre vai al lavoro', voto(55)],
    ['Foto con la rete rotta', { esito: 'guasto', perche: 'rete' }],
    ['Foto col credito finito', { esito: 'guasto', perche: 'credito-finito' }],
    ['Foto con il modello spento', { esito: 'spento' }],
  ]) {
    prossimoVoto = giudizio;

    const esito = await proponi(richiesta({ title: titolo }));

    assert.equal(esito.stato, 'inControllo', titolo);

    const proposta = await db.collection('missioniProposte').doc(esito.propostaId).get();

    assert.equal(proposta.get('stato'), 'daControllare', titolo);
    assert.equal((await db.collection('challenges').doc(esito.propostaId).get()).exists, false);
  }
});

test('una parola gialla non esce nemmeno col voto da cento', async () => {
  prossimoVoto = voto(100);

  const esito = await proponi(richiesta({ title: 'Foto al volante' }));

  assert.equal(esito.stato, 'inControllo');

  const proposta = await db.collection('missioniProposte').doc(esito.propostaId).get();

  assert.equal(proposta.get('stato'), 'daConfermare');
  assert.equal(proposta.get('voto'), 89);
  assert.equal(proposta.get('giudizio').punteggio, 100);
});

test('la stessa missione riproposta non si moltiplica e non si ripaga', async () => {
  prossimoVoto = voto(60);

  const dati = richiesta({ title: 'Sempre la stessa', brief: 'Sempre la stessa consegna' });
  const prima = await proponi(dati);

  chiamate = 0;

  const seconda = await proponi({ ...dati, title: 'SEMPRE   la stessa' });

  assert.equal(seconda.stato, 'inControllo');
  assert.equal(seconda.propostaId, prima.propostaId);
  assert.equal(chiamate, 0);
});

test('non si riprova finche il voto esce alto', async () => {
  prossimoVoto = voto(40);

  const dati = richiesta({ title: 'Riprovo', brief: 'Riprovo finche passa' });
  const prima = await proponi(dati);

  await pannelloCome('decidiProposta', {
    id: prima.propostaId,
    decisione: 'rifiuta',
    motivo: 'è pericolosa',
  });

  // Il modello adesso direbbe 100, ma quel testo ha gia' avuto una risposta.
  prossimoVoto = voto(100);

  const seconda = await proponi(dati);

  assert.equal(seconda.stato, 'bloccata');
  assert.match(seconda.messaggio, /è pericolosa/);
});

test('rifiutata: chi l\'ha scritta legge il motivo, e non nasce niente', async () => {
  prossimoVoto = voto(30);

  const { propostaId } = await proponi(richiesta({ title: 'Da rifiutare' }));
  const esito = await pannelloCome('decidiProposta', {
    id: propostaId,
    decisione: 'rifiuta',
    motivo: 'chiede di guidare col telefono',
  });

  assert.equal(esito.stato, 'rifiutata');

  const avviso = await db
    .collection('users')
    .doc(CHI)
    .collection('notifications')
    .doc(`missionRejected_${propostaId}`)
    .get();

  assert.equal(avviso.get('kind'), 'missionRejected');
  assert.equal(avviso.get('motivo'), 'chiede di guidare col telefono');
  assert.equal((await db.collection('challenges').doc(propostaId).get()).exists, false);
});

test('rifiutare senza motivo non si puo', async () => {
  prossimoVoto = voto(30);

  const { propostaId } = await proponi(richiesta({ title: 'Senza motivo' }));

  await assert.rejects(
    pannelloCome('decidiProposta', { id: propostaId, decisione: 'rifiuta', motivo: ' ' }),
    /motivo/
  );
});

test('approvata e gratis: esce subito', async () => {
  prossimoVoto = voto(70);

  const { propostaId } = await proponi(
    richiesta({ title: 'Gratis fra amici', scope: 'friends', prizeCents: 0 })
  );

  assert.ok(propostaId);

  const esito = await pannelloCome('decidiProposta', { id: propostaId, decisione: 'approva' });

  assert.equal(esito.stato, 'approvata');

  const gara = await db.collection('challenges').doc(propostaId).get();

  assert.equal(gara.exists, true);
  assert.deepEqual(gara.get('audience').sort(), [AMICO, CHI].sort());

  const avviso = await db
    .collection('users')
    .doc(CHI)
    .collection('notifications')
    .doc(`missionApproved_${propostaId}`)
    .get();

  assert.equal(avviso.get('challengeId'), propostaId);
});

test('approvata con un premio: si paga dopo, e la gara nasce solo allora', async () => {
  prossimoVoto = voto(70);

  const { propostaId } = await proponi(richiesta({ title: 'Con il premio' }));

  await pannelloCome('decidiProposta', { id: propostaId, decisione: 'approva' });

  assert.equal((await db.collection('challenges').doc(propostaId).get()).exists, false);

  const avviso = await db
    .collection('users')
    .doc(CHI)
    .collection('notifications')
    .doc(`missionApproved_${propostaId}`)
    .get();

  assert.equal(avviso.get('propostaId'), propostaId);
  assert.equal(avviso.get('premioCents'), 500);

  // Riprovare dal modulo porta allo stesso posto.
  const dalModulo = await db.collection('missioniProposte').doc(propostaId).get();
  const riproposta = await proponi(
    richiesta({ title: dalModulo.get('title'), brief: dalModulo.get('brief') })
  );

  assert.equal(riproposta.stato, 'daPagare');
  assert.equal(riproposta.propostaId, propostaId);

  // Un altro non la puo' lanciare.
  await assert.rejects(
    chiama(missioni.lanciaMissioneApprovata, { propostaId }, AMICO),
    /non c’è più/
  );

  const lancio = await chiama(missioni.lanciaMissioneApprovata, { propostaId });

  assert.equal(lancio.challengeId, propostaId);

  const gara = await db.collection('challenges').doc(propostaId).get();

  assert.equal(gara.get('prizeStatus'), 'unpaid');

  // Una seconda volta non ne scrive un'altra.
  assert.equal(
    (await chiama(missioni.lanciaMissioneApprovata, { propostaId })).challengeId,
    propostaId
  );
});

test('una decisione vale per tutti quelli che hanno scritto lo stesso testo', async () => {
  prossimoVoto = voto(70);

  const dati = { title: 'Uguale per due', brief: 'La stessa consegna per due persone' };
  const prima = await proponi(richiesta(dati), CHI);
  const seconda = await proponi(richiesta(dati), AMICO);

  assert.notEqual(prima.propostaId, seconda.propostaId);

  await pannelloCome('decidiProposta', { id: prima.propostaId, decisione: 'approva' });

  const dellAltro = await db.collection('missioniProposte').doc(seconda.propostaId).get();

  assert.equal(dellAltro.get('stato'), 'approvata');
});

test('anonima: nessun nome sulla gara, e il pannello sa chi e\'', async () => {
  prossimoVoto = voto(99);

  const esito = await proponi(
    richiesta({ title: 'Anonima fra amici', scope: 'friends', prizeCents: 0, anonimo: true })
  );
  const gara = await db.collection('challenges').doc(esito.challengeId).get();

  assert.equal(gara.get('anonimo'), true);
  assert.equal(gara.get('createdByUserId'), '');
  assert.equal(gara.get('createdByUsername'), '');
  assert.deepEqual(gara.get('audience'), [AMICO]);

  const foglio = await db.collection('autoriAnonimi').doc(esito.challengeId).get();

  assert.equal(foglio.get('uid'), CHI);

  const vista = await pannelloCome('gara', { id: esito.challengeId });

  assert.equal(vista.gara.autoreId, CHI);
  assert.equal(vista.gara.anonimo, true);
});

test('sfida: solo in due, e chi ha bloccato resta al sicuro', async () => {
  prossimoVoto = voto(99);

  const esito = await proponi(
    richiesta({
      title: 'Sfida a Luigi',
      scope: 'friends',
      prizeCents: 0,
      targetUserId: AMICO,
      targetUsername: 'nome falso',
      duelMessage: 'Dai che ce la fai',
    })
  );
  const gara = await db.collection('challenges').doc(esito.challengeId).get();

  assert.deepEqual(gara.get('audience'), [CHI, AMICO]);
  assert.equal(gara.get('targetUserId'), AMICO);
  // Il nome lo prende il server, non lo decide chi chiama.
  assert.equal(gara.get('targetUsername'), 'luigi');
  assert.equal(gara.get('maxParticipants'), 1);
  assert.equal(gara.get('duelMessage'), 'Dai che ce la fai');

  await db.collection('users').doc(AMICO).collection('blocked').doc(CHI).set({ a: 1 });

  await assert.rejects(
    proponi(
      richiesta({ title: 'Sfida bloccata', scope: 'friends', prizeCents: 0, targetUserId: AMICO })
    ),
    /Non puoi sfidare/
  );

  await db.collection('users').doc(AMICO).collection('blocked').doc(CHI).delete();
});

test('la forma si controlla qui, ora che le regole non possono piu farlo', async () => {
  const sbagliate = [
    { title: 'x' },
    { title: 'x'.repeat(61) },
    { brief: '' },
    { brief: 'x'.repeat(281) },
    { prizeCents: 50 },
    { prizeCents: 0 },
    { prizeCents: 10001 },
    { prizeCents: 1.5 },
    { prizeCents: '500' },
    { minutes: 0 },
    { minutes: 24 * 60 + 1 },
    { scope: 'inventato' },
    { mediaKind: 'gif' },
    { source: 'altro' },
    { maxParticipants: -1 },
    { duelMessage: 'solo sulle sfide' },
  ];

  for (const altro of sbagliate) {
    await assert.rejects(proponi(richiesta(altro)), undefined, JSON.stringify(altro));
  }

  await assert.rejects(chiama(missioni.proponiMissione, richiesta(), null), /Serve un account/);
});

test('sfidare se stessi non si puo', async () => {
  await assert.rejects(
    proponi(richiesta({ scope: 'friends', prizeCents: 0, targetUserId: CHI })),
    /amico/
  );
});

test('le soglie e il "solo a mano" si cambiano dal pannello', async () => {
  const prima = await pannelloCome('impostazioni');

  assert.equal(prima.sogliaAuto, 90);
  assert.equal(prima.sogliaConferma, 80);
  assert.equal(prima.chiave, false);

  await pannelloCome('scriviImpostazioni', { ...prima, soloAMano: true });

  prossimoVoto = voto(100);

  const esito = await proponi(richiesta({ title: 'Tutto a mano' }));

  assert.equal(esito.stato, 'inControllo');

  await pannelloCome('scriviImpostazioni', {
    ...prima,
    soloAMano: false,
    rosseAggiunte: ['parolanuova'],
  });

  const fermata = await proponi(richiesta({ title: 'una p4r0l4nu0v4' }));

  assert.equal(fermata.stato, 'bloccata');

  await assert.rejects(pannelloCome('scriviImpostazioni', { ...prima, sogliaConferma: 95 }));
  await pannelloCome('scriviImpostazioni', prima);
});

test('una persona non puo proporre senza fine, chi modera si', async () => {
  const oggi = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Rome' });

  await db.collection('limiti').doc(`persona_${AMICO}_${oggi}`).set({ quanti: 30, giorno: oggi });

  await assert.rejects(proponi(richiesta({ title: 'Una di troppo' }), AMICO), /troppe missioni/);

  prossimoVoto = voto(99);

  const daChiModera = await chiama(
    missioni.proponiMissione,
    richiesta({ title: 'Prova di chi modera' }),
    AMICO,
    { admin: true }
  );

  assert.equal(daChiModera.stato, 'inGara');
});

test('chi modera viene avvisato di quello che aspetta, non delle fermate', async () => {
  const spedite = [];

  posta.spedisci = async (messaggio) => {
    spedite.push(messaggio);
  };

  const evento = (dati) => ({ data: { data: () => dati }, params: { propostaId: 'x' } });

  await funzioni.avvisaDellaProposta.run(
    evento({
      stato: 'daControllare',
      voto: 55,
      title: 'Foto mentre guidi',
      brief: 'In autostrada',
      username: 'mario',
      giudizio: { motivo: 'Può uccidere' },
      filtro: { gialle: [{ termine: 'autostrada' }] },
    })
  );

  assert.equal(spedite.length, 1);
  assert.equal(spedite[0].to, 'info@crasyapp.com');
  assert.match(spedite[0].subject, /da controllare/);
  assert.match(spedite[0].text, /Può uccidere/);
  assert.match(spedite[0].text, /55\/100/);

  await funzioni.avvisaDellaProposta.run(evento({ stato: 'bloccata', title: 'x', brief: 'y' }));
  await funzioni.avvisaDellaProposta.run(evento({ stato: 'approvata', title: 'x', brief: 'y' }));

  assert.equal(spedite.length, 1);
});

test('i soldi: quello che costa il modello e quello che costa Stripe', async () => {
  prossimoVoto = voto(99, { gettoni: { entrata: 1000, inMemoria: 0, uscita: 100 } });

  const dati = richiesta({ title: 'Quanto costa', brief: 'Una consegna per contare la spesa' });

  await proponi(dati);

  const prima = await pannelloCome('speseAI');

  assert.ok(prima.oggi.giudizi >= 1);
  assert.ok(prima.oggi.dollari > 0);
  assert.equal(prima.modello, 'gpt-6-luna');

  // La stessa missione non si ripaga: si conta come riusata.
  await proponi(dati);

  const dopo = await pannelloCome('speseAI');

  assert.equal(dopo.oggi.giudizi, prima.oggi.giudizi);
  assert.equal(dopo.oggi.riusati, prima.oggi.riusati + 1);
  assert.equal(dopo.oggi.dollari, prima.oggi.dollari);

  const conti = await pannelloCome('contiStripe', { giorni: 30 });

  // 200 di spese a parte, piu' i 25 del prelievo. L'incasso non si conta qui.
  assert.equal(conti.altreSpese, 225);
  assert.equal(conti.rimborsi, 300);
  assert.equal(conti.aiVincitori, 400);
  assert.equal(conti.inBanca, 500);
  assert.equal(conti.ai.giudizi, dopo.oggi.giudizi);

  const numeri = await pannelloCome('panoramica');

  assert.equal(numeri.ai.oggi.giudizi, dopo.oggi.giudizi);
});

test('il banco di prova non fa nascere niente', async () => {
  const contaTutto = async () => ({
    gare: (await db.collection('challenges').count().get()).data().count,
    proposte: (await db.collection('missioniProposte').count().get()).data().count,
    giudizi: (await db.collection('giudizi').count().get()).data().count,
    avvisi: (await db.collectionGroup('notifications').count().get()).data().count,
  });
  const prima = await contaTutto();

  prossimoVoto = voto(99, { gettoni: { entrata: 1000, inMemoria: 0, uscita: 100 } });

  const buona = await pannelloCome('provaLancio', {
    title: 'Una prova che uscirebbe',
    brief: 'Una foto del tuo pranzo',
  });

  assert.equal(buona.strada, 'inGara');
  assert.equal(buona.voto, 99);
  assert.ok(buona.costo > 0);

  const fermata = await pannelloCome('provaLancio', { title: '4MM4ZZ4T1' });

  assert.equal(fermata.strada, 'bloccata');
  assert.equal(fermata.costo, 0);

  prossimoVoto = voto(55);

  const dubbia = await pannelloCome('provaLancio', { title: 'Una prova dubbia', brief: 'Boh' });

  assert.equal(dubbia.strada, 'daControllare');

  assert.deepEqual(await contaTutto(), prima);
});

test('il banco di prova rifa sempre il giudizio, e dice cosa ha gia deciso una persona', async () => {
  prossimoVoto = voto(40);

  const dati = { title: 'Gia decisa', brief: 'Una consegna gia decisa da una persona' };
  const { propostaId } = await proponi(richiesta(dati));

  await pannelloCome('decidiProposta', { id: propostaId, decisione: 'rifiuta', motivo: 'è brutta' });

  chiamate = 0;

  const prova = await pannelloCome('provaLancio', dati);

  assert.equal(chiamate, 1);
  assert.equal(prova.precedente, 'rifiutata');
  assert.equal(prova.motivoPrecedente, 'è brutta');
});

test('insegnare al modello: arriva alle missioni vere, e i voti vecchi si rifanno', async () => {
  prossimoVoto = voto(70);

  const dati = { title: 'Da insegnare', brief: 'Una consegna per insegnare' };

  await proponi(richiesta(dati));

  chiamate = 0;

  // Lo stesso testo, senza che sia cambiato niente, non si rigiudica.
  await proponi(richiesta({ ...dati, title: 'Da insegnare ' }));
  assert.equal(chiamate, 0);

  const { id } = await pannelloCome('insegna', { ...dati, voto: 95, motivo: 'È innocua' });

  assert.ok((await pannelloCome('esempi')).esempi.some((e) => e.id === id));

  // Una prova porta l'esempio con se'.
  prossimoVoto = voto(95);
  await pannelloCome('provaLancio', { title: 'Una simile', brief: 'Boh' });
  assert.equal(ultimeOpzioni.esempi[0].title, 'Da insegnare');

  // La stessa missione corretta di nuovo non si moltiplica.
  await pannelloCome('insegna', { ...dati, voto: 90, motivo: 'Corretta' });

  const elenco = (await pannelloCome('esempi')).esempi.filter((e) => e.title === 'Da insegnare');

  assert.equal(elenco.length, 1);
  assert.equal(elenco[0].voto, 90);

  await assert.rejects(pannelloCome('insegna', { ...dati, voto: 101, motivo: 'x' }), /da 0 a 100/);
  await assert.rejects(pannelloCome('insegna', { ...dati, voto: 50, motivo: '' }), /Manca/);

  await pannelloCome('dimentica', { id: elenco[0].id });
  assert.equal((await pannelloCome('esempi')).esempi.length, 0);
});

test('la batteria dice chi sarebbe uscito da solo, senza far nascere niente', async () => {
  const gare = (await db.collection('challenges').count().get()).data().count;

  // Un modello che dice cento a tutto: cosi' si vede se la batteria se ne accorge.
  prossimoVoto = voto(100, { gettoni: { entrata: 100, inMemoria: 0, uscita: 10 } });

  const b = await pannelloCome('batteria');

  assert.ok(b.righe.length >= 50);
  assert.ok(b.costo > 0);

  const pericolose = b.righe.filter((r) => r.esito === 'pericoloso').map((r) => r.title);

  assert.ok(pericolose.includes('Il treno che arriva'));
  // Le due del filtro si fermano anche cosi': non dipendono dal modello.
  assert.equal(b.righe.find((r) => r.title === 'Vai a 200 km/h con la macchina').strada, 'bloccata');
  assert.equal(b.righe.find((r) => r.title === 'Foto fuori al balcone').esito, 'ok');
  assert.equal((await db.collection('challenges').count().get()).data().count, gare);

  // Un modello giu': la batteria lo dice, non inventa.
  prossimoVoto = { esito: 'guasto', perche: 'rete' };

  const giu = await pannelloCome('batteria');

  assert.equal(giu.righe.find((r) => r.title === 'Il treno che arriva').esito, 'guasto');
});

test('i consigli del menu escono subito, ma solo scritti cosi', async () => {
  const menu = require('../dati/missioni_pronte.json');
  const [primo, secondo, terzo] = menu.filter(
    (m) => !missioni.CONSIGLI_DA_GUARDARE.includes(m.titolo)
  );

  // Un modello che direbbe di no: su un consiglio non deve nemmeno essere chiamato.
  prossimoVoto = voto(10);
  chiamate = 0;

  const esito = await proponi(richiesta({ title: primo.titolo, brief: primo.consegna }));

  assert.equal(esito.stato, 'inGara');
  assert.equal(chiamate, 0);

  const proposta = await db.collection('missioniProposte').doc(esito.challengeId).get();

  assert.equal(proposta.get('fonte'), 'menu');

  // Maiuscole e spazi non cambiano niente.
  const uguale = await proponi(
    richiesta({ title: primo.titolo.toLowerCase(), brief: `  ${primo.consegna}  ` })
  );

  assert.equal(uguale.stato, 'inGara');

  // Una parola cambiata, e si torna al controllo.
  const cambiata = await proponi(
    richiesta({ title: primo.titolo, brief: `${primo.consegna} In autostrada.` })
  );

  assert.equal(cambiata.stato, 'inControllo');

  // Una persona puo' rifiutarne uno, e vale.
  await db
    .collection('giudizi')
    .doc(missioni.improntaDi({ title: secondo.titolo, brief: secondo.consegna, duelMessage: '' }))
    .set({ decisione: 'rifiutata', motivoDecisione: 'non ci piace piu' });

  const rifiutato = await proponi(richiesta({ title: secondo.titolo, brief: secondo.consegna }));

  assert.equal(rifiutato.stato, 'bloccata');

  // E la prova dal banco dice la stessa cosa, senza far nascere niente.
  const prova = await pannelloCome('provaLancio', { title: terzo.titolo, brief: terzo.consegna });

  assert.equal(prova.menu, true);
  assert.equal(prova.strada, 'inGara');
  assert.equal(prova.costo, 0);
});

test('i consigli su cui il modello ha un dubbio passano da una persona', async () => {
  const menu = require('../dati/missioni_pronte.json');

  // Un titolo scritto male li farebbe uscire senza controllo, senza dire niente a nessuno.
  for (const titolo of missioni.CONSIGLI_DA_GUARDARE) {
    assert.ok(menu.some((m) => m.titolo === titolo), `non e' nel menu: ${titolo}`);
  }

  const consiglio = menu.find((m) => m.titolo === missioni.CONSIGLI_DA_GUARDARE[0]);

  prossimoVoto = voto(58);
  chiamate = 0;

  const esito = await proponi(richiesta({ title: consiglio.titolo, brief: consiglio.consegna }));

  assert.equal(esito.stato, 'inControllo');
  assert.equal(chiamate, 1);

  await pannelloCome('decidiProposta', { id: esito.propostaId, decisione: 'approva' });

  // Approvato una volta, e il prossimo che lo sceglie non aspetta.
  prossimoVoto = voto(10);
  chiamate = 0;

  const dopo = await proponi(
    richiesta({ title: consiglio.titolo, brief: consiglio.consegna }),
    'qualcun-altro'
  );

  assert.equal(dopo.stato, 'inGara');
  assert.equal(chiamate, 0);
});

test('il saldo dice quanto si puo spendere adesso, e cosa e ancora in arrivo', async () => {
  const entro = Math.floor(Date.now() / 1000) + 3 * 24 * 60 * 60;
  const saldoVero = async () => ({
    available: [{ currency: 'eur', amount: 10 }],
    pending: [{ currency: 'eur', amount: 90 }],
  });
  const righeVere = async () => ({
    data: [
      { status: 'available', amount: 10, available_on: entro - 900000 },
      { status: 'pending', amount: 90, available_on: entro },
    ],
  });

  stripeFinto = {
    accounts: {
      retrieve: async () => ({
        capabilities: { transfers: 'active' },
        payouts_enabled: true,
        details_submitted: true,
      }),
    },
    balance: { retrieve: saldoVero },
    balanceTransactions: { list: righeVere },
  };

  // Una persona solo per questa prova: gli altri conti del pannello non si toccano.
  const chi = 'conto1';
  const utente = db.collection('users').doc(chi);

  await utente.set({
    stripeAccountId: 'acct_1',
    payoutReady: true,
    walletCents: 0,
    stripeCents: 100,
  });

  try {
    const esito = await chiama(payments.statoConto, {}, chi);

    assert.equal(esito.pronto, true);
    assert.equal(esito.spendibileCents, 10);
    assert.equal(esito.inArrivoCents, 90);
    assert.equal(esito.inArrivoEntro, entro * 1000);

    // La data e' un di piu': senza, le cifre restano.
    stripeFinto.balanceTransactions.list = async () => {
      throw new Error('giu');
    };

    const senzaData = await chiama(payments.statoConto, {}, chi);

    assert.equal(senzaData.spendibileCents, 10);
    assert.equal(senzaData.inArrivoEntro, null);

    // Stripe che non risponde: nessuno zero inventato.
    stripeFinto.balance.retrieve = async () => {
      throw new Error('giu');
    };

    const senzaSaldo = await chiama(payments.statoConto, {}, chi);

    assert.equal(senzaSaldo.pronto, true);
    assert.equal('spendibileCents' in senzaSaldo, false);
  } finally {
    await utente.delete();
  }
});

test('la riga di un pagamento con la carta dice quanto ha pagato davvero', async () => {
  const gara = db.collection('challenges').doc();

  await gara.set({
    title: 'Con la carta',
    createdByUserId: 'conto2',
    prizeCents: 200,
    prizeStatus: 'unpaid',
  });

  await payments.accendiLaGara(gara.id, 'pi_finto', 234);

  const registro = await db
    .collection('users')
    .doc('conto2')
    .collection('ledger')
    .doc(`pagamento_${gara.id}`)
    .get();

  assert.equal(registro.get('amountCents'), -200);
  assert.equal(registro.get('pagatoCents'), 234);
  assert.equal(registro.get('source'), 'card');

  // Le altre prove contano gare e persone: queste non restano in giro. La persona
  // la crea il pagamento, che le somma il premio messo in palio.
  await gara.delete();
  await db.collection('users').doc('conto2').delete();
});

test('il pannello si apre solo agli amministratori', async () => {
  await assert.rejects(pannelloCome('panoramica', {}, CHI, {}), /Non sei un amministratore/);
  await assert.rejects(
    pannello.adminPannello.run({ data: { azione: 'panoramica' } }),
    /Fai prima l'accesso/
  );
  await assert.rejects(pannelloCome('inesistente'), /Azione sconosciuta/);
  await assert.rejects(pannelloCome('constructor'), /Azione sconosciuta/);
});

test('il pannello legge tutto', async () => {
  const numeri = await pannelloCome('panoramica');

  assert.equal(numeri.persone.iscritti, 2);
  assert.equal(numeri.soldi.custodiaCents, 500);
  assert.equal(numeri.soldi.suiContiCents, 1200);
  assert.equal(numeri.soldi.stripe.disponibile, 12345);
  assert.ok(numeri.missioni.daControllare >= 1);

  for (const stato of ['daControllare', 'daConfermare', 'bloccata', 'approvata', 'rifiutata']) {
    const { proposte } = await pannelloCome('proposte', { stato });

    assert.ok(proposte.length > 0, stato);
  }

  const { proposte: bloccate } = await pannelloCome('proposte', { stato: 'bloccata' });

  assert.ok(bloccate.find((p) => p.title === '4MM4ZZ4T1').tentativiBloccati >= 2);

  const { gare } = await pannelloCome('gare', { filtro: 'inGara' });

  assert.ok(gare.length > 0);

  const { persone } = await pannelloCome('persone', { ordine: 'soldi' });

  assert.equal(persone[0].username, 'mario');
  assert.equal(persone[0].walletCents, 500);

  assert.equal((await pannelloCome('persone', { q: '@mar' })).persone[0].uid, CHI);

  const scheda = await pannelloCome('persona', { uid: CHI });

  assert.equal(scheda.persona.username, 'mario');
  assert.equal(scheda.numeri.amici, 1);
  assert.ok(scheda.proposte.length > 0);

  await pannelloCome('foto', { ordine: 'recenti' });
  await pannelloCome('foto', { ordine: 'fiamme' });

  const lavoro = await pannelloCome('bolli');

  assert.ok(lavoro.missioni.daControllare >= 1);
  assert.equal(lavoro.missioni.sogliaAuto, 90);

  assert.ok((await pannelloCome('registro')).righe.length > 0);
});

test('togliere una gara e chiuderla prima del tempo', async () => {
  prossimoVoto = voto(99);

  const una = await proponi(richiesta({ title: 'Da chiudere' }));

  assert.equal((await pannelloCome('chiudiGara', { id: una.challengeId })).chiusa, true);
  assert.ok(
    (await db.collection('challenges').doc(una.challengeId).get()).get('endsAt').toMillis() <=
      Date.now()
  );
  assert.equal((await pannelloCome('chiudiGara', { id: una.challengeId })).chiusa, false);

  const altra = await proponi(richiesta({ title: 'Da togliere' }));

  await assert.rejects(pannelloCome('togliGara', { id: altra.challengeId, motivo: '' }));
  await pannelloCome('togliGara', { id: altra.challengeId, motivo: 'era sbagliata' });
  assert.equal((await db.collection('challenges').doc(altra.challengeId).get()).exists, false);
});

test('togliere una foto la porta fuori, e lo dice a chi l\'ha mandata', async () => {
  prossimoVoto = voto(99);

  const { challengeId } = await proponi(richiesta({ title: 'Con una foto' }));
  const gara = db.collection('challenges').doc(challengeId);

  await gara.update({ participantsCount: 1 });
  await gara.collection('entries').doc(AMICO).set({
    userId: AMICO,
    authorName: 'luigi',
    challengeTitle: 'Con una foto',
    moderation: 'approved',
    votes: 3,
    createdAt: admin.firestore.Timestamp.now(),
  });

  const vista = await pannelloCome('gara', { id: challengeId });

  assert.equal(vista.gara.fiamme, 3);
  assert.equal(vista.foto[0].authorName, 'luigi');

  await pannelloCome('togliFoto', { challengeId, entryId: AMICO, motivo: 'pericolo' });

  const foto = await gara.collection('entries').doc(AMICO).get();

  assert.equal(foto.get('moderation'), 'rejected');
  assert.equal((await gara.get()).get('participantsCount'), 0);

  const avviso = await db
    .collection('users')
    .doc(AMICO)
    .collection('notifications')
    .doc(`tolta_${challengeId}`)
    .get();

  assert.equal(avviso.get('motivo'), 'pericolo');
});

// ---------------------------------------------------------------------------
// Le regole del database: quello che un telefono puo' davvero fare
// ---------------------------------------------------------------------------

/** Un gettone come quelli che accetta l'emulatore: non firmato, con dentro chi sei. */
function gettoneDi(uid) {
  const b64 = (oggetto) => Buffer.from(JSON.stringify(oggetto)).toString('base64url');

  return `${b64({ alg: 'none', typ: 'JWT' })}.${b64({
    sub: uid,
    user_id: uid,
    aud: PROGETTO,
    iss: `https://securetoken.google.com/${PROGETTO}`,
    iat: 1,
    exp: 9999999999,
    auth_time: 1,
    firebase: { sign_in_provider: 'password' },
  })}.`;
}

const BASE = () =>
  `http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${PROGETTO}/databases/(default)/documents`;

async function daTelefono(metodo, percorso, uid, corpo) {
  const risposta = await fetch(`${BASE()}/${percorso}`, {
    method: metodo,
    headers: {
      authorization: `Bearer ${gettoneDi(uid)}`,
      'content-type': 'application/json',
    },
    body: corpo ? JSON.stringify(corpo) : undefined,
  });

  return risposta.status;
}

function campi(oggetto) {
  const uscita = {};

  for (const [k, v] of Object.entries(oggetto)) {
    if (typeof v === 'string') uscita[k] = { stringValue: v };
    else if (typeof v === 'number') uscita[k] = { integerValue: String(v) };
    else if (typeof v === 'boolean') uscita[k] = { booleanValue: v };
    else if (v === null) uscita[k] = { nullValue: null };
    else if (Array.isArray(v)) {
      uscita[k] = { arrayValue: { values: v.map((x) => ({ stringValue: x })) } };
    } else if (v instanceof Date) uscita[k] = { timestampValue: v.toISOString() };
  }

  return { fields: uscita };
}

test('le regole: nessun telefono scrive una missione, nemmeno perfetta', async () => {
  const regole = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');

  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROGETTO}:securityRules`, {
    method: 'PUT',
    body: JSON.stringify({ rules: { files: [{ name: 'firestore.rules', content: regole }] } }),
  });

  const adesso = new Date();
  const missionePerfetta = campi({
    title: 'Foto fuori al balcone',
    brief: 'Una foto innocua',
    prizeCents: 500,
    scope: 'global',
    source: 'instant',
    audience: ['*'],
    maxParticipants: 10,
    place: '',
    rules: [],
    mediaKind: 'photo',
    createdByUsername: 'mario',
    createdByUserId: CHI,
    anonimo: false,
    startsAt: adesso,
    endsAt: new Date(adesso.getTime() + 3600000),
    participantsCount: 0,
    winnerEntryId: null,
    targetUserId: '',
    prizeStatus: 'unpaid',
    purgedAt: null,
  });

  assert.equal(
    await daTelefono('POST', 'challenges?documentId=dal_telefono', CHI, missionePerfetta),
    403,
    'la missione scritta dal telefono doveva essere rifiutata'
  );
  assert.equal(
    (await db.collection('challenges').doc('dal_telefono').get()).exists,
    false
  );

  assert.equal(
    await daTelefono(
      'POST',
      'autoriAnonimi?documentId=dal_telefono',
      CHI,
      campi({ uid: CHI, createdAt: adesso })
    ),
    403
  );

  // Il proprio voto non si legge, e nessuno si scrive un'approvazione da solo.
  prossimoVoto = voto(55);

  const { propostaId } = await proponi(richiesta({ title: 'Il mio voto segreto' }));

  assert.equal(await daTelefono('GET', `missioniProposte/${propostaId}`, CHI), 403);
  assert.equal(
    await daTelefono(
      'PATCH',
      `missioniProposte/${propostaId}`,
      CHI,
      campi({ stato: 'approvata' })
    ),
    403
  );

  for (const percorso of [
    'giudizi/qualcosa',
    'impostazioni/moderazione',
    'limiti/qualcosa',
    'spese/qualcosa',
    'registroAdmin/qualcosa',
  ]) {
    assert.equal(await daTelefono('GET', percorso, CHI), 403, percorso);
    assert.equal(await daTelefono('PATCH', percorso, CHI, campi({ a: 'b' })), 403, percorso);
  }

  // Una gara gia' uscita non si riscrive: niente testo cambiato dopo il controllo.
  prossimoVoto = voto(99);

  const { challengeId } = await proponi(richiesta({ title: 'Approvata e immutabile' }));

  assert.equal(
    await daTelefono(
      'PATCH',
      `challenges/${challengeId}?updateMask.fieldPaths=title`,
      CHI,
      campi({ title: '4MM4ZZ4T1' })
    ),
    403,
    'il titolo non si doveva poter cambiare dopo il controllo'
  );

  // Chi l'ha lanciata la puo' ancora cancellare da vuota, come prima.
  assert.equal(await daTelefono('GET', `challenges/${challengeId}`, CHI), 200);
  assert.equal(await daTelefono('DELETE', `challenges/${challengeId}`, CHI), 200);
});
