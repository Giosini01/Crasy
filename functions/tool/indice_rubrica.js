/**
 * **Mette nell'indice i numeri di chi era gia' iscritto.**
 *
 * L'indice si riempie da solo quando un profilo cambia: chi si iscrive da
 * adesso ci entra senza che nessuno faccia niente. Ma chi c'era prima ha il
 * numero nel profilo e nessuna impronta nell'indice, e finche' resta cosi'
 * **non lo trova nessuno** — la sezione dei suggeriti direbbe a tutti che non
 * conoscono nessuno.
 *
 * Si lancia una volta sola, dopo aver pubblicato le funzioni.
 *
 *     node tool/indice_rubrica.js --chiave C:/percorso/chiave.json --pepe <segreto>
 *     node tool/indice_rubrica.js --chiave ... --pepe ... --scrivi
 *
 * Senza `--scrivi` non tocca niente e dice solo quanti ne metterebbe: e' il
 * modo di accorgersi di aver sbagliato il segreto **prima** di riempire
 * l'indice di impronte che non corrisponderanno mai a niente.
 *
 * Il segreto e' lo stesso che sta in Secret Manager sotto `PEPE_RUBRICA`. Se
 * qui se ne usa un altro, le impronte scritte ora e quelle cercate dal server
 * non si incontreranno mai, e non se ne accorgera' nessuno: non esce nessun
 * errore, semplicemente non si trova piu' nessuno.
 */

'use strict';

const crypto = require('crypto');
const admin = require('firebase-admin');

const argomenti = process.argv.slice(2);

function opzione(nome) {
  const posto = argomenti.indexOf(nome);

  return posto >= 0 ? argomenti[posto + 1] : null;
}

const chiave = opzione('--chiave');
const pepe = opzione('--pepe');
const scrivi = argomenti.includes('--scrivi');

if (!chiave || !pepe) {
  console.error('Servono --chiave <file json> e --pepe <segreto>.');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(chiave)) });

const db = admin.firestore();

/** La stessa spazzolata che fa il server: se cambia li', deve cambiare qui. */
function pulisci(numero) {
  const solo = String(numero || '').replace(/[^\d+]/g, '');

  if (!solo.startsWith('+') || solo.length < 8 || solo.length > 16) {
    return null;
  }

  return solo;
}

function impronta(numero) {
  return crypto.createHmac('sha256', pepe).update(numero).digest('hex');
}

async function riempi() {
  const utenti = await db.collection('users').get();

  let conNumero = 0;
  let saltati = 0;
  let spenti = 0;
  let scritti = 0;

  // Si scrive a blocchi da 400: un batch di Firestore ne regge 500, e andare
  // al limite significa che il giorno in cui qualcuno aggiunge un'altra
  // scrittura per utente tutto smette di funzionare.
  let lotto = db.batch();
  let nelLotto = 0;

  for (const utente of utenti.docs) {
    const numero = pulisci(utente.get('phone'));

    if (!numero) {
      saltati += 1;

      continue;
    }

    conNumero += 1;

    if (utente.get('findableByPhone') === false) {
      spenti += 1;

      continue;
    }

    if (scrivi) {
      lotto.set(db.collection('phoneIndex').doc(impronta(numero)), {
        userId: utente.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      nelLotto += 1;

      if (nelLotto >= 400) {
        await lotto.commit();
        lotto = db.batch();
        nelLotto = 0;
      }
    }

    scritti += 1;
  }

  if (scrivi && nelLotto > 0) {
    await lotto.commit();
  }

  console.log('');
  console.log('  Profili guardati      ', utenti.size);
  console.log('   con un numero buono  ', conNumero);
  console.log('   senza numero         ', saltati);
  console.log('   che non vogliono     ', spenti);
  console.log('  ' + '-'.repeat(34));
  console.log(scrivi ? '  Scritti nell\'indice  ' : '  Da scrivere          ', scritti);

  if (!scrivi) {
    console.log('');
    console.log('  Niente e\' stato toccato. Rilancia con --scrivi.');
  }

  console.log('');
}

riempi().catch((errore) => {
  console.error(errore.message);
  process.exit(1);
});
