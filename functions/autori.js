'use strict';

/**
 * **Chi ha lanciato una gara, anche quando non si e' firmato.**
 *
 * Una gara anonima non porta scritto chi l'ha lanciata. Il documento della gara
 * lo legge chiunque la possa vedere, e un `createdByUserId` lasciato li' dentro
 * era un anonimato che reggeva solo nell'interfaccia: bastava leggere il
 * database per sapere chi c'era dietro. Il nome vero sta in
 * `autoriAnonimi/{gara}`, un foglio che legge solo chi l'ha lanciata (vedi
 * `firestore.rules`) e il server.
 *
 * **Tutto il server chiede l'autore da qui, mai dal campo.** Rimborsi, avvisi,
 * permessi e limiti funzionano allo stesso modo per le gare firmate e per
 * quelle anonime: un punto che leggesse ancora il campo tratterebbe una gara
 * anonima come una gara di nessuno — e una gara di nessuno, su CRASY, e' una
 * missione ufficiale.
 */
const admin = require('firebase-admin');

/** Dove sta chi ha lanciato una gara anonima. */
const AUTORI_ANONIMI = 'autoriAnonimi';

function foglioDi(challengeId) {
  return admin.firestore().collection(AUTORI_ANONIMI).doc(String(challengeId));
}

/**
 * Chi ha lanciato una gara.
 *
 * Si passa il documento della gara, oppure il suo identificativo con i campi
 * gia' letti (quando arrivano da un evento, senza documento). Torna la stringa
 * vuota quando non c'e' nessun autore: una missione di CRASY.
 */
async function autoreDi(gara, campi) {
  const id = typeof gara === 'string' ? gara : gara && gara.id;
  const dati =
    typeof gara === 'string' ? campi || {} : (gara && gara.data && gara.data()) || {};
  const scritto = String(dati.createdByUserId || '');

  if (scritto) {
    return scritto;
  }

  if (dati.anonimo !== true || !id) {
    return '';
  }

  const foglio = await foglioDi(id).get();

  return foglio.exists ? String(foglio.get('uid') || '') : '';
}

module.exports = { AUTORI_ANONIMI, foglioDi, autoreDi };
