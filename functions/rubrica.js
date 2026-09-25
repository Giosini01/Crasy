/**
 * **Trovare gli amici che hai gia' in rubrica.**
 *
 * Il telefono ha duecento numeri dentro, e qualcuno di quei numeri ha CRASY.
 * Dirlo e' facile; farlo senza costruire per sbaglio uno schedario di chi
 * conosce chi e' tutto il lavoro di questo file.
 *
 * ## Come funziona, e perche' cosi'
 *
 * L'app legge la rubrica, tiene solo i numeri, li riscrive in forma
 * internazionale (`+39...`) e li manda qui. Il server li trasforma in
 * impronte — una stringa di lettere e numeri da cui il numero **non si
 * ricava** — e cerca quelle impronte nel proprio indice.
 *
 * L'impronta non e' il solo risultato della funzione di hash: prima del numero
 * si mette una parola segreta che vive solo nel Secret Manager. Senza, l'indice
 * sarebbe inutile come difesa — i numeri di cellulare italiani sono dieci
 * cifre, e provarli tutti richiede pochi minuti. Con il segreto, un indice
 * rubato non dice niente a nessuno.
 *
 * **I numeri che arrivano qui non vengono scritti da nessuna parte.** Vivono
 * il tempo della ricerca e muoiono con la richiesta: non finiscono in un
 * documento, non finiscono in un log. E' la differenza fra cercare fra i
 * propri utenti e collezionare le rubriche altrui, ed e' anche quello che il
 * GDPR chiede quando i dati riguardano gente che non si e' mai iscritta.
 *
 * ## Chi si fa trovare
 *
 * Nessuno per forza. Nel profilo c'e' un interruttore: chi lo spegne esce
 * dall'indice, e da quel momento non lo trova piu' nessuno per numero. Chi non
 * l'ha mai toccato si fa trovare — e' il comportamento che serve perche' la
 * cosa funzioni — ma glielo si dice, invece di lasciarglielo scoprire.
 */

'use strict';

const crypto = require('crypto');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

/** La parola segreta che si mette davanti al numero prima di fare l'impronta. */
const PEPE_RUBRICA = defineSecret('PEPE_RUBRICA');

/** Quanti numeri si accettano in una richiesta sola. */
const MASSIMO = 2000;

/**
 * **Il numero, ridotto all'osso.**
 *
 * Due persone scrivono lo stesso numero in cinque modi diversi — con gli
 * spazi, con i trattini, con lo zero davanti, con `0039` al posto del `+39`.
 * Se non li si riporta tutti alla stessa forma, l'impronta cambia e l'amico
 * non si trova: sarebbe un difetto invisibile, di quelli che sembrano "non
 * funziona e non si capisce perche'".
 *
 * Qui si accetta solo la forma internazionale, gia' fatta dall'app che conosce
 * il paese del telefono. Questa e' l'ultima spazzolata.
 */
function pulisci(numero) {
  const solo = String(numero || '').replace(/[^\d+]/g, '');

  if (!solo.startsWith('+') || solo.length < 8 || solo.length > 16) {
    return null;
  }

  return solo;
}

function impronta(numero, pepe) {
  return crypto.createHmac('sha256', pepe).update(numero).digest('hex');
}

/**
 * **L'indice si aggiorna da solo quando cambia il numero.**
 *
 * Guarda `users/{id}/private/contatto`, non il profilo: il numero sta li'
 * dentro perche' il profilo lo legge chiunque abbia fatto l'accesso, e un
 * numero di telefono in un documento pubblico e' un numero di telefono
 * pubblico.
 *
 * Non lo scrive l'app: se lo scrivesse, il segreto dovrebbe stare dentro ogni
 * telefono, e un segreto che sta in centomila telefoni non e' un segreto.
 */
exports.aggiornaIndiceRubrica = onDocumentWritten(
  { document: 'users/{userId}/private/contatto', secrets: [PEPE_RUBRICA] },
  async (evento) => {
    const prima = evento.data?.before?.data() || {};
    const dopo = evento.data?.after?.data() || {};

    const numeroPrima = pulisci(prima.phone);
    const numeroDopo = pulisci(dopo.phone);
    const trovabilePrima = prima.findableByPhone !== false;
    const trovabileDopo = dopo.findableByPhone !== false;

    if (numeroPrima === numeroDopo && trovabilePrima === trovabileDopo) {
      return;
    }

    const pepe = PEPE_RUBRICA.value();
    const indice = admin.firestore().collection('phoneIndex');
    const lavori = [];

    // Il vecchio si toglie sempre: se il numero e' cambiato, quello di prima
    // punterebbe ancora a questa persona, e chi ha in rubrica il numero vecchio
    // la troverebbe per sempre.
    if (numeroPrima && (numeroPrima !== numeroDopo || !trovabileDopo)) {
      lavori.push(indice.doc(impronta(numeroPrima, pepe)).delete());
    }

    if (numeroDopo && trovabileDopo) {
      lavori.push(
        indice.doc(impronta(numeroDopo, pepe)).set({
          userId: evento.params.userId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }),
      );
    }

    await Promise.all(lavori);
  },
);

/**
 * **Chi cancella l'account esce dall'indice.**
 *
 * Il documento privato sparisce con il resto dei suoi dati, e il trigger qui
 * sopra lo vede: `dopo` e' vuoto, il numero nuovo non c'e', e il vecchio viene
 * tolto. Vale la pena dirlo perche' non si vede leggendo — sembra che manchi
 * una funzione apposta, e invece manca perche' non serve.
 */

/**
 * **La ricerca vera e propria.**
 *
 * Riceve dei numeri, restituisce dei profili. Quello che non fa e' altrettanto
 * importante: non dice mai *quale* numero corrispondeva a *quale* profilo, e
 * non risponde niente sui numeri che non hanno trovato nessuno. Chi manda una
 * rubrica intera non scopre di piu' di chi manda un numero solo — impara solo
 * chi, fra i suoi contatti, sta su CRASY.
 */
exports.trovaDallaRubrica = onCall(
  { secrets: [PEPE_RUBRICA] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Serve aver fatto l\'accesso.');
    }

    const mio = request.auth.uid;
    const numeri = Array.isArray(request.data?.numeri) ? request.data.numeri : [];

    if (numeri.length === 0) {
      return { trovati: [] };
    }

    if (numeri.length > MASSIMO) {
      throw new HttpsError(
        'invalid-argument',
        'Troppi numeri in una volta sola.',
      );
    }

    const pepe = PEPE_RUBRICA.value();
    const db = admin.firestore();

    // Le impronte si tengono in un insieme: una rubrica ha lo stesso numero
    // scritto tre volte — casa, lavoro, quello vecchio — e cercarlo tre volte
    // costerebbe tre letture per niente.
    const impronte = new Set();

    for (const numero of numeri) {
      const pulito = pulisci(numero);

      if (pulito) {
        impronte.add(impronta(pulito, pepe));
      }
    }

    if (impronte.size === 0) {
      return { trovati: [] };
    }

    const indice = db.collection('phoneIndex');
    const chiavi = [...impronte];
    const trovatiId = new Set();

    // `getAll` legge a blocchi: in un colpo solo si superano i limiti di
    // Firestore, e una rubrica grossa manderebbe la richiesta in errore proprio
    // per le persone che hanno piu' amici.
    for (let i = 0; i < chiavi.length; i += 300) {
      const blocco = chiavi.slice(i, i + 300).map((c) => indice.doc(c));
      const documenti = await db.getAll(...blocco);

      for (const documento of documenti) {
        const chi = documento.get('userId');

        if (chi && chi !== mio) {
          trovatiId.add(chi);
        }
      }
    }

    if (trovatiId.size === 0) {
      return { trovati: [] };
    }

    // **Chi e' gia' amico non si suggerisce.** Vedersi proporre come "forse
    // conosci" qualcuno con cui si gioca da un mese fa sembrare che l'app non
    // sappia niente di te.
    const amici = await db
      .collection('users')
      .doc(mio)
      .collection('friends')
      .get();

    for (const amico of amici.docs) {
      trovatiId.delete(amico.id);
    }

    // Nemmeno chi ti ha gia' chiesto l'amicizia: quella richiesta e' in cima
    // alla stessa schermata, con i suoi due tasti. Vederlo anche fra i
    // suggeriti vorrebbe dire due modi di rispondere alla stessa persona.
    const richieste = await db
      .collection('users')
      .doc(mio)
      .collection('friendRequests')
      .get();

    for (const richiesta of richieste.docs) {
      trovatiId.delete(richiesta.id);
    }

    const profili = [];
    const daLeggere = [...trovatiId].slice(0, 200);

    for (let i = 0; i < daLeggere.length; i += 300) {
      const blocco = daLeggere
        .slice(i, i + 300)
        .map((id) => db.collection('users').doc(id));
      const documenti = await db.getAll(...blocco);

      for (const documento of documenti) {
        if (!documento.exists) {
          continue;
        }

        // Si restituisce **il minimo per riconoscerlo e toccarlo**: nome,
        // faccia, identificativo. Niente numero di telefono di ritorno — quello
        // lo sa gia' chi ha chiesto, ed e' l'unica cosa che non va rimandata
        // indietro accoppiata a un profilo.
        profili.push({
          userId: documento.id,
          username: documento.get('username') || '',
          displayName: documento.get('displayName') || '',
          photoUrl: documento.get('photoUrl') || '',
        });
      }
    }

    logger.info('rubrica: cercati %d numeri, trovati %d profili', impronte.size,
      profili.length);

    return { trovati: profili };
  },
);
