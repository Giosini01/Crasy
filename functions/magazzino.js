// In quale magazzino sta il file di una partecipazione.

const admin = require('firebase-admin');

/**
 * **Il magazzino di una foto, letto dal suo indirizzo.**
 *
 * Le foto stavano tutte nel magazzino di partenza, negli Stati Uniti: ogni foto
 * mandata o guardata dall'Italia attraversava l'oceano, e si sentiva — misurato
 * da qui, una foto da 300 KB ci metteva un secondo a salire e piu' di mezzo a
 * scendere. Le nuove salgono a Milano, quattro volte piu' in fretta.
 *
 * Le vecchie pero' restano dov'erano, e le app non ancora aggiornate
 * continuano a mandarle li': per un po' i magazzini sono due. L'indirizzo di
 * ogni foto dice in quale sta — `.../v0/b/{magazzino}/o/...` — e chi deve
 * controllarla o cancellarla la va a cercare li'. Senza indirizzo, quello di
 * partenza.
 *
 * Accetta sia un documento sia i suoi dati.
 */
function magazzinoDi(partecipazione) {
  const indirizzo = String(
    (partecipazione && typeof partecipazione.get === 'function'
      ? partecipazione.get('mediaUrl')
      : partecipazione && partecipazione.mediaUrl) || ''
  );
  const trovato = indirizzo.match(/\/v0\/b\/([^/]+)\/o\//);

  return trovato
    ? admin.storage().bucket(decodeURIComponent(trovato[1]))
    : admin.storage().bucket();
}

/** Il magazzino di Milano, dove salgono le foto nuove. */
const MILANO = 'daily-dating-app-milano';

/**
 * **Tutti i magazzini in cui puo' stare la foto di una gara**: quello di
 * partenza e quello di Milano. Chi ripulisce una gara guarda in tutti e due.
 */
function tuttiIMagazzini() {
  return [admin.storage().bucket(), admin.storage().bucket(MILANO)];
}

/**
 * La miniatura di un file: `.../{id}.jpg` -> `.../{id}_thumb.jpg`. Le due
 * salgono insieme con lo stesso nome, e devono andarsene insieme.
 */
function miniaturaDi(percorso) {
  return String(percorso || '').replace(/\.[^./]+$/, '_thumb.jpg');
}

module.exports = { magazzinoDi, tuttiIMagazzini, miniaturaDi };
