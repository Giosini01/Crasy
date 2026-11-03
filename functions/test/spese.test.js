'use strict';

/**
 * **I conti delle spese.** Si lanciano con `npm test`, senza credenziali e senza rete: le
 * risposte di Google e di Stripe si scrivono qui.
 */
const test = require('node:test');
const assert = require('node:assert/strict');

process.env.GCLOUD_PROJECT = 'demo-crasy';

const spese = require('../spese');

const GIB = 1024 ** 3;

function voce(nome, gruppo = 'Database') {
  return spese.VOCI_GOOGLE.find((v) => v.nome === nome && v.gruppo === gruppo);
}

function vicino(a, b) {
  assert.ok(Math.abs(a - b) < 1e-9, `${a} non e' ${b}`);
}

test('la quota al giorno si toglie giorno per giorno', () => {
  const conto = spese.costoDellaVoce(voce('Letture'), [
    { giorno: '2026-11-01', valore: 96155 },
    { giorno: '2026-11-02', valore: 10000 },
  ]);

  assert.equal(conto.usato, 106155);
  assert.equal(conto.aPagamento, 46155);
  vicino(conto.costo, 46155 * 0.00000031);
  assert.equal(conto.giorni.length, 2);
  assert.equal(conto.quotaPercento, 192.31);
});

test('la quota al mese si toglie mese per mese', () => {
  const conto = spese.costoDellaVoce(voce('Scaricati', 'Foto e video'), [
    { giorno: '2026-10-31', valore: 120 * GIB },
    { giorno: '2026-11-01', valore: 10 * GIB },
  ]);

  assert.equal(conto.usato, 130);
  assert.equal(conto.aPagamento, 20);
  vicino(conto.costo, 20 * 0.107772);
  assert.equal(conto.quotaPercento, 120);
  assert.equal(conto.giorni, undefined);
});

test('lo spazio si paga al mese, un trentesimo al giorno', () => {
  const trentaGiorni = Array.from({ length: 30 }, (_, i) => ({
    giorno: `2026-11-${String(i + 1).padStart(2, '0')}`,
    valore: 3 * GIB,
  }));
  const conto = spese.costoDellaVoce(voce('Spazio occupato'), trentaGiorni);

  assert.equal(conto.usato, 3);
  vicino(conto.aPagamento, 2);
  vicino(conto.costo, 2 * 0.1562694);
  assert.equal(conto.quotaPercento, 300);
});

test('senza quota si paga tutto, e senza consumi non si paga niente', () => {
  const sms = voce('SMS di verifica del numero', 'SMS');

  vicino(spese.costoDellaVoce(sms, [{ giorno: '2026-11-01', valore: 38 }]).costo, 38 * 0.044905);
  assert.equal(spese.costoDellaVoce(sms, []).costo, 0);
  assert.equal(spese.costoDellaVoce(voce('Spazio occupato'), []).usato, 0);
});

test('stripe si divide voce per voce, e il totale torna', () => {
  const conti = spese.vociStripe([
    {
      type: 'charge',
      amount: 234,
      fee: 29,
      created: 300,
      fee_details: [{ type: 'stripe_fee', amount: 29 }],
      source: { description: 'Premio: la foto', metadata: { challengeId: 'g1' } },
    },
    {
      type: 'charge',
      amount: 500,
      fee: 33,
      created: 200,
      source: { description: 'Mancia', metadata: { kind: 'mancia' }, amount_refunded: 500 },
    },
    {
      type: 'charge',
      amount: 100,
      fee: 2,
      created: 100,
      source: { metadata: { kind: 'addebitoSaldo' }, amount_refunded: 50 },
    },
    {
      type: 'stripe_fee',
      amount: -200,
      fee: 0,
      created: 400,
      reporting_category: 'fee',
      description: 'Connect (2026-10-01 - 2026-10-31): Active Account Billing',
    },
    {
      type: 'stripe_fee',
      amount: -100,
      fee: 0,
      created: 500,
      reporting_category: 'fee',
      description: 'Connect (2026-11-01 - 2026-11-30): Active Account Billing',
    },
    { type: 'payout', amount: -500, fee: 25, created: 50, reporting_category: 'payout' },
    { type: 'refund', amount: -300, fee: 0, created: 60, reporting_category: 'refund' },
    { type: 'transfer', amount: -400, fee: 0, created: 70, reporting_category: 'transfer' },
    {
      type: 'adjustment',
      amount: -500,
      fee: 1500,
      created: 80,
      reporting_category: 'dispute',
      fee_details: [
        { type: 'stripe_fee', amount: 1400 },
        { type: 'tax', amount: 100 },
      ],
    },
  ]);
  const quanto = (nome) => conti.voci.find((v) => v.nome === nome);

  assert.equal(conti.totale, 29 + 33 + 2 + 200 + 100 + 25 + 1400 + 100);
  assert.equal(quanto('Commissioni sui pagamenti con la carta').cents, 29);
  assert.equal(quanto('Commissioni sulle mance').cents, 33);
  assert.equal(quanto('Commissioni sulle missioni pagate col saldo').cents, 2);
  assert.equal(quanto('Commissioni sui bonifici verso la banca').cents, 25);
  assert.equal(quanto('Contestazioni').cents, 1400);
  assert.equal(quanto('Tasse sulle commissioni di Stripe').cents, 100);

  // Lo stesso extra di due mesi diversi e' una voce sola, con due righe.
  assert.equal(quanto('Extra: Connect: Active Account Billing').cents, 300);
  assert.equal(quanto('Extra: Connect: Active Account Billing').quante, 2);

  // Solo i rimborsati per intero: la commissione su quelli parziali resta guadagnata.
  assert.equal(conti.suRimborsati, 33);

  assert.equal(conti.quanteRighe, 8);
  assert.equal(conti.righe[0].quando, 500000);
  assert.equal(conti.voci[0].nome, 'Contestazioni');
});

test('le spese fisse si spalmano sul periodo, e una tantum conta se ci cade dentro', () => {
  const ora = Date.parse('2026-11-03T12:00:00Z');
  const conti = spese.fissePerIlPeriodo(
    [
      { id: 'a', nome: 'Email', cents: 3000, ogni: 'mese', quando: '2026-01-01' },
      { id: 'b', nome: 'Apple', cents: 36500, ogni: 'anno', quando: '2026-01-01' },
      { id: 'c', nome: 'Logo', cents: 5000, ogni: 'una', quando: '2026-10-20' },
      { id: 'd', nome: 'Vecchia', cents: 7000, ogni: 'una', quando: '2026-01-01' },
    ],
    30,
    ora
  );

  assert.deepEqual(
    conti.righe.map((r) => r.nelPeriodo),
    [3000, 3000, 5000, 0]
  );
  assert.equal(conti.totale, 11000);
  assert.equal(spese.fissePerIlPeriodo(undefined, 30, ora).totale, 0);
});

test('una spesa scritta male non entra', () => {
  const buona = spese.nuovaSpesaFissa({ nome: ' Apple ', euro: '99,5'.replace(',', '.'), ogni: 'anno' });

  assert.equal(buona.nome, 'Apple');
  assert.equal(buona.cents, 9950);
  assert.ok(buona.id);

  for (const sbagliata of [
    { nome: '', euro: 10, ogni: 'mese' },
    { nome: 'x'.repeat(81), euro: 10, ogni: 'mese' },
    { nome: 'Niente', euro: 0, ogni: 'mese' },
    { nome: 'Niente', euro: 'tanto', ogni: 'mese' },
    { nome: 'Niente', euro: 10, ogni: 'settimana' },
  ]) {
    assert.throws(() => spese.nuovaSpesaFissa(sbagliata), JSON.stringify(sbagliata));
  }
});

function googleFinto(risposte) {
  spese.servizi.token = async () => 'finto';
  spese.servizi.fetch = async (url, opzioni = {}) => {
    const risposta = risposte(String(url), opzioni);

    return {
      ok: !risposta.status || risposta.status < 400,
      status: risposta.status || 200,
      text: async () => JSON.stringify(risposta.corpo || {}),
    };
  };
}

test('i consumi leggono ogni voce, e una che non si legge resta scritta', async () => {
  googleFinto((url) => {
    if (url.includes('document%2Fread_count') || url.includes('document/read_count')) {
      return {
        corpo: {
          timeSeries: [
            {
              points: [
                {
                  interval: { endTime: '2026-11-03T00:00:00Z' },
                  value: { int64Value: '60000' },
                },
              ],
            },
          ],
        },
      };
    }

    if (url.includes('write_count')) {
      return { status: 500, corpo: { error: { message: 'giu' } } };
    }

    if (url.includes('/secrets?')) {
      return { corpo: { secrets: [{ name: 'projects/x/secrets/A' }, { name: 'projects/x/secrets/B' }] } };
    }

    if (url.includes('/versions?')) {
      return { corpo: { versions: Array.from({ length: 4 }, () => ({ state: 'ENABLED' })) } };
    }

    if (url.includes('/jobs?')) {
      return { corpo: { jobs: Array.from({ length: 11 }, () => ({})) } };
    }

    if (url.includes('/builds?')) {
      return {
        corpo: url.includes('global')
          ? {}
          : { builds: [{ startTime: '2026-11-01T10:00:00Z', finishTime: '2026-11-01T10:30:00Z' }] },
      };
    }

    return { corpo: {} };
  });

  const conti = await spese.consumiGoogle({ giorni: 30 });
  const di = (nome) => conti.voci.find((v) => v.nome === nome);

  assert.equal(di('Letture').usato, 60000);
  assert.equal(di('Letture').aPagamento, 10000);
  // Il punto che finisce a mezzanotte appartiene al giorno prima.
  assert.equal(di('Letture').giorni[0].giorno, '2026-11-02');

  assert.equal(di('Scritture').nonLetta, true);
  assert.equal(conti.nonLette, 1);

  assert.equal(di('Segreti').usato, 8);
  assert.equal(di('Segreti').aPagamento, 2);
  assert.equal(di('Attività pianificate').aPagamento, 8);
  assert.equal(di('Costruzione delle funzioni').usato, 30);
  assert.equal(di('Costruzione delle funzioni').aPagamento, 0);

  const somma = conti.voci.reduce((totale, v) => totale + v.costo, 0);

  vicino(conti.costo, somma);
});

test('la fattura dice cosa manca, e quando c\'e\' la legge', async () => {
  googleFinto(() => ({ status: 404, corpo: { error: { message: 'non c\'e\'' } } }));
  assert.deepEqual(await spese.contoVero({ giorni: 30 }), {
    attivo: false,
    perche: 'manca-il-dataset',
    dataset: spese.DATASET,
  });

  googleFinto(() => ({ corpo: { tables: [{ tableReference: { tableId: 'altro' } }] } }));
  assert.equal((await spese.contoVero({ giorni: 30 })).perche, 'da-attivare');

  const domande = [];

  googleFinto((url, opzioni) => {
    if (url.includes('/tables')) {
      return { corpo: { tables: [{ tableReference: { tableId: 'gcp_billing_export_v1_ABC' } }] } };
    }

    const corpo = JSON.parse(opzioni.body);

    domande.push(corpo);

    return corpo.query.includes('AS giorno')
      ? {
          corpo: {
            jobComplete: true,
            schema: { fields: [{ name: 'giorno' }, { name: 'netto' }] },
            rows: [{ f: [{ v: '2026-11-02' }, { v: '0.4' }] }],
          },
        }
      : {
          corpo: {
            jobComplete: true,
            schema: {
              fields: ['servizio', 'voce', 'valuta', 'costo', 'crediti', 'quantita', 'unita', 'aggiornato'].map(
                (name) => ({ name })
              ),
            },
            rows: [
              { f: ['Cloud Firestore', 'Read Ops', 'EUR', '0.5', '-0.1', '1000', 'count', '1793744694'].map((v) => ({ v })) },
              { f: ['Identity Platform', 'SMS IT', 'EUR', '1.7', '0', '38', 'count', '1793700000'].map((v) => ({ v })) },
            ],
          },
        };
  });

  const conto = await spese.contoVero({ giorni: 30 });

  assert.equal(conto.attivo, true);
  assert.equal(conto.valuta, 'EUR');
  vicino(conto.costo, 2.2);
  vicino(conto.crediti, -0.1);
  vicino(conto.netto, 2.1);
  assert.equal(conto.aggiornato, 1793744694000);
  assert.equal(conto.righe.length, 2);
  assert.equal(conto.giorni[0].netto, 0.4);

  // Il dataset e' nell'UE, e la domanda dice da dove legge.
  assert.equal(domande[0].location, spese.POSIZIONE_DATASET);
  assert.ok(domande.every((d) => d.query.includes('gcp_billing_export_v1_ABC')));

  // Una risposta non ancora pronta non diventa zero spese.
  googleFinto((url) =>
    url.includes('/tables')
      ? { corpo: { tables: [{ tableReference: { tableId: 'gcp_billing_export_v1_ABC' } }] } }
      : { corpo: { jobComplete: false } }
  );
  assert.equal((await spese.contoVero({ giorni: 30 })).inCorso, true);

  // Un altro errore non si traveste da "non attiva".
  googleFinto(() => ({ status: 403, corpo: { error: { message: 'no' } } }));
  await assert.rejects(spese.contoVero({ giorni: 30 }), /no/);
});
