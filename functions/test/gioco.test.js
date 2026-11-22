'use strict';

// Il gioco: sfide del giorno, traguardi, XP e livelli. Qui si prova la logica
// senza database: chi conta cosa, quando un premio si da', e che non si dia
// mai due volte.

const test = require('node:test');
const assert = require('node:assert/strict');

const g = require('../gioco_regole');

const REGOLE = g.valida(require('../dati/gioco.json'));
const OGGI = '2026-12-02';
const DOMANI = '2026-12-03';

/** Regole piccole e prevedibili: ogni giorno le stesse tre sfide. */
const PICCOLE = g.valida({
  giornaliere: {
    quante: 3,
    elenco: [
      { id: 'una_foto', gruppo: 'foto', titolo: 'Una foto', descrizione: 'x', metrica: 'foto', obiettivo: 1, xp: 20 },
      { id: 'tre_fiamme', gruppo: 'fiamme', titolo: 'Tre fiamme', descrizione: 'x', metrica: 'fiammeDate', obiettivo: 3, xp: 10 },
      { id: 'un_amico', gruppo: 'amici', titolo: 'Un amico', descrizione: 'x', metrica: 'amici', obiettivo: 1, xp: 30 },
    ],
  },
  permanenti: [
    { id: 'due_foto', titolo: 'Due foto', descrizione: 'x', metrica: 'foto', obiettivo: 2, xp: 50 },
    { id: 'serie_tre', titolo: 'Serie', descrizione: 'x', metrica: 'serieRecord', obiettivo: 3, xp: 40 },
  ],
  livelli: [
    { nome: 'Novizio', xp: 0 },
    { nome: 'Curioso', xp: 60 },
    { nome: 'Attivo', xp: 200 },
  ],
});

/** Un fatto, come lo passa il server: con la sua chiave e il suo foglio. */
function fatto(stato, eventi, { chiave, metrica, attivo = true, oggi = OGGI, regole = PICCOLE }) {
  const decisione = g.decidi(eventi[chiave] || null, attivo, oggi);

  if (!decisione.delta) {
    return { stato, premi: [] };
  }

  eventi[chiave] = decisione.evento;

  return g.applica({ stato, regole, uid: 'anna', oggi, metrica, delta: decisione.delta, contaOggi: decisione.contaOggi, adesso: 1 });
}

test('le regole di partenza sono valide, e quelle scritte male no', () => {
  assert.equal(REGOLE.livelli.length, 8);
  assert.equal(REGOLE.livelli[0].xp, 0);
  assert.ok(REGOLE.giornaliere.elenco.length >= 4);

  const rotte = [
    [{ ...require('../dati/gioco.json'), livelli: [{ nome: 'A', xp: 0 }, { nome: 'B', xp: 0 }] }, /piu' XP/],
    [{ ...require('../dati/gioco.json'), permanenti: [{ id: 'x1', titolo: 'X', descrizione: 'x', metrica: 'inventata', obiettivo: 1, xp: 1 }] }, /non esiste/],
    [{ ...require('../dati/gioco.json'), permanenti: [
      { id: 'xx', titolo: 'X', descrizione: 'x', metrica: 'foto', obiettivo: 1, xp: 1 },
      { id: 'xx', titolo: 'Y', descrizione: 'y', metrica: 'foto', obiettivo: 2, xp: 1 },
    ] }, /due volte/],
    [{ ...require('../dati/gioco.json'), giornaliere: { quante: 2, elenco: [
      { id: 'serie', titolo: 'S', descrizione: 's', metrica: 'serieRecord', obiettivo: 1, xp: 1 },
    ] } }, /non si fa in un giorno/],
    [{ ...require('../dati/gioco.json'), permanenti: [{ id: 'xy', titolo: 'X', descrizione: 'x', metrica: 'foto', obiettivo: 1, xp: 999999 }] }, /xp/],
  ];

  for (const [regole, errore] of rotte) {
    assert.throws(() => g.valida(regole), errore);
  }
});

test('le sfide di oggi: sempre le stesse per la stessa persona e lo stesso giorno', () => {
  const a = g.sceltaDelGiorno('anna', OGGI, REGOLE);
  const b = g.sceltaDelGiorno('anna', OGGI, REGOLE);

  assert.deepEqual(a, b);
  assert.equal(a.length, REGOLE.giornaliere.quante);
  assert.equal(new Set(a).size, a.length, 'nessuna due volte');

  // Il gruppo delle foto c'e' sempre, e ogni sfida viene da un gruppo diverso.
  const gruppi = a.map((id) => REGOLE.giornaliere.elenco.find((v) => v.id === id).gruppo);

  assert.ok(gruppi.includes('foto'));
  assert.equal(new Set(gruppi).size, gruppi.length);

  // Fra persone e giorni diversi la giornata cambia (non per tutti: per molti).
  const giornate = new Set();

  for (const chi of ['anna', 'bruno', 'carla', 'dino', 'elena']) {
    for (const giorno of [OGGI, DOMANI, '2026-12-04']) {
      giornate.add(g.sceltaDelGiorno(chi, giorno, REGOLE).join(','));
    }
  }

  assert.ok(giornate.size > 3, `solo ${giornate.size} giornate diverse su 15`);
});

test('una sfida del giorno fatta da XP una volta sola', () => {
  const eventi = {};
  let stato = g.statoIniziale();
  let esito = fatto(stato, eventi, { chiave: 'foto_g1', metrica: 'foto' });

  assert.deepEqual(esito.premi.map((p) => p.chiave), [`g_${OGGI}_una_foto`]);
  assert.equal(esito.stato.xp, 20);
  stato = esito.stato;

  // Lo stesso fatto che arriva di nuovo (il server riprova): niente.
  esito = fatto(stato, eventi, { chiave: 'foto_g1', metrica: 'foto' });
  assert.equal(esito.premi.length, 0);
  assert.equal((esito.stato || stato).xp, 20);

  // Una seconda foto in un'altra gara: la sfida del giorno e' gia' fatta, ma
  // arriva il traguardo delle due foto, una volta per sempre.
  esito = fatto(stato, eventi, { chiave: 'foto_g2', metrica: 'foto' });
  assert.deepEqual(esito.premi.map((p) => p.chiave), ['p_due_foto']);
  assert.equal(esito.stato.xp, 70);
  assert.equal(esito.stato.sfideCompletate, 2);
  stato = esito.stato;

  // Una terza: nessun premio nuovo.
  esito = fatto(stato, eventi, { chiave: 'foto_g3', metrica: 'foto' });
  assert.equal(esito.premi.length, 0);
  assert.equal(esito.stato.xp, 70);
});

test('una fiamma tolta e rimessa non conta due volte, ne oggi ne domani', () => {
  const eventi = {};
  let stato = g.statoIniziale();

  for (const foto of ['f1', 'f2']) {
    stato = fatto(stato, eventi, { chiave: `fiamma_${foto}`, metrica: 'fiammeDate' }).stato;
  }

  assert.equal(stato.oggi.contatori.fiammeDate, 2);

  // Togliere e rimettere la stessa fiamma: il conto torna dov'era.
  stato = fatto(stato, eventi, { chiave: 'fiamma_f2', metrica: 'fiammeDate', attivo: false }).stato;
  assert.equal(stato.oggi.contatori.fiammeDate, 1);
  stato = fatto(stato, eventi, { chiave: 'fiamma_f2', metrica: 'fiammeDate' }).stato;
  assert.equal(stato.oggi.contatori.fiammeDate, 2);
  assert.equal(stato.xp, 0, 'due fiamme non bastano per tre');

  // Il giorno dopo, toglierla e rimetterla non fa una sfida del giorno nuova.
  stato = fatto(stato, eventi, { chiave: 'fiamma_f2', metrica: 'fiammeDate', attivo: false, oggi: DOMANI }).stato;
  stato = fatto(stato, eventi, { chiave: 'fiamma_f2', metrica: 'fiammeDate', oggi: DOMANI }).stato;
  assert.equal(stato.giorno, DOMANI);
  assert.equal(stato.oggi.contatori.fiammeDate || 0, 0);
  assert.equal(stato.contatori.fiammeDate, 2, 'il totale resta giusto');
});

test('al cambio di giorno le sfide si rinnovano e i traguardi restano', () => {
  const eventi = {};
  let stato = fatto(g.statoIniziale(), eventi, { chiave: 'foto_g1', metrica: 'foto' }).stato;

  assert.ok(stato.oggi.completate.una_foto);

  // Una settimana senza aprire l'app: si riparte da oggi, non da sette giorni fa.
  const fra = '2026-12-09';
  const esito = fatto(stato, eventi, { chiave: 'foto_g2', metrica: 'foto', oggi: fra });

  assert.equal(esito.stato.giorno, fra);
  assert.equal(esito.stato.oggi.contatori.foto, 1);
  assert.deepEqual(esito.premi.map((p) => p.chiave).sort(), [`g_${fra}_una_foto`, 'p_due_foto']);
  assert.equal(esito.stato.contatori.foto, 2);
});

test('una sfida fatta resta fatta anche se il conto poi scende', () => {
  const eventi = {};
  let stato = fatto(g.statoIniziale(), eventi, { chiave: 'foto_g1', metrica: 'foto' }).stato;

  stato = fatto(stato, eventi, { chiave: 'foto_g1', metrica: 'foto', attivo: false }).stato;

  assert.equal(stato.oggi.contatori.foto, 0);
  assert.ok(stato.oggi.completate.una_foto);
  assert.equal(stato.xp, 20);

  // E rimandarla non rida' i punti di oggi.
  const esito = fatto(stato, eventi, { chiave: 'foto_g1', metrica: 'foto' });

  assert.equal(esito.premi.length, 0);
});

test('il livello sale con gli XP, e dice quanto manca al prossimo', () => {
  assert.deepEqual(g.livelloDi(0, REGOLE.livelli), { numero: 1, nome: 'Novizio', xpDa: 0, xpA: 100, progresso: 0 });
  assert.equal(g.livelloDi(150, REGOLE.livelli).numero, 2);
  assert.equal(g.livelloDi(150, REGOLE.livelli).progresso, 0.25);
  assert.equal(g.livelloDi(12000, REGOLE.livelli).xpA, null);
  assert.equal(g.livelloDi(99999, REGOLE.livelli).nome, 'Leggenda');

  // Una foto (20) + il traguardo delle due foto (50) = 70: si passa a Curioso.
  const eventi = {};
  let stato = fatto(g.statoIniziale(), eventi, { chiave: 'foto_g1', metrica: 'foto' }).stato;
  const esito = fatto(stato, eventi, { chiave: 'foto_g2', metrica: 'foto' });

  assert.equal(esito.livelloPrima, 1);
  assert.equal(esito.livelloDopo, 2);
  assert.equal(esito.stato.livello, 2);
});

test('il record della serie vale il massimo, e il traguardo arriva una volta', () => {
  let esito = g.applica({ stato: g.statoIniziale(), regole: PICCOLE, uid: 'anna', oggi: OGGI, metrica: 'serieRecord', valore: 2 });

  assert.equal(esito.premi.length, 0);
  esito = g.applica({ stato: esito.stato, regole: PICCOLE, uid: 'anna', oggi: OGGI, metrica: 'serieRecord', valore: 3 });
  assert.deepEqual(esito.premi.map((p) => p.chiave), ['p_serie_tre']);

  // Una serie che si rompe e riparte da uno non abbassa il record.
  esito = g.applica({ stato: esito.stato, regole: PICCOLE, uid: 'anna', oggi: OGGI, metrica: 'serieRecord', valore: 1 });
  assert.equal(esito.stato.contatori.serieRecord, 3);
  assert.equal(esito.premi.length, 0);
});

test('il primo arrivo di un fatto conta oggi, il ritorno solo se era di oggi', () => {
  assert.deepEqual(g.decidi(null, true, OGGI), { delta: 1, contaOggi: true, evento: { attivo: true, giorno: OGGI } });
  assert.deepEqual(g.decidi({ attivo: true, giorno: OGGI }, true, OGGI), { delta: 0 });
  assert.deepEqual(g.decidi(null, false, OGGI), { delta: 0 });
  assert.deepEqual(g.decidi({ attivo: true, giorno: OGGI }, false, DOMANI), { delta: -1, contaOggi: false, evento: { attivo: false, giorno: OGGI } });
  assert.deepEqual(g.decidi({ attivo: false, giorno: OGGI }, true, DOMANI), { delta: 1, contaOggi: false, evento: { attivo: true, giorno: OGGI } });
});
