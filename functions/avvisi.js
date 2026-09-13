/**
 * Dice a chi ha mandato una foto che gliel'hanno tolta.
 *
 * **Prima non lo diceva nessuno.** La foto spariva dalla griglia e basta. Chi
 * l'aveva mandata restava dentro una gara con dei soldi in palio senza piu'
 * esserci davvero, e se ne accorgeva solo tornando a guardare — oppure non se
 * ne accorgeva affatto, e continuava ad aspettare un risultato che non poteva
 * arrivare. E' il tipo di silenzio che fa disinstallare un'app: uno non capisce
 * cos'e' successo, e la spiegazione piu' facile che si da' e' che sia rotta.
 *
 * **Non si dice chi ha segnalato, e non si dira' mai.** Le segnalazioni sono
 * anonime per costruzione: dirlo trasformerebbe una moderazione in una lite fra
 * due persone, e la segnalazione dopo non la manderebbe piu' nessuno.
 *
 * Sta in un file suo perche' la chiamano in due — il controllo automatico
 * delle immagini in `index.js` e la decisione dell'amministratore in
 * `admin.js` — e due copie della stessa frase sono due frasi che al primo
 * cambiamento si dicono cose diverse.
 *
 * Il nome del documento porta dentro la gara, quindi due passaggi sulla stessa
 * rimozione non fanno due avvisi: la notifica push si aggancia alla **nascita**
 * di un documento, e riscriverne uno che esiste gia' non fa squillare niente.
 */

const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

async function avvisaChiLHaMandata(autore, challengeId, titolo) {
  if (!autore || !challengeId) {
    return;
  }

  try {
    await admin
      .firestore()
      .collection('users')
      .doc(autore)
      .collection('notifications')
      .doc('tolta_' + challengeId)
      .set({
        kind: 'removed',
        // Nessun attore: chi decide non si firma, e il controllo automatico
        // non e' nessuno.
        actorId: '',
        actorUsername: '',
        challengeId,
        challengeTitle: titolo || '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  } catch (error) {
    // **Non si rovescia la rimozione per un avviso.** La foto e' gia' fuori
    // dalla gara, ed e' quella la cosa che doveva succedere: fallire qui e
    // rifare tutto vorrebbe dire rimetterla dentro.
    logger.error('avviso di rimozione non partito', {
      autore,
      challengeId,
      error,
    });
  }
}

module.exports = { avvisaChiLHaMandata };
