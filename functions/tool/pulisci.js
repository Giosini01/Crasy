/**
 * **Svuota CRASY di quello che ci si e' provato dentro, e lascia le persone.**
 *
 * Mesi di prove lasciano un database che non somiglia a niente: missioni
 * chiamate "test", undici "MARIO" nate da undici tocchi sullo stesso bottone,
 * gare seminate a mano per vedere se la classifica si disegnava. Nessuna di
 * quelle cose e' un errore — servivano tutte — ma restano li' a fare da fondale
 * a un'app che sta per essere vista da gente vera.
 *
 * ## Cosa resta in piedi
 *
 * **Gli account.** Nome, foto, password, amicizie: chi si e' registrato resta
 * registrato e rientra come se niente fosse. Cancellare una persona per fare
 * pulizia sarebbe il modo piu' veloce di perdere le uniche sei che ci sono.
 *
 * **Le sfide del giorno.** Sono scritte a mano, una per giorno, e arrivano fino
 * a fine ottobre: rifarle vorrebbe dire riscriverle.
 *
 * ## Cosa se ne va
 *
 * Tutte le altre missioni, con dentro le partecipazioni e **i file su
 * Storage**. Quelli soprattutto: cancellare il documento e lasciare la foto
 * vuol dire pagare per sempre un'immagine che non e' piu' raggiungibile da
 * nessuna parte.
 *
 * Con loro se ne vanno le fiamme e le notifiche, che parlano di gare che non
 * esistono piu'. E si svuotano da sole le bacheche — figurine, prove d'onore,
 * classifiche — perche' quelle non sono dati: sono il riflesso delle missioni.
 *
 * ## Si guarda prima di toccare
 *
 * Senza `--conferma` non cancella niente e si limita a dire cosa farebbe. E'
 * l'unico modo onesto di scrivere uno strumento che non ha un tasto "annulla".
 *
 *     node tool/pulisci.js --chiave C:/percorso/chiave.json
 *     node tool/pulisci.js --chiave C:/percorso/chiave.json --conferma
 */

'use strict';

const admin = require('firebase-admin');

const argomenti = process.argv.slice(2);
const conferma = argomenti.includes('--conferma');
const chiave = argomenti[argomenti.indexOf('--chiave') + 1];

if (!chiave || chiave.startsWith('--')) {
  console.error('Serve --chiave <percorso del file json>.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(chiave)),
  storageBucket: 'daily-dating-app.firebasestorage.app',
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

/** Le sfide del giorno si riconoscono dal nome, e non si toccano. */
function daTenere(id) {
  return id.startsWith('daily-');
}

/** Se una gara sta ancora andando. */
function inCorso(challenge) {
  const fine = challenge.get('endsAt');

  return Boolean(fine) && fine.toMillis() > Date.now();
}

async function pulisci() {
  const challenges = await db.collection('challenges').get();
  const daCancellare = challenges.docs.filter((d) => !daTenere(d.id));

  // **Anche le foto mandate alle sfide del giorno gia' finite.**
  //
  // La gara resta — serve, e' scritta a mano — ma le partecipazioni no: sono
  // prove come tutte le altre, e finche' stanno li' continuano a comparire sui
  // profili, che e' esattamente cio' che si sta ripulendo. Tenere la gara e
  // buttare le foto non e' incoerente: la gara e' un testo, le foto sono roba
  // di qualcuno.
  //
  // **Quella di oggi si salva.** E' aperta adesso: cancellare la foto di chi
  // ha appena partecipato sarebbe toglierla di gara mentre gioca.
  const svuotare = challenges.docs.filter(
    (d) => daTenere(d.id) && !inCorso(d)
  );

  let foto = 0;
  let file = 0;

  for (const challenge of [...daCancellare, ...svuotare]) {
    const entries = await challenge.ref.collection('entries').get();

    for (const entry of entries.docs) {
      foto += 1;

      const percorso = entry.get('storagePath');

      if (percorso) {
        file += 1;

        if (conferma) {
          // `ignoreNotFound`: un file gia' sparito non e' un motivo per
          // fermare tutto a meta' pulizia.
          await bucket
            .file(percorso)
            .delete({ ignoreNotFound: true })
            .catch(() => {});
        }
      }

      if (conferma) {
        await entry.ref.delete();
      }
    }

    // La sfida del giorno resta: si e' svuotata, non cancellata.
    if (conferma && !daTenere(challenge.id)) {
      await challenge.ref.delete();
    }
  }

  const notifiche = await db.collectionGroup('notifications').get();
  const voti = await db.collectionGroup('votes').get();
  const viste = await db.collectionGroup('revealsSeen').get();

  if (conferma) {
    for (const gruppo of [notifiche, voti, viste]) {
      // A lotti da quattrocento: Firestore ne accetta cinquecento per volta, e
      // stare sotto il limite evita di doverci pensare.
      for (let i = 0; i < gruppo.docs.length; i += 400) {
        const lotto = db.batch();

        for (const documento of gruppo.docs.slice(i, i + 400)) {
          lotto.delete(documento.ref);
        }

        await lotto.commit();
      }
    }
  }

  const utenti = await db.collection('users').get();
  const verbo = conferma ? 'Cancellate' : 'Da cancellare:';

  console.log(`${verbo} ${daCancellare.length} missioni`);
  console.log(
    `${verbo} le foto di ${svuotare.length} sfide del giorno gia' finite ` +
      '(la gara resta)'
  );
  console.log(`${verbo} ${foto} partecipazioni e ${file} file su Storage`);
  console.log(`${verbo} ${notifiche.size} notifiche, ${voti.size} fiamme`);
  console.log(
    `Restano ${utenti.size} account e ` +
      `${challenges.size - daCancellare.length} sfide del giorno.`
  );

  if (!conferma) {
    console.log('\nNiente e\' stato toccato. Per farlo davvero: --conferma');
  }
}

pulisci().catch((errore) => {
  console.error(errore);
  process.exit(1);
});
