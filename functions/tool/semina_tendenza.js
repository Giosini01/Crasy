/**
 * **Riempie le classifiche con delle gare finte, per poterle guardare.**
 *
 * Le due classifiche — chi ha vinto di piu' e chi fa giocare di piu' — si
 * calcolano dalle gare chiuse nelle ultime ore. Su un'app con quattro persone
 * e nessuna gara chiusa, sono due podi vuoti: non si vede se funzionano, e
 * soprattutto non si vede se l'ordinamento e' quello giusto.
 *
 * ## Cosa scrive, e cosa non scrive
 *
 * Gare **gia' finite**, pubbliche, con un vincitore e un premio, datate poche
 * ore fa. Niente partecipazioni, niente foto: quelle gare alimentano i due podi
 * e **nient'altro**. Non compaiono fra le gare aperte — sono scadute — non
 * lasciano figurine sui profili — senza foto non c'e' trofeo — e non entrano
 * nell'elenco "appena finite", che pretende almeno un partecipante.
 *
 * L'impronta e' quella: due classifiche piene e zero altro.
 *
 * ## Si tolgono com'erano venute
 *
 * Ogni documento porta `semina: true`, che nessuna gara vera avra' mai. Con
 * `--pulisci` se ne vanno tutte, e il database torna esattamente com'era.
 *
 *     node tool/semina_tendenza.js --chiave C:/percorso/chiave.json
 *     node tool/semina_tendenza.js --chiave C:/percorso/chiave.json --pulisci
 */

'use strict';

const admin = require('firebase-admin');

const argomenti = process.argv.slice(2);
const pulisci = argomenti.includes('--pulisci');
const chiave = argomenti[argomenti.indexOf('--chiave') + 1];

if (!chiave || chiave.startsWith('--')) {
  console.error('Serve --chiave <percorso del file json>.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(chiave)),
});

const db = admin.firestore();

/** Quante ore fa e' finita, in euro, chi l'ha lanciata e chi l'ha vinta. */
const GARE = [
  // Il caso che mette alla prova la regola: dieci gare da un euro contro una
  // da cento. Chi ha vinto le dieci deve stare **sotto**.
  ...Array.from({ length: 10 }, (_, i) => ({
    ore: 6 + i * 0.5,
    euro: 1,
    lancia: 'giosini',
    vince: 'frankk',
  })),
  { ore: 3, euro: 100, lancia: 'giosini', vince: 'giowandowski' },
  { ore: 9, euro: 30, lancia: 'giowandowski', vince: 'giosini' },
  { ore: 14, euro: 20, lancia: 'frankk', vince: 'giosini' },
  { ore: 20, euro: 15, lancia: 'frankk', vince: 'matteoruggieri' },
  { ore: 26, euro: 45, lancia: 'giowandowski', vince: 'giovannidio' },
  // Lanciata e mai fatta da nessuno: i soldi li ha messi lo stesso, e nella
  // classifica di chi fa giocare contano.
  { ore: 30, euro: 50, lancia: 'giowandowski', vince: null },
];

const TITOLI = [
  'Balla in mezzo alla piazza',
  'Canta a squarciagola per strada',
  'Fatti una foto con uno sconosciuto',
  'Tuffati vestito',
  'Corri sotto la pioggia',
  'Parla in dialetto per un minuto',
  'Fatti fare una treccia da un passante',
  'Mangia qualcosa che non hai mai provato',
  'Saluta dieci persone di fila',
  'Fai una verticale al parco',
  'Ordina in una lingua inventata',
  'Regala un fiore a qualcuno',
  'Fatti un selfie con un cane altrui',
  'Racconta una barzelletta a un cameriere',
  'Attraversa la piazza camminando all indietro',
];

async function anagrafica() {
  const utenti = await db.collection('users').limit(50).get();
  const perNome = new Map();

  for (const utente of utenti.docs) {
    const nome = String(utente.get('username') || '').trim();

    if (nome) {
      perNome.set(nome, utente.id);
    }
  }

  return perNome;
}

async function semina() {
  const perNome = await anagrafica();
  const mancanti = new Set();

  for (const gara of GARE) {
    for (const nome of [gara.lancia, gara.vince]) {
      if (nome && !perNome.has(nome)) {
        mancanti.add(nome);
      }
    }
  }

  if (mancanti.size > 0) {
    console.error(`Account non trovati: ${[...mancanti].join(', ')}`);
    process.exit(1);
  }

  const lotto = db.batch();
  const adesso = Date.now();

  GARE.forEach((gara, i) => {
    const fine = new Date(adesso - gara.ore * 3600000);
    const inizio = new Date(fine.getTime() - 24 * 3600000);
    const riferimento = db.collection('challenges').doc();

    lotto.set(riferimento, {
      // Il segno che permette di toglierle tutte, e che nessuna gara vera
      // avra' mai.
      semina: true,

      title: TITOLI[i % TITOLI.length],
      brief: 'Gara di prova per vedere le classifiche.',
      prizeCents: gara.euro * 100,
      scope: 'global',
      audience: ['*'],
      place: '',
      mediaKind: 'photo',
      source: 'instant',
      rules: [],
      maxParticipants: 10,

      createdByUserId: perNome.get(gara.lancia),
      createdByUsername: gara.lancia,

      startsAt: admin.firestore.Timestamp.fromDate(inizio),
      endsAt: admin.firestore.Timestamp.fromDate(fine),

      // **Senza partecipanti e senza foto**, di proposito: cosi' queste gare
      // alimentano i due podi e non toccano nient'altro.
      participantsCount: 0,
      winnerEntryId: gara.vince ? 'semina' : '',
      winnerUserId: gara.vince ? perNome.get(gara.vince) : '',
      winnerUsername: gara.vince || '',
      winnerMediaUrl: '',
      winnerMediaKind: 'photo',
      winnerVotes: 0,

      prizeStatus: 'unpaid',
      purgedAt: null,
      targetUserId: '',
      targetUsername: '',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  await lotto.commit();
  console.log(`Seminate ${GARE.length} gare di prova.`);
  console.log('Per toglierle: aggiungi --pulisci allo stesso comando.');
}

async function ripulisci() {
  const finte = await db
    .collection('challenges')
    .where('semina', '==', true)
    .limit(200)
    .get();

  if (finte.empty) {
    console.log('Non c\'e\' niente da togliere.');

    return;
  }

  const lotto = db.batch();

  for (const gara of finte.docs) {
    lotto.delete(gara.ref);
  }

  await lotto.commit();
  console.log(`Tolte ${finte.size} gare di prova.`);
}

(pulisci ? ripulisci() : semina()).catch((errore) => {
  console.error(errore);
  process.exit(1);
});
