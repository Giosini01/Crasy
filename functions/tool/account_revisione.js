/**
 * **L'account che Apple usa per guardare dentro l'app.**
 *
 * Alla revisione serve poter entrare, e un revisore che non entra boccia senza
 * nemmeno guardare: e' il motivo per cui questo account esiste. Non e' un
 * ingresso di servizio — e' un utente normale, che passa dalla stessa porta di
 * tutti gli altri. L'app non sa che esiste e non ha nessuna riga scritta per
 * lui.
 *
 *     node tool/account_revisione.js --chiave C:/percorso/chiave.json
 *     node tool/account_revisione.js --chiave ... --scrivi
 *
 * Senza `--scrivi` dice solo cosa farebbe.
 *
 * ## I muri che deve attraversare
 *
 * Fra l'accesso e la prima schermata ci sono sei controlli, e ognuno di loro
 * rimanda indietro chi non lo soddisfa. Un account creato a meta' non
 * fallisce: gira in tondo su una schermata di iscrizione, e il revisore scrive
 * "non riesco ad accedere". Quindi qui si valorizzano tutti e sei:
 *
 * 1. **email confermata** — altrimenti si resta sulla schermata della conferma;
 * 2. **profilo creato e onboarding fatto**;
 * 3. **data di nascita**, maggiorenne: su CRASY girano soldi veri;
 * 4. **telefono verificato** — vedi sotto, ed e' il punto delicato;
 * 5. **documenti accettati**, nella versione corrente;
 * 6. **giro di presentazione, permessi e rubrica** gia' visti, cosi' si
 *    atterra direttamente sulle gare.
 *
 * ## Il telefono: nessun numero inventato
 *
 * Il muro numero quattro guarda **`phoneVerified`**, un si' o no scritto nel
 * profilo. Il numero vero non sta li': vive in `users/{id}/private/contatto`,
 * lo legge solo il proprietario, e serve a **una cosa sola** — l'indice con cui
 * si trovano gli amici dalla rubrica.
 *
 * Quindi qui si scrive `phoneVerified: true` e **nessun numero**. L'account
 * entra, e non finisce nell'indice dei numeri: non si fa trovare da nessuno e
 * non trova nessuno. Inventare un numero vorrebbe dire scriverne uno che
 * appartiene a una persona vera — i numeri italiani sono tutti di qualcuno — e
 * quella persona comparirebbe fra i contatti di chi ce l'ha in rubrica.
 */

'use strict';

const admin = require('firebase-admin');

const argomenti = process.argv.slice(2);

function opzione(nome) {
  const posto = argomenti.indexOf(nome);

  return posto >= 0 ? argomenti[posto + 1] : null;
}

const chiave = opzione('--chiave');
const scrivi = argomenti.includes('--scrivi');

if (!chiave) {
  console.error('Serve --chiave <file json>.');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(chiave)) });

const EMAIL = 'appreview@crasy.it';
const PASSWORD = 'CrasyReview2026!';
const NOME = 'appreview';

/** La versione dei documenti che l'app pretende. Deve stare in pari con
 *  `LegalTexts.version` dentro l'app: se divergono, l'account si ritrova
 *  davanti la schermata dei consensi a ogni avvio. */
const VERSIONE_LEGALE = '0.1-bozza';

const db = admin.firestore();

async function prepara() {
  let utente;

  try {
    utente = await admin.auth().getUserByEmail(EMAIL);
    console.log(`  C'e' gia': ${utente.uid}`);
  } catch (errore) {
    if (errore.code !== 'auth/user-not-found') {
      throw errore;
    }

    console.log("  Non c'e' ancora: va creato.");
  }

  if (!scrivi) {
    console.log('');
    console.log("  Niente e' stato toccato. Rilancia con --scrivi.");
    console.log('');

    return;
  }

  if (!utente) {
    utente = await admin.auth().createUser({
      email: EMAIL,
      password: PASSWORD,
      // **Confermata d'ufficio.** La conferma serve a dimostrare che
      // l'indirizzo esiste e risponde; questa casella non la legge nessuno, e
      // un revisore che aspetta un'email che non arrivera' mai e' un revisore
      // che chiude l'app.
      emailVerified: true,
      displayName: NOME,
    });

    console.log(`  Creato: ${utente.uid}`);
  } else {
    // Se c'era gia', la password torna quella scritta qui: e' l'unica che
    // Apple conosce, e un account a cui non si entra non serve a niente.
    await admin.auth().updateUser(utente.uid, {
      password: PASSWORD,
      emailVerified: true,
    });

    console.log('  Password e conferma rimesse a posto.');
  }

  const profilo = db.collection('users').doc(utente.uid);
  const esistente = await profilo.get();

  const dati = {
    username: NOME,
    bio: 'Account di prova per la revisione.',
    city: '',
    // Trent'anni tondi: maggiorenne con larghezza, cosi' il controllo
    // sull'eta' non dipende da quando si rilancia questo strumento.
    birthDate: admin.firestore.Timestamp.fromDate(
      new Date(Date.UTC(1996, 0, 1)),
    ),
    onboardingCompleted: true,
    // Vedi il blocco in cima: il si' senza il numero.
    phoneVerified: true,
    // Fuori dall'indice della rubrica, e scritto a chiare lettere invece che
    // lasciato al ripiego — che e' "si'".
    findableByPhone: false,
    legalVersion: VERSIONE_LEGALE,
    legalAcceptedAt: admin.firestore.FieldValue.serverTimestamp(),
    marketingConsent: false,
    profilingConsent: false,
    tutorialSeen: true,
    permissionsSeen: true,
    contactsPromptSeen: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (!esistente.exists) {
    dati.createdAt = admin.firestore.FieldValue.serverTimestamp();
  }

  await profilo.set(dati, { merge: true });

  console.log('  Profilo scritto.');

  // **La verifica, e non e' una formalita'.** Quello che conta non e' che la
  // scrittura sia riuscita: e' che ognuno dei sei muri trovi il suo campo
  // valorizzato. Qui si rilegge il documento appena scritto e si controlla
  // uno per uno, perche' un campo dimenticato non da' nessun errore — da' un
  // revisore che gira in tondo su una schermata di iscrizione.
  const riletto = await profilo.get();
  const auth = await admin.auth().getUser(utente.uid);

  const muri = [
    ['email confermata', auth.emailVerified === true],
    ['email giusta', auth.email === EMAIL],
    ['onboarding fatto', riletto.get('onboardingCompleted') === true],
    ['data di nascita', riletto.get('birthDate') != null],
    ['telefono verificato', riletto.get('phoneVerified') === true],
    ['documenti accettati', riletto.get('legalVersion') === VERSIONE_LEGALE],
    ['presentazione vista', riletto.get('tutorialSeen') === true],
    ['permessi visti', riletto.get('permissionsSeen') === true],
    ['rubrica saltata', riletto.get('contactsPromptSeen') === true],
    ['nessun numero scritto', riletto.get('phone') === undefined],
  ];

  console.log('');

  for (const [cosa, bene] of muri) {
    console.log(`  ${bene ? 'ok ' : 'NO '} ${cosa}`);
  }

  const contatto = await profilo.collection('private').doc('contatto').get();

  console.log(
    `  ${contatto.exists ? 'NO ' : 'ok '} nessun contatto privato salvato`,
  );

  const tutto = muri.every(([, bene]) => bene) && !contatto.exists;

  console.log('');
  console.log(
    tutto
      ? "  L'account entra e atterra sulle gare."
      : '  Qualcosa manca: le righe con NO qui sopra.',
  );
  console.log('');
}

prepara().catch((errore) => {
  console.error(errore.message);
  process.exit(1);
});
