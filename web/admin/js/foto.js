/*
 * **Le foto di tutte le gare**: le ultime arrivate, quelle con piu' fiamme, e quelle che
 * il controllo automatico ha scartato. Il controllo delle immagini e' severo apposta e
 * ogni tanto sbaglia: chi se le vede scartare crede di essere in gara e non c'e'.
 */
import {
  chiama,
  chiedi,
  dillo,
  FIAMMA,
  fa,
  html,
  media,
  metti,
  nome,
  numero,
  pannello,
  quando,
  quanti,
  tasti,
  testata,
} from './base.js';

const SCHEDE = [
  { id: 'recenti', nome: 'Le ultime' },
  { id: 'fiamme', nome: 'Più fiamme, ultimi 3 giorni' },
  { id: 'scartate', nome: 'Scartate' },
];

const MOTIVI_FOTO = [
  ['pericolo', 'Mette in pericolo qualcuno'],
  ['sessuale', 'Contenuto sessualmente esplicito'],
  ['violenza', 'Violenza'],
  ['odio', 'Molestie o bullismo'],
  ['illegale', 'Contenuto illegale'],
  ['spam', 'Spam o frode'],
  ['minore', 'C’è un minore'],
];

function tessera(f) {
  const fuori = f.moderation === 'rejected';

  return html`<figure class="foto ${fuori ? 'foto--fuori' : ''}" style="margin:0">
    ${media(f)}
    <figcaption class="foto__sotto">
      <div style="display:flex;justify-content:space-between;gap:8px">
        ${nome(f.userId, f.authorName)}
        <span class="foto__fiamme">${FIAMMA} ${numero(f.votes)}</span>
      </div>
      <a class="foto__titolo" href="#/missione/${encodeURIComponent(f.challengeId)}">${f.challengeTitle}</a>
      <div class="sotto-riga">${fa(f.createdAt)}</div>
      ${f.segnalazioni ? html`<div class="pastiglie"><span class="pastiglia pastiglia--rossa">${quanti(f.segnalazioni, 'segnalazione', 'segnalazioni')}</span></div>` : ''}
      <div class="comandi">
        ${fuori
          ? html`<span class="pastiglia pastiglia--rossa">fuori dalla gara</span>`
          : html`<button class="tasto tasto--piccolo tasto--bordo-rosso" data-fai="togli" data-gara="${f.challengeId}" data-foto="${f.entryId}">Togli</button>`}
      </div>
    </figcaption>
  </figure>`;
}

function tesseraScartata(f) {
  const aperta = f.revisione && f.revisione.stato === 'aperta';
  const perche = f.daUnaPersona
    ? 'Tolta da noi dopo una segnalazione'
    : f.motivi.length
    ? f.motivi.join(', ')
    : 'Senza motivo';

  return html`<figure class="foto" style="margin:0">
    ${media(f)}
    <figcaption class="foto__sotto">
      ${aperta ? html`<div class="pastiglie" style="margin:0 0 6px"><span class="pastiglia pastiglia--rossa">Chiede una revisione · ${quando(f.revisione.chiestaIl)}</span></div>` : ''}
      <b>${perche}</b>
      <div>${nome(f.userId, f.authorName)}</div>
      <a class="foto__titolo" href="#/missione/${encodeURIComponent(f.challengeId)}">${f.challengeTitle}</a>
      <div class="sotto-riga">scartata ${quando(f.moderatedAt)}</div>
      <div class="comandi">
        <button class="tasto tasto--piccolo tasto--nero" data-fai="rimetti" data-gara="${f.challengeId}" data-foto="${f.entryId}">Rimetti in gara</button>
        ${aperta
          ? html`<button class="tasto tasto--piccolo" data-fai="respingi" data-gara="${f.challengeId}" data-chi="${f.userId}">Resta fuori</button>`
          : ''}
      </div>
    </figcaption>
  </figure>`;
}

export async function mostraFoto(contenuto, parametri, ancoraQui) {
  const scelta = SCHEDE.some((s) => s.id === parametri[0]) ? parametri[0] : 'recenti';

  metti(
    contenuto,
    html`
      ${testata('Foto')}
      <div class="schede">
        ${SCHEDE.map(
          (s) => html`<a class="scheda ${s.id === scelta ? 'scelta' : ''}" href="#/foto/${s.id}">${s.nome}</a>`
        )}
      </div>
      <div id="griglia"><p class="carico">Carico…</p></div>
    `
  );

  const griglia = contenuto.querySelector('#griglia');
  const ridisegna = () => mostraFoto(contenuto, parametri, ancoraQui);

  if (scelta === 'scartate') {
    const { foto } = await chiama('adminFotoScartate');

    if (!ancoraQui()) {
      return;
    }

    metti(
      griglia,
      foto.length
        ? html`<div class="griglia">${foto.map(tesseraScartata)}</div>`
        : html`<p class="vuoto">Nessuna foto scartata.</p>`
    );
  } else {
    const { foto } = await pannello('foto', { ordine: scelta });

    if (!ancoraQui()) {
      return;
    }

    metti(
      griglia,
      foto.length
        ? html`<div class="griglia">${foto.map(tessera)}</div>`
        : html`<p class="vuoto">Nessuna foto.</p>`
    );
  }

  tasti(griglia, {
    togli: async ({ gara, foto }) => {
      const risposta = await chiedi({
        titolo: 'Togliere la foto dalla gara?',
        testo: 'Non può più vincere, le fiamme tornano a chi le ha date, e chi l\'ha mandata riceve un avviso con il motivo. Si può sempre rimettere.',
        tasto: 'Togli',
        pericolo: true,
        motivo: {
          etichetta: 'Perché: scegli una voce',
          obbligatorio: true,
          scelte: MOTIVI_FOTO.map(([, testo]) => testo),
        },
      });

      if (!risposta) {
        return;
      }

      const voce = MOTIVI_FOTO.find(([, testo]) => testo === risposta.motivo);

      await pannello('togliFoto', {
        challengeId: gara,
        entryId: foto,
        motivo: voce ? voce[0] : 'altro',
      });
      dillo('Foto tolta.');
      await ridisegna();
    },
    rimetti: async ({ gara, foto }) => {
      const risposta = await chiedi({
        titolo: 'Rimettere la foto in gara?',
        testo: 'La vedranno tutti, e chi l\'ha mandata riceve un avviso.',
        tasto: 'Rimetti',
      });

      if (risposta) {
        await chiama('adminRimettiFoto', { challengeId: gara, entryId: foto });
        dillo('Foto rimessa in gara.');
        await ridisegna();
      }
    },
    respingi: async ({ gara, chi }) => {
      const risposta = await chiedi({
        titolo: 'Confermare che resta fuori?',
        testo: 'Chi l\'ha mandata lo leggerà nell\'app.',
        tasto: 'Resta fuori',
        pericolo: true,
      });

      if (risposta) {
        await chiama('adminRespingiRevisione', { challengeId: gara, userId: chi });
        dillo('Revisione chiusa.');
        window.dispatchEvent(new Event('pannello:cambiato'));
        await ridisegna();
      }
    },
  });
}
