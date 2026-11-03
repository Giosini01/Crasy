/*
 * **Le segnalazioni, e cosa se ne fa.** Foto, missioni e persone separate: una foto si
 * decide guardandola, una missione leggendola, e alternare i due gesti a ogni riga costa
 * piu' di quanto sembri.
 *
 * **Chi ha segnalato non si vede**, nemmeno da qui: il numero si', il nome mai.
 */
import {
  chiama,
  chiedi,
  dillo,
  html,
  indirizzo,
  media,
  metti,
  nome,
  numero,
  quando,
  tasti,
  testata,
} from './base.js';

const FILTRI = [
  { id: 'new', nome: 'Nuove' },
  { id: 'reviewing', nome: 'In revisione' },
  { id: 'fake', nome: 'Fake' },
  { id: 'removed', nome: 'Rimosse' },
  { id: 'all', nome: 'Tutte' },
];

const MOTIVI = {
  danger: 'Mette in pericolo qualcuno',
  sexual: 'Contenuto sessuale',
  violence: 'Violenza',
  hate: 'Odio o insulti',
  minor: 'C’è un minore',
  other: 'Altro',
};

const STATI = { new: 'Nuova', reviewing: 'In revisione', fake: 'Fake', removed: 'Rimossa' };

const STATI_FOTO = { approved: 'in gara', pending: 'in controllo', rejected: 'fuori dalla gara' };

const GRUPPI = [
  { titolo: 'Foto e video', suo: (r) => r.kind === 'entry', vuoto: 'Nessuna foto segnalata.' },
  { titolo: 'Missioni', suo: (r) => r.kind === 'challenge', vuoto: 'Nessuna missione segnalata.' },
  {
    // Tutto il resto, e non solo le persone: se nascesse un altro tipo di segnalazione
    // finirebbe qui invece di sparire senza che nessuno se ne accorga.
    titolo: 'Persone e commenti',
    suo: (r) => r.kind !== 'entry' && r.kind !== 'challenge',
    vuoto: 'Nessuna persona segnalata.',
  },
];

function cartaSegnalazione(r) {
  const eLaMissione = r.kind === 'challenge';
  // **Una persona segnalata non ha una foto da togliere.** Il tasto deve dire quello
  // che fa davvero: chiude la segnalazione, e se serve sospende.
  const conLaFoto = !eLaMissione && Boolean(r.entryId && r.challengeId);

  return html`<article class="carta">
    ${eLaMissione
      ? html`<h3 class="gara" style="margin-top:0">${r.challengeTitle || r.challengeId}</h3>`
      : indirizzo(r.mediaUrl)
      ? media(r)
      : ''}
    <div class="pastiglie">
      <span class="pastiglia ${r.status === 'new' ? 'pastiglia--rossa' : ''}">${STATI[r.status] || r.status}</span>
      <span class="pastiglia pastiglia--piena">${MOTIVI[r.reason] || r.reason || 'Senza motivo'}</span>
      ${r.reportsOnTarget > 1 ? html`<span class="pastiglia pastiglia--rossa">${numero(r.reportsOnTarget)} persone</span>` : ''}
    </div>
    ${r.note ? html`<p class="riga-sfida">“${r.note}”</p>` : ''}
    <div class="fatti">
      <span>di ${nome(r.reportedUserId, r.reportedUsername)}</span>
      ${!eLaMissione && r.challengeTitle
        ? html`<span>in <a href="#/missione/${encodeURIComponent(r.challengeId)}">${r.challengeTitle}</a></span>`
        : ''}
      ${eLaMissione && r.challengeId ? html`<span><a href="#/missione/${encodeURIComponent(r.challengeId)}">Apri la missione</a></span>` : ''}
      <span>${quando(r.createdAt)}</span>
      ${conLaFoto
        ? html`<span>${r.entryExists ? STATI_FOTO[r.entryModeration] || r.entryModeration : 'foto non più presente'}</span>`
        : ''}
    </div>
    <div class="comandi">
      <button class="tasto tasto--rosso" data-fai="togli" data-id="${r.id}" data-cosa="${eLaMissione ? 'missione' : conLaFoto ? 'foto' : 'persona'}" data-chi="${r.reportedUsername}">
        ${eLaMissione ? 'Togli la missione' : conLaFoto ? 'Togli la foto' : 'Ha ragione'}
      </button>
      <button class="tasto" data-fai="fake" data-id="${r.id}">Fake</button>
      ${r.status === 'reviewing' ? '' : html`<button class="tasto" data-fai="guardo" data-id="${r.id}">La guardo io</button>`}
    </div>
  </article>`;
}

export async function mostraSegnalazioni(contenuto, parametri, ancoraQui) {
  const filtro = FILTRI.some((f) => f.id === parametri[0]) ? parametri[0] : 'new';
  const { reports } = await chiama('adminListReports', { status: filtro });

  if (!ancoraQui()) {
    return;
  }

  metti(
    contenuto,
    html`
      ${testata('Segnalazioni', 'A decidere è una persona, anche su una segnalazione sola: niente esce da solo perché è stato segnalato.')}
      <div class="schede">
        ${FILTRI.map(
          (f) => html`<a class="scheda ${f.id === filtro ? 'scelta' : ''}" href="#/segnalazioni/${f.id}">${f.nome}</a>`
        )}
      </div>
      ${GRUPPI.map((gruppo) => {
        const sue = reports.filter(gruppo.suo);

        return html`<div class="sezione" style="margin-top:26px">
          <h2>${gruppo.titolo} <span class="fioco">${numero(sue.length)}</span></h2>
          ${sue.length
            ? html`<div class="carte">${sue.map(cartaSegnalazione)}</div>`
            : html`<p class="vuoto">${gruppo.vuoto}</p>`}
        </div>`;
      })}
    `
  );

  const ridisegna = async () => {
    window.dispatchEvent(new Event('pannello:cambiato'));
    await mostraSegnalazioni(contenuto, parametri, ancoraQui);
  };

  tasti(contenuto, {
    togli: async ({ id, cosa, chi }) => {
      const domande = {
        missione: [
          'Togliere la missione?',
          "Sparisce con tutte le sue foto, e il premio torna a chi l'ha messo, senza le spese.",
          'Togli',
        ],
        foto: [
          'Togliere la foto dalla gara?',
          `Non può più vincere, e ${chi ? `@${chi}` : "chi l'ha mandata"} riceve un avviso con il motivo.`,
          'Togli',
        ],
        persona: [
          'La segnalazione era giusta?',
          `Si chiude, e da qui puoi sospendere ${chi ? `@${chi}` : 'questa persona'}. Le foto restano dove sono.`,
          'Chiudi',
        ],
      };
      const [titolo, testo, tasto] = domande[cosa];
      const risposta = await chiedi({
        titolo,
        testo,
        tasto,
        pericolo: true,
        sospensione: true,
      });

      if (!risposta) {
        return;
      }

      await chiama('adminResolveReport', {
        reportId: id,
        decision: 'remove',
        ...(risposta.sospendiGiorni === null ? {} : { sospendiGiorni: risposta.sospendiGiorni }),
      });
      dillo('Fatto.');
      await ridisegna();
    },
    fake: async ({ id }) => {
      await chiama('adminResolveReport', { reportId: id, decision: 'fake' });
      dillo('Segnalazione chiusa: la foto resta.');
      await ridisegna();
    },
    guardo: async ({ id }) => {
      await chiama('adminResolveReport', { reportId: id, decision: 'reviewing' });
      dillo('Segnata come “in revisione”.');
      await ridisegna();
    },
  });
}
