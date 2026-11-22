'use strict';

/**
 * **Il calendario del fondo: chi lancia cosa, a che ora, con che premio.**
 *
 * Sta in un file suo, senza Firebase, per una ragione sola: e' l'unica parte
 * del fondo che si puo' sbagliare **in silenzio**. Un conto sbagliato qui non
 * fa nessun errore: fa uscire la missione sbagliata, a nome della persona
 * sbagliata, o fa vedere nella pagina di amministrazione un programma diverso
 * da quello che poi succede. Cosi' si prova con `node --test` senza un
 * database, e la funzione a orario e l'anteprima leggono **la stessa** regola.
 */

/**
 * **A che ora parte una missione, in Italia, a seconda di quante al giorno.**
 *
 * Non le prime ore di una fila: con tre al giorno sarebbero uscite alle dieci,
 * all'una e alle quattro, e la sera — quando il telefono e' in mano a tutti —
 * non sarebbe uscito niente. Ogni numero ha le sue ore: tre sono mattina,
 * pomeriggio e sera. Durando ventiquattro ore, si chiudono alle stesse ore, e
 * in ogni momento ce ne sono aperte tante quante ne escono in un giorno.
 */
const ORARI = {
  1: [19],
  2: [13, 19],
  3: [10, 14, 19],
  4: [10, 13, 16, 19],
  5: [10, 13, 16, 19, 21],
};

/** Quante al giorno, al massimo. */
const MASSIMO_AL_GIORNO = 5;

/**
 * **Tutte le ore in cui la funzione a orario si sveglia**: a ogni ora guarda se
 * con le regole di oggi quella e' un'ora di lancio. Stanno anche nella riga
 * `schedule` di `lanciaLeMissioni`, scritte a mano: si cambiano insieme.
 */
const ORE_DI_LANCIO = [...new Set(Object.values(ORARI).flat())].sort((a, b) => a - b);

/** Le ore di lancio per `alGiorno` missioni al giorno. */
function oreDelGiorno(alGiorno) {
  return ORARI[Math.max(1, Math.min(MASSIMO_AL_GIORNO, Number(alGiorno) || 1))];
}

const UN_GIORNO = 24 * 60 * 60 * 1000;

/** Che giorno e' in Italia, scritto `2026-12-02`. */
function oggiInItalia(adesso = new Date()) {
  return adesso.toLocaleDateString('sv-SE', { timeZone: 'Europe/Rome' });
}

/** Che ora e' in Italia, da 0 a 23. */
function oraInItalia(adesso = new Date()) {
  return Number(
    adesso.toLocaleString('en-GB', {
      timeZone: 'Europe/Rome',
      hour: '2-digit',
      hourCycle: 'h23',
    })
  );
}

/** Il giorno dopo, sempre scritto `2026-12-03`. */
function giornoDopo(giorno, quanti = 1) {
  const [anno, mese, data] = giorno.split('-').map(Number);

  return new Date(Date.UTC(anno, mese - 1, data) + quanti * UN_GIORNO)
    .toISOString()
    .slice(0, 10);
}

/**
 * **L'istante vero delle dieci in Italia**, non le dieci del server.
 *
 * Il server gira all'ora di Greenwich: "le dieci" costruite li' sarebbero le
 * undici a Roma d'inverno e mezzogiorno d'estate, e la pagina di
 * amministrazione — che le rimette all'ora di chi guarda — farebbe vedere un
 * programma spostato di una o due ore rispetto a quello vero.
 */
function istanteInItalia(giorno, ora) {
  const [anno, mese, data] = giorno.split('-').map(Number);
  const comeSeFosseGreenwich = Date.UTC(anno, mese - 1, data, ora, 0, 0);
  const letto = new Date(comeSeFosseGreenwich);
  const aRoma = new Date(letto.toLocaleString('en-US', { timeZone: 'Europe/Rome' }));
  const aGreenwich = new Date(letto.toLocaleString('en-US', { timeZone: 'UTC' }));

  return comeSeFosseGreenwich - (aRoma - aGreenwich);
}

/** Da `1`, `1.5` o `"1,50"` ai centesimi. Niente di valido, niente premio. */
function centesimi(euro) {
  const numero = Number(String(euro === undefined ? '' : euro).replace(',', '.'));

  return Number.isFinite(numero) && numero > 0 ? Math.round(numero * 100) : 0;
}

/** La missione numero `indice`, girando in tondo sull'elenco. */
function missioneAl(missioni, indice) {
  return missioni.length ? missioni[indice % missioni.length] : null;
}

/**
 * Quanto mette in palio una missione: il suo `euro`, se ce l'ha, altrimenti il
 * premio del fondo, altrimenti un euro.
 */
function premioDi(missione, fondo) {
  return centesimi(missione && missione.euro) || (fondo && fondo.premioCents) || 100;
}

/** Chi tocca dopo `passi` lanci da adesso. Vuoto se non c'e' nessuno in fila. */
function autoreAl(fondo, passi) {
  const autori = (fondo && fondo.autori) || [];

  if (!autori.length) {
    return null;
  }

  return autori[((fondo.turno || 0) + passi) % autori.length];
}

/**
 * **Le prossime missioni, con ora, premio e faccia.**
 *
 * Si ferma dove si fermerebbe il server: quando i soldi non bastano per la
 * prossima, dopo `fino`, o dopo `quante`. Prima di `dal` non esce niente —
 * e' il giorno in cui l'app esce, e un calendario che parte prima mostrerebbe
 * missioni che nessuno vedrebbe.
 *
 * L'autore e' quello che tocca **se tutti sono ancora al loro posto**: se il
 * giorno del lancio un account non c'e' piu', il server passa al successivo e
 * da li' in poi il turno scorre di uno.
 */
function prossime(fondo, missioni, adesso = new Date(), quante = 60) {
  const elenco = [];

  if (!fondo || !missioni.length) {
    return elenco;
  }

  const oggi = oggiInItalia(adesso);
  const oraAdesso = oraInItalia(adesso);
  const alGiorno = Math.max(1, Math.min(MASSIMO_AL_GIORNO, fondo.alGiorno || 1));
  const orari = oreDelGiorno(alGiorno);
  const fatteOggi = fondo.giorno === oggi ? fondo.fatte || 0 : 0;
  let soldi = fondo.fondoCents || 0;
  let indice = (fondo.lanciate || 0) + (fondo.saltate || 0);
  let passi = 0;

  for (let giorni = 0; giorni < 90 && elenco.length < quante; giorni += 1) {
    const giorno = giornoDopo(oggi, giorni);

    if (fondo.fino && giorno > fondo.fino) {
      break;
    }

    if (fondo.dal && giorno < fondo.dal) {
      continue;
    }

    // Oggi: solo le ore che devono ancora suonare, e solo quante ne restano
    // sotto il tetto. Gli altri giorni: tutte le ore di `alGiorno`.
    const ore = giorni === 0
      ? orari.filter((ora) => ora > oraAdesso).slice(0, Math.max(0, alGiorno - fatteOggi))
      : orari;

    for (const ora of ore) {
      const missione = missioneAl(missioni, indice);
      const premio = premioDi(missione, fondo);

      if (premio > soldi || elenco.length >= quante) {
        return elenco;
      }

      const autore = autoreAl(fondo, passi);

      elenco.push({
        quando: istanteInItalia(giorno, ora),
        giorno,
        titolo: missione.titolo,
        consegna: missione.consegna,
        mediaKind: missione.media === 'video' ? 'video' : 'photo',
        source: missione.fonte === 'archive' ? 'archive' : 'instant',
        premioCents: premio,
        autoreId: autore ? autore.uid : '',
        autore: autore ? autore.username : '',
      });

      soldi -= premio;
      indice += 1;
      passi += 1;
    }
  }

  return elenco;
}

module.exports = {
  ORARI,
  MASSIMO_AL_GIORNO,
  ORE_DI_LANCIO,
  oreDelGiorno,
  oggiInItalia,
  oraInItalia,
  giornoDopo,
  istanteInItalia,
  centesimi,
  missioneAl,
  premioDi,
  autoreAl,
  prossime,
};
