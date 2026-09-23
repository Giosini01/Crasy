/**
 * **L'estratto dei movimenti, per chi tiene i conti.**
 *
 * Il commercialista non deve entrare in Stripe ne' in Firestore: deve avere
 * davanti un elenco di righe con delle date e degli importi, e sapere quali di
 * quegli importi sono ricavi e quali no. E' tutta qui la difficolta' di CRASY
 * dal lato contabile — sul conto arrivano soldi che **non sono ricavi**, e
 * distinguerli e' il lavoro.
 *
 * ## La distinzione che conta
 *
 * Quando qualcuno lancia una missione da 5 euro, sul conto arrivano 5,33. Di
 * quei soldi:
 *
 * - **4,50 sono del vincitore**, custoditi per conto di chi li ha messi. Non
 *   sono ricavo: entrano e usciranno.
 * - **0,50 sono il ricavo di CRASY**, il dieci per cento del premio.
 * - **0,33 sono spese di Stripe**, che escono subito e sono un costo.
 *
 * **La percentuale non si aggiunge al premio: si toglie da dentro.** Chi lancia
 * paga il premio piu' le spese di incasso; il vincitore riceve il premio meno
 * la percentuale. E' la differenza fra dire "cinque euro piu' commissioni" e
 * "cinque euro in palio", e la seconda e' quella che si legge nell'app.
 *
 * Questo file scrive tutte e tre le colonne, riga per riga, cosi' che nessuno
 * debba ricostruirle a mano — ed e' proprio la ricostruzione a mano il punto in
 * cui si sbaglia e si finisce per pagare le tasse su soldi di altri.
 *
 * ## Cosa produce
 *
 * Due file nella cartella da cui lo lanci: `movimenti.csv` con una riga per
 * operazione, e un riepilogo a schermo. Il CSV si apre con Excel.
 *
 *     node tool/contabilita.js --chiave C:/percorso/chiave.json --stripe rk_live_...
 *     node tool/contabilita.js --chiave ... --stripe ... --dal 2026-01-01
 */

'use strict';

const fs = require('fs');
const admin = require('firebase-admin');
const Stripe = require('stripe');

const argomenti = process.argv.slice(2);

function opzione(nome) {
  const posto = argomenti.indexOf(nome);

  return posto >= 0 ? argomenti[posto + 1] : null;
}

const chiave = opzione('--chiave');
const chiaveStripe = opzione('--stripe');
const dal = opzione('--dal');

if (!chiave || !chiaveStripe) {
  console.error('Servono --chiave <file json> e --stripe <chiave di Stripe>.');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(chiave)) });

const db = admin.firestore();
const stripe = new Stripe(chiaveStripe);

const daQuando = dal ? Math.floor(new Date(dal).getTime() / 1000) : undefined;

/** In euro con la virgola, come si scrive in Italia. */
function euro(centesimi) {
  return (centesimi / 100).toFixed(2).replace('.', ',');
}

function giorno(secondi) {
  return new Date(secondi * 1000).toLocaleDateString('it-IT');
}

/** Una cella di CSV: le virgolette raddoppiate, il resto fra virgolette. */
function cella(valore) {
  return `"${String(valore == null ? '' : valore).replace(/"/g, '""')}"`;
}

async function estrai() {
  const righe = [];
  const totali = {
    incassato: 0,
    premi: 0,
    ricavo: 0,
    speseStripe: 0,
    rimborsato: 0,
  };

  // **Si parte dal registro di Stripe, non dai pagamenti.** Il registro ha
  // dentro anche le commissioni che Stripe trattiene su ogni riga, ed e'
  // l'unico posto in cui quel numero e' quello vero invece che calcolato.
  const movimenti = await stripe.balanceTransactions.list({
    limit: 100,
    ...(daQuando ? { created: { gte: daQuando } } : {}),
    expand: ['data.source'],
  });

  for (const movimento of movimenti.data) {
    const fonte = movimento.source;
    const challengeId =
      (fonte && fonte.metadata && fonte.metadata.challengeId) || '';

    let titolo = '';

    // **Il premio si legge dal pagamento, non dalla gara.**
    //
    // La gara puo' non esserci piu' — cancellata, o ripulita dopo mesi — e
    // allora quell'incasso diventerebbe un numero che non si sa piu' dividere
    // fra soldi di altri e compenso di CRASY. Nel pagamento invece resta
    // scritto per sempre. Dal database si prende solo il titolo, che serve a
    // leggere l'elenco e non a fare i conti.
    let premio = Number((fonte && fonte.metadata && fonte.metadata.prizeCents) || 0);

    if (challengeId) {
      const gara = await db.collection('challenges').doc(challengeId).get();

      if (gara.exists) {
        titolo = gara.get('title') || '';

        if (!premio) {
          premio = gara.get('prizeCents') || 0;
        }
      } else {
        titolo = '(missione cancellata)';
      }
    }

    if (movimento.type === 'charge' || movimento.type === 'payment') {
      // **Quanto e' tornato indietro di questo incasso.**
      //
      // Senza guardarlo, un pagamento rimborsato risultava un ricavo: il
      // conto diceva "un euro guadagnato" su una missione cancellata in cui
      // CRASY ci ha invece rimesso le spese. E' l'errore che in contabilita'
      // fa pagare le tasse su soldi mai guadagnati.
      const reso = (fonte && fonte.amount_refunded) || 0;
      const netto = movimento.amount - reso;

      // **Quello che e' di altri e' il premio meno la percentuale**, cioe'
      // esattamente la cifra che uscira' verso il vincitore. Il dieci per
      // cento non viene aggiunto sopra il premio: viene trattenuto da dentro,
      // quindi contarlo come soldi altrui vorrebbe dire non contare mai il
      // ricavo di CRASY.
      const perIlVincitore = premio - Math.floor(premio / 10);

      // Se il rimborso ha gia' restituito tutto, non resta custodito niente.
      const premioNetto = Math.max(0, Math.min(perIlVincitore, netto));

      // Le spese di Stripe restano a carico anche sui rimborsi: e' il motivo
      // per cui una missione cancellata lascia CRASY sotto di qualche
      // centesimo invece che in pari.
      const ricavo = netto - premioNetto - movimento.fee;

      totali.incassato += movimento.amount;
      totali.premi += premioNetto;
      totali.ricavo += ricavo;
      totali.speseStripe += movimento.fee;

      righe.push([
        giorno(movimento.created),
        reso ? 'incasso (rimborsato)' : 'incasso',
        titolo,
        euro(movimento.amount),
        euro(premioNetto),
        euro(ricavo),
        euro(movimento.fee),
        movimento.id,
      ]);

      continue;
    }

    if (movimento.type === 'refund' || movimento.type === 'payment_refund') {
      totali.rimborsato += Math.abs(movimento.amount);

      righe.push([
        giorno(movimento.created),
        'rimborso',
        titolo,
        euro(movimento.amount),
        '',
        '',
        euro(movimento.fee),
        movimento.id,
      ]);

      continue;
    }

    righe.push([
      giorno(movimento.created),
      movimento.type,
      titolo,
      euro(movimento.amount),
      '',
      '',
      euro(movimento.fee),
      movimento.id,
    ]);
  }

  // **I premi usciti davvero**, cioe' i bonifici fatti a mano ai vincitori.
  // Non stanno su Stripe — li fa una persona dal conto — quindi si leggono da
  // dove sono segnati.
  const pagati = await db
    .collection('payoutRequests')
    .where('status', '==', 'paid')
    .get();

  let usciti = 0;

  for (const richiesta of pagati.docs) {
    const quando = richiesta.get('decidedAt');
    usciti += richiesta.get('amountCents') || 0;

    righe.push([
      quando ? giorno(quando.seconds) : '',
      'premio pagato',
      `${richiesta.get('firstName')} ${richiesta.get('lastName')}`,
      euro(-(richiesta.get('amountCents') || 0)),
      '',
      '',
      '',
      richiesta.get('iban') || '',
    ]);
  }

  const intestazione = [
    'data',
    'tipo',
    'missione o beneficiario',
    'importo',
    'di cui premio (non e ricavo)',
    'ricavo CRASY',
    'spese Stripe',
    'riferimento',
  ];

  const csv = [intestazione, ...righe]
    .map((riga) => riga.map(cella).join(';'))
    .join('\n');

  fs.writeFileSync('movimenti.csv', '\ufeff' + csv, 'utf8');

  console.log('');
  console.log('  RIEPILOGO' + (dal ? ` dal ${dal}` : ''));
  console.log('  ' + '-'.repeat(46));
  console.log('  Incassato in tutto      ', euro(totali.incassato), '€');
  console.log('   di cui premi altrui    ', euro(totali.premi), '€');
  console.log('   di cui spese Stripe    ', euro(totali.speseStripe), '€');
  console.log('  ' + '-'.repeat(46));
  console.log('  RICAVO CRASY            ', euro(totali.ricavo), '€',
    totali.ricavo < 0 ? '  (in perdita: rimborsi)' : '');
  console.log('  ' + '-'.repeat(46));
  console.log('  Rimborsato              ', euro(totali.rimborsato), '€');
  console.log('  Premi pagati ai vincitori', euro(usciti), '€');
  console.log('');
  console.log(`  Scritte ${righe.length} righe in movimenti.csv`);
  console.log('');
  console.log('  Il ricavo da fatturare e\' solo la riga RICAVO CRASY:');
  console.log('  i premi entrano e escono, non sono soldi di CRASY.');
  console.log('');
}

estrai().catch((errore) => {
  console.error(errore.message);
  process.exit(1);
});
