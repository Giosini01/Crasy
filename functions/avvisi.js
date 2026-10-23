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
 *
 * ## Perche', e se l'ha deciso una macchina
 *
 * **L'avviso dice il motivo, e chi l'ha deciso.** Prima diceva solo "la tua
 * foto e' stata tolta", e chi la riceveva non sapeva ne' perche' ne' cosa
 * poterci fare. Il Digital Services Act chiede tre cose a chi toglie un
 * contenuto: dire perche', dire se la decisione e' automatica, e dire come
 * contestarla. Il motivo e' una parola sola (`motivo`), e la frase la compone
 * l'app; `automatico` distingue il controllo delle immagini da una persona del
 * team. La contestazione e' `chiediRevisione` (vedi `revisioni.js`).
 *
 * Il motivo sta **qui**, nell'avviso che legge solo chi ha mandato la foto, e
 * non sulla foto: la foto la legge chiunque sia nella gara, e "tolta perche'
 * sessuale" scritto li' sopra sarebbe un'etichetta appiccicata a una persona.
 */

const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

/**
 * Il motivo, da quello che ha visto il controllo delle immagini.
 *
 * I nomi vengono da `reasonsFromSafeSearch` e da `moderateVideo` in `index.js`.
 */
function motivoDaiControlli(motivi) {
  const elenco = (Array.isArray(motivi) ? motivi : []).map(String);

  if (elenco.some((m) => m.startsWith('nudita'))) {
    return 'sessuale';
  }

  if (elenco.some((m) => m.startsWith('violenza'))) {
    return 'violenza';
  }

  // Non e' il contenuto: era la sesta del giorno. Vedi `oltreIlLimiteDelGiorno`.
  if (elenco.some((m) => m.startsWith('limite'))) {
    return 'limite';
  }

  return 'altro';
}

/** Il motivo, dalla voce scelta da chi ha segnalato (`ReportReason` nell'app). */
function motivoDallaSegnalazione(voce) {
  return (
    {
      danger: 'pericolo',
      sexual: 'sessuale',
      violence: 'violenza',
      hate: 'odio',
      minor: 'minore',
    }[String(voce || '')] || 'altro'
  );
}

function avvisiDi(autore) {
  return admin.firestore().collection('users').doc(autore).collection('notifications');
}

async function avvisaChiLHaMandata(
  autore,
  challengeId,
  titolo,
  { motivo = 'altro', automatico = false } = {}
) {
  if (!autore || !challengeId) {
    return;
  }

  try {
    await avvisiDi(autore)
      .doc('tolta_' + challengeId)
      .set({
        kind: 'removed',
        // Nessun attore: chi decide non si firma, e il controllo automatico
        // non e' nessuno.
        actorId: '',
        actorUsername: '',
        challengeId,
        challengeTitle: titolo || '',
        // La partecipazione si chiama come chi l'ha mandata.
        entryId: autore,
        motivo,
        automatico: automatico === true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    // Se un giorno era stata rimessa in gara, quell'avviso non e' piu' vero.
    // Toglierlo fa anche si' che una seconda rimessa faccia squillare di nuovo.
    await avvisiDi(autore).doc('rimessa_' + challengeId).delete();
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

/**
 * **Toglie l'avviso "la tua foto e' stata tolta" quando la foto torna in gara.**
 *
 * Restava li': chi aveva ritrovato la propria foto in gara leggeva ancora in
 * campanella che era stata tolta. E se la stessa foto veniva tolta una seconda
 * volta, l'avviso c'era gia' — riscriverlo non lo fa nascere di nuovo, quindi
 * non partiva nessuna notifica.
 */
async function togliLAvvisoDiRimozione(autore, challengeId) {
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
      .delete();
  } catch (error) {
    // Un avviso di troppo non vale una foto rimessa a meta'.
    logger.warn('avviso di rimozione non tolto', { autore, challengeId, error });
  }
}

/**
 * **"La tua foto e' tornata in gara."**
 *
 * Chi ha chiesto una revisione aspetta una risposta, e la risposta buona e'
 * quella che deve arrivare di sicuro: la foto e' di nuovo li', e i minuti che
 * restano sono minuti per prendere fiamme. Un documento nuovo, quindi una
 * notifica che squilla.
 */
async function avvisaCheETornata(autore, challengeId, titolo) {
  if (!autore || !challengeId) {
    return;
  }

  try {
    await avvisiDi(autore)
      .doc('rimessa_' + challengeId)
      .set({
        kind: 'restored',
        actorId: '',
        actorUsername: '',
        challengeId,
        challengeTitle: titolo || '',
        entryId: autore,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  } catch (error) {
    logger.warn('avviso di rimessa non partito', { autore, challengeId, error });
  }
}

module.exports = {
  avvisaChiLHaMandata,
  togliLAvvisoDiRimozione,
  avvisaCheETornata,
  motivoDaiControlli,
  motivoDallaSegnalazione,
};
