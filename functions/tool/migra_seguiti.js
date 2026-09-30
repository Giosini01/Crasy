/**
 * **Chi seguiva gia' qualcuno, adesso lo segue davvero. E i contatori.**
 *
 * Seguire scrive due cose: la "richiesta" nella cartella di chi e' seguito —
 * e' quella che gli dice "ti segue" — e chi seguo, dalla parte di chi segue.
 * La seconda e' nata dopo, e chi aveva gia' iniziato a seguire qualcuno ha
 * solo la prima: il bottone diceva "Segui gia'", ma le gare di quella persona
 * in SEGUITI non comparivano.
 *
 * Questo script:
 *
 * - per ogni `users/{seguito}/friendRequests/{chiSegue}` scrive
 *   `users/{chiSegue}/following/{seguito}` e aggiunge `seguito` all'elenco
 *   `seguiti` nel documento di chi segue;
 * - lo stesso per gli amici, da tutte e due le parti: un amico e' qualcuno che
 *   si segue, e le amicizie nate prima dei follower quella riga non l'hanno;
 * - alla fine rifa' da capo i contatori sul profilo di ognuno — follower e
 *   seguiti — contando le righe vere. Da li' in poi li tengono le funzioni.
 *
 * Si puo' rilanciare quante volte si vuole: quello che c'e' gia' resta
 * com'e', e i contatori tornano giusti.
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
  const amicizie = await db.collectionGroup('friends').get();
  const nomi = new Map();

  async function nomeDi(userId) {
    if (!nomi.has(userId)) {
      const profilo = await db.collection('users').doc(userId).get();
      nomi.set(userId, profilo.exists ? String(profilo.get('username') || '') : null);
    }

    return nomi.get(userId);
  }

  const conto = {
    richieste: richieste.size,
    amicizie: amicizie.size,
    scritte: 0,
    gia: 0,
    senzaProfilo: 0,
    contatori: 0,
  };

  // Una richiesta in users/{seguito}/friendRequests/{chiSegue}: chiSegue segue
  // seguito. Un'amicizia in users/{a}/friends/{b}: a segue b — la riga
  // speculare, b segue a, arriva da sola perche' c'e' anche quella.
  const coppie = [
    ...richieste.docs.map((doc) => ({
      chiSegue: doc.id,
      seguito: doc.ref.parent.parent?.id,
      quando: doc.get('createdAt'),
    })),
    ...amicizie.docs.map((doc) => ({
      chiSegue: doc.ref.parent.parent?.id,
      seguito: doc.id,
      quando: doc.get('since'),
    })),
  ];

  for (const { chiSegue, seguito, quando } of coppie) {
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
        since: quando || admin.firestore.FieldValue.serverTimestamp(),
      });

      await db.collection('users').doc(chiSegue).set(
        { seguiti: admin.firestore.FieldValue.arrayUnion(seguito) },
        { merge: true },
      );
    }
  }

  // **I contatori, da capo**, contati sulle righe vere per ognuno.
  const utenti = await db.collection('users').get();

  for (const utente of utenti.docs) {
    const [chiesti, amici, seguiti] = await Promise.all([
      utente.ref.collection('friendRequests').count().get(),
      utente.ref.collection('friends').count().get(),
      utente.ref.collection('following').count().get(),
    ]);

    const followersCount = chiesti.data().count + amici.data().count;
    const followingCount = seguiti.data().count;

    if (
      utente.get('followersCount') === followersCount &&
      utente.get('followingCount') === followingCount
    ) {
      continue;
    }

    conto.contatori += 1;

    if (scrivi) {
      await utente.ref.update({ followersCount, followingCount });
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
