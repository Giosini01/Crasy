/**
 * **Chi seguiva gia' qualcuno, adesso lo segue davvero.**
 *
 * Seguire scrive due cose: la "richiesta" nella cartella di chi e' seguito —
 * e' quella che gli dice "ti segue" — e chi seguo, dalla parte di chi segue.
 * La seconda e' nata dopo, e chi aveva gia' iniziato a seguire qualcuno ha
 * solo la prima: il bottone diceva "Segui gia'", ma le gare di quella persona
 * in SEGUITI non comparivano.
 *
 * Per ogni `users/{seguito}/friendRequests/{chiSegue}` questo script scrive
 * `users/{chiSegue}/following/{seguito}` e aggiunge `seguito` all'elenco
 * `seguiti` nel documento di chi segue. Si puo' rilanciare quante volte si
 * vuole: quello che c'e' gia' resta com'e'.
 *
 *     node tool/migra_seguiti.js --chiave C:/percorso/chiave.json
 *     node tool/migra_seguiti.js --chiave C:/percorso/chiave.json --scrivi
 *
 * Senza `--scrivi` conta soltanto.
 */

'use strict';

const admin = require('firebase-admin');

const argomenti = process.argv.slice(2);
const posto = argomenti.indexOf('--chiave');
const chiave = posto >= 0 ? argomenti[posto + 1] : null;
const scrivi = argomenti.includes('--scrivi');

if (!chiave) {
  console.error('Serve --chiave <file json>.');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(chiave)) });

const db = admin.firestore();

async function migra() {
  const richieste = await db.collectionGroup('friendRequests').get();
  const nomi = new Map();

  async function nomeDi(userId) {
    if (!nomi.has(userId)) {
      const profilo = await db.collection('users').doc(userId).get();
      nomi.set(userId, profilo.exists ? String(profilo.get('username') || '') : null);
    }

    return nomi.get(userId);
  }

  const conto = { richieste: richieste.size, scritte: 0, gia: 0, senzaProfilo: 0 };

  for (const richiesta of richieste.docs) {
    const chiSegue = richiesta.id;
    const seguito = richiesta.ref.parent.parent?.id;

    if (!seguito || !chiSegue || seguito === chiSegue) {
      continue;
    }

    // Chi segue deve esistere ancora: un account cancellato non segue nessuno.
    if ((await nomeDi(chiSegue)) === null) {
      conto.senzaProfilo += 1;

      continue;
    }

    const riga = db
      .collection('users')
      .doc(chiSegue)
      .collection('following')
      .doc(seguito);

    if ((await riga.get()).exists) {
      conto.gia += 1;

      continue;
    }

    conto.scritte += 1;

    if (scrivi) {
      await riga.set({
        username: (await nomeDi(seguito)) || '',
        since: richiesta.get('createdAt') || admin.firestore.FieldValue.serverTimestamp(),
      });

      await db.collection('users').doc(chiSegue).set(
        { seguiti: admin.firestore.FieldValue.arrayUnion(seguito) },
        { merge: true },
      );
    }
  }

  console.log(scrivi ? 'Fatto:' : 'Prova (niente scritto):', conto);
}

migra().then(
  () => process.exit(0),
  (errore) => {
    console.error(errore);
    process.exit(1);
  },
);
