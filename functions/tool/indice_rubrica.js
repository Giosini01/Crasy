/**
 * **Sposta i numeri di telefono al riparo, e riempie l'indice.**
 *
 * Fa due cose che vanno fatte insieme, una volta sola, dopo aver pubblicato le
 * funzioni e le regole.
 *
 * ## 1. Toglie i numeri dal profilo
 *
 * Il profilo lo legge chiunque abbia fatto l'accesso — deve, e' fatto per
 * essere guardato — e dentro c'era anche `phone`. Questo voleva dire che
 * chiunque avesse l'app poteva scaricarsi i numeri di tutti gli iscritti:
 * niente di ingegnoso, una lettura.
 *
 * Qui il numero passa in `users/{id}/private/contatto`, dove arrivano solo il
 * proprietario e il server, e nel profilo resta `phoneVerified: true` — il si'
 * o no che serve alle schermate per sapere se lasciar passare. Il campo
 * vecchio viene cancellato: finche' resta li', tutto il resto non serve a
 * niente.
 *
 * ## 2. Mette le impronte nell'indice
 *
 * L'indice si riempie da solo quando qualcuno cambia il proprio numero, ma chi
 * era gia' iscritto non cambia niente e resterebbe fuori per sempre: la
 * sezione dei suggeriti direbbe a tutti che non conoscono nessuno.
 *
 *     node tool/indice_rubrica.js --chiave C:/percorso/chiave.json --pepe <segreto>
 *     node tool/indice_rubrica.js --chiave ... --pepe ... --scrivi
 *
 * Senza `--scrivi` non tocca niente e dice solo cosa farebbe. E' il modo di
 * accorgersi di aver sbagliato il segreto **prima** di riempire l'indice di
 * impronte che non corrisponderanno mai a niente: il segreto e' lo stesso che
 * sta in Secret Manager sotto `PEPE_RUBRICA`, e se qui se ne usa un altro le
 * impronte scritte ora e quelle cercate dal server non si incontreranno mai.
 * Non esce nessun errore. Semplicemente, non si trova piu' nessuno.
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

async function sistema() {
  const utenti = await db.collection('users').get();

  const conto = {
    guardati: utenti.size,
    spostati: 0,
    giaAlSicuro: 0,
    senzaNumero: 0,
    spenti: 0,
    nellIndice: 0,
  };

  // Si scrive a blocchi da 150: ogni utente costa fino a tre scritture, e un
  // batch di Firestore ne regge cinquecento. Andare al limite significa che il
  // giorno in cui qualcuno aggiunge un'altra scrittura per utente tutto smette
  // di funzionare, senza che nessuno colleghi le due cose.
  let lotto = db.batch();
  let nelLotto = 0;

  async function forse() {
    if (nelLotto >= 150) {
      await lotto.commit();
      lotto = db.batch();
      nelLotto = 0;
    }
  }

  for (const utente of utenti.docs) {
    const contatto = db
      .collection('users')
      .doc(utente.id)
      .collection('private')
      .doc('contatto');

    const gia = await contatto.get();
    const nelProfilo = pulisci(utente.get('phone'));
    const nelPrivato = pulisci(gia.get('phone'));
    const numero = nelPrivato || nelProfilo;

    if (!numero) {
      conto.senzaNumero += 1;

      continue;
    }

    if (nelPrivato && !utente.get('phone')) {
      conto.giaAlSicuro += 1;
    } else {
      conto.spostati += 1;

      if (scrivi) {
        lotto.set(contatto, {
          phone: numero,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        lotto.update(utente.ref, {
          phoneVerified: true,
          phone: admin.firestore.FieldValue.delete(),
        });

        nelLotto += 2;
        await forse();
      }
    }

    // La preferenza puo' stare ancora sul profilo, dove l'aveva scritta la
    // prima versione dell'interruttore: si guardano tutti e due i posti, o
    // qualcuno che aveva detto di no si ritroverebbe di nuovo trovabile.
    const trovabile =
      gia.get('findableByPhone') !== false &&
      utente.get('findableByPhone') !== false;

    if (!trovabile) {
      conto.spenti += 1;

      continue;
    }

    conto.nellIndice += 1;

    if (scrivi) {
      lotto.set(db.collection('phoneIndex').doc(impronta(numero)), {
        userId: utente.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      nelLotto += 1;
      await forse();
    }
  }

  if (scrivi && nelLotto > 0) {
    await lotto.commit();
  }

  console.log('');
  console.log('  Profili guardati        ', conto.guardati);
  console.log('   senza numero           ', conto.senzaNumero);
  console.log('   gia\' al sicuro         ', conto.giaAlSicuro);
  console.log('  ' + '-'.repeat(36));
  console.log(
    scrivi ? '  Numeri spostati         ' : '  Numeri da spostare      ',
    conto.spostati,
  );
  console.log(
    scrivi ? '  Messi nell\'indice       ' : '  Da mettere nell\'indice  ',
    conto.nellIndice,
  );
  console.log('   non vogliono farsi trovare', conto.spenti);

  if (!scrivi) {
    console.log('');
    console.log('  Niente e\' stato toccato. Rilancia con --scrivi.');
  }

  console.log('');
}

sistema().catch((errore) => {
  console.error(errore.message);
  process.exit(1);
});
