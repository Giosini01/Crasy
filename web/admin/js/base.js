/*
 * **Quello che serve a tutte le sezioni del pannello.**
 *
 * Questa pagina non legge il database: chiama delle funzioni sul server, e sono loro
 * a guardare il permesso di amministratore dentro il gettone firmato da Firebase. Il
 * sorgente si puo' leggere senza che succeda niente: qui non c'e' nessun segreto, e
 * la configurazione qui sotto identifica il progetto, non autorizza nessuno.
 *
 * **Tutto quello che si vede qui lo ha scritto qualcun altro.** Titoli, nomi, bio:
 * chiunque abbia un account puo' provare a metterci dentro del codice, e questa e' la
 * pagina da cui si tolgono missioni e si sospendono persone. Per questo l'HTML si
 * compone solo con `html`, che ripulisce da solo ogni valore: scordarselo in un punto
 * non e' possibile, perche' per non ripulire bisogna chiederlo.
 */
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js';
import { connectAuthEmulator, getAuth } from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js';
import {
  connectFunctionsEmulator,
  getFunctions,
  httpsCallable,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-functions.js';

/** Sul proprio computer si parla con gli emulatori: mai con i dati veri. */
const IN_PROVA = location.hostname === 'localhost' || location.hostname === '127.0.0.1';

const app = initializeApp({
  apiKey: 'AIzaSyBU4t2vSi7fv9T3J3iUB2cylopQ5GONwrA',
  authDomain: 'crasyapp.com',
  projectId: IN_PROVA ? 'demo-crasy' : 'daily-dating-app',
  storageBucket: 'daily-dating-app.firebasestorage.app',
  messagingSenderId: '781052311292',
  appId: '1:781052311292:web:4e9ed36cc12836f6264979',
});

export const auth = getAuth(app);

// La stessa regione delle funzioni. Sbagliarla non da' un errore chiaro: da' un
// rifiuto di rete, che somiglia a tutto tranne che alla sua causa.
const functions = getFunctions(app, 'europe-west8');

if (IN_PROVA) {
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  connectFunctionsEmulator(functions, '127.0.0.1', 5001);
}

/** Chiama una funzione del server e torna solo i dati. */
export async function chiama(nome, dati = {}) {
  const funzione = httpsCallable(functions, nome, { timeout: 120000 });
  const esito = await funzione(dati);

  return esito.data;
}

/** Il pannello: una porta sola sul server, vedi `functions/pannello.js`. */
export function pannello(azione, dati = {}) {
  return chiama('adminPannello', { azione, ...dati });
}

// ---------------------------------------------------------------------------
// Comporre l'HTML senza fidarsi di niente
// ---------------------------------------------------------------------------

class Html {
  constructor(testo) {
    this.testo = testo;
  }

  toString() {
    return this.testo;
  }
}

const SEGNI = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;', '`': '&#96;' };

function ripulisci(valore) {
  if (valore === null || valore === undefined || valore === false) {
    return '';
  }

  if (valore instanceof Html) {
    return valore.testo;
  }

  if (Array.isArray(valore)) {
    return valore.map(ripulisci).join('');
  }

  return String(valore).replace(/[&<>"'`]/g, (segno) => SEGNI[segno]);
}

/** ``html`<b>${nome}</b>` ``: ogni valore si ripulisce, tranne un altro `html`. */
export function html(pezzi, ...valori) {
  let uscita = pezzi[0];

  valori.forEach((valore, i) => {
    uscita += ripulisci(valore) + pezzi[i + 1];
  });

  return new Html(uscita);
}

/** Per i frammenti scritti da noi, senza niente che arrivi da fuori. */
export function fidato(testo) {
  return new Html(testo);
}

/** Solo indirizzi veri: `javascript:` in un `href` eseguirebbe del codice al clic. */
export function indirizzo(url) {
  const testo = String(url || '');

  return /^https?:\/\//i.test(testo) ? testo : '';
}

export function metti(elemento, contenuto) {
  elemento.innerHTML = ripulisci(contenuto);
}

// ---------------------------------------------------------------------------
// Numeri, date
// ---------------------------------------------------------------------------

export function euro(centesimi) {
  if (centesimi === null || centesimi === undefined) {
    return '—';
  }

  const valore = Math.abs(centesimi) / 100;
  const scritto = valore.toLocaleString('it-IT', {
    minimumFractionDigits: Number.isInteger(valore) ? 0 : 2,
    maximumFractionDigits: 2,
  });

  return `${centesimi < 0 ? '−' : ''}€${scritto}`;
}

/**
 * **I dollari, con i decimali che servono.** Il modello costa frazioni di centesimo: con
 * due decimali si leggerebbe sempre "$0,00", che sembra gratis e non lo e'.
 */
export function dollari(valore) {
  if (valore === null || valore === undefined) {
    return '—';
  }

  const decimali = valore === 0 ? 2 : valore < 1 ? 4 : 2;

  return `$${Number(valore).toLocaleString('it-IT', {
    minimumFractionDigits: decimali,
    maximumFractionDigits: decimali,
  })}`;
}

export function numero(valore) {
  return valore === null || valore === undefined ? '—' : Number(valore).toLocaleString('it-IT');
}

/** `1 prelievo`, `3 prelievi`. */
export function quanti(valore, uno, tanti) {
  return `${numero(valore)} ${valore === 1 ? uno : tanti}`;
}

export function quando(ms) {
  if (!ms) {
    return '—';
  }

  return new Date(ms).toLocaleString('it-IT', {
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function giorno(ms) {
  return ms
    ? new Date(ms).toLocaleDateString('it-IT', { day: 'numeric', month: 'long', year: 'numeric' })
    : '—';
}

export function fa(ms) {
  if (!ms) {
    return 'mai';
  }

  const minuti = Math.round((Date.now() - ms) / 60000);

  if (minuti < 1) return 'adesso';
  if (minuti < 60) return `${minuti} min fa`;
  if (minuti < 60 * 24) return `${Math.round(minuti / 60)} h fa`;

  return `${Math.round(minuti / (60 * 24))} g fa`;
}

export function restano(ms) {
  if (!ms) {
    return '—';
  }

  const minuti = Math.round((ms - Date.now()) / 60000);

  if (minuti <= 0) return 'finita';
  if (minuti < 60) return `${minuti} min`;

  return `${Math.floor(minuti / 60)} h ${minuti % 60} min`;
}

export function durata(minuti) {
  if (!minuti) return '—';
  if (minuti < 60) return `${minuti} min`;

  return `${Math.round(minuti / 60)} h`;
}

// ---------------------------------------------------------------------------
// Parlare con chi guarda
// ---------------------------------------------------------------------------

const scatola = () => document.getElementById('messaggi');

export function dillo(testo, { errore = false } = {}) {
  const nodo = document.createElement('div');

  nodo.className = `messaggio${errore ? ' messaggio--errore' : ''}`;
  nodo.textContent = testo;
  scatola().appendChild(nodo);
  setTimeout(() => nodo.remove(), errore ? 7000 : 3500);
}

/** La frase di un errore del server: quelle di `HttpsError` sono gia' scritte per chi legge. */
export function frase(errore) {
  const testo = errore && errore.message;

  if (!testo || testo === 'internal' || testo === 'INTERNAL') {
    return 'Il server non ha risposto bene. Riprova, e se capita ancora guarda i log.';
  }

  return testo;
}

export function dilloErrore(errore) {
  console.error(errore);
  dillo(frase(errore), { errore: true });
}

export const SOSPENSIONI = [
  ['', 'Senza sospendere'],
  ['1', 'Sospendi 1 giorno'],
  ['7', 'Sospendi 7 giorni'],
  ['30', 'Sospendi 30 giorni'],
  ['0', 'Sospendi per sempre'],
];

/**
 * **Una domanda prima di fare una cosa.** Dice cosa succede davvero, e se serve chiede
 * il motivo e la sospensione. Torna `null` se ci si ripensa.
 */
export function chiedi({
  titolo,
  testo = '',
  tasto = 'Conferma',
  pericolo = false,
  motivo = null,
  sospensione = false,
  conferma = null,
}) {
  const finestra = document.getElementById('domanda');

  metti(
    finestra,
    html`<form method="dialog">
      <h2>${titolo}</h2>
      ${testo ? html`<p>${testo}</p>` : ''}
      ${motivo
        ? html`<div>
            <label for="domandaMotivo">${motivo.etichetta || 'Motivo'}</label>
            ${motivo.scelte
              ? html`<div class="scelte-motivo" style="margin-bottom:8px">
                  ${motivo.scelte.map(
                    (s) => html`<button type="button" class="scheda" data-riempi="${s}">${s}</button>`
                  )}
                </div>`
              : ''}
            <textarea id="domandaMotivo" maxlength="500" ${motivo.obbligatorio ? fidato('required') : ''}>${motivo.iniziale || ''}</textarea>
          </div>`
        : ''}
      ${sospensione
        ? html`<div>
            <label for="domandaSospensione">E chi l'ha scritta?</label>
            <select id="domandaSospensione">
              ${SOSPENSIONI.map(([v, t]) => html`<option value="${v}">${t}</option>`)}
            </select>
          </div>`
        : ''}
      ${conferma
        ? html`<div>
            <label for="domandaConferma">${conferma.etichetta}</label>
            <input id="domandaConferma" type="text" autocomplete="off">
          </div>`
        : ''}
      <div class="comandi">
        <button type="button" class="tasto" value="no" data-chiudi>Annulla</button>
        <button type="submit" class="tasto ${pericolo ? 'tasto--rosso' : 'tasto--nero'}" value="si">${tasto}</button>
      </div>
    </form>`
  );

  return new Promise((risolvi) => {
    const modulo = finestra.querySelector('form');
    const campoMotivo = finestra.querySelector('#domandaMotivo');
    const campoSospensione = finestra.querySelector('#domandaSospensione');
    const campoConferma = finestra.querySelector('#domandaConferma');
    let esito = null;

    finestra.querySelectorAll('[data-riempi]').forEach((scelta) => {
      scelta.addEventListener('click', () => {
        campoMotivo.value = scelta.dataset.riempi;
        campoMotivo.focus();
      });
    });

    finestra.querySelector('[data-chiudi]').addEventListener('click', () => finestra.close());

    modulo.addEventListener('submit', (evento) => {
      if (campoMotivo && motivo.obbligatorio && !campoMotivo.value.trim()) {
        evento.preventDefault();
        campoMotivo.focus();

        return;
      }

      // **Una cosa da cui non si torna indietro si conferma scrivendo**, non premendo un
      // tasto: un tasto si preme anche senza leggere.
      if (campoConferma && campoConferma.value.trim().toLowerCase() !== conferma.atteso.toLowerCase()) {
        evento.preventDefault();
        campoConferma.focus();

        return;
      }

      const scelta = campoSospensione ? campoSospensione.value : '';

      esito = {
        motivo: campoMotivo ? campoMotivo.value.trim() : '',
        sospendiGiorni: scelta === '' ? null : Number(scelta),
        conferma: campoConferma ? campoConferma.value.trim() : '',
      };
    });

    finestra.addEventListener('close', () => risolvi(esito), { once: true });
    finestra.showModal();
  });
}

/**
 * **I tasti di una sezione, da un punto solo.** Ogni tasto dice cosa fa con `data-fai`;
 * mentre lavora resta spento, e se va storto l'errore si legge a schermo. Un tasto che
 * non fa niente e non spiega si preme tre volte.
 */
export function tasti(radice, mappa) {
  radice.onclick = async (evento) => {
    const tasto = evento.target.closest('[data-fai]');

    if (!tasto || !radice.contains(tasto)) {
      return;
    }

    const azione = mappa[tasto.dataset.fai];

    if (!azione) {
      return;
    }

    evento.preventDefault();
    tasto.disabled = true;

    try {
      await azione(tasto.dataset, tasto);
    } catch (errore) {
      dilloErrore(errore);
    } finally {
      if (tasto.isConnected) {
        tasto.disabled = false;
      }
    }
  };
}

/** Un riquadro che carica per conto suo: se fallisce lo dice li', e gli altri vanno avanti. */
export async function caricaIn(elemento, lavoro) {
  metti(elemento, html`<p class="carico">Carico…</p>`);

  try {
    await lavoro();
  } catch (errore) {
    console.error(errore);
    metti(elemento, html`<p class="errore">${frase(errore)}</p>`);
  }
}

export function testata(titolo, sotto) {
  return html`<header class="testata">
    <div>
      <h1>${titolo}<span class="rosso">.</span></h1>
      ${sotto ? html`<p class="testata__sotto">${sotto}</p>` : ''}
    </div>
  </header>`;
}

export const FIAMMA = fidato(
  '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M13.5 1.5c.6 3.3-1.1 5.2-2.8 6.9-1.7 1.8-3.4 3.4-3 6.6-2-1.2-2.6-3.6-2.6-3.6S3 13.6 3 16.3C3 20.6 7 23 12 23s9-2.6 9-7.2c0-5.6-4.5-7.5-4.5-7.5s.4 2.3-.8 3.6c-.2-2.3-1-6.5-2.2-10.4z"/></svg>'
);

/** Una foto, o un video, o il buco di una foto che non c'e' piu'. */
export function media(f, classe = 'foto__media') {
  const url = indirizzo(f.mediaUrl);

  if (!url) {
    return html`<div class="${classe} foto__vuota">Foto non più disponibile</div>`;
  }

  if (f.mediaKind === 'video') {
    return html`<video class="${classe}" src="${url}" controls muted preload="metadata" playsinline></video>`;
  }

  const anteprima = indirizzo(f.thumbUrl) || url;

  return html`<a href="${url}" target="_blank" rel="noopener noreferrer"><img class="${classe}" src="${anteprima}" alt="" loading="lazy"></a>`;
}

/** La faccia di una persona, o un tondo grigio. */
export function faccia(url, classe = '') {
  const pulito = indirizzo(url);

  return pulito
    ? html`<img class="faccia ${classe}" src="${pulito}" alt="" loading="lazy">`
    : html`<span class="faccia ${classe}" aria-hidden="true"></span>`;
}

/** `@nome`, che porta alla scheda della persona. */
export function nome(uid, username) {
  if (!uid) {
    return html`<span class="tenue">—</span>`;
  }

  return html`<a href="#/persona/${encodeURIComponent(uid)}">@${username || uid}</a>`;
}
