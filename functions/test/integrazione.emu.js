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
    legalVersion: '1.6',
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
    legalVersion: '1.6',
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
  await db.collection('users').doc('qualcun-altro').set({ username: 'altro', legalVersion: '1.6' });

  const dopo = await proponi(
    richiesta({ title: consiglio.titolo, brief: consiglio.consegna }),
    'qualcun-altro'
  );

  // Le altre prove contano le persone: questa non resta in giro.
  await db.collection('users').doc('qualcun-altro').delete();

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

test('tutte le spese: stripe, google, ai e quelle scritte a mano', async () => {
  const spese = require('../spese');

  spese.servizi.token = async () => 'finto';
  spese.servizi.fetch = async (url) => {
    if (String(url).includes('bigquery')) {
      return { ok: false, status: 404, text: async () => '{}' };
    }

    return { ok: true, status: 200, text: async () => '{}' };
  };

  const prima = await pannelloCome('spese', { giorni: 30 });

  // Dal registro finto di Stripe: 50 sull'incasso, 200 di extra, 25 sul bonifico.
  assert.equal(prima.stripe.totale, 275);
  assert.equal(prima.parti.stripe, 275);
  assert.equal(prima.parti.google, 0);
  assert.equal(prima.googleVero, false);
  assert.equal(prima.vero.perche, 'manca-il-dataset');
  assert.equal(prima.fisse.totale, 0);

  await assert.rejects(
    pannelloCome('aggiungiSpesaFissa', { nome: 'Apple', euro: 'tanto', ogni: 'anno' }),
    /quanto costa/
  );

  const { voce } = await pannelloCome('aggiungiSpesaFissa', { nome: 'Email', euro: 30, ogni: 'mese' });
  const dopo = await pannelloCome('spese', { giorni: 30 });

  assert.equal(dopo.parti.fisse, 3000);
  assert.equal(dopo.totale, 275 + dopo.parti.ai + 3000);

  // Si legge solo dal pannello: un telefono non ci arriva nemmeno.
  await assert.rejects(pannelloCome('spese', {}, CHI, {}));

  await pannelloCome('togliSpesaFissa', { id: voce.id });
  assert.equal((await pannelloCome('spese', { giorni: 30 })).parti.fisse, 0);
  await assert.rejects(pannelloCome('togliSpesaFissa', { id: voce.id }), /non c'è più/);

  const registro = await pannelloCome('registro');

  assert.ok(registro.righe.some((riga) => riga.azione === 'spesaFissa'));
  assert.ok(registro.righe.some((riga) => riga.azione === 'togliSpesaFissa'));
});

// ---------------------------------------------------------------------------
// Si paga subito, poi la guarda una persona
// ---------------------------------------------------------------------------

/** Stripe come lo vede un rimborso: 234 pagati, 29 di commissioni. */
function stripeDelRimborso(altro = {}) {
  const rimborsi = [];

  stripeFinto = {
    paymentIntents: {
      retrieve: async () => ({
        amount: 234,
        latest_charge: { amount: 234, balance_transaction: { fee: 29 } },
      }),
    },
    refunds: {
      create: async (dati) => {
        rimborsi.push(dati);

        return { amount: dati.amount };
      },
    },
    ...altro,
  };

  return rimborsi;
}

async function lanciaPagandoPrima(punteggio = 60, dati = {}, uid = CHI) {
  prossimoVoto = voto(punteggio);

  return proponi(richiesta({ pagaPrima: true, prizeCents: 200, ...dati }), uid);
}

async function foglioDellaProposta(id) {
  return db.collection('missioniProposte').doc(id).get();
}

async function laGara(id) {
  return db.collection('challenges').doc(id).get();
}

/** Passano le 48 ore, ma solo per questa: le altre prove hanno le loro missioni in coda. */
async function falloScadere(id) {
  await db
    .collection('missioniProposte')
    .doc(id)
    .update({ scadeIl: admin.firestore.Timestamp.fromMillis(Date.now() - 1000) });
}

async function notifica(id, tipo, uid = CHI) {
  return db.collection('users').doc(uid).collection('notifications').doc(`${tipo}_${id}`).get();
}

test('sotto la soglia con un premio: si paga, e finche non si paga non la guarda nessuno', async () => {
  const esito = await lanciaPagandoPrima(60);

  assert.equal(esito.stato, 'daPagareInRevisione');
  assert.equal(esito.challengeId, esito.propostaId);

  const proposta = await foglioDellaProposta(esito.propostaId);
  const gara = await laGara(esito.challengeId);

  assert.equal(proposta.get('stato'), 'daPagare');
  assert.equal(proposta.get('stradaDopoIlPagamento'), 'daControllare');
  assert.equal(proposta.get('scadeIl'), undefined);

  assert.equal(gara.get('prizeStatus'), 'unpaid');
  assert.equal(gara.get('inRevisione'), true);
  assert.deepEqual(gara.get('audience'), []);
  assert.equal(gara.get('minutiDiGara'), 60);
  // La fine scritta e' lontana: lo spazzino delle gare scadute non la tocca.
  assert.ok(gara.get('endsAt').toMillis() > Date.now() + 30 * 24 * 60 * 60 * 1000);

  // In coda non c'e'.
  const coda = await pannelloCome('proposte', { stato: 'daControllare' });

  assert.ok(!coda.proposte.some((p) => p.id === esito.propostaId));

  // Riprovando si riprende quella: non ne nasce un'altra.
  const dinuovo = await proponi(
    richiesta({
      pagaPrima: true,
      prizeCents: 200,
      title: gara.get('title'),
      brief: gara.get('brief'),
    })
  );

  assert.equal(dinuovo.stato, 'daPagareInRevisione');
  assert.equal(dinuovo.propostaId, esito.propostaId);
});

test('arrivati i soldi resta in pausa, entra in coda e corrono le 48 ore', async () => {
  const { challengeId: id } = await lanciaPagandoPrima(85);
  const prima = Date.now();

  await payments.accendiLaGara(id, 'pi_rev', 234);

  const gara = await laGara(id);
  const proposta = await foglioDellaProposta(id);

  assert.equal(gara.get('prizeStatus'), 'inRevisione');
  assert.equal(gara.get('stripePaymentIntentId'), 'pi_rev');
  assert.deepEqual(gara.get('audience'), []);

  assert.equal(proposta.get('stato'), 'daConfermare');
  assert.equal(proposta.get('pagatoCents'), 234);

  const scade = proposta.get('scadeIl').toMillis() - prima;

  assert.ok(scade > 47.9 * 60 * 60 * 1000 && scade < 48.1 * 60 * 60 * 1000);

  // Il registro dice quanto ha pagato la carta, e che e' in revisione.
  const registro = await db
    .collection('users')
    .doc(CHI)
    .collection('ledger')
    .doc(`pagamento_${id}`)
    .get();

  assert.equal(registro.get('pagatoCents'), 234);
  assert.match(registro.get('note'), /in revisione/);

  // Lo stesso evento due volte non cambia niente.
  await payments.accendiLaGara(id, 'pi_altro', 999);
  assert.equal((await laGara(id)).get('stripePaymentIntentId'), 'pi_rev');
  assert.equal((await foglioDellaProposta(id)).get('pagatoCents'), 234);

  // Dal telefono non si cancella, con i soldi dentro.
  await assert.rejects(
    chiama(payments.cancelChallenge, { challengeId: id }),
    /in revisione/
  );

  // E dal pannello si vede cosa c'e' in ballo.
  const coda = await pannelloCome('proposte', { stato: 'daConfermare' });
  const carta = coda.proposte.find((p) => p.id === id);

  assert.equal(carta.pagatoCents, 234);
  assert.ok(carta.scadeIl);

  // Non e' in gara, e non si toglie da quella porta.
  const inGara = await pannelloCome('gare', { filtro: 'inGara' });

  assert.ok(!inGara.gare.some((g) => g.id === id));
  await assert.rejects(pannelloCome('togliGara', { id, motivo: 'prova' }), /in revisione/);
});

test('approvata: esce, parte il tempo, e chi la puo vedere si decide adesso', async () => {
  const { challengeId: id } = await lanciaPagandoPrima(60, { minutes: 90 });

  await payments.accendiLaGara(id, 'pi_ok', 234);

  const contatoriPrima = (await db.collection('users').doc(CHI).get()).get('totalStakedCents') || 0;
  const prima = Date.now();
  const esito = await pannelloCome('decidiProposta', { id, decisione: 'approva' });

  assert.equal(esito.stato, 'approvata');

  const gara = await laGara(id);
  const proposta = await foglioDellaProposta(id);

  assert.equal(gara.get('prizeStatus'), 'held');
  assert.equal(gara.get('inRevisione'), false);
  assert.deepEqual(gara.get('audience'), ['*']);

  const durata = gara.get('endsAt').toMillis() - gara.get('startsAt').toMillis();

  assert.equal(durata, 90 * 60 * 1000);
  assert.ok(gara.get('startsAt').toMillis() >= prima - 2000);

  assert.equal(proposta.get('stato'), 'approvata');
  assert.equal(proposta.get('scadeIl'), undefined);

  const avviso = await notifica(id, 'missionApproved');

  assert.equal(avviso.get('challengeId'), id);

  const contatoriDopo = (await db.collection('users').doc(CHI).get()).get('totalStakedCents') || 0;

  assert.equal(contatoriDopo - contatoriPrima, 200);

  // Una decisione arrivata tardi non tocca una gara gia' uscita.
  const rimborsi = stripeDelRimborso();
  const tardi = await pannelloCome('decidiProposta', { id, decisione: 'rifiuta', motivo: 'no' });

  assert.equal(rimborsi.length, 0);
  assert.equal(tardi.esiti[0].saltata, 'già in gara');
  assert.equal((await laGara(id)).get('prizeStatus'), 'held');
  await db.collection('giudizi').doc((await foglioDellaProposta(id)).get('impronta')).delete();
});

test('rifiutata: tornano i soldi tranne le commissioni di Stripe, e lo si dice', async () => {
  const rimborsi = stripeDelRimborso();
  const { challengeId: id } = await lanciaPagandoPrima(40);

  await payments.accendiLaGara(id, 'pi_no', 234);

  const contatoriPrima = (await db.collection('users').doc(CHI).get()).get('totalStakedCents') || 0;
  const esito = await pannelloCome('decidiProposta', {
    id,
    decisione: 'rifiuta',
    motivo: 'Mette in pericolo chi la fa',
  });

  assert.equal(rimborsi.length, 1);
  assert.equal(rimborsi[0].amount, 205);
  assert.equal(rimborsi[0].payment_intent, 'pi_no');
  assert.deepEqual(esito.esiti[0].rimborso, { restituitoCents: 205, dove: 'carta' });

  // Non c'e' piu', e la classifica non si e' mossa: non era mai entrata.
  assert.equal((await laGara(id)).exists, false);

  const contatoriDopo = (await db.collection('users').doc(CHI).get()).get('totalStakedCents') || 0;

  assert.equal(contatoriDopo, contatoriPrima);

  const proposta = await foglioDellaProposta(id);

  assert.equal(proposta.get('stato'), 'rifiutata');
  assert.equal(proposta.get('rimborso'), 'fatto');
  assert.equal(proposta.get('rimborsatiCents'), 205);

  const avviso = await notifica(id, 'missionRejected');

  assert.equal(avviso.get('rimborsoCents'), 205);
  assert.equal(avviso.get('rimborsoDove'), 'carta');
  assert.equal(avviso.get('motivo'), 'Mette in pericolo chi la fa');

  const ricevuta = await db.collection('users').doc(CHI).collection('refunds').doc(id).get();

  assert.equal(ricevuta.get('refundedCents'), 205);
  assert.equal(ricevuta.get('motivo'), 'non-accettata');

  const registro = await db
    .collection('users')
    .doc(CHI)
    .collection('ledger')
    .doc(`rimborso_${id}`)
    .get();

  assert.equal(registro.get('amountCents'), 205);
  assert.match(registro.get('note'), /senza le commissioni di Stripe/);

  await db.collection('giudizi').doc(proposta.get('impronta')).delete();
});

test('48 ore senza risposta: non viene caricata, e i soldi tornano da soli', async () => {
  const rimborsi = stripeDelRimborso();
  const { challengeId: id } = await lanciaPagandoPrima(60);

  await payments.accendiLaGara(id, 'pi_tardi', 234);

  // Non ancora: la coda resta com'e'. (L'orologio e' quello di adesso: le altre missioni in
  // coda nelle altre prove non sono scadute.)
  let giro = await missioni.chiudiLeScadute();

  assert.equal(giro.chiuse, 0);
  assert.equal(rimborsi.length, 0);

  await falloScadere(id);
  giro = await missioni.chiudiLeScadute();

  assert.equal(giro.chiuse, 1);
  assert.equal(rimborsi[0].amount, 205);
  assert.equal((await laGara(id)).exists, false);

  const proposta = await foglioDellaProposta(id);

  assert.equal(proposta.get('stato'), 'scaduta');
  assert.equal(proposta.get('fonte'), 'tempo');

  const avviso = await notifica(id, 'missionExpired');

  assert.equal(avviso.get('rimborsoCents'), 205);

  const ricevuta = await db.collection('users').doc(CHI).collection('refunds').doc(id).get();

  assert.equal(ricevuta.get('motivo'), 'non-caricata');

  // Non l'ha decisa nessuno: sul testo non resta scritto niente, e si puo' rilanciare.
  assert.equal(
    (await db.collection('giudizi').doc(proposta.get('impronta')).get()).get('decisione'),
    undefined
  );

  // Il giro dopo non la rifa'.
  giro = await missioni.chiudiLeScadute();
  assert.equal(giro.chiuse, 0);
  assert.equal(rimborsi.length, 1);
});

test('una gratis dopo 48 ore si chiude con l avviso, senza rimborsi', async () => {
  const rimborsi = stripeDelRimborso();

  prossimoVoto = voto(50);

  const esito = await proponi(
    richiesta({ pagaPrima: true, prizeCents: 0, scope: 'friends' })
  );

  assert.equal(esito.stato, 'inControllo');

  await falloScadere(esito.propostaId);
  await missioni.chiudiLeScadute();

  assert.equal((await foglioDellaProposta(esito.propostaId)).get('stato'), 'scaduta');
  assert.equal((await notifica(esito.propostaId, 'missionExpired')).get('rimborsoCents'), 0);
  assert.equal(rimborsi.length, 0);
});

test('un rimborso che Stripe non accetta non si perde: riprova da solo, e avvisa una volta', async () => {
  let giu = true;
  const rimborsi = [];

  stripeDelRimborso({
    refunds: {
      create: async (dati) => {
        if (giu) {
          throw new Error('Stripe giu');
        }

        rimborsi.push(dati);

        return { amount: dati.amount };
      },
    },
  });

  const { challengeId: id } = await lanciaPagandoPrima(40);

  await payments.accendiLaGara(id, 'pi_giu', 234);

  const esito = await pannelloCome('decidiProposta', { id, decisione: 'rifiuta', motivo: 'no' });

  assert.equal(esito.esiti[0].rimborso.daRifare, true);
  assert.equal((await foglioDellaProposta(id)).get('rimborso'), 'daRifare');
  // La missione resta, con i soldi: non e' sparita niente.
  assert.equal((await laGara(id)).get('prizeStatus'), 'inRevisione');
  assert.equal((await notifica(id, 'missionRejected')).exists, false);

  giu = false;

  const giro = await missioni.chiudiLeScadute();

  assert.ok(giro.riprovati >= 1);
  assert.equal(rimborsi[0].amount, 205);
  assert.equal((await foglioDellaProposta(id)).get('rimborso'), 'fatto');
  assert.equal((await laGara(id)).exists, false);
  assert.equal((await notifica(id, 'missionRejected')).get('rimborsoCents'), 205);

  await db
    .collection('giudizi')
    .doc((await foglioDellaProposta(id)).get('impronta'))
    .delete();
});

test('un rimborso rimasto a meta perche il server si e fermato riparte da solo', async () => {
  const rimborsi = stripeDelRimborso();
  const { challengeId: id } = await lanciaPagandoPrima(40);

  await payments.accendiLaGara(id, 'pi_appeso', 234);

  // Chiusa, e il server si ferma prima di rimborsare.
  await db
    .collection('missioniProposte')
    .doc(id)
    .update({
      stato: 'scaduta',
      rimborso: 'daFare',
      rimborsoTipo: 'missionExpired',
      decisaIl: admin.firestore.Timestamp.now(),
      scadeIl: admin.firestore.FieldValue.delete(),
    });

  // Appena chiusa potrebbe essere ancora al lavoro: non ci si mette in mezzo.
  let giro = await missioni.chiudiLeScadute();

  assert.equal(giro.riprovati, 0);
  assert.equal(rimborsi.length, 0);

  giro = await missioni.chiudiLeScadute(Date.now() + 6 * 60 * 1000);

  assert.equal(giro.riprovati, 1);
  assert.equal(rimborsi[0].amount, 205);
  assert.equal((await foglioDellaProposta(id)).get('rimborso'), 'fatto');
  assert.equal((await notifica(id, 'missionExpired')).get('rimborsoCents'), 205);
});

test('nei guadagni una rifiutata lascia CRASY a zero, e una in revisione puo tornare', async () => {
  const gara = db.collection('challenges').doc('guadagni-rev');

  await gara.set({ title: 'In revisione', prizeCents: 200, prizeStatus: 'inRevisione' });

  stripeFinto = {
    balanceTransactions: {
      list: async function* () {
        // Rifiutata: pagati 234, tornati 205, Stripe ne ha tenuti 29.
        yield {
          type: 'charge',
          amount: 234,
          fee: 29,
          created: 200,
          source: {
            amount_refunded: 205,
            metadata: { challengeId: 'non-ce-piu', prizeCents: '200' },
          },
        };
        // In revisione: pagata e ancora ferma.
        yield {
          type: 'charge',
          amount: 234,
          fee: 29,
          created: 100,
          source: { metadata: { challengeId: 'guadagni-rev', prizeCents: '200' } },
        };
      },
    },
  };

  const { totali, righe } = await funzioni.adminGuadagni.run({
    auth: { uid: CHI_MODERA, token: { admin: true } },
    data: { giorni: 30 },
  });
  const [rifiutata, inRevisione] = righe;

  assert.equal(rifiutata.stato, 'rimborsata, senza le commissioni di Stripe');
  assert.equal(rifiutata.tuo, 0);
  assert.equal(rifiutata.reso, 205);
  assert.equal(rifiutata.alVincitore, 0);

  assert.equal(inRevisione.stato, 'pagata, in revisione');
  assert.equal(totali.guadagnoInAttesa, inRevisione.tuo);
  assert.equal(totali.guadagno, inRevisione.tuo);

  await gara.delete();
});

test('pagata col portafoglio: resta in pausa, e se non esce torna tutta nel portafoglio', async () => {
  const utente = db.collection('users').doc(CHI);
  const saldoPrima = (await utente.get()).get('walletCents') || 0;

  await utente.set({ walletCents: saldoPrima + 300 }, { merge: true });

  const { challengeId: id } = await lanciaPagandoPrima(60);
  const pagata = await chiama(payments.payChallengeFromWallet, { challengeId: id });

  assert.equal(pagata.ok, true);
  assert.equal((await utente.get()).get('walletCents'), saldoPrima + 100);
  assert.equal((await laGara(id)).get('prizeStatus'), 'inRevisione');
  assert.equal((await laGara(id)).get('paidFromWallet'), true);

  const proposta = await foglioDellaProposta(id);

  assert.equal(proposta.get('stato'), 'daControllare');
  assert.equal(proposta.get('pagatoCents'), 200);

  // Il secondo tocco non paga di nuovo.
  const secondo = await chiama(payments.payChallengeFromWallet, { challengeId: id });

  assert.equal(secondo.giaPagata, true);
  assert.equal((await utente.get()).get('walletCents'), saldoPrima + 100);

  stripeFinto = { accounts: {}, balance: {}, balanceTransactions: {} };

  const esito = await pannelloCome('decidiProposta', { id, decisione: 'rifiuta', motivo: 'no' });

  assert.deepEqual(esito.esiti[0].rimborso, { restituitoCents: 200, dove: 'portafoglio' });
  assert.equal((await utente.get()).get('walletCents'), saldoPrima + 300);

  await utente.set({ walletCents: saldoPrima }, { merge: true });
  await db
    .collection('giudizi')
    .doc((await foglioDellaProposta(id)).get('impronta'))
    .delete();
});

test('non partecipa nessuno: tornano i soldi tranne le commissioni di Stripe', async () => {
  const rimborsi = stripeDelRimborso();

  prossimoVoto = voto(99);

  const { challengeId: id } = await proponi(richiesta({ prizeCents: 200 }));

  await payments.accendiLaGara(id, 'pi_vuota', 234);

  const contatoriPrima = (await db.collection('users').doc(CHI).get()).get('totalStakedCents') || 0;
  const esito = await payments.refundChallenge(id);

  assert.deepEqual(esito, { restituito: 205, dove: 'carta' });
  assert.equal(rimborsi[0].amount, 205);
  assert.equal((await laGara(id)).get('prizeStatus'), 'refunded');

  const registro = await db
    .collection('users')
    .doc(CHI)
    .collection('ledger')
    .doc(`rimborso_${id}`)
    .get();

  assert.equal(registro.get('amountCents'), 205);
  assert.match(registro.get('note'), /senza le commissioni di Stripe: non ha partecipato nessuno/);

  const ricevuta = await db.collection('users').doc(CHI).collection('refunds').doc(id).get();

  assert.equal(ricevuta.get('motivo'), 'nessun-partecipante');

  // Era uscita: dal conteggio di chi fa giocare esce.
  const contatoriDopo = (await db.collection('users').doc(CHI).get()).get('totalStakedCents') || 0;

  assert.equal(contatoriDopo, contatoriPrima - 200);

  await db.collection('challenges').doc(id).delete();
});

test('se non si riesce a leggere la commissione il rimborso parte lo stesso', async () => {
  const rimborsi = stripeDelRimborso({
    paymentIntents: {
      retrieve: async () => {
        throw new Error('Stripe giu');
      },
    },
  });

  prossimoVoto = voto(99);

  const { challengeId: id } = await proponi(richiesta({ prizeCents: 200 }));

  await payments.accendiLaGara(id, 'pi_cieca', 234);
  await payments.refundChallenge(id);

  // Il premio e il servizio: quello che resta togliendo la commissione attesa.
  assert.equal(rimborsi[0].amount, 205);
  await db.collection('challenges').doc(id).delete();
});

test('chi cancella riceve solo il premio, e una gara in corso non torna come in revisione', async () => {
  const rimborsi = stripeDelRimborso();

  prossimoVoto = voto(99);

  const { challengeId: id } = await proponi(richiesta({ prizeCents: 200 }));

  await payments.accendiLaGara(id, 'pi_mia', 234);

  // Una decisione arrivata tardi non tocca una gara gia' uscita.
  assert.equal(await payments.refundChallenge(id, { inRevisione: true }), undefined);
  assert.equal(rimborsi.length, 0);

  await payments.refundChallenge(id, { soloIlPremio: true });
  assert.equal(rimborsi[0].amount, 200);
  await db.collection('challenges').doc(id).delete();
});

test('le versioni vecchie dell app restano sul giro di prima', async () => {
  prossimoVoto = voto(60);

  const esito = await proponi(richiesta({ prizeCents: 200 }));

  assert.equal(esito.stato, 'inControllo');
  assert.equal(esito.challengeId, undefined);

  const proposta = await foglioDellaProposta(esito.propostaId);

  assert.equal(proposta.get('stato'), 'daControllare');
  assert.ok(proposta.get('scadeIl'));

  await pannelloCome('decidiProposta', { id: esito.propostaId, decisione: 'approva' });
  assert.equal((await notifica(esito.propostaId, 'missionApproved')).get('challengeId'), '');
  await db.collection('giudizi').doc(proposta.get('impronta')).delete();
});

test('da 90 in su non cambia niente: esce e si paga', async () => {
  const esito = await lanciaPagandoPrima(99);

  assert.equal(esito.stato, 'inGara');
  assert.equal((await laGara(esito.challengeId)).get('inRevisione'), undefined);
  await payments.accendiLaGara(esito.challengeId, 'pi_alto', 234);
  assert.equal((await laGara(esito.challengeId)).get('prizeStatus'), 'held');
});

test('chi l ha lanciata la modifica finche non partecipa nessuno', async () => {
  prossimoVoto = voto(99);

  const { challengeId: id } = await proponi(
    richiesta({ prizeCents: 200, source: 'instant', maxParticipants: 15, minutes: 60 })
  );

  await payments.accendiLaGara(id, 'pi_mod', 234);

  const modifica = (dati, uid) =>
    chiama(missioni.modificaMissione, { challengeId: id, ...dati }, uid);

  await modifica({ source: 'archive', maxParticipants: 10, mediaKind: 'video', minutes: 120 });

  let gara = await laGara(id);

  assert.equal(gara.get('source'), 'archive');
  assert.equal(gara.get('maxParticipants'), 10);
  assert.equal(gara.get('mediaKind'), 'video');
  assert.equal(
    gara.get('endsAt').toMillis() - gara.get('startsAt').toMillis(),
    120 * 60 * 1000
  );
  // Il premio e il testo non si toccano.
  assert.equal(gara.get('prizeCents'), 200);

  await assert.rejects(modifica({ maxParticipants: 5, title: 'Altro' }, AMICO), /non è tua/);
  await assert.rejects(modifica({ source: 'boh' }), /non è valido/);
  await assert.rejects(modifica({ maxParticipants: 0 }), /posti/);
  await assert.rejects(modifica({ minutes: 100000 }), /24 ore/);
  await assert.rejects(modifica({}), /Non hai cambiato/);

  // Una foto dentro, e non si tocca piu'.
  await db.collection('challenges').doc(id).collection('entries').doc('e1').set({ votes: 0 });
  await assert.rejects(modifica({ maxParticipants: 5 }), /già partecipato/);
  await db.collection('challenges').doc(id).collection('entries').doc('e1').delete();

  await db.collection('challenges').doc(id).update({ participantsCount: 1 });
  await assert.rejects(modifica({ maxParticipants: 5 }), /già partecipato/);
  await db.collection('challenges').doc(id).update({ participantsCount: 0 });

  // Il titolo mandato insieme non passa: resta quello controllato.
  const titolo = gara.get('title');

  await modifica({ maxParticipants: 7, title: 'Scritto dopo il controllo' });
  gara = await laGara(id);
  assert.equal(gara.get('title'), titolo);
  assert.equal(gara.get('maxParticipants'), 7);

  // Finita non si modifica.
  await db
    .collection('challenges')
    .doc(id)
    .update({ endsAt: admin.firestore.Timestamp.fromMillis(Date.now() - 1000) });
  await assert.rejects(modifica({ maxParticipants: 5 }), /non è in gara/);
  await db.collection('challenges').doc(id).delete();
});

test('una sfida a una persona non si modifica, e una non pagata nemmeno', async () => {
  prossimoVoto = voto(99);

  const sfida = await proponi(
    richiesta({ targetUserId: AMICO, scope: 'friends', prizeCents: 0, duelMessage: '' })
  );

  await assert.rejects(
    chiama(missioni.modificaMissione, { challengeId: sfida.challengeId, minutes: 120 }),
    /sfida/
  );

  const nonPagata = await proponi(richiesta({ prizeCents: 200 }));

  await assert.rejects(
    chiama(missioni.modificaMissione, { challengeId: nonPagata.challengeId, minutes: 120 }),
    /non è in gara/
  );

  await db.collection('challenges').doc(sfida.challengeId).delete();
  await db.collection('challenges').doc(nonPagata.challengeId).delete();
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
