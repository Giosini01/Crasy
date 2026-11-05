'use strict';

/**
 * **Le regole di Firestore, provate contro l'emulatore come le prova un telefono.**
 *
 * Il telefono non passa dall'SDK di amministrazione: scrive con il suo gettone, e le
 * regole decidono. Qui si fa lo stesso, con l'interfaccia REST dell'emulatore: un
 * gettone senza firma, che l'emulatore accetta, e nessuna dipendenza in piu'.
 *
 * Parte con le altre prove sul server:
 *
 *     npm run test:server
 *
 * Copre quello che Apple chiede per la linea guida 1.2 e che non deve dipendere
 * dall'app: chi e' bloccato non interagisce, una segnalazione non si falsifica e non
 * si raddoppia, una firma non si retrodata.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const PROGETTO = process.env.GCLOUD_PROJECT || 'demo-crasy';
const HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const BASE = `http://${HOST}/v1/projects/${PROGETTO}/databases/(default)/documents`;
const RADICE = `projects/${PROGETTO}/databases/(default)/documents`;

/** Un gettone come quello di Firebase, senza firma: all'emulatore basta. */
function gettone(uid) {
  const parte = (oggetto) => Buffer.from(JSON.stringify(oggetto)).toString('base64url');
  const adesso = Math.floor(Date.now() / 1000);

  return [
    parte({ alg: 'none', typ: 'JWT' }),
    parte({
      iss: `https://securetoken.google.com/${PROGETTO}`,
      aud: PROGETTO,
      sub: uid,
      user_id: uid,
      iat: adesso,
      exp: adesso + 3600,
      auth_time: adesso,
      firebase: { sign_in_provider: 'password', identities: {} },
    }),
    '',
  ].join('.');
}

/** Da un valore JavaScript al formato dell'interfaccia REST. */
function valore(v) {
  if (v === null) return { nullValue: null };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return { integerValue: String(v) };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(valore) } };

  return { mapValue: { fields: campi(v) } };
}

function campi(oggetto) {
  return Object.fromEntries(Object.entries(oggetto).map(([k, v]) => [k, valore(v)]));
}

const ORA_DEL_SERVER = Symbol('ora del server');

/**
 * Una scrittura come quelle dell'app: i campi con [ORA_DEL_SERVER] li riempie il
 * server, come `FieldValue.serverTimestamp()`.
 */
function scrittura(percorso, dati, { soloSeNuovo = false, soloSeEsiste = false } = {}) {
  const normali = {};
  const ore = [];

  for (const [campo, v] of Object.entries(dati)) {
    if (v === ORA_DEL_SERVER) {
      ore.push({ fieldPath: campo, setToServerValue: 'REQUEST_TIME' });
    } else {
      normali[campo] = v;
    }
  }

  return {
    update: { name: `${RADICE}/${percorso}`, fields: campi(normali) },
    ...(ore.length ? { updateTransforms: ore } : {}),
    ...(soloSeNuovo ? { currentDocument: { exists: false } } : {}),
    ...(soloSeEsiste ? { currentDocument: { exists: true } } : {}),
  };
}

/** Manda delle scritture a nome di [uid]. Torna `true` se le regole le fanno passare. */
async function scrive(uid, ...scritture) {
  const risposta = await fetch(`${BASE}:commit`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${gettone(uid)}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ writes: scritture }),
  });

  return risposta.ok;
}

/** Una lettura a nome di [uid]. Torna il codice: 200, 404, 403. */
async function legge(uid, percorso) {
  const risposta = await fetch(`${BASE}/${percorso}`, {
    headers: { Authorization: `Bearer ${gettone(uid)}` },
  });

  return risposta.status;
}

/** Scrive senza passare dalle regole, come fa il server. */
async function prepara(percorso, dati) {
  const risposta = await fetch(`${BASE}:commit`, {
    method: 'POST',
    headers: { Authorization: 'Bearer owner', 'Content-Type': 'application/json' },
    body: JSON.stringify({ writes: [scrittura(percorso, dati)] }),
  });

  assert.equal(risposta.ok, true, `preparazione di ${percorso}: ${await risposta.text()}`);
}

const PRIMA = new Date(Date.now() - 3600 * 1000);
const DOPO = new Date(Date.now() + 3600 * 1000);
const NASCITA = new Date('1990-01-01T00:00:00Z');

/** Una foto da mandare in gara, come la scrive l'app. */
function partecipazione(uid, altro = {}) {
  return {
    userId: uid,
    authorName: uid,
    mediaUrl: `https://firebasestorage.googleapis.com/v0/b/x/o/entries%2Fg%2F${uid}%2Fa.jpg?alt=media`,
    mediaKind: 'photo',
    votes: 0,
    moderation: 'pending',
    createdAt: ORA_DEL_SERVER,
    ...altro,
  };
}

/** La segnalazione di una foto, come la scrive l'app. */
function segnalazione(chi, autore, altro = {}) {
  return {
    kind: 'entry',
    reporterId: chi,
    reportedUserId: autore,
    reason: 'sexual',
    challengeId: 'gara',
    entryId: autore,
    commentId: '',
    note: '',
    reportedUsername: autore,
    mediaUrl: '',
    challengeTitle: '',
    commentText: '',
    createdAt: ORA_DEL_SERVER,
    status: 'new',
    ...altro,
  };
}

test.before(async () => {
  await fetch(`http://${HOST}/emulator/v1/projects/${PROGETTO}/databases/(default)/documents`, {
    method: 'DELETE',
  });

  for (const uid of ['anna', 'bruno', 'carla', 'dino']) {
    await prepara(`users/${uid}`, { username: uid, birthDate: NASCITA, legalVersion: '1.6' });
  }

  await prepara('users/senzaFirma', { username: 'senzaFirma', birthDate: NASCITA });
  await prepara('challenges/gara', {
    title: 'Gara',
    createdByUserId: 'anna',
    startsAt: PRIMA,
    endsAt: DOPO,
    audience: ['*'],
    prizeCents: 0,
    mediaKind: 'photo',
  });
  await prepara('challenges/gara/entries/bruno', partecipazione('bruno', { createdAt: PRIMA }));
  await prepara('challenges/gara/entries/carla', partecipazione('carla', { createdAt: PRIMA }));
});

test('senza fiamme, commenti, notifiche e amicizie fra chi si e\' bloccato', async () => {
  // Bruno blocca Carla, e la cosa vale per tutti e due.
  assert.equal(await scrive('bruno', scrittura('users/bruno/blocked/carla', { createdAt: ORA_DEL_SERVER })), true);

  const fiamma = (chi, foto) =>
    scrittura(`users/${chi}/votes/gara__${foto}`, {
      challengeId: 'gara',
      entryId: foto,
      createdAt: ORA_DEL_SERVER,
    });

  assert.equal(await scrive('carla', fiamma('carla', 'bruno')), false, 'chi e\' stato bloccato non da\' fiamme');
  assert.equal(await scrive('bruno', fiamma('bruno', 'carla')), false, 'e nemmeno chi ha bloccato');
  assert.equal(await scrive('dino', fiamma('dino', 'bruno')), true, 'gli altri si\'');

  const commento = (chi, foto, id) =>
    scrittura(`challenges/gara/entries/${foto}/comments/${id}`, {
      userId: chi,
      authorName: chi,
      text: 'Ciao',
      createdAt: ORA_DEL_SERVER,
    });

  assert.equal(await scrive('carla', commento('carla', 'bruno', 'c1')), false);
  assert.equal(await scrive('bruno', commento('bruno', 'carla', 'c2')), false);
  assert.equal(await scrive('dino', commento('dino', 'bruno', 'c3')), true);

  const avviso = (chi) => ({
    kind: 'mention',
    actorId: chi,
    actorUsername: chi,
    challengeId: 'gara',
    challengeTitle: 'Gara',
    entryId: 'x',
    message: '',
    createdAt: ORA_DEL_SERVER,
  });

  assert.equal(await scrive('carla', scrittura('users/bruno/notifications/n1', avviso('carla'))), false);
  assert.equal(await scrive('dino', scrittura('users/bruno/notifications/n2', avviso('dino'))), true);

  assert.equal(
    await scrive('carla', scrittura('users/bruno/following/carla', { username: 'bruno' })),
    false,
    'non si scrive nemmeno nei seguiti di un altro'
  );
  assert.equal(
    await scrive('carla', scrittura('users/carla/following/bruno', { username: 'bruno' })),
    false,
    'chi e\' bloccato non segue'
  );
  assert.equal(
    await scrive('bruno', scrittura('users/bruno/following/carla', { username: 'carla' })),
    false,
    'chi ha bloccato nemmeno'
  );
  assert.equal(
    await scrive('carla', scrittura('users/bruno/friendRequests/carla', { fromUsername: 'carla' })),
    false
  );
  assert.equal(
    await scrive('bruno', scrittura('users/carla/friendRequests/bruno', { fromUsername: 'bruno' })),
    false
  );
});

test('lo sblocco riapre le interazioni', async () => {
  await prepara('users/anna/blocked/dino', { createdAt: PRIMA });

  const seguire = scrittura('users/dino/following/anna', { username: 'anna' });

  assert.equal(await scrive('dino', seguire), false);

  const via = await fetch(`${BASE}/users/anna/blocked/dino`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${gettone('anna')}` },
  });

  assert.equal(via.ok, true);
  assert.equal(await scrive('dino', seguire), true);
});

test('non si entra nella gara di chi ti ha bloccato', async () => {
  await prepara('users/anna/blocked/carla', { createdAt: PRIMA });
  await prepara('challenges/gara2', {
    title: 'Altra',
    createdByUserId: 'anna',
    startsAt: PRIMA,
    endsAt: DOPO,
    audience: ['*'],
    prizeCents: 0,
    mediaKind: 'photo',
  });

  const entra = (chi) =>
    scrittura(`challenges/gara2/entries/${chi}`, partecipazione(chi), { soloSeNuovo: true });

  assert.equal(await scrive('carla', entra('carla')), false);
  assert.equal(await scrive('dino', entra('dino')), true);
});

test('il blocco lo tocca solo chi lo scrive, e non vale su se stessi o su CRASY', async () => {
  const blocco = { createdAt: ORA_DEL_SERVER, origine: 'user' };

  assert.equal(await scrive('dino', scrittura('users/anna/blocked/bruno', blocco)), false);
  assert.equal(await scrive('dino', scrittura('users/dino/blocked/dino', blocco)), false);
  assert.equal(await scrive('dino', scrittura('users/dino/blocked/crasy', blocco)), false);
  assert.equal(await legge('dino', 'users/bruno/blocked/carla'), 403, 'chi e\' bloccato non puo\' saperlo');
  assert.equal(
    await scrive('dino', scrittura('users/dino/blocked/anna', { createdAt: ORA_DEL_SERVER, roba: 'x' })),
    false,
    'dentro non ci va altro'
  );
  // Le app gia' installate scrivono solo la data.
  assert.equal(
    await scrive('dino', scrittura('users/dino/blocked/bruno', { createdAt: ORA_DEL_SERVER })),
    true
  );
});

test('una foto nasce in attesa, e per pubblicare serve aver accettato', async () => {
  const gara3 = {
    title: 'Terza',
    createdByUserId: '',
    startsAt: PRIMA,
    endsAt: DOPO,
    audience: ['*'],
    prizeCents: 0,
    mediaKind: 'photo',
  };

  await prepara('challenges/gara3', gara3);

  assert.equal(
    await scrive(
      'anna',
      scrittura('challenges/gara3/entries/anna', partecipazione('anna', { moderation: 'approved' }))
    ),
    false,
    'un telefono non si approva da solo'
  );
  assert.equal(
    await scrive('senzaFirma', scrittura('challenges/gara3/entries/senzaFirma', partecipazione('senzaFirma'))),
    false,
    'senza la firma dei documenti non si pubblica'
  );
  assert.equal(await scrive('anna', scrittura('challenges/gara3/entries/anna', partecipazione('anna'))), true);
  assert.equal(
    await scrive(
      'senzaFirma',
      scrittura('challenges/gara/entries/bruno/comments/s1', {
        userId: 'senzaFirma',
        authorName: 'senzaFirma',
        text: 'Ciao',
        createdAt: ORA_DEL_SERVER,
      })
    ),
    false
  );
});

test('una segnalazione si scrive a nome proprio, e una volta sola', async () => {
  const id = 'dino__entry__gara__carla';

  assert.equal(
    await scrive('dino', scrittura(`reports/${id}`, segnalazione('anna', 'carla'))),
    false,
    'non a nome di un altro'
  );
  assert.equal(
    await scrive('dino', scrittura(`reports/${id}`, segnalazione('dino', 'bruno', { entryId: 'carla' }))),
    false,
    'la foto di uno non si segnala scrivendo il nome di un altro'
  );
  assert.equal(
    await scrive('dino', scrittura(`reports/${id}`, segnalazione('dino', 'carla', { reason: 'inventato' }))),
    false,
    'il motivo e\' uno di quelli previsti'
  );
  assert.equal(
    await scrive('dino', scrittura(`reports/${id}`, segnalazione('dino', 'carla', { note: 'x'.repeat(501) }))),
    false,
    'la nota ha una misura'
  );
  assert.equal(
    await scrive('dino', scrittura(`reports/${id}`, segnalazione('dino', 'carla', { status: 'removed' }))),
    false,
    'non nasce gia\' decisa'
  );
  assert.equal(
    await scrive('dino', scrittura(`reports/${id}`, segnalazione('dino', 'carla', { createdAt: PRIMA }))),
    false,
    'l\'ora la mette il server'
  );
  assert.equal(
    await scrive('dino', scrittura(`reports/${id}`, segnalazione('dino', 'carla', { sospetta: false }))),
    false,
    'dentro non ci va altro'
  );
  assert.equal(
    await scrive('dino', scrittura('reports/altro', segnalazione('dino', 'carla'))),
    false,
    'il nome e\' quello giusto'
  );

  assert.equal(await legge('dino', `reports/${id}`), 404, 'la propria si puo\' chiedere');
  assert.equal(await scrive('dino', scrittura(`reports/${id}`, segnalazione('dino', 'carla'))), true);
  assert.equal(await legge('dino', `reports/${id}`), 200);
  assert.equal(await legge('carla', `reports/${id}`), 403, 'chi e\' segnalato non la legge');
  assert.equal(await legge('anna', `reports/${id}`), 403, 'e nemmeno un altro');
  assert.equal(
    await scrive('dino', scrittura(`reports/${id}`, segnalazione('dino', 'carla'))),
    false,
    'la seconda non passa'
  );

  const ritiro = await fetch(`${BASE}/reports/${id}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${gettone('dino')}` },
  });

  assert.equal(ritiro.ok, false, 'e non si ritira');
});

test('si segnalano anche i commenti, e la missione anonima senza autore', async () => {
  assert.equal(
    await scrive(
      'dino',
      scrittura(
        'reports/dino__comment__gara__carla__c9',
        segnalazione('dino', 'anna', {
          kind: 'comment',
          entryId: 'carla',
          commentId: 'c9',
          commentText: 'Un insulto',
          reason: 'hate',
        })
      )
    ),
    true
  );
  assert.equal(
    await scrive(
      'dino',
      scrittura(
        'reports/dino__challenge__gara__',
        segnalazione('dino', '', { kind: 'challenge', entryId: '', reason: 'danger' })
      )
    ),
    true
  );
});

test('la firma dei documenti porta la versione e l\'ora del server', async () => {
  const firma = (altro = {}) => ({
    kind: 'legale',
    version: '1.6',
    marketing: false,
    origine: 'prima-della-registrazione',
    at: ORA_DEL_SERVER,
    ...altro,
  });

  // Chi si e' appena registrato non ha ancora un profilo: la firma nasce lo stesso.
  assert.equal(await scrive('nuovo', scrittura('users/nuovo/consents/f1', firma())), true);
  assert.equal(await scrive('nuovo', scrittura('users/nuovo/consents/f2', firma({ at: PRIMA }))), false, 'non si retrodata');
  assert.equal(await scrive('nuovo', scrittura('users/nuovo/consents/f3', firma({ version: '' }))), false);
  assert.equal(await scrive('altro', scrittura('users/nuovo/consents/f4', firma())), false, 'a nome di un altro no');
  assert.equal(await legge('altro', 'users/nuovo/consents/f1'), 403);
  assert.equal(await scrive('nuovo', scrittura('users/nuovo/consents/f1', firma())), false, 'una firma non si riscrive');

  const via = await fetch(`${BASE}/users/nuovo/consents/f1`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${gettone('nuovo')}` },
  });

  assert.equal(via.ok, false, 'e non si cancella');

  // E quella copiata sul profilo non si scrive con una data a piacere.
  const profilo = (at) => ({ username: 'anna', birthDate: NASCITA, legalVersion: '1.6', legalAcceptedAt: at });

  assert.equal(await scrive('anna', scrittura('users/anna', profilo(PRIMA))), false);
  assert.equal(await scrive('anna', scrittura('users/anna', profilo(ORA_DEL_SERVER))), true);

  // **Chi rifa l'onboarding riscrive il profilo da capo**, senza la firma: deve poterlo
  // fare, e poi l'app gli richiede i documenti.
  assert.equal(
    await scrive('anna', scrittura('users/anna', { username: 'anna', birthDate: NASCITA, legalVersion: '1.6' })),
    true
  );
});

test('il team e i suoi registri non si aprono da un telefono', async () => {
  for (const percorso of ['blocchi/a__b', 'segnalanti/dino', 'registroAdmin/r', 'sospensioni/dino']) {
    assert.equal(await legge('dino', percorso), 403, percorso);
    assert.equal(await scrive('dino', scrittura(percorso, { a: 'b' })), false, percorso);
  }
});

test('le regole pubblicate sono quelle provate qui', () => {
  // Un controllo da poco, che evita di provare un file e pubblicarne un altro.
  const regole = fs.readFileSync(path.join(__dirname, '..', '..', 'firestore.rules'), 'utf8');

  assert.ok(regole.includes('function bloccoFra'));
});
