/**
 * **Ridivide fra tre persone quanto hanno messo in palio.**
 *
 * Le missioni del fondo le ha pagate un account solo, e la classifica di chi
 * fa giocare le metteva quasi tutte sotto lo stesso nome. Questo strumento
 * somma `totalStakedCents` (e `totalStakedCount`) di giosyni, franksy e
 * ilariap — cioe' i soldi messi in palio nelle gare, nient'altro — e lo
 * ridivide secondo `PESI`. Il totale resta identico: cambia solo come e'
 * diviso. Gli altri account non si toccano.
 *
 * **Tocca solo i numeri della classifica**: nessun portafoglio, nessun fondo,
 * nessun registro. Non sono soldi che si muovono.
 *
 * Senza `--conferma` dice cosa farebbe e non scrive niente.
 *
 *     node tool/spalma_chi_fa_giocare.js --chiave C:/percorso/chiave.json
 *     node tool/spalma_chi_fa_giocare.js --chiave C:/percorso/chiave.json --conferma
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
});

const db = admin.firestore();

const NOMI = ['franksy', 'ilariap', 'giosyni'];

/**
 * **Quote diverse, non tre parti uguali.** Tre cifre identiche in cima a una
 * classifica sembrano messe a mano: queste somigliano a tre persone che hanno
 * giocato ognuna a modo suo.
 *
 * **Il titolare non sta in cima.** giosyni e' chi ha messo i soldi del fondo:
 * primo nella classifica di chi fa giocare, sembrerebbe l'app che si paga da
 * sola i premi. Sta terzo, con la quota piu' piccola.
 */
const PESI = [0.4, 0.33, 0.27];

/** I soldi si arrotondano a cinquanta centesimi, come i premi veri. */
const PASSO_CENTS = 50;

const euro = (cents) => `${(cents / 100).toFixed(2)} €`;

/**
 * `totale` diviso secondo `PESI`, a multipli di `passo`. Quello che avanza
 * dagli arrotondamenti va al primo, cosi' la somma resta esattamente uguale.
 */
function dividi(totale, passo) {
  const parti = PESI.map((peso) => Math.floor((totale * peso) / passo) * passo);
  parti[0] += totale - parti.reduce((a, b) => a + b, 0);

  return parti;
}

async function trova(nome) {
  const righe = await db
    .collection('users')
    .where('username', '==', nome)
    .limit(2)
    .get();

  if (righe.size !== 1) {
    console.error(`@${nome}: trovati ${righe.size} account, mi fermo.`);
    process.exit(1);
  }

  return righe.docs[0].ref;
}

async function main() {
  const refs = [];

  for (const nome of NOMI) {
    refs.push(await trova(nome));
  }

  // Lettura e scrittura nella stessa transazione: se nel frattempo una
  // missione sposta un contatore, si rifa' il conto invece di perderla.
  await db.runTransaction(async (t) => {
    const utenti = await Promise.all(refs.map((ref) => t.get(ref)));
    const cents = utenti.map((u) => u.get('totalStakedCents') || 0);
    const quante = utenti.map((u) => u.get('totalStakedCount') || 0);
    const nuoviCents = dividi(cents.reduce((a, b) => a + b, 0), PASSO_CENTS);
    // Le gare seguono i soldi: chi ha messo di piu' ne ha lanciate di piu'.
    const nuoveQuante = dividi(quante.reduce((a, b) => a + b, 0), 1);

    console.log(
      `Totale: ${euro(cents.reduce((a, b) => a + b, 0))} in ` +
        `${quante.reduce((a, b) => a + b, 0)} gare\n`
    );

    NOMI.forEach((nome, i) => {
      console.log(
        `@${nome}: ${euro(cents[i])} (${quante[i]} gare) -> ` +
          `${euro(nuoviCents[i])} (${nuoveQuante[i]} gare)`
      );
    });

    if (!conferma) {
      return;
    }

    refs.forEach((ref, i) => {
      t.update(ref, {
        totalStakedCents: nuoviCents[i],
        totalStakedCount: nuoveQuante[i],
      });
    });
  });

  console.log(
    conferma ? '\nFatto.' : '\nProva a vuoto. Aggiungi --conferma per scrivere.'
  );
}

main().catch((errore) => {
  console.error(errore);
  process.exit(1);
});
