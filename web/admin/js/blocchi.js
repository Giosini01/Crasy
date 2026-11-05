/*
 * **Chi ha bloccato chi.** Apple chiede che lo sviluppatore sappia quando qualcuno viene
 * bloccato per un comportamento inappropriato (linea guida 1.2).
 *
 * **Non sono segnalazioni, e non c'e' niente da decidere.** Un blocco e' una scelta di una
 * persona, e nessun contenuto esce per questo. Serve a vedere dove qualcosa non va: quando
 * tante persone bloccano la stessa, si apre la sua scheda e si guarda.
 */
import { dillo, fa, html, metti, nome, numero, pannello, quando, tasti, testata } from './base.js';

const FILTRI = [
  { id: 'nuovo', nome: 'Da guardare' },
  { id: 'visto', nome: 'Visti' },
  { id: 'tutti', nome: 'Tutti' },
];

const ORIGINI = {
  entry: 'da una foto',
  comment: 'da un commento',
  challenge: 'da una missione',
  user: 'dal profilo',
};

function carta(b) {
  return html`<article class="carta">
    <div class="pastiglie">
      <span class="pastiglia ${b.stato === 'nuovo' ? 'pastiglia--rossa' : ''}">${b.stato === 'nuovo' ? 'Da guardare' : 'Visto'}</span>
      ${b.contro > 1 ? html`<span class="pastiglia pastiglia--rossa">Bloccata da ${numero(b.contro)} persone</span>` : ''}
      ${b.sbloccatoIl ? html`<span class="pastiglia">Sbloccata ${fa(b.sbloccatoIl)}</span>` : ''}
    </div>
    <p style="margin:12px 0 0">
      ${nome(b.bloccaId, b.bloccaNome)} ha bloccato ${nome(b.bloccatoId, b.bloccatoNome)}
    </p>
    <div class="fatti">
      <span>${quando(b.createdAt)}</span>
      ${ORIGINI[b.origine] ? html`<span>${ORIGINI[b.origine]}</span>` : ''}
      ${b.challengeId ? html`<span><a href="#/missione/${encodeURIComponent(b.challengeId)}">Apri la missione</a></span>` : ''}
    </div>
    <div class="comandi">
      <a class="tasto" href="#/persona/${encodeURIComponent(b.bloccatoId)}">Apri la scheda</a>
      ${b.stato === 'nuovo' ? html`<button class="tasto" data-fai="visto" data-id="${b.id}">Visto</button>` : ''}
    </div>
  </article>`;
}

export async function mostraBlocchi(contenuto, parametri, ancoraQui) {
  const filtro = FILTRI.some((f) => f.id === parametri[0]) ? parametri[0] : 'nuovo';
  const { blocchi } = await pannello('blocchi', { stato: filtro });

  if (!ancoraQui()) {
    return;
  }

  metti(
    contenuto,
    html`
      ${testata('Blocchi', 'Chi ha bloccato chi. Non è una segnalazione: nessun contenuto viene toccato. Se qualcosa non va, si interviene dalla scheda della persona.')}
      <div class="schede">
        ${FILTRI.map(
          (f) => html`<a class="scheda ${f.id === filtro ? 'scelta' : ''}" href="#/blocchi/${f.id}">${f.nome}</a>`
        )}
      </div>
      ${blocchi.length
        ? html`<div class="carte">${blocchi.map(carta)}</div>`
        : html`<p class="vuoto">Niente da guardare.</p>`}
    `
  );

  tasti(contenuto, {
    visto: async ({ id }) => {
      await pannello('segnaBlocco', { id });
      dillo('Segnato.');
      window.dispatchEvent(new Event('pannello:cambiato'));
      await mostraBlocchi(contenuto, parametri, ancoraQui);
    },
  });
}
