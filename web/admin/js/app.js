/*
 * **L'ingresso del pannello e le sue strade.**
 *
 * Ogni sezione sta in un file e ha un indirizzo: `#/missioni`, `#/persona/abc`. Si
 * torna indietro col tasto del browser, e un link si puo' mandare all'altro
 * amministratore. Le email di "missione da controllare" portano dritte alla coda.
 */
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js';
import { auth, chiama, frase, html, metti, pannello } from './base.js';
import { mostraPanoramica } from './panoramica.js';
import { mostraGara, mostraMissioni } from './missioni.js';
import { mostraProve } from './prove.js';
import { mostraPersona, mostraPersone } from './persone.js';
import { mostraFoto } from './foto.js';
import { mostraSegnalazioni } from './segnalazioni.js';
import { mostraBlocchi } from './blocchi.js';
import { mostraSoldi } from './soldi.js';
import { mostraSpese } from './spese.js';
import { mostraAutomatiche } from './automatiche.js';
import { mostraRegole } from './regole.js';
import { mostraRegistro } from './registro.js';

const $ = (id) => document.getElementById(id);

const VOCI = [
  { id: 'panoramica', nome: 'Panoramica', mostra: mostraPanoramica },
  { id: 'missioni', nome: 'Missioni', mostra: mostraMissioni },
  { id: 'prove', nome: 'Banco di prova', mostra: mostraProve },
  { id: 'persone', nome: 'Persone', mostra: mostraPersone },
  { id: 'foto', nome: 'Foto', mostra: mostraFoto },
  { id: 'segnalazioni', nome: 'Segnalazioni', mostra: mostraSegnalazioni },
  { id: 'blocchi', nome: 'Blocchi', mostra: mostraBlocchi },
  { id: 'soldi', nome: 'Soldi', mostra: mostraSoldi },
  { id: 'spese', nome: 'Spese', mostra: mostraSpese },
  { id: 'automatiche', nome: 'Automatiche', mostra: mostraAutomatiche },
  { id: 'regole', nome: 'Regole', mostra: mostraRegole },
  { id: 'registro', nome: 'Registro', mostra: mostraRegistro },
];

/** Le pagine interne, e la voce del menu sotto cui stanno. */
const INTERNE = {
  missione: { sotto: 'missioni', mostra: mostraGara },
  persona: { sotto: 'persone', mostra: mostraPersona },
};

let bolli = {};

function disegnaLeVoci(scelta) {
  metti(
    $('voci'),
    VOCI.map(
      (voce) => html`<li>
        <a class="voce ${voce.id === scelta ? 'scelta' : ''}" href="#/${voce.id}">
          <span>${voce.nome}</span>
          ${bolli[voce.id] ? html`<span class="bollo">${bolli[voce.id]}</span>` : ''}
        </a>
      </li>`
    )
  );
}

function strada() {
  const parti = location.hash.replace(/^#\/?/, '').split('/').map(decodeURIComponent);

  return { nome: parti[0] || 'panoramica', parametri: parti.slice(1) };
}

let vista = 0;

async function vai() {
  const { nome: chiesta, parametri } = strada();
  const interna = INTERNE[chiesta];
  const voce = interna ? { id: interna.sotto, mostra: interna.mostra } : VOCI.find((v) => v.id === chiesta) || VOCI[0];
  const contenuto = $('contenuto');
  const questa = (vista += 1);

  disegnaLeVoci(voce.id);
  metti(contenuto, html`<p class="carico">Carico…</p>`);
  window.scrollTo(0, 0);

  try {
    await voce.mostra(contenuto, parametri, () => questa === vista);
  } catch (errore) {
    console.error(errore);

    if (questa === vista) {
      metti(contenuto, html`<p class="errore">${frase(errore)}</p>`);
    }
  }
}

/** I pallini del menu: quanto lavoro c'e' dietro ogni voce, senza doverla aprire. */
async function aggiornaIBolli() {
  try {
    const n = await pannello('bolli');

    bolli = {
      missioni: (n.missioni.daControllare || 0) + (n.missioni.daConfermare || 0),
      segnalazioni: (n.lavoro.segnalazioni || 0) + (n.lavoro.revisioni || 0),
      blocchi: n.lavoro.blocchi || 0,
      soldi: n.lavoro.prelievi || 0,
    };
    disegnaLeVoci((INTERNE[strada().nome] || {}).sotto || strada().nome);
  } catch (errore) {
    console.error(errore);
  }
}

window.addEventListener('hashchange', () => {
  vai();
  aggiornaIBolli();
});
window.addEventListener('pannello:cambiato', aggiornaIBolli);

$('modulo').addEventListener('submit', async (evento) => {
  evento.preventDefault();
  $('erroreAccesso').hidden = true;

  try {
    await signInWithEmailAndPassword(auth, $('email').value, $('password').value);
  } catch (errore) {
    $('erroreAccesso').textContent = 'Accesso non riuscito. Controlla email e password.';
    $('erroreAccesso').hidden = false;
  }
});

$('esci').addEventListener('click', () => signOut(auth));

let giro = null;

onAuthStateChanged(auth, async (utente) => {
  clearInterval(giro);

  if (!utente) {
    $('tavolo').hidden = true;
    $('accesso').hidden = false;

    return;
  }

  try {
    // **Si rinnova il gettone prima di chiedere, e non e' una precauzione.** Il permesso
    // e' dentro il gettone, e il browser se lo tiene per un'ora: chi e' appena stato
    // nominato leggerebbe "non sei un amministratore" fino al rinnovo.
    await utente.getIdToken(true);

    // E poi lo si chiede al server, non al gettone: e' lui a doverlo controllare.
    const { admin } = await chiama('adminWhoAmI');

    if (!admin) {
      await signOut(auth);
      $('erroreAccesso').textContent =
        'Questo account non ha il permesso di amministratore. Se te l’hanno appena dato, riprova tra un attimo.';
      $('erroreAccesso').hidden = false;

      return;
    }
  } catch (errore) {
    $('erroreAccesso').textContent = frase(errore);
    $('erroreAccesso').hidden = false;

    return;
  }

  $('accesso').hidden = true;
  $('tavolo').hidden = false;
  $('chi').textContent = utente.email || utente.uid;

  vai();
  aggiornaIBolli();
  giro = setInterval(aggiornaIBolli, 60 * 1000);
});
