/**
 * **Il menu delle missioni gia' scritte: dal file al database.**
 *
 * Quando si lancia una gara l'app consiglia dieci missioni, e altre dieci dopo
 * dieci minuti. Le legge da `missioniPronte`; quelle che ci stanno dentro le
 * decide `functions/dati/missioni_pronte.json`, e questo strumento mette il
 * database in pari col file. **Quello che non e' nel file sparisce**: e' cosi'
 * che una missione che non va bene si toglie, senza pubblicare un'app.
 *
 *     node tool/menu_missioni.js --chiave C:/percorso/chiave.json
 *     node tool/menu_missioni.js --chiave C:/percorso/chiave.json --scrivi
 *
 * Senza `--scrivi` dice solo cosa farebbe. Si puo' rilanciare quante volte si
 * vuole, e riscrive soltanto le righe cambiate: lo fa il deploy del server a ogni
 * giro (`.github/workflows/server-firebase.yml`).
 *
 * ## L'ordine e' la meta' del lavoro
 *
 * L'app legge dieci righe di fila a partire da un punto qualunque, quindi **dieci
 * righe di fila devono essere gia' un bel menu**: un po' di tutto, non dieci foto
 * dalla galleria. Le missioni di ogni tipo si distribuiscono a intervalli regolari
 * lungo la fila, in proporzione a quante sono, e dentro ogni tipo l'ordine dipende
 * dal titolo: rilanciare lo strumento non rimescola niente.
 */

'use strict';

const CATEGORIE = ['hot', 'verita', 'coraggio', 'abilita', 'pazza', 'ricordo', 'halloween'];
const MEDIA = ['photo', 'video'];
const PROVENIENZE = ['instant', 'archive'];

/** Gli stessi limiti della prova sull'app: `missione_pronta_test.dart`. */
const TITOLO_MASSIMO = 44;
const CONSEGNA_MASSIMA = 280;

/** Un numero sempre uguale a partire dallo stesso testo. */
function impronta(testo) {
  let valore = 0x811c9dc5;

  for (let i = 0; i < testo.length; i += 1) {
    valore = Math.imul(valore ^ testo.charCodeAt(i), 0x01000193) >>> 0;
  }

  return valore;
}

/** Il nome del documento: si legge, e non cambia finche' non cambia il titolo. */
function nomeDi(titolo) {
  return titolo
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/** Quello che non va nel file: una riga per problema. */
function problemiDi(catalogo) {
  const problemi = [];
  const nomi = new Set();

  if (!Array.isArray(catalogo) || catalogo.length === 0) {
    return ['Il catalogo e\' vuoto: non si cancella tutto il menu per un file sbagliato.'];
  }

  for (const riga of catalogo) {
    const titolo = String(riga.titolo || '');
    const consegna = String(riga.consegna || '');

    if (titolo.length < 3 || titolo.length > TITOLO_MASSIMO) {
      problemi.push(`Titolo lungo ${titolo.length}: ${titolo}`);
    }

    if (!consegna || consegna.length > CONSEGNA_MASSIMA) {
      problemi.push(`Consegna lunga ${consegna.length}: ${titolo}`);
    }

    if (!CATEGORIE.includes(riga.categoria)) {
      problemi.push(`Categoria sconosciuta "${riga.categoria}": ${titolo}`);
    }

    if (!MEDIA.includes(riga.media)) {
      problemi.push(`Media sconosciuto "${riga.media}": ${titolo}`);
    }

    if (riga.source !== undefined && !PROVENIENZE.includes(riga.source)) {
      problemi.push(`Provenienza sconosciuta "${riga.source}": ${titolo}`);
    }

    if (nomi.has(nomeDi(titolo))) {
      problemi.push(`Due missioni con lo stesso titolo: ${titolo}`);
    }

    nomi.add(nomeDi(titolo));
  }

  return problemi;
}

/**
 * Il menu come deve stare nel database: `{ nome: documento }`.
 *
 * Ogni missione prende un punto lungo la fila, da 0 a 1, in base al suo posto
 * dentro il suo tipo: i tipi piccoli hanno i punti piu' radi, ma arrivano fino in
 * fondo come quelli grandi. Poi si ordina per punto, e `ordine` e' la posizione.
 */
function preparaIlMenu(catalogo) {
  const conPunto = [];

  for (const categoria of CATEGORIE) {
    const delTipo = catalogo
      .filter((riga) => riga.categoria === categoria)
      .sort((a, b) => impronta(a.titolo) - impronta(b.titolo) || a.titolo.localeCompare(b.titolo));

    delTipo.forEach((riga, i) => {
      conPunto.push({ riga, punto: (i + 0.5) / delTipo.length });
    });
  }

  conPunto.sort(
    (a, b) => a.punto - b.punto || impronta(a.riga.titolo) - impronta(b.riga.titolo),
  );

  const menu = {};

  conPunto.forEach(({ riga }, ordine) => {
    menu[nomeDi(riga.titolo)] = {
      titolo: riga.titolo,
      consegna: riga.consegna,
      categoria: riga.categoria,
      mediaKind: riga.media,
      source: riga.source || 'instant',
      ordine,
    };
  });

  return menu;
}

/** Se un documento e' gia' uguale a come dovrebbe essere. */
function uguale(attuale, voluto) {
  return Object.keys(voluto).every((campo) => attuale[campo] === voluto[campo]);
}

/** Mette il database in pari col menu, e dice cos'ha fatto. */
async function mettiInPari(db, menu, scrivi) {
  const raccolta = db.collection('missioniPronte');
  const presenti = await raccolta.get();
  const attuali = new Map(presenti.docs.map((doc) => [doc.id, doc.data()]));

  const daScrivere = Object.keys(menu).filter(
    (nome) => !attuali.has(nome) || !uguale(attuali.get(nome), menu[nome]),
  );
  const daTogliere = [...attuali.keys()].filter((nome) => !(nome in menu));

  if (scrivi) {
    const operazioni = [
      ...daScrivere.map((nome) => (lotto) => lotto.set(raccolta.doc(nome), menu[nome])),
      ...daTogliere.map((nome) => (lotto) => lotto.delete(raccolta.doc(nome))),
    ];

    // A blocchi di quattrocento: il massimo che un lotto regge e' cinquecento.
    for (let i = 0; i < operazioni.length; i += 400) {
      const lotto = db.batch();

      operazioni.slice(i, i + 400).forEach((operazione) => operazione(lotto));

      await lotto.commit();
    }
  }

  return { scritte: daScrivere.length, tolte: daTogliere.length, totale: Object.keys(menu).length };
}

async function main() {
  const argomenti = process.argv.slice(2);
  const posto = argomenti.indexOf('--chiave');
  const chiave = posto >= 0 ? argomenti[posto + 1] : null;
  const scrivi = argomenti.includes('--scrivi');

  if (!chiave) {
    console.error('Serve --chiave <file json>.');
    process.exit(1);
  }

  const catalogo = require('../dati/missioni_pronte.json');
  const problemi = problemiDi(catalogo);

  if (problemi.length > 0) {
    problemi.forEach((problema) => console.error(problema));
    process.exit(1);
  }

  const admin = require('firebase-admin');

  admin.initializeApp({ credential: admin.credential.cert(require(chiave)) });

  const esito = await mettiInPari(admin.firestore(), preparaIlMenu(catalogo), scrivi);

  console.log(
    `Menu delle missioni: ${esito.totale} in tutto, ${esito.scritte} da scrivere, ${esito.tolte} da togliere.`,
  );

  if (!scrivi) {
    console.log("Niente e' stato toccato. Rilancia con --scrivi.");
  }
}

if (require.main === module) {
  main().catch((errore) => {
    console.error(errore.message);
    process.exit(1);
  });
}

module.exports = { preparaIlMenu, problemiDi, mettiInPari, nomeDi };
