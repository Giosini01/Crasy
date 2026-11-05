'use strict';

/**
 * **Quello che succede dopo una segnalazione o un blocco, e il filtro sui testi.**
 *
 * Apple chiede cinque cose a un'app con contenuti degli utenti (linea guida 1.2):
 * filtrare, far segnalare, far bloccare, avvisare lo sviluppatore di un blocco, e
 * intervenire sulle segnalazioni entro 24 ore. Le prime tre ci sono nell'app; qui
 * c'e' la parte che un telefono non puo' fare:
 *
 * - **una segnalazione arriva a una persona.** `segnalazioneArrivata` la confronta
 *   con il contenuto vero, la mette in coda con la sua scadenza e avvisa il team;
 * - **le 24 ore si contano.** `sollecitaLeSegnalazioni` richiama chi modera quando
 *   ne restano poche, e di nuovo quando sono passate. Non toglie niente da sola: a
 *   decidere resta una persona, come sta scritto in `admin.js`;
 * - **un blocco arriva al team, e non e' una segnalazione.** `bloccoArrivato` toglie
 *   i legami fra i due e scrive un evento in `blocchi`, da guardare. Nessuno deve
 *   decidere niente, e nessun contenuto esce per questo;
 * - **i testi passano da un elenco anche qui.** Commenti, didascalie, nomi e
 *   descrizioni erano filtrati solo sul telefono, e un telefono si puo' modificare.
 *   `filtraIlCommento` e `controllaIlProfilo` rileggono con lo stesso elenco delle
 *   missioni (`parole.js`), e solo le parole che fermano una missione tolgono un
 *   testo: le "gialle" no, perche' qui non c'e' nessuno a guardarle dopo;
 * - **la foto profilo passa da SafeSearch**, come quelle in gara. Prima non la
 *   guardava nessuno.
 */

const {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentWritten,
} = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const vision = require('@google-cloud/vision');
const { autoreDi } = require('./autori');
const { avvisaDelContenutoTolto, motivoDaiControlli } = require('./avvisi');
const missioni = require('./missioni');
const parole = require('./parole');
const posta = require('./posta');
const { registra } = require('./registro');

const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

const ORA = 60 * 60 * 1000;

/** Entro quanto si risponde a una segnalazione: e' il tetto scritto da Apple. */
const ORE_PER_DECIDERE = 24;

/** Quando si richiama chi modera, prima che il tempo finisca. */
const ORE_AL_SOLLECITO = 18;

/**
 * **Oltre questo numero al giorno una segnalazione e' sospetta.**
 *
 * Non si butta e non si nasconde: la guarda comunque una persona. Ma finisce in
 * fondo alla coda e non fa squillare nessuno: una sola persona non deve poter
 * sommergere chi modera, e soprattutto nascondere le segnalazioni vere.
 */
const SEGNALAZIONI_AL_GIORNO = 20;

/** Quanti blocchi di una stessa persona, in un giorno, arrivano via email. */
const AVVISI_DI_BLOCCO_AL_GIORNO = 10;

const STATI_APERTI = ['new', 'open', 'reviewing'];

/** Dove sono i blocchi visti dal team: li scrive e li legge solo il server. */
const BLOCCHI = 'blocchi';

/** Quante segnalazioni di una persona sono state respinte: vedi `admin.js`. */
const SEGNALANTI = 'segnalanti';

const COSE = {
  entry: 'una foto',
  comment: 'un commento',
  challenge: 'una missione',
  user: 'una persona',
};

const MOTIVI = {
  danger: 'Mette in pericolo qualcuno',
  sexual: 'Contenuto sessualmente esplicito',
  violence: 'Violenza',
  hate: 'Molestie o bullismo',
  illegal: 'Contenuto illegale',
  spam: 'Spam o frode',
  minor: 'C’è un minore',
  other: 'Altro',
};

/** Il motivo di una parola vietata, nelle parole che legge chi se la vede togliere. */
const MOTIVI_DELLE_PAROLE = {
  autolesionismo: 'pericolo',
  pericolo: 'pericolo',
  violenza: 'violenza',
  sessuale: 'sessuale',
  reato: 'illegale',
  odio: 'odio',
  volgarita: 'odio',
};

// Passate da `index.js`, che le ha gia': vedi `collega`.
let mandaAUnaPersona = async () => {};
let reasonsFromSafeSearch = () => [];

/**
 * **Quello che serve da `index.js`, che sta sopra di questo file.** Richiederlo da
 * qui farebbe un giro: `index.js` carica questo modulo.
 */
function collega(funzioni) {
  mandaAUnaPersona = funzioni.mandaAUnaPersona;
  reasonsFromSafeSearch = funzioni.reasonsFromSafeSearch;
}

function oggi() {
  return new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Rome' });
}

function ms(valore) {
  return valore && typeof valore.toMillis === 'function' ? valore.toMillis() : null;
}

/** Quando scade una segnalazione arrivata a [millisecondi]. */
function scadenzaDi(millisecondi) {
  return millisecondi + ORE_PER_DECIDERE * ORA;
}

/** Aggiunge uno al contatore di oggi, e torna quanto fa. Non lancia. */
async function contaOggi(chiave) {
  const riferimento = db.collection(missioni.LIMITI).doc(`${chiave}_${oggi()}`);

  try {
    return await db.runTransaction(async (t) => {
      const adesso = await t.get(riferimento);
      const quanti = (adesso.exists ? adesso.get('quanti') || 0 : 0) + 1;

      t.set(riferimento, { quanti }, { merge: true });

      return quanti;
    });
  } catch (errore) {
    logger.warn('contatore non aggiornato', { chiave, errore: String(errore).slice(0, 200) });

    return 0;
  }
}

/**
 * **Avvisa il team: una riga sul telefono di chi modera, e un'email.**
 *
 * Le due strade insieme, e nessuna delle due deve poter far fallire il resto: la
 * segnalazione e' gia' scritta, e il pannello la mostra comunque.
 */
async function avvisaIlTeam({ frase, oggetto, righe, dove }) {
  try {
    const chi = await db.collection(missioni.IMPOSTAZIONI).doc('amministratori').get();
    const amministratori = (chi.exists && chi.get('uids')) || [];

    await Promise.all(
      amministratori.map((uid) =>
        mandaAUnaPersona(uid, frase, { kind: 'moderazione', challengeId: '' }).catch((errore) => {
          logger.warn('avviso a chi modera non partito', { uid, errore });
        })
      )
    );
  } catch (errore) {
    logger.warn('amministratori non letti', { errore: String(errore).slice(0, 200) });
  }

  try {
    await posta.spedisci({
      from: '"CRASY" <' + posta.CASELLA + '>',
      to: 'info@crasyapp.com',
      subject: oggetto,
      text: [...righe, `https://crasyapp.com/admin/#/${dove}`].filter(Boolean).join('\n\n'),
    });
  } catch (errore) {
    logger.error('email a chi modera non partita', errore);
  }
}

// ---------------------------------------------------------------------------
// Le segnalazioni
// ---------------------------------------------------------------------------

/**
 * **Quello che c'e' davvero dietro una segnalazione.**
 *
 * Quello che arriva dal telefono non e' fidato: chi segnala potrebbe scrivere il
 * nome di una persona diversa da chi ha pubblicato la foto, e l'amministratore
 * finirebbe per sospendere chi non c'entra. Qui si legge il contenuto vero, mentre
 * esiste ancora: le foto vengono cancellate dopo quarantotto ore, e una prova che
 * sparisce non serve a giudicare.
 */
async function leggiIlContenuto(dati) {
  const challengeId = String(dati.challengeId || '');
  const entryId = String(dati.entryId || '');
  const commentId = String(dati.commentId || '');
  const gara = challengeId ? db.collection('challenges').doc(challengeId) : null;

  if (dati.kind === 'comment' && gara && entryId && commentId) {
    const commento = await gara.collection('entries').doc(entryId).collection('comments').doc(commentId).get();

    return commento.exists
      ? {
          autoreId: String(commento.get('userId') || ''),
          autoreNome: String(commento.get('authorName') || ''),
          testo: String(commento.get('text') || ''),
        }
      : null;
  }

  if (dati.kind === 'entry' && gara && entryId) {
    const foto = await gara.collection('entries').doc(entryId).get();

    if (foto.exists) {
      return {
        autoreId: String(foto.get('userId') || ''),
        autoreNome: String(foto.get('authorName') || ''),
        mediaUrl: String(foto.get('mediaUrl') || ''),
        mediaKind: String(foto.get('mediaKind') || 'photo'),
        titolo: String(foto.get('challengeTitle') || ''),
        testo: String(foto.get('caption') || ''),
      };
    }

    // La partecipazione non c'e' piu', ma la foto del vincitore resta sulla gara.
    const finita = await gara.get();

    if (finita.exists && finita.get('winnerEntryId') === entryId) {
      return {
        autoreId: String(finita.get('winnerUserId') || ''),
        autoreNome: String(finita.get('winnerUsername') || ''),
        mediaUrl: String(finita.get('winnerMediaUrl') || ''),
        mediaKind: String(finita.get('winnerMediaKind') || 'photo'),
        titolo: String(finita.get('title') || ''),
      };
    }

    return null;
  }

  if (dati.kind === 'challenge' && gara) {
    const missione = await gara.get();

    return missione.exists
      ? {
          // Anche di una missione anonima: chi modera deve sapere chi chiede cosa.
          autoreId: await autoreDi(missione),
          autoreNome: String(missione.get('createdByUsername') || ''),
          titolo: String(missione.get('title') || ''),
          testo: String(missione.get('brief') || ''),
        }
      : null;
  }

  if (dati.kind === 'user' && dati.reportedUserId) {
    const persona = await db.collection('users').doc(String(dati.reportedUserId)).get();

    return persona.exists
      ? {
          autoreId: persona.id,
          autoreNome: String(persona.get('username') || ''),
          mediaUrl: String(persona.get('photoUrl') || ''),
          testo: String(persona.get('bio') || ''),
        }
      : null;
  }

  return null;
}

/** Il lavoro di `segnalazioneArrivata`, senza Firebase attorno: si prova da solo. */
async function accogliLaSegnalazione(riferimento, dati) {
  const adesso = ms(dati.createdAt) || Date.now();
  const contenuto = await leggiIlContenuto(dati).catch((errore) => {
    logger.warn('contenuto segnalato non letto', { errore: String(errore).slice(0, 200) });

    return null;
  });
  const quante = await contaOggi(`segnalazioni_${dati.reporterId}`);
  const sospetta = quante > SEGNALAZIONI_AL_GIORNO;

  await riferimento.update({
    scadeIl: Timestamp.fromMillis(scadenzaDi(adesso)),
    sospetta,
    ...(contenuto ? { verificato: contenuto } : {}),
    // **Chi l'ha pubblicato lo dice il contenuto, non chi segnala.**
    ...(contenuto && contenuto.autoreId ? { reportedUserId: contenuto.autoreId } : {}),
  });

  if (sospetta) {
    logger.warn('troppe segnalazioni da una persona', { reporterId: dati.reporterId, quante });

    return { sospetta };
  }

  const motivo = MOTIVI[dati.reason] || 'Altro';
  const cosa = COSE[dati.kind] || 'un contenuto';
  const autore = (contenuto && contenuto.autoreNome) || dati.reportedUsername || '';
  const titolo = (contenuto && contenuto.titolo) || dati.challengeTitle || '';

  await avvisaIlTeam({
    frase: `Hanno segnalato ${cosa}: ${motivo}`,
    oggetto: `Segnalazione: ${motivo} (${cosa})`,
    dove: 'segnalazioni',
    righe: [
      `Hanno segnalato ${cosa}: ${motivo}.`,
      autore ? `Di: @${autore}` : '',
      titolo ? `Missione: ${titolo}` : '',
      dati.note ? `Nota di chi segnala: ${dati.note}` : '',
      `Va guardata entro ${ORE_PER_DECIDERE} ore.`,
    ],
  });

  return { sospetta };
}

const segnalazioneArrivata = onDocumentCreated(
  {
    document: 'reports/{reportId}',
    secrets: [posta.SMTP_PASSWORD, posta.RESEND_API_KEY],
  },
  async (event) => {
    const dati = event.data?.data();

    if (dati) {
      await accogliLaSegnalazione(event.data.ref, dati);
    }
  }
);

/**
 * **Le 24 ore.** Passa ogni ora sulle segnalazioni aperte, e scrive a chi modera
 * due volte per ognuna: quando sta per scadere, e quando e' scaduta.
 *
 * I due segni sulla segnalazione servono a non scrivere ogni ora le stesse cose:
 * un avviso che si ripete smette di essere letto. Torna quante ne ha trovate.
 */
async function sollecita(adesso = Date.now()) {
  const aperte = await db
    .collection('reports')
    .where('status', 'in', STATI_APERTI)
    .limit(500)
    .get();

  const scadute = [];
  const inScadenza = [];

  for (const doc of aperte.docs) {
    const arrivata = ms(doc.get('createdAt'));

    if (!arrivata) {
      continue;
    }

    const eta = adesso - arrivata;

    if (eta >= ORE_PER_DECIDERE * ORA) {
      if (doc.get('sollecitoScaduta') !== true) {
        scadute.push(doc);
      }
    } else if (eta >= ORE_AL_SOLLECITO * ORA && doc.get('sollecitoInScadenza') !== true) {
      inScadenza.push(doc);
    }
  }

  if (scadute.length === 0 && inScadenza.length === 0) {
    return { scadute: 0, inScadenza: 0 };
  }

  const scrittura = db.batch();

  scadute.forEach((doc) =>
    scrittura.update(doc.ref, { sollecitoScaduta: true, sollecitoInScadenza: true })
  );
  inScadenza.forEach((doc) => scrittura.update(doc.ref, { sollecitoInScadenza: true }));
  await scrittura.commit();

  const pezzi = [
    scadute.length ? `${scadute.length} oltre le ${ORE_PER_DECIDERE} ore` : '',
    inScadenza.length ? `${inScadenza.length} in scadenza` : '',
  ].filter(Boolean);
  const frase = `Segnalazioni da guardare: ${pezzi.join(', ')}`;

  await avvisaIlTeam({
    frase,
    oggetto: frase,
    dove: 'segnalazioni',
    righe: [
      frase + '.',
      `Apple chiede di intervenire entro ${ORE_PER_DECIDERE} ore: rimuovere il contenuto e, ` +
        'se serve, sospendere o espellere chi l\'ha pubblicato.',
    ],
  });

  return { scadute: scadute.length, inScadenza: inScadenza.length };
}

const sollecitaLeSegnalazioni = onSchedule(
  {
    schedule: 'every 60 minutes',
    timeZone: 'Europe/Rome',
    secrets: [posta.SMTP_PASSWORD, posta.RESEND_API_KEY],
  },
  async () => {
    await sollecita();
  }
);

// ---------------------------------------------------------------------------
// I blocchi
// ---------------------------------------------------------------------------

/**
 * **Fra due persone che si sono bloccate non resta niente.** Amicizia, chi segue
 * chi, richieste in sospeso, in tutte e due le direzioni: con una scrittura sola,
 * perche' `contaFollowerAmici` rimette fra i follower chi segue ancora, e se
 * trovasse la riga `following` ancora li' rimetterebbe il legame appena tolto.
 */
async function togliILegami(uno, altro) {
  const utenti = db.collection('users');
  const scrittura = db.batch();
  const profili = await db.getAll(utenti.doc(uno), utenti.doc(altro));

  for (const [profilo, b] of [
    [profili[0], altro],
    [profili[1], uno],
  ]) {
    scrittura.delete(profilo.ref.collection('friends').doc(b));
    scrittura.delete(profilo.ref.collection('following').doc(b));
    scrittura.delete(profilo.ref.collection('friendRequests').doc(b));

    // Solo se c'era: scrivere sul profilo di chi ha chiuso l'account lo farebbe
    // rinascere vuoto.
    const seguiti = profilo.exists ? profilo.get('seguiti') : null;

    if (Array.isArray(seguiti) && seguiti.includes(b)) {
      scrittura.update(profilo.ref, { seguiti: FieldValue.arrayRemove(b) });
    }
  }

  await scrittura.commit();
}

/** Il lavoro di `bloccoArrivato`, senza Firebase attorno: si prova da solo. */
async function accogliIlBlocco(userId, altroId, dati) {
  await togliILegami(userId, altroId);

  const [chi, altro] = await db.getAll(
    db.collection('users').doc(userId),
    db.collection('users').doc(altroId)
  );
  const bloccaNome = String(chi.get('username') || '');
  const bloccatoNome = String(altro.get('username') || '');
  const eventi = db.collection(BLOCCHI);

  await eventi.doc(`${userId}__${altroId}`).set({
    bloccaId: userId,
    bloccaNome,
    bloccatoId: altroId,
    bloccatoNome,
    // Dov'era chi ha bloccato: dice cosa l'ha fatto scattare. Arriva dal telefono,
    // e serve a guardare, non a decidere.
    origine: String(dati.origine || ''),
    challengeId: String(dati.challengeId || ''),
    entryId: String(dati.entryId || ''),
    commentId: String(dati.commentId || ''),
    stato: 'nuovo',
    createdAt: FieldValue.serverTimestamp(),
  });

  const contro = await eventi
    .where('bloccatoId', '==', altroId)
    .count()
    .get()
    .then((conto) => conto.data().count)
    .catch(() => 0);

  // **Chi blocca non deve poter riempire la casella di chi modera.** Oltre un
  // certo numero al giorno il blocco resta valido e l'evento resta nel pannello,
  // ma non parte un'email per ognuno.
  if ((await contaOggi(`blocchi_${userId}`)) > AVVISI_DI_BLOCCO_AL_GIORNO) {
    return { contro };
  }

  const frase = `@${bloccaNome} ha bloccato @${bloccatoNome}`;

  await avvisaIlTeam({
    frase,
    oggetto: `Blocco: ${frase}`,
    dove: 'blocchi',
    righe: [
      `${frase}.`,
      contro > 1 ? `In tutto, ${contro} persone hanno bloccato @${bloccatoNome}.` : '',
      'Non è una segnalazione: nessun contenuto è stato toccato. Guarda se c’è qualcosa ' +
        'che non va.',
    ],
  });

  return { contro };
}

const bloccoArrivato = onDocumentCreated(
  {
    document: 'users/{userId}/blocked/{altroId}',
    secrets: [posta.SMTP_PASSWORD, posta.RESEND_API_KEY],
  },
  async (event) => {
    await accogliIlBlocco(event.params.userId, event.params.altroId, event.data?.data() || {});
  }
);

/** Lo sblocco resta scritto sull'evento: il team deve sapere che non vale piu'. */
const bloccoTolto = onDocumentDeleted('users/{userId}/blocked/{altroId}', async (event) => {
  const { userId, altroId } = event.params;

  try {
    await db
      .collection(BLOCCHI)
      .doc(`${userId}__${altroId}`)
      .update({ sbloccatoIl: FieldValue.serverTimestamp() });
  } catch (errore) {
    // Un blocco di prima che ci fossero gli eventi: non c'e' niente da aggiornare.
    if (errore.code !== 5) {
      logger.warn('sblocco non segnato', { userId, altroId, errore: String(errore).slice(0, 200) });
    }
  }
});

// ---------------------------------------------------------------------------
// Il filtro sui testi e sulla foto profilo
// ---------------------------------------------------------------------------

/** La prima parola che ferma questi testi, o `null`. Un guasto non toglie niente. */
async function parolaVietata(testi) {
  try {
    return parole.controlla(testi, await missioni.leggiImpostazioni()).rossa;
  } catch (errore) {
    logger.error('testo non controllato', errore);

    return null;
  }
}

function motivoDellaParola(rossa) {
  return MOTIVI_DELLE_PAROLE[rossa.categoria] || 'altro';
}

/** Il lavoro di `filtraIlCommento`, senza Firebase attorno. Torna se l'ha tolto. */
async function filtraUnCommento(riferimento, dati) {
  const rossa = await parolaVietata([dati.text]);

  if (!rossa) {
    return false;
  }

  await riferimento.delete();

  const motivo = motivoDellaParola(rossa);

  await avvisaDelContenutoTolto(String(dati.userId || ''), {
    cosa: 'commento',
    id: riferimento.id,
    motivo,
    automatico: true,
  });
  await registra('automatico', 'togliCommento', {
    uid: String(dati.userId || ''),
    testo: String(dati.text || '').slice(0, 300),
    parola: rossa.termine,
  });

  return true;
}

const filtraIlCommento = onDocumentCreated(
  'challenges/{challengeId}/entries/{entryId}/comments/{commentId}',
  async (event) => {
    if (event.data) {
      await filtraUnCommento(event.data.ref, event.data.data() || {});
    }
  }
);

/**
 * **La didascalia di una foto appena arrivata.** La foto puo' andare benissimo:
 * si toglie il testo, e la foto resta in gara. La chiama `controllaPartecipazione`.
 */
async function controllaLaDidascalia(partecipazione) {
  const didascalia = String(partecipazione.get('caption') || '').trim();

  if (!didascalia) {
    return false;
  }

  const rossa = await parolaVietata([didascalia]);

  if (!rossa) {
    return false;
  }

  await partecipazione.ref.update({ caption: FieldValue.delete() });
  await avvisaDelContenutoTolto(String(partecipazione.get('userId') || ''), {
    cosa: 'didascalia',
    id: partecipazione.ref.parent.parent.id,
    motivo: motivoDellaParola(rossa),
    automatico: true,
  });
  await registra('automatico', 'togliTesto', {
    uid: String(partecipazione.get('userId') || ''),
    cosa: 'didascalia',
    testo: didascalia.slice(0, 300),
    parola: rossa.termine,
  });

  return true;
}

/** Il percorso di un file dentro il suo indirizzo: `.../v0/b/{magazzino}/o/{percorso}?...`. */
function fileDellIndirizzo(indirizzo) {
  const trovato = String(indirizzo || '').match(/\/v0\/b\/([^/]+)\/o\/([^?]+)/);

  if (!trovato) {
    return null;
  }

  try {
    return { magazzino: decodeURIComponent(trovato[1]), percorso: decodeURIComponent(trovato[2]) };
  } catch (errore) {
    return null;
  }
}

/** Cosa c'e' da togliere dal profilo di [uid], e perche'. Non lancia. */
async function guardaLaFotoProfilo(uid, indirizzo) {
  const file = fileDellIndirizzo(indirizzo);

  // **Un indirizzo che non e' il suo file non e' una foto che si puo' controllare.**
  // L'app scrive solo quello: chi ne scrive un altro sta provando a passare dietro al
  // controllo, con un'immagine ospitata chissa' dove.
  if (!file || !file.percorso.startsWith(`profiles/${uid}/`)) {
    return { motivi: ['file diverso da quello dichiarato'], file: null };
  }

  const client = new vision.ImageAnnotatorClient();
  const [risultato] = await client.safeSearchDetection(`gs://${file.magazzino}/${file.percorso}`);

  return { motivi: reasonsFromSafeSearch(risultato.safeSearchAnnotation), file };
}

/**
 * **Quello che scrive una persona di se': nome, descrizione, foto.**
 *
 * Si guarda solo quando uno dei tre cambia: questo documento si aggiorna spesso
 * (l'ultima visita, i contatori), e per tutto il resto la funzione esce subito.
 *
 * Non si richiama da sola in giro: quello che scrive non cambia niente che debba
 * essere ricontrollato, e un nome sostituito passa dal filtro senza fermarsi.
 */
async function controllaUnProfilo(riferimento, prima, dopo) {
  const uid = riferimento.id;

  // L'account ufficiale lo scriviamo noi.
  if (uid === 'crasy') {
    return {};
  }

  const cambiato = (campo) => (prima ? prima[campo] : undefined) !== dopo[campo];
  const correzioni = {};
  const esito = {};
  const nome = String(dopo.username || '');
  const bio = String(dopo.bio || '');
  const foto = String(dopo.photoUrl || '');

  if (cambiato('username') && nome) {
    const rossa = await parolaVietata([nome]);

    if (rossa) {
      // Il nome non si puo' lasciare vuoto: ne serve uno, e deve essere unico.
      correzioni.username = `utente_${uid.slice(0, 8).toLowerCase()}`;
      esito.nome = true;

      await avvisaDelContenutoTolto(uid, {
        cosa: 'nome',
        id: 'nome',
        motivo: motivoDellaParola(rossa),
        automatico: true,
      });
      await registra('automatico', 'togliTesto', { uid, cosa: 'nome', testo: nome, parola: rossa.termine });
    }
  }

  if (cambiato('bio') && bio) {
    const rossa = await parolaVietata([bio]);

    if (rossa) {
      correzioni.bio = '';
      esito.descrizione = true;

      await avvisaDelContenutoTolto(uid, {
        cosa: 'descrizione',
        id: 'descrizione',
        motivo: motivoDellaParola(rossa),
        automatico: true,
      });
      await registra('automatico', 'togliTesto', {
        uid,
        cosa: 'descrizione',
        testo: bio.slice(0, 300),
        parola: rossa.termine,
      });
    }
  }

  if (cambiato('photoUrl') && foto) {
    try {
      const { motivi, file } = await guardaLaFotoProfilo(uid, foto);

      if (motivi.length > 0) {
        correzioni.photoUrl = FieldValue.delete();
        correzioni.photoStoragePath = FieldValue.delete();
        esito.foto = true;

        if (file) {
          await admin
            .storage()
            .bucket(file.magazzino)
            .file(file.percorso)
            .delete()
            .catch((errore) => {
              logger.warn('foto profilo non cancellata', { uid, errore: String(errore).slice(0, 200) });
            });
        }

        await avvisaDelContenutoTolto(uid, {
          cosa: 'fotoProfilo',
          id: 'fotoProfilo',
          motivo: motivoDaiControlli(motivi),
          automatico: true,
        });
        await registra('automatico', 'togliFotoProfilo', { uid, motivi });
      }
    } catch (errore) {
      // **Un guasto nostro non toglie la foto a nessuno.** Resta nei log, e chi la
      // trova sbagliata la segnala dal profilo.
      logger.error('foto profilo non controllata', { uid, errore: String(errore).slice(0, 300) });
    }
  }

  if (Object.keys(correzioni).length > 0) {
    await riferimento.update(correzioni);
  }

  return esito;
}

const controllaIlProfilo = onDocumentWritten('users/{userId}', async (event) => {
  const dopo = event.data?.after;

  if (!dopo || !dopo.exists) {
    return;
  }

  const prima = event.data.before;
  const datiPrima = prima && prima.exists ? prima.data() : null;
  const datiDopo = dopo.data();

  if (
    datiPrima &&
    datiPrima.username === datiDopo.username &&
    datiPrima.bio === datiDopo.bio &&
    datiPrima.photoUrl === datiDopo.photoUrl
  ) {
    return;
  }

  await controllaUnProfilo(dopo.ref, datiPrima, datiDopo);
});

module.exports = {
  BLOCCHI,
  SEGNALANTI,
  ORE_PER_DECIDERE,
  STATI_APERTI,
  SEGNALAZIONI_AL_GIORNO,
  scadenzaDi,
  collega,
  fileDellIndirizzo,
  // Le funzioni vere.
  segnalazioneArrivata,
  sollecitaLeSegnalazioni,
  bloccoArrivato,
  bloccoTolto,
  filtraIlCommento,
  controllaIlProfilo,
  // Per `controllaPartecipazione` e per le prove.
  controllaLaDidascalia,
  accogliLaSegnalazione,
  accogliIlBlocco,
  sollecita,
  filtraUnCommento,
  controllaUnProfilo,
};
