'use strict';

// Il calendario del fondo: chi lancia cosa, a che ora, con che premio, e
// quando si ferma. E' la parte che sbaglia in silenzio, quindi si prova qui.

const test = require('node:test');
const assert = require('node:assert/strict');

const c = require('../calendario_del_fondo');
const MISSIONI = require('../dati/missioni_automatiche.json');

const AUTORI = [
  { uid: 'a', username: 'anna' },
  { uid: 'b', username: 'bruno' },
  { uid: 'c', username: 'carla' },
];

const ELENCO = [
  { titolo: 'UNO', consegna: 'x', euro: 1 },
  { titolo: 'DUE', consegna: 'x', euro: 1.5 },
  { titolo: 'TRE', consegna: 'x' },
];

/** Le 8:00 di un giorno d'inverno in Italia (7:00 a Greenwich). */
const MATTINA = new Date('2026-12-02T07:00:00Z');

function fondo(extra = {}) {
  return {
    fondoCents: 10000,
    alGiorno: 5,
    premioCents: 200,
    autori: AUTORI,
    ...extra,
  };
}

test('le dieci in Italia sono le dieci in Italia, d inverno e d estate', () => {
  assert.equal(new Date(c.istanteInItalia('2026-12-02', 10)).toISOString(), '2026-12-02T09:00:00.000Z');
  assert.equal(new Date(c.istanteInItalia('2026-07-02', 10)).toISOString(), '2026-07-02T08:00:00.000Z');
});

test('il premio e quello della missione, se no quello del fondo', () => {
  assert.equal(c.premioDi({ euro: 1.5 }, { premioCents: 300 }), 150);
  assert.equal(c.premioDi({ euro: '1,50' }, {}), 150);
  assert.equal(c.premioDi({}, { premioCents: 300 }), 300);
  assert.equal(c.premioDi({}, {}), 100);
});

test('cinque al giorno, alle ore giuste, a turno fra le facce', () => {
  const lista = c.prossime(fondo(), ELENCO, MATTINA, 7);
  const ore = lista.map((p) =>
    new Date(p.quando).toLocaleTimeString('it-IT', { timeZone: 'Europe/Rome', hour: '2-digit' })
  );

  assert.deepEqual(ore, ['10', '13', '16', '19', '21', '10', '13']);
  assert.deepEqual(lista.map((p) => p.autore), ['anna', 'bruno', 'carla', 'anna', 'bruno', 'carla', 'anna']);
  assert.deepEqual(lista.map((p) => p.premioCents), [100, 150, 200, 100, 150, 200, 100]);
  assert.equal(lista[0].giorno, '2026-12-02');
  assert.equal(lista[5].giorno, '2026-12-03');
});

test('si ferma quando i soldi non bastano per la prossima', () => {
  // 100 + 150 + 200 = 450: con 4,49 euro ne escono due.
  const lista = c.prossime(fondo({ fondoCents: 449 }), ELENCO, MATTINA);

  assert.equal(lista.length, 2);
});

test('prima della partenza non esce niente, dopo la fine nemmeno', () => {
  const lista = c.prossime(fondo({ dal: '2026-12-04', fino: '2026-12-05' }), ELENCO, MATTINA);

  assert.equal(lista.length, 10);
  assert.ok(lista.every((p) => p.giorno === '2026-12-04' || p.giorno === '2026-12-05'));
});

test('oggi conta quelle gia uscite e le ore gia passate', () => {
  // Alle 14 ne sono gia' uscite due: restano le 16 e le 19 (tetto a quattro).
  const lista = c.prossime(
    fondo({ alGiorno: 4, giorno: '2026-12-02', fatte: 2 }),
    ELENCO,
    new Date('2026-12-02T13:00:00Z'),
    3
  );

  assert.deepEqual(
    lista.map((p) => `${p.giorno} ${new Date(p.quando).toLocaleTimeString('it-IT', { timeZone: 'Europe/Rome', hour: '2-digit' })}`),
    ['2026-12-02 16', '2026-12-02 19', '2026-12-03 10']
  );
});

test('riparte da dove era rimasto: missioni lanciate, saltate e turno', () => {
  const lista = c.prossime(fondo({ lanciate: 4, saltate: 1, turno: 7 }), ELENCO, MATTINA, 2);

  // Indice 5 % 3 = 2 -> TRE, poi UNO; turno 7 % 3 = 1 -> bruno, poi carla.
  assert.deepEqual(lista.map((p) => p.titolo), ['TRE', 'UNO']);
  assert.deepEqual(lista.map((p) => p.autore), ['bruno', 'carla']);
});

test('senza facce il calendario c e lo stesso, ma dice che non lancia nessuno', () => {
  const lista = c.prossime(fondo({ autori: [] }), ELENCO, MATTINA, 2);

  assert.equal(lista.length, 2);
  assert.ok(lista.every((p) => p.autore === '' && p.autoreId === ''));
});

test('le missioni del file sono scritte bene', () => {
  assert.ok(MISSIONI.length > 0);

  for (const m of MISSIONI) {
    assert.ok(m.titolo && m.titolo.length <= 80, `titolo: ${m.titolo}`);
    assert.ok(m.consegna && m.consegna.length <= 300, `consegna: ${m.titolo}`);
    assert.ok(['photo', 'video'].includes(m.media), `media: ${m.titolo}`);
    assert.ok(['instant', 'archive'].includes(m.fonte), `fonte: ${m.titolo}`);
    assert.ok(m.euro === undefined || (c.centesimi(m.euro) >= 50 && c.centesimi(m.euro) <= 10000), `euro: ${m.titolo}`);
  }
});
