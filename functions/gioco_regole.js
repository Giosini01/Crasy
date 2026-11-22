'use strict';

/**
 * **Le regole del gioco: sfide del giorno, traguardi, XP e livelli.**
 *
 * Qui c'e' solo la logica, senza Firebase: chi conta cosa, quando una sfida e'
 * fatta, quanti XP vale, a che livello si e'. Il server (`gioco.js`) legge e
 * scrive il database e chiede qui ogni decisione; i test la provano senza un
 * database. Cosi' la regola che assegna dei punti esiste in un posto solo.
 *
 * ## Cosa si conta, e perche' solo questo
 *
 * Solo **fatti veri che il server vede**: una foto approvata in gara, una
 * fiamma data o ricevuta, un'amicizia, un commento sotto la foto di un altro,
 * una vittoria, un giorno di gioco, la serie. Niente che si possa dichiarare
 * dal telefono, e niente che si conti aprendo una schermata.
 *
 * Fuori, di proposito: gli inviti (CRASY non registra chi ha portato chi, vedi
 * `invite_friend.dart`), le visite ai profili (si conterebbero aprendo una
 * schermata), le condivisioni su Instagram (non si possono verificare), le
 * conversazioni (non c'e' una chat). In CRASY "completare una missione" e'
 * mandarci la foto: e' la metrica `foto`.
 */

const { oggiInItalia } = require('./calendario_del_fondo');

/** Cosa si puo' contare, detto come lo leggerebbe una persona. */
const METRICHE = {
  foto: 'foto mandate in gara e approvate',
  fiammeDate: 'fiamme date alle foto degli altri',
  fiammeRicevute: 'fiamme ricevute',
  amici: 'amicizie',
  commenti: 'foto di altri commentate',
  vittorie: 'missioni vinte',
  giorniGiocati: 'giorni in cui si e\' giocato',
  serieRecord: 'giorni di fila, il record',
};

/**
 * **Le metriche che valgono come record, non come conteggio.** La serie la
 * calcola gia' il server (`aggiornaLaSerie`): qui si tiene il massimo, che non
 * scende quando la serie si rompe.
 */
const A_VALORE = new Set(['serieRecord']);

/**
 * **Le metriche che non hanno senso in una giornata**: un record di giorni di
 * fila, o i giorni giocati, non si fanno in un giorno.
 */
const SOLO_PERMANENTI = new Set(['serieRecord', 'giorniGiocati']);

/** Le icone che l'app sa disegnare. Una sconosciuta diventa la stella. */
const ICONE = ['foto', 'fiamma', 'amici', 'commento', 'coppa', 'serie', 'calendario', 'stella'];

function intero(valore, minimo, massimo, nome) {
  const numero = Number(valore);

  if (!Number.isInteger(numero) || numero < minimo || numero > massimo) {
    throw new Error(`${nome}: un numero intero da ${minimo} a ${massimo}.`);
  }

  return numero;
}

function testo(valore, massimo, nome) {
  const pulito = String(valore === undefined || valore === null ? '' : valore).trim();

  if (!pulito || pulito.length > massimo) {
    throw new Error(`${nome}: da 1 a ${massimo} caratteri.`);
  }

  return pulito;
}

function sfida(grezza, giornaliera, dove) {
  if (!grezza || typeof grezza !== 'object') {
    throw new Error(`${dove}: non e' una sfida.`);
  }

  const id = String(grezza.id || '');

  if (!/^[a-z0-9_]{2,40}$/.test(id)) {
    throw new Error(`${dove}: l'id va scritto con lettere minuscole, numeri e _ (2-40).`);
  }

  const metrica = String(grezza.metrica || '');

  if (!METRICHE[metrica]) {
    throw new Error(`${id}: la metrica "${metrica}" non esiste. Si puo' usare: ${Object.keys(METRICHE).join(', ')}.`);
  }

  if (giornaliera && SOLO_PERMANENTI.has(metrica)) {
    throw new Error(`${id}: "${metrica}" non si fa in un giorno, va fra le permanenti.`);
  }

  return {
    id,
    ...(giornaliera ? { gruppo: grezza.gruppo ? testo(grezza.gruppo, 30, `${id}.gruppo`) : metrica } : {}),
    titolo: testo(grezza.titolo, 40, `${id}.titolo`),
    descrizione: testo(grezza.descrizione, 120, `${id}.descrizione`),
    icona: ICONE.includes(grezza.icona) ? grezza.icona : 'stella',
    metrica,
    obiettivo: intero(grezza.obiettivo, 1, 100000, `${id}.obiettivo`),
    xp: intero(grezza.xp, 0, 10000, `${id}.xp`),
    attiva: grezza.attiva !== false,
  };
}

function senzaDoppioni(elenco, dove) {
  const visti = new Set();

  for (const voce of elenco) {
    if (visti.has(voce.id)) {
      throw new Error(`${dove}: l'id "${voce.id}" c'e' due volte.`);
    }

    visti.add(voce.id);
  }

  return elenco;
}

/**
 * **Le regole come devono essere, o un errore che dice cosa manca.**
 *
 * Le regole si cambiano dal pannello senza toccare il codice, quindi passano
 * tutte da qui prima di essere salvate: una soglia scritta male non deve poter
 * regalare XP a tutti, ne' bloccare il gioco a nessuno.
 */
function valida(grezze) {
  if (!grezze || typeof grezze !== 'object') {
    throw new Error('Le regole sono vuote.');
  }

  const giornaliere = grezze.giornaliere || {};
  const elenco = Array.isArray(giornaliere.elenco) ? giornaliere.elenco : [];

  if (elenco.length < 1 || elenco.length > 60) {
    throw new Error('Le sfide giornaliere vanno da 1 a 60.');
  }

  const giorno = senzaDoppioni(
    elenco.map((voce, i) => sfida(voce, true, `giornaliera ${i + 1}`)),
    'giornaliere'
  );

  const permanenti = senzaDoppioni(
    (Array.isArray(grezze.permanenti) ? grezze.permanenti : []).map((voce, i) =>
      sfida(voce, false, `permanente ${i + 1}`)
    ),
    'permanenti'
  );

  if (permanenti.length > 100) {
    throw new Error('Le sfide permanenti vanno da 0 a 100.');
  }

  const livelli = Array.isArray(grezze.livelli) ? grezze.livelli : [];

  if (livelli.length < 2 || livelli.length > 30) {
    throw new Error('I livelli vanno da 2 a 30.');
  }

  const scale = livelli.map((voce, i) => ({
    numero: i + 1,
    nome: testo(voce && voce.nome, 30, `livello ${i + 1}.nome`),
    xp: intero(voce && voce.xp, 0, 10000000, `livello ${i + 1}.xp`),
  }));

  if (scale[0].xp !== 0) {
    throw new Error('Il primo livello parte da 0 XP.');
  }

  for (let i = 1; i < scale.length; i += 1) {
    if (scale[i].xp <= scale[i - 1].xp) {
      throw new Error(`Il livello ${i + 1} deve chiedere piu' XP del livello ${i}.`);
    }
  }

  const gruppi = new Set(giorno.map((voce) => voce.gruppo));

  return {
    versione: intero(grezze.versione === undefined ? 1 : grezze.versione, 1, 1000000, 'versione'),
    giornaliere: {
      quante: intero(giornaliere.quante === undefined ? 4 : giornaliere.quante, 1, 8, 'giornaliere.quante'),
      sempre: (Array.isArray(giornaliere.sempre) ? giornaliere.sempre : [])
        .map(String)
        .filter((gruppo) => gruppi.has(gruppo)),
      elenco: giorno,
    },
    permanenti,
    livelli: scale,
  };
}

// ---------------------------------------------------------------------------
// La scelta delle sfide del giorno
// ---------------------------------------------------------------------------

/** Un numero da un testo, sempre lo stesso per lo stesso testo (FNV-1a). */
function impronta(testoDaMescolare) {
  let h = 0x811c9dc5;

  for (let i = 0; i < testoDaMescolare.length; i += 1) {
    h ^= testoDaMescolare.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }

  return h >>> 0;
}

/** Un dado che, partendo dallo stesso seme, tira sempre gli stessi numeri. */
function dado(seme) {
  let a = seme >>> 0;

  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);

    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function mescola(elenco, tira) {
  const copia = [...elenco];

  for (let i = copia.length - 1; i > 0; i -= 1) {
    const j = Math.floor(tira() * (i + 1));
    [copia[i], copia[j]] = [copia[j], copia[i]];
  }

  return copia;
}

/**
 * **Le sfide di oggi per una persona.**
 *
 * Diverse da persona a persona e da giorno a giorno, ma sempre le stesse per
 * la stessa persona nello stesso giorno: dipendono solo da chi e da quando.
 * Una per gruppo — foto, fiamme, amici... — cosi' la giornata chiede cose
 * diverse; i gruppi in `sempre` ci sono ogni giorno.
 */
function sceltaDelGiorno(uid, giorno, regole) {
  const attive = regole.giornaliere.elenco.filter((voce) => voce.attiva);
  const quante = Math.min(regole.giornaliere.quante, attive.length);
  const tira = dado(impronta(`${uid}|${giorno}`));
  const gruppi = [...new Set(attive.map((voce) => voce.gruppo))];
  const sempre = regole.giornaliere.sempre.filter((gruppo) => gruppi.includes(gruppo));
  const ordine = [...sempre, ...mescola(gruppi.filter((gruppo) => !sempre.includes(gruppo)), tira)];
  const scelte = [];

  for (const gruppo of ordine) {
    if (scelte.length >= quante) {
      break;
    }

    const delGruppo = attive.filter((voce) => voce.gruppo === gruppo);
    scelte.push(delGruppo[Math.floor(tira() * delGruppo.length)].id);
  }

  // Meno gruppi che posti: si riempie con le altre, sempre a caso ma fisso.
  for (const voce of mescola(attive.filter((v) => !scelte.includes(v.id)), tira)) {
    if (scelte.length >= quante) {
      break;
    }

    scelte.push(voce.id);
  }

  return scelte;
}

// ---------------------------------------------------------------------------
// Lo stato di una persona
// ---------------------------------------------------------------------------

function statoIniziale() {
  return {
    xp: 0,
    livello: 1,
    sfideCompletate: 0,
    contatori: {},
    completate: {},
    giorno: '',
    oggi: { scelte: [], contatori: {}, completate: {} },
  };
}

/** Il livello per una quantita' di XP: numero, nome, da dove parte e dove arriva. */
function livelloDi(xp, livelli) {
  let attuale = livelli[0];

  for (const livello of livelli) {
    if (xp >= livello.xp) {
      attuale = livello;
    }
  }

  const prossimo = livelli.find((livello) => livello.numero === attuale.numero + 1) || null;

  return {
    numero: attuale.numero,
    nome: attuale.nome,
    xpDa: attuale.xp,
    xpA: prossimo ? prossimo.xp : null,
    progresso: prossimo ? Math.min(1, (xp - attuale.xp) / (prossimo.xp - attuale.xp)) : 1,
  };
}

/**
 * **Il giorno nuovo.** Le sfide di ieri restano com'erano — fatte o no — e
 * arrivano quelle di oggi, con i contatori a zero. Chi non apre l'app per una
 * settimana non si ritrova sette giornate arretrate: si ritrova oggi.
 */
function rinnova(stato, regole, uid, oggi) {
  if (stato.giorno === oggi && stato.oggi && Array.isArray(stato.oggi.scelte)) {
    return stato;
  }

  return {
    ...statoIniziale(),
    ...stato,
    giorno: oggi,
    oggi: { scelte: sceltaDelGiorno(uid, oggi, regole), contatori: {}, completate: {} },
  };
}

/**
 * **Un evento ripetuto non conta due volte, uno annullato non conta.**
 *
 * Ogni fatto ha una chiave — "la fiamma di Anna alla foto di Bruno in quella
 * gara" — e un foglio che dice se oggi vale. Qui si decide di quanto si muove
 * il contatore quando quel fatto arriva (`attivo`) o se ne va (`!attivo`):
 *
 * - arriva la prima volta: +1, anche oggi;
 * - arriva di nuovo mentre vale gia' (il server riprova): niente;
 * - se ne va (fiamma tolta, foto ritirata): -1, e anche oggi se oggi aveva
 *   contato;
 * - torna dopo essersene andato: +1 al totale, ma **oggi solo se era contato
 *   oggi**. Togliere e rimettere la stessa fiamma il giorno dopo non fa una
 *   sfida del giorno nuova.
 */
function decidi(evento, attivo, oggi) {
  const valeva = Boolean(evento && evento.attivo === true);

  if (attivo) {
    if (valeva) {
      return { delta: 0 };
    }

    if (!evento) {
      return { delta: 1, contaOggi: true, evento: { attivo: true, giorno: oggi } };
    }

    const stessoGiorno = evento.giorno === oggi;

    return { delta: 1, contaOggi: stessoGiorno, evento: { attivo: true, giorno: evento.giorno || '' } };
  }

  if (!valeva) {
    return { delta: 0 };
  }

  return { delta: -1, contaOggi: evento.giorno === oggi, evento: { attivo: false, giorno: evento.giorno || '' } };
}

/**
 * **Un fatto entra nello stato: contatori, sfide fatte, XP, livello.**
 *
 * `delta` per i conteggi (+1, -1), `valore` per i record. Torna lo stato nuovo
 * e i premi da scrivere, ognuno con la sua chiave: quella che lo rende unico
 * per sempre (`p_...`) o per quel giorno (`g_giorno_...`). Una sfida fatta non
 * si disfa quando un contatore scende: i punti dati restano dati, ma per
 * riprenderli bisogna rifare tutto da capo con fatti nuovi.
 */
function applica({ stato, regole, uid, oggi, metrica, delta = 0, valore = null, contaOggi = true, adesso = Date.now() }) {
  const base = rinnova(stato || statoIniziale(), regole, uid, oggi);
  const nuovo = {
    ...base,
    contatori: { ...(base.contatori || {}) },
    completate: { ...(base.completate || {}) },
    oggi: {
      scelte: [...base.oggi.scelte],
      contatori: { ...(base.oggi.contatori || {}) },
      completate: { ...(base.oggi.completate || {}) },
    },
  };
  const livelloPrima = livelloDi(nuovo.xp || 0, regole.livelli).numero;

  if (valore !== null && valore !== undefined) {
    nuovo.contatori[metrica] = Math.max(nuovo.contatori[metrica] || 0, Number(valore) || 0);
  } else if (delta) {
    nuovo.contatori[metrica] = Math.max(0, (nuovo.contatori[metrica] || 0) + delta);

    if (contaOggi && !A_VALORE.has(metrica)) {
      nuovo.oggi.contatori[metrica] = Math.max(0, (nuovo.oggi.contatori[metrica] || 0) + delta);
    }
  }

  const premi = [];

  for (const id of nuovo.oggi.scelte) {
    const voce = regole.giornaliere.elenco.find((v) => v.id === id);

    if (voce && !nuovo.oggi.completate[id] && (nuovo.oggi.contatori[voce.metrica] || 0) >= voce.obiettivo) {
      nuovo.oggi.completate[id] = adesso;
      premi.push({ chiave: `g_${oggi}_${id}`, tipo: 'giornaliera', sfida: id, titolo: voce.titolo, xp: voce.xp, giorno: oggi });
    }
  }

  for (const voce of regole.permanenti) {
    if (voce.attiva && !nuovo.completate[voce.id] && (nuovo.contatori[voce.metrica] || 0) >= voce.obiettivo) {
      nuovo.completate[voce.id] = adesso;
      premi.push({ chiave: `p_${voce.id}`, tipo: 'permanente', sfida: voce.id, titolo: voce.titolo, xp: voce.xp, giorno: oggi });
    }
  }

  nuovo.xp = (nuovo.xp || 0) + premi.reduce((somma, premio) => somma + premio.xp, 0);
  nuovo.sfideCompletate = (nuovo.sfideCompletate || 0) + premi.length;
  nuovo.livello = livelloDi(nuovo.xp, regole.livelli).numero;

  return { stato: nuovo, premi, livelloPrima, livelloDopo: nuovo.livello };
}

module.exports = {
  METRICHE,
  A_VALORE,
  ICONE,
  valida,
  sceltaDelGiorno,
  statoIniziale,
  livelloDi,
  rinnova,
  decidi,
  applica,
  oggiInItalia,
};
