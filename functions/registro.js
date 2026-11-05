'use strict';

/**
 * **Chi ha fatto cosa, in un posto solo.**
 *
 * Nel pannello entra piu' di una persona, e il giorno in cui qualcuno chiede
 * perche' una foto e' sparita o perche' un account e' stato chiuso si deve poter
 * rispondere. Prima lo scriveva solo `pannello.js`: tutto quello che passava da
 * `admin.js` — le decisioni sulle segnalazioni, cioe' la cosa piu' importante —
 * restava nei log e basta.
 *
 * `registroAdmin` non lo legge e non lo scrive nessun telefono (vedi
 * `firestore.rules`), e il pannello lo mostra senza poterlo correggere.
 *
 * `chi` e' l'identificativo dell'amministratore, o `automatico` quando a decidere
 * e' stato un controllo.
 */
const admin = require('firebase-admin');

async function registra(chi, azione, dettagli) {
  await admin.firestore().collection('registroAdmin').add({
    chi,
    azione,
    dettagli,
    il: admin.firestore.FieldValue.serverTimestamp(),
  });
}

module.exports = { registra };
