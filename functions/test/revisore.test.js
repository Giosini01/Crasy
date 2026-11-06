'use strict';

/**
 * **Quando la firma del revisore di Apple si toglie.** Si lancia con `npm test`, senza
 * credenziali e senza rete.
 */
const test = require('node:test');
const assert = require('node:assert/strict');

process.env.GCLOUD_PROJECT = 'demo-crasy';

const { firmaDaTogliere, DURATA_DELLA_FIRMA_MS } = require('../revisore');

const ADESSO = Date.UTC(2026, 10, 6, 15);

/** Un'ora di Firestore, come la legge l'SDK di amministrazione. */
function ora(millisecondi) {
  return { toMillis: () => millisecondi };
}

test('un account gia\' da firmare resta com\'e\'', () => {
  assert.equal(firmaDaTogliere({}, ADESSO), false);
  assert.equal(firmaDaTogliere({ legalVersion: '' }, ADESSO), false);
});

test('una firma appena data resta: chi sta provando l\'app non viene interrotto', () => {
  const profilo = { legalVersion: '1.6', legalAcceptedAt: ora(ADESSO - 10 * 60 * 1000) };

  assert.equal(firmaDaTogliere(profilo, ADESSO), false);
});

test('passata un\'ora, la firma si toglie', () => {
  const profilo = { legalVersion: '1.6', legalAcceptedAt: ora(ADESSO - DURATA_DELLA_FIRMA_MS) };

  assert.equal(firmaDaTogliere(profilo, ADESSO), true);
  assert.equal(
    firmaDaTogliere({ ...profilo, legalAcceptedAt: ora(ADESSO - 3 * 24 * 60 * 60 * 1000) }, ADESSO),
    true,
  );
});

test('una firma senza ora si toglie subito', () => {
  assert.equal(firmaDaTogliere({ legalVersion: '1.6' }, ADESSO), true);
});
