'use strict';

/**
 * **Quello che chiede Apple per la linea guida 1.2, dalla parte del server.**
 *
 * Contro gli emulatori, come `integrazione.emu.js`: niente Google Vision, niente email
 * e niente notifiche vere. Parte con:
 *
 *     npm run test:server
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const vision = require('@google-cloud/vision');

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-crasy';
process.env.OPENAI_API_KEY = 'spenta';
process.env.STRIPE_SECRET_KEY = 'sk_test_finta';
process.env.STRIPE_PAYOUT_KEY = 'da-sostituire';

const funzioni = require('../index');
const moderazione = require('../moderazione');
const pannello = require('../pannello');
const posta = require('../posta');
const magazzino = require('../magazzino');

const db = admin.firestore();
const { Timestamp } = admin.firestore;

const ORA = 3600 * 1000;
const NASCITA = Timestamp.fromDate(new Date('1990-01-01T00:00:00Z'));
const MODERA = 'capo';

let email = [];
let squilli = [];
let controlli = [];
let verdetto = {};

posta.spedisci = async (messaggio) => {
  email.push(messaggio);
};

moderazione.collega({
  mandaAUnaPersona: async (uid, frase) => {
    squilli.push({ uid, frase });
  },
  reasonsFromSafeSearch: (annotazione) =>
    annotazione && annotazione.adult === 'VERY_LIKELY' ? ['nudita/sesso'] : [],
});

// Niente Google Vision: il controllo risponde quello che decide la prova.
vision.ImageAnnotatorClient = class {
  async safeSearchDetection(uri) {
    controlli.push(uri);

    return [{ safeSearchAnnotation: verdetto[uri] || { adult: 'VERY_UNLIKELY' } }];
  }
};

// Niente Storage: si guarda solo che ci si provi.
const cancellati = [];

magazzino.tuttiIMagazzini = () => [
  {
    deleteFiles: async ({ prefix }) => {
      cancellati.push(prefix);
    },
  },
];

function pannelloCome(azione, dati = {}, uid = MODERA) {
  return pannello.adminPannello.run({
    auth: { uid, token: { admin: true } },
    data: { azione, ...dati },
  });
}

function chiama(funzione, dati, uid = MODERA) {
  return funzione.run({ auth: { uid, token: { admin: true } }, data: dati });
}

async function ultimaRiga(azione) {
  const righe = await db
    .collection('registroAdmin')
    .where('azione', '==', azione)
    .get();

  return righe.docs
    .map((d) => d.data())
    .sort((a, b) => (b.il?.toMillis() || 0) - (a.il?.toMillis() || 0))[0];
}

async function persona(uid, dati = {}) {
  await db.collection('users').doc(uid).set({ username: uid, birthDate: NASCITA, ...dati });
}

async function foto(gara, autore, dati = {}) {
  await db
    .collection('challenges')
    .doc(gara)
    .collection('entries')
    .doc(autore)
    .set({
      userId: autore,
      authorName: autore,
      challengeTitle: 'Gara',
      mediaUrl: `https://esempio/${autore}.jpg`,
      moderation: 'approved',
      votes: 0,
      createdAt: Timestamp.now(),
      ...dati,
    });
}

async function segnala(id, dati) {
  const riferimento = db.collection('reports').doc(id);

  await riferimento.set({
    kind: 'entry',
    reporterId: 'chiSegnala',
    reportedUserId: '',
    reason: 'sexual',
    challengeId: '',
    entryId: '',
    commentId: '',
    note: '',
    reportedUsername: '',
    mediaUrl: '',
    challengeTitle: '',
    commentText: '',
    status: 'new',
    createdAt: Timestamp.now(),
    ...dati,
  });

  return riferimento;
}

test.before(async () => {
  await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${process.env.GCLOUD_PROJECT}/databases/(default)/documents`,
    { method: 'DELETE' }
  );

  await persona('chiSegnala');
  await db.collection('challenges').doc('gara').set({ title: 'Gara', participantsCount: 5 });
});

test.beforeEach(() => {
  email = [];
  squilli = [];
  controlli = [];
  verdetto = {};
});

test('una segnalazione arriva al team, con il contenuto vero e la scadenza', async () => {
  await persona('autore1');
  await foto('gara', 'autore1', { caption: 'Una didascalia' });
  await db.collection('impostazioni').doc('amministratori').set({ uids: [MODERA] });

  const quando = Timestamp.fromMillis(Date.now() - 1000);
  // Il nome scritto dal telefono e' di un altro: non si crede.
  const riferimento = await segnala('s1', {
    challengeId: 'gara',
    entryId: 'autore1',
    reportedUserId: 'innocente',
    createdAt: quando,
  });

  await moderazione.accogliLaSegnalazione(riferimento, (await riferimento.get()).data());

  const scritta = await riferimento.get();

  assert.equal(scritta.get('reportedUserId'), 'autore1');
  assert.equal(scritta.get('verificato').testo, 'Una didascalia');
  assert.equal(scritta.get('scadeIl').toMillis(), quando.toMillis() + 24 * ORA);
  assert.equal(scritta.get('sospetta'), false);
  assert.equal(email.length, 1);
  assert.equal(email[0].to, 'info@crasyapp.com');
  assert.match(email[0].subject, /Contenuto sessualmente esplicito/);
  assert.deepEqual(squilli.map((s) => s.uid), [MODERA]);
});

test('chi segnala troppo non fa squillare nessuno, ma la segnalazione resta', async () => {
  const oggi = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Rome' });

  await db
    .collection('limiti')
    .doc(`segnalazioni_abusa_${oggi}`)
    .set({ quanti: moderazione.SEGNALAZIONI_AL_GIORNO });

  const riferimento = await segnala('s2', { reporterId: 'abusa', kind: 'user', reportedUserId: 'autore1' });

  await moderazione.accogliLaSegnalazione(riferimento, (await riferimento.get()).data());

  assert.equal((await riferimento.get()).get('sospetta'), true);
  assert.equal(email.length, 0);
  assert.equal(squilli.length, 0);

  // E sta in fondo alla coda.
  const { reports } = await chiama(funzioni.adminListReports, { status: 'new' });

  assert.equal(reports.at(-1).id, 's2');
  assert.equal(reports.at(-1).sospetta, true);
});

test('le 24 ore: un avviso prima, uno dopo, e mai due volte lo stesso', async () => {
  const adesso = Date.now();
  const vecchia = (ore) => Timestamp.fromMillis(adesso - ore * ORA);
  const ripulita = await db.collection('reports').where('status', '==', 'new').get();

  await Promise.all(ripulita.docs.map((d) => d.ref.delete()));

  await segnala('fresca', { createdAt: vecchia(2) });
  const inScadenza = await segnala('quasi', { createdAt: vecchia(20) });
  const scaduta = await segnala('passata', { createdAt: vecchia(30) });
  await segnala('decisa', { createdAt: vecchia(30), status: 'removed' });

  assert.deepEqual(await moderazione.sollecita(adesso), { scadute: 1, inScadenza: 1 });
  assert.equal(email.length, 1);
  assert.equal((await inScadenza.get()).get('sollecitoInScadenza'), true);
  assert.equal((await scaduta.get()).get('sollecitoScaduta'), true);

  email = [];
  assert.deepEqual(await moderazione.sollecita(adesso), { scadute: 0, inScadenza: 0 });
  assert.equal(email.length, 0);

  // La stessa, sei ore dopo, e' scaduta: un secondo avviso, e basta.
  assert.deepEqual(await moderazione.sollecita(adesso + 6 * ORA), { scadute: 1, inScadenza: 0 });

  const { reports } = await chiama(funzioni.adminListReports, { status: 'new' });
  const trovata = reports.find((r) => r.id === 'passata');

  assert.equal(trovata.scaduta, true);
  assert.equal((await pannelloCome('bolli')).lavoro.scadute >= 1, true);
  assert.equal((await pannelloCome('panoramica')).lavoro.scadute >= 1, true);
  assert.equal(reports[0].id, 'passata', 'la piu\' vecchia sta in cima');
  assert.equal(reports.find((r) => r.id === 'fresca').scaduta, false);
});

test('il pannello filtra per stato, tipo, motivo e data, e dice chi ha segnalato', async () => {
  await persona('segnalante2');
  await db.collection('segnalanti').doc('segnalante2').set({ respinte: 3 });
  await segnala('f1', {
    kind: 'comment',
    reason: 'hate',
    reporterId: 'segnalante2',
    commentText: 'Un insulto',
    createdAt: Timestamp.fromMillis(Date.parse('2026-03-10T12:00:00Z')),
  });
  await segnala('f2', {
    kind: 'user',
    reason: 'spam',
    createdAt: Timestamp.fromMillis(Date.parse('2026-04-10T12:00:00Z')),
  });

  const perTipo = await chiama(funzioni.adminListReports, { status: 'all', kind: 'comment' });

  assert.deepEqual(perTipo.reports.map((r) => r.id), ['f1']);
  assert.equal(perTipo.reports[0].testo, 'Un insulto');
  assert.equal(perTipo.reports[0].reporterId, 'segnalante2');
  assert.equal(perTipo.reports[0].reporterUsername, 'segnalante2');
  assert.equal(perTipo.reports[0].reporterRespinte, 3);

  const perMotivo = await chiama(funzioni.adminListReports, { status: 'all', reason: 'spam' });

  assert.deepEqual(perMotivo.reports.map((r) => r.id), ['f2']);

  const perData = await chiama(funzioni.adminListReports, {
    status: 'new',
    dal: Date.parse('2026-04-01T00:00:00Z'),
    al: Date.parse('2026-04-30T00:00:00Z'),
  });

  assert.deepEqual(perData.reports.map((r) => r.id), ['f2']);

  const vecchiaLettura = await chiama(funzioni.adminListReports, { status: 'removed' });

  assert.ok(vecchiaLettura.reports.every((r) => r.status === 'removed'));
});

test('togliere una foto: fuori dalla gara, sospeso l\'autore vero, e resta scritto', async () => {
  await persona('autore2');
  await admin.auth().createUser({ uid: 'autore2', email: 'autore2@esempio.it' });
  await foto('gara', 'autore2');

  // Il campo dice un altro: chi viene sospeso e' chi l'ha pubblicata.
  await segnala('d1', { challengeId: 'gara', entryId: 'autore2', reportedUserId: 'innocente' });
  await segnala('d2', { challengeId: 'gara', entryId: 'autore2', reportedUserId: 'autore2', reporterId: 'altra' });

  const esito = await chiama(funzioni.adminResolveReport, {
    reportId: 'd1',
    decision: 'remove',
    sospendiGiorni: 7,
  });

  assert.equal(esito.status, 'removed');
  assert.equal(esito.insieme, 2);
  assert.equal(esito.sospeso.userId, 'autore2');

  const uscita = await db.doc('challenges/gara/entries/autore2').get();

  assert.equal(uscita.get('moderation'), 'rejected');
  assert.equal((await db.collection('reports').doc('d2').get()).get('status'), 'removed');
  assert.equal((await db.collection('reports').doc('d1').get()).get('resolvedBy'), MODERA);

  await persona(MODERA);

  const decisa = (await chiama(funzioni.adminListReports, { status: 'removed' })).reports.find(
    (r) => r.id === 'd1'
  );

  assert.equal(decisa.resolvedBy, MODERA);
  assert.equal(decisa.resolvedByUsername, MODERA);
  assert.ok(decisa.resolvedAt);
  assert.equal(decisa.scadeIl, null, 'una decisa non scade');
  assert.equal(decisa.scaduta, false);
  assert.ok((await db.collection('reports').doc('d1').get()).get('resolvedAt'));
  assert.equal((await admin.auth().getUser('autore2')).disabled, true);

  const riga = await ultimaRiga('decidiSegnalazione');

  assert.equal(riga.chi, MODERA);
  assert.equal(riga.dettagli.decisione, 'removed');
  assert.equal(riga.dettagli.uid, 'autore2');
  assert.deepEqual(riga.dettagli.sospeso, { giorni: 7 });

  const partecipanti = (await db.doc('challenges/gara').get()).get('participantsCount');

  // Due clic: niente avviene due volte.
  const ancora = await chiama(funzioni.adminResolveReport, { reportId: 'd1', decision: 'remove' });

  assert.equal(ancora.giaDecisa, true);
  assert.equal((await db.doc('challenges/gara').get()).get('participantsCount'), partecipanti);
});

test('togliere un commento non tocca la foto, e nemmeno le sue segnalazioni', async () => {
  await persona('autore3');
  await persona('commentatore');
  await foto('gara', 'autore3');

  const commento = db.doc('challenges/gara/entries/autore3/comments/c1');

  await commento.set({ userId: 'commentatore', authorName: 'commentatore', text: 'Un insulto' });
  await segnala('sulCommento', {
    kind: 'comment',
    reason: 'hate',
    challengeId: 'gara',
    entryId: 'autore3',
    commentId: 'c1',
    reportedUserId: 'commentatore',
  });
  await segnala('sullaFoto', { challengeId: 'gara', entryId: 'autore3', reportedUserId: 'autore3' });

  const esito = await chiama(funzioni.adminResolveReport, { reportId: 'sulCommento', decision: 'remove' });

  assert.equal(esito.insieme, 1);
  assert.equal((await commento.get()).exists, false);
  assert.equal((await db.doc('challenges/gara/entries/autore3').get()).get('moderation'), 'approved');
  assert.equal((await db.collection('reports').doc('sullaFoto').get()).get('status'), 'new');

  const avviso = await db.doc('users/commentatore/notifications/tolto_commento_c1').get();

  assert.equal(avviso.get('kind'), 'contentRemoved');
  assert.equal(avviso.get('motivo'), 'odio');
  assert.equal(avviso.get('automatico'), false);
});

test('una segnalazione respinta si conta a chi l\'ha fatta', async () => {
  await segnala('r1', { kind: 'user', reportedUserId: 'autore3', reporterId: 'bugiardo' });
  await chiama(funzioni.adminResolveReport, { reportId: 'r1', decision: 'fake' });

  assert.equal((await db.collection('segnalanti').doc('bugiardo').get()).get('respinte'), 1);
  assert.equal((await ultimaRiga('decidiSegnalazione')).dettagli.decisione, 'fake');
});

test('"la guardo io" non chiude la segnalazione', async () => {
  await segnala('g1', { kind: 'user', reportedUserId: 'autore3' });
  await chiama(funzioni.adminResolveReport, { reportId: 'g1', decision: 'reviewing' });

  const presa = await db.collection('reports').doc('g1').get();

  assert.equal(presa.get('status'), 'reviewing');
  assert.equal(presa.get('presaDa'), MODERA);
  assert.equal(presa.get('resolvedAt'), undefined);
  // La sorella gia' decisa resta decisa.
  assert.equal((await db.collection('reports').doc('r1').get()).get('status'), 'fake');
});

test('un blocco toglie i legami, arriva al team, e non e\' una segnalazione', async () => {
  await persona('blocca', { seguiti: ['bloccato', 'altro'] });
  await persona('bloccato', { seguiti: ['blocca'] });

  const utenti = db.collection('users');

  await utenti.doc('blocca').collection('friends').doc('bloccato').set({ username: 'bloccato' });
  await utenti.doc('bloccato').collection('friends').doc('blocca').set({ username: 'blocca' });
  await utenti.doc('blocca').collection('following').doc('bloccato').set({ username: 'bloccato' });
  await utenti.doc('bloccato').collection('following').doc('blocca').set({ username: 'blocca' });
  await utenti.doc('bloccato').collection('friendRequests').doc('blocca').set({ fromUsername: 'blocca' });

  const prima = await db.collection('reports').count().get();

  await moderazione.accogliIlBlocco('blocca', 'bloccato', {
    origine: 'entry',
    challengeId: 'gara',
    entryId: 'bloccato',
    createdAt: Timestamp.now(),
  });

  for (const percorso of [
    'users/blocca/friends/bloccato',
    'users/bloccato/friends/blocca',
    'users/blocca/following/bloccato',
    'users/bloccato/following/blocca',
    'users/bloccato/friendRequests/blocca',
  ]) {
    assert.equal((await db.doc(percorso).get()).exists, false, percorso);
  }

  assert.deepEqual((await utenti.doc('blocca').get()).get('seguiti'), ['altro']);
  assert.deepEqual((await utenti.doc('bloccato').get()).get('seguiti'), []);

  const evento = await db.collection(moderazione.BLOCCHI).doc('blocca__bloccato').get();

  assert.equal(evento.get('stato'), 'nuovo');
  assert.equal(evento.get('bloccaNome'), 'blocca');
  assert.equal(evento.get('bloccatoNome'), 'bloccato');
  assert.equal(evento.get('origine'), 'entry');

  // Allo sviluppatore arriva, ed e' cio' che chiede Apple.
  assert.equal(email.length, 1);
  assert.match(email[0].subject, /Blocco/);
  assert.equal(squilli.length, 1);

  // **Ma non diventa una segnalazione.**
  assert.equal((await db.collection('reports').count().get()).data().count, prima.data().count);

  const { blocchi } = await pannelloCome('blocchi', { stato: 'nuovo' });
  const visto = blocchi.find((b) => b.id === 'blocca__bloccato');

  assert.equal(visto.bloccatoId, 'bloccato');
  assert.equal(visto.contro, 1);
  assert.equal((await pannelloCome('bolli')).lavoro.blocchi >= 1, true);
  assert.equal((await pannelloCome('panoramica')).lavoro.blocchi >= 1, true);

  await pannelloCome('segnaBlocco', { id: 'blocca__bloccato' });
  await pannelloCome('segnaBlocco', { id: 'blocca__bloccato' });

  assert.equal((await db.collection(moderazione.BLOCCHI).doc('blocca__bloccato').get()).get('stato'), 'visto');
  assert.deepEqual((await pannelloCome('blocchi', { stato: 'nuovo' })).blocchi.filter((b) => b.id === 'blocca__bloccato'), []);

  const righe = await db.collection('registroAdmin').where('azione', '==', 'segnaBlocco').get();

  assert.equal(righe.size, 1, 'due clic, una riga');
});

test('bloccare chi ha chiuso l\'account non lo fa rinascere', async () => {
  await persona('resta');
  await moderazione.accogliIlBlocco('resta', 'andatoVia', {});

  assert.equal((await db.collection('users').doc('andatoVia').get()).exists, false);
  assert.equal((await db.collection(moderazione.BLOCCHI).doc('resta__andatoVia').get()).exists, true);
});

test('chi blocca a raffica non riempie la casella di chi modera', async () => {
  const oggi = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Rome' });

  await persona('raffica');
  await persona('bersaglio');
  await db.collection('limiti').doc(`blocchi_raffica_${oggi}`).set({ quanti: 99 });
  await moderazione.accogliIlBlocco('raffica', 'bersaglio', {});

  assert.equal(email.length, 0);
  assert.equal((await db.collection(moderazione.BLOCCHI).doc('raffica__bersaglio').get()).exists, true);
});

test('un commento vietato si toglie, uno normale resta', async () => {
  await persona('scrive');

  const normale = db.doc('challenges/gara/entries/x/comments/buono');
  const vietato = db.doc('challenges/gara/entries/x/comments/cattivo');

  await normale.set({ userId: 'scrive', text: 'Sei una bomba, che foto!' });
  await vietato.set({ userId: 'scrive', text: 'sei un coglione' });

  assert.equal(await moderazione.filtraUnCommento(normale, (await normale.get()).data()), false);
  assert.equal(await moderazione.filtraUnCommento(vietato, (await vietato.get()).data()), true);
  assert.equal((await normale.get()).exists, true);
  assert.equal((await vietato.get()).exists, false);

  const avviso = await db.doc('users/scrive/notifications/tolto_commento_cattivo').get();

  assert.equal(avviso.get('automatico'), true);
  assert.equal(avviso.get('cosa'), 'commento');
  assert.equal((await ultimaRiga('togliCommento')).chi, 'automatico');
});

test('il nome e la descrizione passano dal filtro', async () => {
  const riferimento = db.collection('users').doc('Maleducato1234');

  await riferimento.set({ username: 'coglione', bio: 'sei un coglione', birthDate: NASCITA });
  await moderazione.controllaUnProfilo(riferimento, null, (await riferimento.get()).data());

  const dopo = await riferimento.get();

  assert.equal(dopo.get('username'), 'utente_maleduca');
  assert.equal(dopo.get('bio'), '');

  // Quello sostituito non si ricontrolla in eterno.
  const buono = await riferimento.get();

  assert.deepEqual(
    await moderazione.controllaUnProfilo(riferimento, buono.data(), buono.data()),
    {}
  );
});

test('la foto profilo passa da SafeSearch, e non si scavalca con un altro indirizzo', async () => {
  const uid = 'faccia1';
  const riferimento = db.collection('users').doc(uid);
  const indirizzo = (percorso) =>
    `https://firebasestorage.googleapis.com/v0/b/magazzino/o/${encodeURIComponent(percorso)}?alt=media&token=x`;
  const buona = indirizzo(`profiles/${uid}/photo.jpg`);

  // Una foto normale resta. E si guarda il file giusto.
  await riferimento.set({ username: 'faccia1', birthDate: NASCITA, photoUrl: buona, photoStoragePath: 'p' });
  await moderazione.controllaUnProfilo(riferimento, {}, (await riferimento.get()).data());

  assert.deepEqual(controlli, [`gs://magazzino/profiles/${uid}/photo.jpg`]);
  assert.equal((await riferimento.get()).get('photoUrl'), buona);

  // Una vietata no: sparisce, e la persona lo sa. Il file non c'e' nell'emulatore:
  // non deve fermare niente.
  verdetto[`gs://magazzino/profiles/${uid}/photo.jpg`] = { adult: 'VERY_LIKELY' };
  await moderazione.controllaUnProfilo(riferimento, {}, (await riferimento.get()).data());

  assert.equal((await riferimento.get()).get('photoUrl'), undefined);
  assert.equal((await riferimento.get()).get('photoStoragePath'), undefined);
  assert.equal((await db.doc(`users/${uid}/notifications/tolto_fotoProfilo_fotoProfilo`).get()).get('motivo'), 'sessuale');
  assert.equal((await ultimaRiga('togliFotoProfilo')).dettagli.uid, uid);

  // Un indirizzo che non e' il suo file non si controlla: si toglie.
  controlli = [];

  for (const altrove of ['https://altrove.example/foto.jpg', indirizzo('profiles/altraPersona/photo.jpg')]) {
    await riferimento.set({ photoUrl: altrove }, { merge: true });
    await moderazione.controllaUnProfilo(riferimento, {}, (await riferimento.get()).data());

    assert.equal((await riferimento.get()).get('photoUrl'), undefined, altrove);
  }

  assert.deepEqual(controlli, []);
});

test('una foto che dichiara un file e ne mostra un altro non entra in gara', async () => {
  const indirizzo = (percorso) =>
    `https://firebasestorage.googleapis.com/v0/b/magazzino/o/${encodeURIComponent(percorso)}?alt=media&token=x`;
  const entra = async (id, dati) => {
    const riferimento = db.doc(`challenges/garaFoto/entries/${id}`);

    await riferimento.set({
      userId: id,
      authorName: id,
      moderation: 'pending',
      createdAt: Timestamp.now(),
      votes: 0,
      ...dati,
    });
    await funzioni.moderateEntryPhoto.run({
      data: await riferimento.get(),
      params: { challengeId: 'garaFoto', entryId: id },
    });

    return riferimento.get();
  };

  await db.collection('challenges').doc('garaFoto').set({ title: 'Foto', participantsCount: 9 });

  const percorso = (id) => `entries/garaFoto/${id}/a.jpg`;
  const miniatura = (id) => `entries/garaFoto/${id}/a_thumb.jpg`;

  const buona = await entra('buona', {
    storagePath: percorso('buona'),
    mediaUrl: indirizzo(percorso('buona')),
    thumbUrl: indirizzo(miniatura('buona')),
  });

  assert.equal(buona.get('moderation'), 'approved');
  // Il file e la miniatura: sono due foto, e si guardano tutte e due.
  assert.deepEqual(controlli, [
    `gs://magazzino/${percorso('buona')}`,
    `gs://magazzino/${miniatura('buona')}`,
  ]);

  const altrove = await entra('altrove', {
    storagePath: percorso('altrove'),
    mediaUrl: 'https://altrove.example/nudo.jpg',
  });

  assert.equal(altrove.get('moderation'), 'rejected');

  const altraMiniatura = await entra('finta', {
    storagePath: percorso('finta'),
    mediaUrl: indirizzo(percorso('finta')),
    thumbUrl: 'https://altrove.example/nudo.jpg',
  });

  assert.equal(altraMiniatura.get('moderation'), 'rejected');

  // Una miniatura vietata, con una foto innocua, non passa.
  verdetto[`gs://magazzino/${miniatura('furba')}`] = { adult: 'VERY_LIKELY' };

  const furba = await entra('furba', {
    storagePath: percorso('furba'),
    mediaUrl: indirizzo(percorso('furba')),
    thumbUrl: indirizzo(miniatura('furba')),
  });

  assert.equal(furba.get('moderation'), 'rejected');
});

test('una didascalia vietata si toglie, e la foto resta in gara', async () => {
  const indirizzo = `https://firebasestorage.googleapis.com/v0/b/magazzino/o/${encodeURIComponent('entries/garaFoto/testo/a.jpg')}?alt=media`;
  const riferimento = db.doc('challenges/garaFoto/entries/testo');

  await riferimento.set({
    userId: 'testo',
    moderation: 'pending',
    createdAt: Timestamp.now(),
    storagePath: 'entries/garaFoto/testo/a.jpg',
    mediaUrl: indirizzo,
    caption: 'sei un coglione',
  });
  await funzioni.moderateEntryPhoto.run({
    data: await riferimento.get(),
    params: { challengeId: 'garaFoto', entryId: 'testo' },
  });

  const dopo = await riferimento.get();

  assert.equal(dopo.get('moderation'), 'approved');
  assert.equal(dopo.get('caption'), undefined);
  assert.equal((await db.doc('users/testo/notifications/tolto_didascalia_garaFoto').get()).get('cosa'), 'didascalia');
});

test('eliminare un account: chiede il nome, non si fa con dei soldi, e lascia le prove', async () => {
  const uid = 'espulso';
  const riferimento = db.collection('users').doc(uid);

  await persona(uid, { walletCents: 100 });
  await admin.auth().createUser({ uid, email: 'espulso@esempio.it' });
  await foto('gara', uid);
  await riferimento.collection('consents').doc('firma').set({ kind: 'legale', version: '1.6' });
  await riferimento.collection('ledger').doc('riga').set({ kind: 'premio' });
  await riferimento.collection('notifications').doc('n').set({ kind: 'fire' });
  await riferimento.collection('friends').doc('amico').set({ a: 1 });
  await db.doc(`users/amico/friends/${uid}`).set({ a: 1 });
  await db.doc('challenges/gara/entries/x/comments/suo').set({ userId: uid, text: 'Ciao' });

  await assert.rejects(pannelloCome('eliminaAccount', { uid, motivo: 'Abusi', conferma: 'qualcunaltro' }), /scrivi il nome/);
  await assert.rejects(pannelloCome('eliminaAccount', { uid, motivo: '', conferma: uid }), /motivo/);
  await assert.rejects(pannelloCome('eliminaAccount', { uid, motivo: 'Abusi', conferma: uid }), /soldi/);
  assert.equal((await riferimento.get()).exists, true, 'con dei soldi non si tocca niente');

  await riferimento.set({ walletCents: 0 }, { merge: true });

  const esito = await pannelloCome('eliminaAccount', { uid, motivo: 'Abusi ripetuti', conferma: `@${uid}` });

  assert.equal(esito.eliminato, true);
  assert.equal((await riferimento.get()).exists, false);
  assert.equal((await riferimento.collection('notifications').doc('n').get()).exists, false);
  assert.equal((await db.doc(`users/amico/friends/${uid}`).get()).exists, false);
  assert.equal((await db.doc('challenges/gara/entries/x/comments/suo').get()).exists, false);
  assert.equal((await db.doc(`challenges/gara/entries/${uid}`).get()).get('moderation'), 'rejected');
  assert.deepEqual(cancellati, [`profiles/${uid}/`]);
  await assert.rejects(admin.auth().getUser(uid));

  // Quello che la legge chiede di conservare resta.
  assert.equal((await riferimento.collection('consents').doc('firma').get()).exists, true);
  assert.equal((await riferimento.collection('ledger').doc('riga').get()).exists, true);

  assert.match(email.at(-1).subject, /eliminato/);
  assert.equal(email.at(-1).to, 'espulso@esempio.it');

  // Le firme dei Termini restano leggibili dalla scheda di chi c'e' ancora.
  await persona('conFirma');
  await db.collection('users').doc('conFirma').collection('consents').doc('f').set({
    kind: 'legale',
    version: '1.6',
    origine: 'prima-dell-accesso',
    at: Timestamp.now(),
  });

  const scheda = await pannelloCome('persona', { uid: 'conFirma' });

  assert.equal(scheda.profilo.firme[0].version, '1.6');
  assert.equal(scheda.profilo.firme[0].origine, 'prima-dell-accesso');

  const riga = await ultimaRiga('eliminaAccount');

  assert.equal(riga.chi, MODERA);
  assert.equal(riga.dettagli.motivo, 'Abusi ripetuti');
  assert.equal((await db.collection('sospensioni').doc(uid).get()).get('eliminato'), true);
});

test('il pannello resta chiuso a chi non e\' amministratore', async () => {
  const comeTutti = { auth: { uid: 'tizio', token: {} }, data: {} };

  await assert.rejects(funzioni.adminListReports.run(comeTutti));
  await assert.rejects(funzioni.adminResolveReport.run({ ...comeTutti, data: { reportId: 'x', decision: 'fake' } }));
  await assert.rejects(pannello.adminPannello.run({ ...comeTutti, data: { azione: 'blocchi' } }));
  await assert.rejects(pannello.adminPannello.run({ ...comeTutti, data: { azione: 'eliminaAccount', uid: 'x' } }));
});
