'use strict';

/**
 * **L'account della revisione di Apple torna sempre con i Termini da firmare.**
 *
 * Apple boccia se non vede i Termini (linea guida 1.2), e li vede solo se l'account
 * che usa non li ha gia' accettati. Prima tornava da firmare soltanto quando si
 * pubblicava il server: bastava entrarci una volta per una prova, accettare, e il
 * revisore non li vedeva piu'. E non dipendeva da noi: lo stesso succedeva fra un
 * revisore e il successivo.
 *
 * Adesso, ogni mezz'ora, una firma del revisore che ha piu' di un'ora si toglie. Chi
 * ci entra dopo deve rimettere le spunte, con qualunque versione dell'app: anche
 * con quelle gia' mandate in revisione, che il segno `firmaAOgniAccesso` non lo
 * conoscono (lo legge l'app dalla 394 in poi, e chiede i Termini a ogni accesso).
 *
 * **Un'ora** perche' una prova di Apple dura molto meno: chi sta guardando l'app
 * non se li vede ricomparire a meta'. E chi l'ha usato per una prova lo ritrova da
 * firmare al massimo un'ora e mezza dopo.
 *
 * **Solo l'account vero.** Il segno nel profilo se lo puo' scrivere chiunque; quello
 * sull'account (`revisione`) lo mette solo `tool/account_revisione.js`, con le
 * chiavi del server. Servono tutti e due.
 */
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

/** Quanto vale la firma del revisore prima di tornare da rifare. */
const DURATA_DELLA_FIRMA_MS = 60 * 60 * 1000;

/**
 * Se la firma di questo profilo va tolta, a [adesso] (millisecondi).
 *
 * Una firma senza ora si toglie subito: non dimostra quando e' stata data.
 */
function firmaDaTogliere(profilo, adesso) {
  const versione = String(profilo.legalVersion || '');
  const il = profilo.legalAcceptedAt;

  if (!versione && !il) {
    return false;
  }

  if (!il || typeof il.toMillis !== 'function') {
    return true;
  }

  return adesso - il.toMillis() >= DURATA_DELLA_FIRMA_MS;
}

const rimettiITerminiAlRevisore = onSchedule(
  { schedule: 'every 30 minutes', timeZone: 'Europe/Rome' },
  async () => {
    const db = admin.firestore();
    const adesso = Date.now();
    const segnati = await db
      .collection('users')
      .where('firmaAOgniAccesso', '==', true)
      .limit(20)
      .get();

    for (const doc of segnati.docs) {
      if (!firmaDaTogliere(doc.data(), adesso)) {
        continue;
      }

      try {
        const persona = await admin.auth().getUser(doc.id);

        if (persona.customClaims?.revisione !== true) {
          continue;
        }

        // **Senza toccare `updatedAt`, di proposito.** Le versioni dell'app gia' in
        // revisione si accorgono del cambio solo da li': cosi' chi e' dentro non
        // viene interrotto, e i Termini li rivede chi entra dopo.
        await doc.ref.update({
          legalVersion: admin.firestore.FieldValue.delete(),
          legalAcceptedAt: admin.firestore.FieldValue.delete(),
        });

        logger.info('Termini di nuovo da firmare per la revisione', { uid: doc.id });
      } catch (errore) {
        logger.error(`Firma del revisore ${doc.id} non tolta.`, errore);
      }
    }
  },
);

module.exports = { rimettiITerminiAlRevisore, firmaDaTogliere, DURATA_DELLA_FIRMA_MS };
