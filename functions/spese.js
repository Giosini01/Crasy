'use strict';

/**
 * **Tutte le spese di CRASY, per filo e per segno.**
 *
 * I numeri di questa pagina sono di tre tipi, e chi legge deve sapere quale sta guardando:
 *
 * - **Veri.** Stripe, movimento per movimento. Il conto di Google, quando l'esportazione
 *   verso BigQuery e' attiva: e' l'unico modo che Google da' per leggere la sua fattura.
 * - **Stimati.** I consumi di Google vengono dal monitoraggio e sono veri, il listino anche.
 *   Il prodotto, tolte le quote gratis, e' una stima: la fattura puo' arrotondare, applicare
 *   sconti e aggiungere l'IVA. L'AI si conta sui gettoni dichiarati da OpenAI, in dollari.
 * - **Scritti a mano.** Quello che non ha nessun posto da cui leggerlo: l'abbonamento Apple,
 *   il dominio, il commercialista.
 *
 * Le chiamate a Google passano da `servizi`, cosi' le prove non toccano la rete.
 */
const crypto = require('node:crypto');
const admin = require('firebase-admin');

/** Il giorno in cui sono stati letti i prezzi qui sotto, dal listino di Google in euro. */
const LISTINO_DEL = '2026-11-03';

/**
 * Il cambio dello stesso listino, solo per sommare l'AI al resto. Sono centesimi: un cambio
 * vecchio di qualche mese non sposta niente, e il numero in dollari resta scritto accanto.
 */
const DOLLARO_IN_EURO = 0.8981;

/** Il dataset di BigQuery in cui Google scrive la fattura. Multi-regione, nell'UE. */
const DATASET = 'fatturazione';
const POSIZIONE_DATASET = 'EU';

const GIB = 1024 ** 3;
const GIORNO = 24 * 60 * 60 * 1000;

/** Quante righe di Stripe si mandano al pannello: le altre stanno sulla dashboard. */
const RIGHE_MASSIME = 500;

const OPERAZIONI_A = [
  'WriteObject',
  'ListObjects',
  'ComposeObject',
  'RewriteObject',
  'CopyObject',
  'UpdateObjectMetadata',
  'UpdateBucketMetadata',
  'ListBuckets',
  'CreateBucket',
];
const OPERAZIONI_B = ['ReadObject', 'GetObjectMetadata', 'GetBucketMetadata', 'GetIamPolicy'];

function unoFra(nomi) {
  return `metric.labels.method=one_of(${nomi.map((n) => `"${n}"`).join(',')})`;
}

/**
 * **Cosa si consuma e quanto costa.** `euro` e' il prezzo per unita', IVA esclusa, a Milano
 * dove ci sono database e funzioni.
 *
 * `gratis` dice come funziona la quota: `alGiorno` e `alMese` su quello che si conta, `spazio`
 * sui GiB tenuti. `byte` vuol dire che la metrica e' in byte e si conta in GiB.
 */
const VOCI_GOOGLE = [
  {
    gruppo: 'Database',
    nome: 'Letture',
    metrica: 'firestore.googleapis.com/document/read_count',
    unita: 'letture',
    gratis: { alGiorno: 50000 },
    gratisTesto: '50.000 al giorno',
    euro: 0.00000031,
    prezzoTesto: '€0,031 ogni 100.000',
  },
  {
    gruppo: 'Database',
    nome: 'Scritture',
    metrica: 'firestore.googleapis.com/document/write_count',
    unita: 'scritture',
    gratis: { alGiorno: 20000 },
    gratisTesto: '20.000 al giorno',
    euro: 0.00000093,
    prezzoTesto: '€0,093 ogni 100.000',
  },
  {
    gruppo: 'Database',
    nome: 'Cancellazioni',
    metrica: 'firestore.googleapis.com/document/delete_count',
    unita: 'cancellazioni',
    gratis: { alGiorno: 20000 },
    gratisTesto: '20.000 al giorno',
    euro: 0.00000011,
    prezzoTesto: '€0,011 ogni 100.000',
  },
  {
    gruppo: 'Database',
    nome: 'Spazio occupato',
    metrica: 'firestore.googleapis.com/storage/data_and_index_storage_bytes',
    unita: 'GiB in media',
    byte: true,
    media: true,
    gratis: { spazio: 1 },
    gratisTesto: '1 GiB',
    euro: 0.1562694,
    prezzoTesto: '€0,156 per GiB al mese',
  },
  {
    gruppo: 'Funzioni',
    nome: 'Chiamate',
    metrica: 'run.googleapis.com/request_count',
    unita: 'chiamate',
    gratis: { alMese: 2000000 },
    gratisTesto: '2 milioni al mese',
    euro: 0.00000036,
    prezzoTesto: '€0,36 ogni milione',
  },
  {
    gruppo: 'Funzioni',
    nome: 'Processore',
    metrica: 'run.googleapis.com/container/cpu/allocation_time',
    unita: 'secondi',
    gratis: { alMese: 180000 },
    gratisTesto: '180.000 secondi al mese',
    euro: 0.00002155,
    prezzoTesto: '€0,0000216 al secondo',
  },
  {
    gruppo: 'Funzioni',
    nome: 'Memoria',
    metrica: 'run.googleapis.com/container/memory/allocation_time',
    unita: 'GiB per secondo',
    gratis: { alMese: 360000 },
    gratisTesto: '360.000 GiB per secondo al mese',
    euro: 0.00000225,
    prezzoTesto: '€0,0000023 a GiB per secondo',
  },
  {
    gruppo: 'Foto e video',
    nome: 'Scaricati',
    metrica: 'storage.googleapis.com/network/sent_bytes_count',
    unita: 'GiB',
    byte: true,
    gratis: { alMese: 100 },
    gratisTesto: '100 GiB al mese',
    euro: 0.107772,
    prezzoTesto: '€0,108 per GiB',
  },
  {
    gruppo: 'Foto e video',
    nome: 'Spazio occupato',
    metrica: 'storage.googleapis.com/storage/total_bytes',
    unita: 'GiB in media',
    byte: true,
    media: true,
    gratis: { spazio: 5 },
    gratisTesto: '5 GiB',
    euro: 0.017962,
    prezzoTesto: '€0,018 per GiB al mese',
  },
  {
    gruppo: 'Foto e video',
    nome: 'Operazioni di scrittura',
    metrica: 'storage.googleapis.com/api/request_count',
    filtro: unoFra(OPERAZIONI_A),
    unita: 'operazioni',
    gratis: { alMese: 5000 },
    gratisTesto: '5.000 al mese',
    euro: 0.00000449,
    prezzoTesto: '€0,0045 ogni 1.000',
  },
  {
    gruppo: 'Foto e video',
    nome: 'Operazioni di lettura',
    metrica: 'storage.googleapis.com/api/request_count',
    filtro: unoFra(OPERAZIONI_B),
    unita: 'operazioni',
    gratis: { alMese: 50000 },
    gratisTesto: '50.000 al mese',
    euro: 0.00000036,
    prezzoTesto: '€0,36 ogni milione',
  },
  {
    gruppo: 'Sito',
    nome: 'Traffico',
    metrica: 'firebasehosting.googleapis.com/network/sent_bytes_count',
    unita: 'GiB',
    byte: true,
    gratis: { alGiorno: 0.3515625 },
    gratisTesto: '360 MiB al giorno',
    euro: 0.134715,
    prezzoTesto: '€0,135 per GiB',
  },
  {
    gruppo: 'Sito',
    nome: 'Spazio occupato',
    metrica: 'firebasehosting.googleapis.com/storage/total_bytes',
    unita: 'GiB in media',
    byte: true,
    media: true,
    gratis: { spazio: 10 },
    gratisTesto: '10 GiB',
    euro: 0.0233506,
    prezzoTesto: '€0,023 per GiB al mese',
  },
  {
    gruppo: 'SMS',
    nome: 'SMS di verifica del numero',
    metrica: 'firebaseauth.googleapis.com/phone_auth/phone_verification_count',
    unita: 'SMS',
    gratisTesto: 'nessuno',
    euro: 0.044905,
    prezzoTesto: '€0,045 a SMS verso l\'Italia',
  },
  {
    gruppo: 'Il resto di Google',
    nome: 'Log',
    metrica: 'logging.googleapis.com/billing/bytes_ingested',
    unita: 'GiB',
    byte: true,
    gratis: { alMese: 50 },
    gratisTesto: '50 GiB al mese',
    euro: 0.44905,
    prezzoTesto: '€0,449 per GiB',
  },
  {
    gruppo: 'Il resto di Google',
    nome: 'Immagini delle funzioni',
    metrica: 'artifactregistry.googleapis.com/repository/size',
    unita: 'GiB in media',
    byte: true,
    media: true,
    gratis: { spazio: 0.5 },
    gratisTesto: '0,5 GiB',
    euro: 0.08981,
    prezzoTesto: '€0,090 per GiB al mese',
  },
];

const servizi = {
  token: async () => (await admin.credential.applicationDefault().getAccessToken()).access_token,
  fetch: (...argomenti) => fetch(...argomenti),
};

function progetto() {
  if (process.env.GCLOUD_PROJECT) {
    return process.env.GCLOUD_PROJECT;
  }

  return JSON.parse(process.env.FIREBASE_CONFIG || '{}').projectId;
}

async function chiamaGoogle(url, corpo) {
  const risposta = await servizi.fetch(url, {
    method: corpo ? 'POST' : 'GET',
    headers: {
      authorization: `Bearer ${await servizi.token()}`,
      'content-type': 'application/json',
    },
    ...(corpo ? { body: JSON.stringify(corpo) } : {}),
  });
  const testo = await risposta.text();
  let dati = {};

  try {
    dati = testo ? JSON.parse(testo) : {};
  } catch (_errore) {
    dati = {};
  }

  if (!risposta.ok) {
    const errore = new Error(
      (dati.error && dati.error.message) || `Google ha risposto ${risposta.status}`
    );

    errore.status = risposta.status;

    throw errore;
  }

  return dati;
}

// ---------------------------------------------------------------------------
// I conti, che non toccano la rete
// ---------------------------------------------------------------------------

/**
 * **Quanto costa una voce, dati i suoi consumi giorno per giorno.**
 *
 * La quota al mese si toglie mese per mese, per intero, anche quando il periodo ne prende
 * solo un pezzo: e' come fa Google, che la conta dal primo del mese. Se il periodo
 * comincia a meta' mese la stima puo' venire un po' piu' bassa del vero.
 */
function costoDellaVoce(voce, punti) {
  const scala = voce.byte ? GIB : 1;
  const giorni = punti.map((punto) => ({ giorno: punto.giorno, valore: punto.valore / scala }));
  const somma = giorni.reduce((totale, punto) => totale + punto.valore, 0);
  const gratis = voce.gratis || {};
  let usato = somma;
  let aPagamento = somma;
  // Quanta quota gratis se ne va nel momento peggiore: e' da li' che arriva la prossima spesa.
  let quota = 0;

  if (voce.media) {
    // Lo spazio si paga al mese, un trentesimo al giorno.
    const sopra = gratis.spazio || 0;

    usato = giorni.length ? somma / giorni.length : 0;
    aPagamento = giorni.reduce(
      (totale, punto) => totale + Math.max(0, punto.valore - sopra) / 30,
      0
    );
    quota = sopra ? usato / sopra : 0;
  } else if (gratis.alGiorno !== undefined) {
    aPagamento = giorni.reduce(
      (totale, punto) => totale + Math.max(0, punto.valore - gratis.alGiorno),
      0
    );
    quota = Math.max(0, ...giorni.map((punto) => punto.valore)) / gratis.alGiorno;
  } else if (gratis.alMese !== undefined) {
    const mesi = new Map();

    for (const punto of giorni) {
      const mese = punto.giorno.slice(0, 7);

      mesi.set(mese, (mesi.get(mese) || 0) + punto.valore);
    }

    aPagamento = [...mesi.values()].reduce(
      (totale, valore) => totale + Math.max(0, valore - gratis.alMese),
      0
    );
    quota = Math.max(0, ...mesi.values()) / gratis.alMese;
  }

  return {
    gruppo: voce.gruppo,
    nome: voce.nome,
    unita: voce.unita,
    usato,
    aPagamento,
    gratis: voce.gratisTesto,
    prezzo: voce.prezzoTesto,
    costo: aPagamento * voce.euro,
    quotaPercento: Math.round(quota * 10000) / 100,
    // Giorno per giorno solo il database: per il resto basterebbe a riempire la pagina.
    ...(voce.gruppo === 'Database' ? { giorni } : {}),
  };
}

function nomeDellaCommissione(movimento, dettaglio) {
  if (dettaglio.type === 'tax') {
    return 'Tasse sulle commissioni di Stripe';
  }

  const tipo = movimento.type || '';

  if (movimento.reporting_category === 'dispute' || /dispute/.test(tipo)) {
    return 'Contestazioni';
  }

  if (tipo === 'charge' || tipo === 'payment') {
    const meta = (movimento.source && movimento.source.metadata) || {};

    if (meta.kind === 'addebitoSaldo') {
      return 'Commissioni sulle missioni pagate col saldo';
    }

    if (meta.kind === 'mancia') {
      return 'Commissioni sulle mance';
    }

    return 'Commissioni sui pagamenti con la carta';
  }

  if (/^payout/.test(tipo)) {
    return 'Commissioni sui bonifici verso la banca';
  }

  if (/^transfer/.test(tipo)) {
    return 'Commissioni sui premi girati ai vincitori';
  }

  if (/refund/.test(tipo)) {
    return 'Commissioni sui rimborsi';
  }

  return dettaglio.description || `Altro di Stripe (${tipo})`;
}

/** Una voce di Stripe che e' di per se' una spesa: le date stanno nella riga, non nel nome. */
function nomeDellExtra(movimento) {
  const descrizione = String(movimento.description || '')
    .replace(/\s*\([^)]*\)/g, '')
    .trim();

  return descrizione ? `Extra: ${descrizione}` : 'Extra di Stripe';
}

function eUnaSpesa(movimento) {
  return movimento.reporting_category === 'fee' || /(^|_)fee$/.test(movimento.type || '');
}

/**
 * **Ogni centesimo che Stripe si e' preso, voce per voce.** Le spese stanno in due posti: la
 * commissione scritta sopra ogni movimento, e i movimenti che sono essi stessi una spesa.
 */
function vociStripe(movimenti) {
  const voci = new Map();
  const righe = [];
  let suRimborsati = 0;

  const conta = (nome, cents, movimento, dettaglio) => {
    const voce = voci.get(nome) || { nome, quante: 0, cents: 0 };

    voce.quante += 1;
    voce.cents += cents;
    voci.set(nome, voce);
    righe.push({ quando: (movimento.created || 0) * 1000, voce: nome, dettaglio, cents });
  };

  for (const movimento of movimenti) {
    const fonte = movimento.source && typeof movimento.source === 'object' ? movimento.source : {};
    const dettaglio = fonte.description || movimento.description || '';
    const fee = movimento.fee || 0;

    if (fee) {
      const pezzi =
        movimento.fee_details && movimento.fee_details.length
          ? movimento.fee_details
          : [{ amount: fee }];

      for (const pezzo of pezzi) {
        conta(nomeDellaCommissione(movimento, pezzo), pezzo.amount || 0, movimento, dettaglio);
      }

      // Stripe non restituisce la sua parte quando si rimborsa: quei soldi li mette CRASY.
      if (fonte.amount_refunded && fonte.amount_refunded >= movimento.amount) {
        suRimborsati += fee;
      }
    }

    if (eUnaSpesa(movimento)) {
      conta(nomeDellExtra(movimento), -(movimento.amount || 0), movimento, movimento.description || '');
    }
  }

  righe.sort((a, b) => b.quando - a.quando);

  return {
    totale: [...voci.values()].reduce((somma, voce) => somma + voce.cents, 0),
    suRimborsati,
    voci: [...voci.values()].sort((a, b) => b.cents - a.cents),
    quanteRighe: righe.length,
    righe: righe.slice(0, RIGHE_MASSIME),
  };
}

/**
 * **Le spese scritte a mano, nel periodo.** Abbonamenti spalmati sui giorni: un mese vale 30
 * giorni e un anno 365. Una spesa una tantum conta solo se cade nel periodo.
 */
function fissePerIlPeriodo(voci, giorni, ora = Date.now()) {
  const soglia = new Date(ora - giorni * GIORNO).toISOString().slice(0, 10);
  const righe = (voci || []).map((voce) => {
    let cents = 0;

    if (voce.ogni === 'mese') {
      cents = Math.round((voce.cents * giorni) / 30);
    } else if (voce.ogni === 'anno') {
      cents = Math.round((voce.cents * giorni) / 365);
    } else if (voce.quando >= soglia) {
      cents = voce.cents;
    }

    return { ...voce, nelPeriodo: cents };
  });

  return {
    righe,
    totale: righe.reduce((somma, riga) => somma + riga.nelPeriodo, 0),
  };
}

/** Controlla quello che arriva dal pannello e costruisce la riga da salvare. */
function nuovaSpesaFissa({ nome, euro, ogni, quando }, ora = Date.now()) {
  const scritto = typeof nome === 'string' ? nome.trim() : '';
  const cents = Math.round(Number(euro) * 100);

  if (!scritto || scritto.length > 80) {
    throw new Error('Scrivi di che spesa si tratta, in meno di 80 lettere.');
  }

  if (!Number.isFinite(cents) || cents <= 0 || cents > 10000000) {
    throw new Error('Scrivi quanto costa, in euro.');
  }

  if (!['mese', 'anno', 'una'].includes(ogni)) {
    throw new Error('Scegli ogni quanto si paga.');
  }

  const giorno = /^\d{4}-\d{2}-\d{2}$/.test(quando || '')
    ? quando
    : new Date(ora).toISOString().slice(0, 10);

  return { id: crypto.randomUUID(), nome: scritto, cents, ogni, quando: giorno };
}

// ---------------------------------------------------------------------------
// I consumi di Google
// ---------------------------------------------------------------------------

/** I valori di una metrica, un punto al giorno, a giornate intere di Greenwich. */
async function puntiDellaMetrica(voce, giorni) {
  const fine = Math.ceil(Date.now() / GIORNO) * GIORNO;
  const inizio = fine - giorni * GIORNO;
  const parametri = new URLSearchParams({
    filter: `metric.type="${voce.metrica}"${voce.filtro ? ` AND ${voce.filtro}` : ''}`,
    'interval.startTime': new Date(inizio).toISOString(),
    'interval.endTime': new Date(fine).toISOString(),
    'aggregation.alignmentPeriod': '86400s',
    'aggregation.perSeriesAligner': voce.media ? 'ALIGN_MEAN' : 'ALIGN_SUM',
    'aggregation.crossSeriesReducer': 'REDUCE_SUM',
  });
  const risposta = await chiamaGoogle(
    `https://monitoring.googleapis.com/v3/projects/${progetto()}/timeSeries?${parametri}`
  );
  const perGiorno = new Map();

  for (const serie of risposta.timeSeries || []) {
    for (const punto of serie.points || []) {
      // Il punto dice quando finisce: un secondo prima e' il giorno a cui appartiene.
      const giorno = new Date(Date.parse(punto.interval.endTime) - 1000).toISOString().slice(0, 10);
      const valore = Number(punto.value.int64Value ?? punto.value.doubleValue ?? 0);

      perGiorno.set(giorno, (perGiorno.get(giorno) || 0) + valore);
    }
  }

  return [...perGiorno.entries()]
    .map(([giorno, valore]) => ({ giorno, valore }))
    .sort((a, b) => (a.giorno < b.giorno ? -1 : 1));
}

/** I segreti non hanno una metrica: si contano le versioni attive, che si pagano al mese. */
async function voceDeiSegreti(giorni) {
  const base = `https://secretmanager.googleapis.com/v1/projects/${progetto()}/secrets`;
  const { secrets = [] } = await chiamaGoogle(`${base}?pageSize=100`);
  const liste = await Promise.all(
    secrets.map((segreto) =>
      chiamaGoogle(`${base}/${segreto.name.split('/').pop()}/versions?pageSize=100`)
    )
  );
  const attive = liste
    .flatMap((lista) => lista.versions || [])
    .filter((versione) => versione.state === 'ENABLED').length;
  const aPagamento = Math.max(0, attive - 6);

  return {
    gruppo: 'Il resto di Google',
    nome: 'Segreti',
    unita: 'versioni attive',
    usato: attive,
    aPagamento,
    gratis: '6 versioni',
    prezzo: '€0,054 a versione al mese',
    costo: (aPagamento * 0.053886 * giorni) / 30,
  };
}

/** Le attivita' pianificate: 3 gratis per conto, le altre si pagano giorno per giorno. */
async function voceDellePianificate(giorni) {
  const { jobs = [] } = await chiamaGoogle(
    `https://cloudscheduler.googleapis.com/v1/projects/${progetto()}/locations/europe-west8/jobs?pageSize=200`
  );
  const aPagamento = Math.max(0, jobs.length - 3);

  return {
    gruppo: 'Il resto di Google',
    nome: 'Attività pianificate',
    unita: 'attività',
    usato: jobs.length,
    aPagamento,
    gratis: '3 attività',
    prezzo: '€0,09 ad attività al mese',
    costo: aPagamento * giorni * 0.0028971,
  };
}

/** I minuti per costruire le funzioni a ogni pubblicazione. */
async function voceDelleCostruzioni(giorni) {
  const limite = new Date(Date.now() - giorni * GIORNO).toISOString();
  let minuti = 0;

  for (const zona of ['europe-west8', 'global']) {
    let pagina = '';

    for (let giro = 0; giro < 10; giro += 1) {
      const parametri = new URLSearchParams({
        pageSize: '200',
        filter: `create_time>"${limite}"`,
        ...(pagina ? { pageToken: pagina } : {}),
      });
      const risposta = await chiamaGoogle(
        `https://cloudbuild.googleapis.com/v1/projects/${progetto()}/locations/${zona}/builds?${parametri}`
      );

      for (const costruzione of risposta.builds || []) {
        if (costruzione.startTime && costruzione.finishTime) {
          minuti += (Date.parse(costruzione.finishTime) - Date.parse(costruzione.startTime)) / 60000;
        }
      }

      pagina = risposta.nextPageToken || '';

      if (!pagina) {
        break;
      }
    }
  }

  const aPagamento = Math.max(0, minuti - (2500 * giorni) / 30);

  return {
    gruppo: 'Il resto di Google',
    nome: 'Costruzione delle funzioni',
    unita: 'minuti',
    usato: minuti,
    aPagamento,
    gratis: '2.500 minuti al mese',
    prezzo: '€0,0054 al minuto',
    costo: aPagamento * 0.0053886,
  };
}

/**
 * **I consumi di ogni servizio di Google, e quanto costerebbero.** Una voce che non si riesce
 * a leggere resta nell'elenco con la sua etichetta: farla sparire farebbe sembrare il totale
 * completo quando non lo e'.
 */
async function consumiGoogle({ giorni }) {
  const dalleMetriche = VOCI_GOOGLE.map((voce) => ({
    voce,
    lavoro: puntiDellaMetrica(voce, giorni).then((punti) => costoDellaVoce(voce, punti)),
  }));
  const contate = [
    { voce: { gruppo: 'Il resto di Google', nome: 'Segreti' }, lavoro: voceDeiSegreti(giorni) },
    { voce: { gruppo: 'Il resto di Google', nome: 'Attività pianificate' }, lavoro: voceDellePianificate(giorni) },
    { voce: { gruppo: 'Il resto di Google', nome: 'Costruzione delle funzioni' }, lavoro: voceDelleCostruzioni(giorni) },
  ];
  const tutte = [...dalleMetriche, ...contate];
  const esiti = await Promise.allSettled(tutte.map((riga) => riga.lavoro));
  const voci = esiti.map((esito, indice) =>
    esito.status === 'fulfilled'
      ? esito.value
      : {
          gruppo: tutte[indice].voce.gruppo,
          nome: tutte[indice].voce.nome,
          nonLetta: true,
          costo: 0,
        }
  );

  return {
    listino: LISTINO_DEL,
    costo: voci.reduce((somma, voce) => somma + voce.costo, 0),
    nonLette: voci.filter((voce) => voce.nonLetta).length,
    voci,
  };
}

// ---------------------------------------------------------------------------
// Il conto vero di Google
// ---------------------------------------------------------------------------

function sqlDelleVoci(daDove) {
  return `
    SELECT
      service.description AS servizio,
      sku.description AS voce,
      currency AS valuta,
      SUM(cost) AS costo,
      SUM(IFNULL((SELECT SUM(credito.amount) FROM UNNEST(credits) AS credito), 0)) AS crediti,
      SUM(usage.amount_in_pricing_units) AS quantita,
      ANY_VALUE(usage.pricing_unit) AS unita,
      UNIX_SECONDS(MAX(export_time)) AS aggiornato
    FROM ${daDove}
    WHERE usage_start_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL @giorni DAY)
      AND (project.id = @progetto OR project.id IS NULL)
    GROUP BY servizio, voce, valuta
    ORDER BY costo DESC`;
}

function sqlDeiGiorni(daDove) {
  return `
    SELECT
      CAST(DATE(usage_start_time) AS STRING) AS giorno,
      SUM(cost) + SUM(IFNULL((SELECT SUM(credito.amount) FROM UNNEST(credits) AS credito), 0)) AS netto
    FROM ${daDove}
    WHERE usage_start_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL @giorni DAY)
      AND (project.id = @progetto OR project.id IS NULL)
    GROUP BY giorno
    ORDER BY giorno DESC`;
}

async function interroga(sql, giorni) {
  const risposta = await chiamaGoogle(
    `https://bigquery.googleapis.com/bigquery/v2/projects/${progetto()}/queries`,
    {
      query: sql,
      useLegacySql: false,
      location: POSIZIONE_DATASET,
      timeoutMs: 30000,
      parameterMode: 'NAMED',
      queryParameters: [
        { name: 'giorni', parameterType: { type: 'INT64' }, parameterValue: { value: String(giorni) } },
        { name: 'progetto', parameterType: { type: 'STRING' }, parameterValue: { value: progetto() } },
      ],
    }
  );

  if (!risposta.jobComplete) {
    return null;
  }

  const campi = risposta.schema.fields.map((campo) => campo.name);

  return (risposta.rows || []).map((riga) =>
    Object.fromEntries(riga.f.map((cella, indice) => [campi[indice], cella.v]))
  );
}

/**
 * **La fattura vera, se Google la sta scrivendo.** Senza l'esportazione attiva non esiste
 * nessun altro modo di leggerla: lo si dice, con cosa manca.
 */
async function contoVero({ giorni }) {
  let tabelle;

  try {
    tabelle = await chiamaGoogle(
      `https://bigquery.googleapis.com/bigquery/v2/projects/${progetto()}/datasets/${DATASET}/tables?maxResults=100`
    );
  } catch (errore) {
    if (errore.status === 404) {
      return { attivo: false, perche: 'manca-il-dataset', dataset: DATASET };
    }

    throw errore;
  }

  const tabella = (tabelle.tables || [])
    .map((riga) => riga.tableReference.tableId)
    .find((nome) => nome.startsWith('gcp_billing_export_v1_'));

  if (!tabella) {
    return { attivo: false, perche: 'da-attivare', dataset: DATASET };
  }

  const daDove = `\`${progetto()}.${DATASET}.${tabella}\``;
  const [voci, giorniDelConto] = await Promise.all([
    interroga(sqlDelleVoci(daDove), giorni),
    interroga(sqlDeiGiorni(daDove), giorni),
  ]);

  if (!voci || !giorniDelConto) {
    return { attivo: true, inCorso: true, righe: [], giorni: [], netto: 0 };
  }

  const righe = voci.map((riga) => {
    const costo = Number(riga.costo) || 0;
    const crediti = Number(riga.crediti) || 0;

    return {
      servizio: riga.servizio,
      voce: riga.voce,
      valuta: riga.valuta,
      costo,
      crediti,
      netto: costo + crediti,
      quantita: Number(riga.quantita) || 0,
      unita: riga.unita || '',
    };
  });
  const aggiornato = Math.max(0, ...voci.map((riga) => Number(riga.aggiornato) || 0));

  return {
    attivo: true,
    valuta: righe.length ? righe[0].valuta : 'EUR',
    costo: righe.reduce((somma, riga) => somma + riga.costo, 0),
    crediti: righe.reduce((somma, riga) => somma + riga.crediti, 0),
    netto: righe.reduce((somma, riga) => somma + riga.netto, 0),
    aggiornato: aggiornato ? aggiornato * 1000 : null,
    righe,
    giorni: giorniDelConto.map((riga) => ({ giorno: riga.giorno, netto: Number(riga.netto) || 0 })),
  };
}

// ---------------------------------------------------------------------------
// Stripe
// ---------------------------------------------------------------------------

async function speseStripe({ giorni }, stripe) {
  const daQuando = Math.floor(Date.now() / 1000) - giorni * 24 * 60 * 60;
  const movimenti = [];

  for await (const movimento of stripe.balanceTransactions.list({
    limit: 100,
    created: { gte: daQuando },
    expand: ['data.source'],
  })) {
    movimenti.push(movimento);
  }

  return vociStripe(movimenti);
}

module.exports = {
  DATASET,
  DOLLARO_IN_EURO,
  LISTINO_DEL,
  POSIZIONE_DATASET,
  VOCI_GOOGLE,
  consumiGoogle,
  contoVero,
  costoDellaVoce,
  fissePerIlPeriodo,
  nuovaSpesaFissa,
  servizi,
  speseStripe,
  sqlDeiGiorni,
  sqlDelleVoci,
  vociStripe,
};
