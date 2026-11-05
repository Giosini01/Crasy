/*
 * **Le segnalazioni, e cosa se ne fa.** Foto, missioni e persone separate: una foto si
 * decide guardandola, una missione leggendola, e alternare i due gesti a ogni riga costa
 * piu' di quanto sembri.
 *
 * **Il tetto e' di 24 ore**, e lo chiede Apple (linea guida 1.2): le aperte arrivano dalla
 * piu' vecchia, con scritto quanto manca, e il server richiama chi modera prima che scada
 * (vedi `functions/moderazione.js`).
 *
 * **Chi ha segnalato si vede solo da qui**: serve a giudicare, e a riconoscere chi usa le
 * segnalazioni come arma. A chi viene segnalato non arriva mai.
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
  restano,
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
  sexual: 'Contenuto sessualmente esplicito',
  violence: 'Violenza',
  hate: 'Molestie o bullismo',
  illegal: 'Contenuto illegale',
  spam: 'Spam o frode',
  minor: 'C’è un minore',
  other: 'Altro',
};

const TIPI = {
  entry: 'Foto e video',
  challenge: 'Missioni',
  comment: 'Commenti',
  user: 'Persone',
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
    vuoto: 'Nessuna persona o commento segnalato.',
  },
];

/** Quanto manca, o da quanto e' scaduta. Solo per quelle ancora da decidere. */
function scadenza(r) {
  if (!r.scadeIl) {
    return '';
  }

  if (r.scaduta) {
    const ore = Math.max(1, Math.round((Date.now() - r.scadeIl) / 3600000));

    return html`<span class="pastiglia pastiglia--piena-rossa">Scaduta da ${numero(ore)} h</span>`;
  }

  const poche = r.scadeIl - Date.now() < 6 * 3600000;

  return html`<span class="pastiglia ${poche ? 'pastiglia--rossa' : ''}">Scade fra ${restano(r.scadeIl)}</span>`;
}

function cartaSegnalazione(r) {
  const eLaMissione = r.kind === 'challenge';
  const ilCommento = r.kind === 'comment';
  // **Una persona segnalata non ha una foto da togliere.** Il tasto deve dire quello
  // che fa davvero: chiude la segnalazione, e se serve sospende.
  const conLaFoto = r.kind === 'entry' && Boolean(r.entryId && r.challengeId);
  const cosa = eLaMissione ? 'missione' : ilCommento ? 'commento' : conLaFoto ? 'foto' : 'persona';
  const tasto = {
    missione: 'Togli la missione',
    commento: 'Togli il commento',
    foto: 'Togli la foto',
    persona: 'Ha ragione',
  }[cosa];

  return html`<article class="carta">
    ${eLaMissione
      ? html`<h3 class="gara" style="margin-top:0">${r.challengeTitle || r.challengeId}</h3>`
      : indirizzo(r.mediaUrl) && !ilCommento
      ? media(r)
      : ''}
    ${r.testo ? html`<p class="riga-sfida">“${r.testo}”</p>` : ''}
    <div class="pastiglie">
      <span class="pastiglia ${r.status === 'new' ? 'pastiglia--rossa' : ''}">${STATI[r.status] || r.status}</span>
      <span class="pastiglia pastiglia--piena">${MOTIVI[r.reason] || r.reason || 'Senza motivo'}</span>
      ${scadenza(r)}
      ${r.reportsOnTarget > 1 ? html`<span class="pastiglia pastiglia--rossa">${numero(r.reportsOnTarget)} persone</span>` : ''}
      ${r.sospetta ? html`<span class="pastiglia">Da chi segnala troppo</span>` : ''}
    </div>
    ${r.note ? html`<p class="riga-sfida">Nota di chi segnala: “${r.note}”</p>` : ''}
    <div class="fatti">
      <span>di ${nome(r.reportedUserId, r.reportedUsername)}</span>
      <span>segnalata da ${nome(r.reporterId, r.reporterUsername)}${
        r.reporterRespinte ? html` <b class="rosso">(${numero(r.reporterRespinte)} respinte)</b>` : ''
      }</span>
      ${!eLaMissione && r.challengeTitle
        ? html`<span>in <a href="#/missione/${encodeURIComponent(r.challengeId)}">${r.challengeTitle}</a></span>`
        : ''}
      ${eLaMissione && r.challengeId ? html`<span><a href="#/missione/${encodeURIComponent(r.challengeId)}">Apri la missione</a></span>` : ''}
      <span>${quando(r.createdAt)}</span>
      ${conLaFoto
        ? html`<span>${r.entryExists ? STATI_FOTO[r.entryModeration] || r.entryModeration : 'foto non più presente'}</span>`
        : ''}
      ${r.resolvedAt
        ? html`<span>decisa ${quando(r.resolvedAt)} da ${nome(r.resolvedBy, r.resolvedByUsername)}</span>`
        : ''}
    </div>
    <div class="comandi">
      <button class="tasto tasto--rosso" data-fai="togli" data-id="${r.id}" data-cosa="${cosa}" data-chi="${r.reportedUsername}">
        ${tasto}
      </button>
      <button class="tasto" data-fai="fake" data-id="${r.id}">Fake</button>
      ${r.status === 'reviewing' ? '' : html`<button class="tasto" data-fai="guardo" data-id="${r.id}">La guardo io</button>`}
    </div>
  </article>`;
}

/** Da un giorno scritto nel modulo ai millisecondi: l'inizio, o la fine, di quel giorno. */
function giornoInMs(testo, fine = false) {
  if (!testo) {
    return 0;
  }

  const data = new Date(`${testo}T${fine ? '23:59:59' : '00:00:00'}`);

  return Number.isNaN(data.getTime()) ? 0 : data.getTime();
}

export async function mostraSegnalazioni(contenuto, parametri, ancoraQui) {
  const filtro = FILTRI.some((f) => f.id === parametri[0]) ? parametri[0] : 'new';
  const tipo = TIPI[parametri[1]] ? parametri[1] : '';
  const motivo = MOTIVI[parametri[2]] ? parametri[2] : '';
  // Un trattino tiene il posto di un filtro vuoto, nell'indirizzo.
  const dal = parametri[3] && parametri[3] !== '-' ? parametri[3] : '';
  const al = parametri[4] && parametri[4] !== '-' ? parametri[4] : '';
  const { reports, total } = await chiama('adminListReports', {
    status: filtro,
    kind: tipo,
    reason: motivo,
    dal: giornoInMs(dal),
    al: giornoInMs(al, true),
  });

  if (!ancoraQui()) {
    return;
  }

  const coda = [tipo, motivo, dal, al].some(Boolean)
    ? `/${[tipo, motivo, dal, al].map((v) => encodeURIComponent(v || '-')).join('/')}`
    : '';
  const scadute = reports.filter((r) => r.scaduta).length;

  metti(
    contenuto,
    html`
      ${testata('Segnalazioni', 'Vanno guardate entro 24 ore. A decidere è una persona, anche su una segnalazione sola: niente esce da solo perché è stato segnalato.')}
      ${scadute
        ? html`<div class="avviso"><strong>${numero(scadute)} oltre le 24 ore.</strong> Sono in cima: vanno decise adesso.</div>`
        : ''}
      <div class="schede">
        ${FILTRI.map(
          (f) => html`<a class="scheda ${f.id === filtro ? 'scelta' : ''}" href="#/segnalazioni/${f.id}${coda}">${f.nome}</a>`
        )}
      </div>
      <form id="filtriSegnalazioni" class="filtri">
        <div>
          <label for="filtroTipo">Tipo</label>
          <select id="filtroTipo">
            <option value="">Tutti</option>
            ${Object.entries(TIPI).map(
              ([id, testo]) => html`<option value="${id}" ${id === tipo ? html`selected` : ''}>${testo}</option>`
            )}
          </select>
        </div>
        <div>
          <label for="filtroMotivo">Motivo</label>
          <select id="filtroMotivo">
            <option value="">Tutti</option>
            ${Object.entries(MOTIVI).map(
              ([id, testo]) => html`<option value="${id}" ${id === motivo ? html`selected` : ''}>${testo}</option>`
            )}
          </select>
        </div>
        <div>
          <label for="filtroDal">Dal</label>
          <input id="filtroDal" type="date" value="${dal}">
        </div>
        <div>
          <label for="filtroAl">Al</label>
          <input id="filtroAl" type="date" value="${al}">
        </div>
        <button class="tasto" type="submit">Filtra</button>
      </form>
      <p class="fioco">${numero(total)} in tutto${total > reports.length ? `, qui le prime ${numero(reports.length)}` : ''}.</p>
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

  contenuto.querySelector('#filtriSegnalazioni').onsubmit = (evento) => {
    evento.preventDefault();

    const valori = ['#filtroTipo', '#filtroMotivo', '#filtroDal', '#filtroAl'].map(
      (campo) => contenuto.querySelector(campo).value
    );

    location.hash = `#/segnalazioni/${filtro}${
      valori.some(Boolean) ? `/${valori.map((v) => encodeURIComponent(v || '-')).join('/')}` : ''
    }`;
  };

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
        commento: [
          'Togliere il commento?',
          `Sparisce per tutti, e ${chi ? `@${chi}` : "chi l'ha scritto"} riceve un avviso con il motivo. Il testo resta scritto qui.`,
          'Togli',
        ],
        persona: [
          'La segnalazione era giusta?',
          `Si chiude, e da qui puoi sospendere ${chi ? `@${chi}` : 'questa persona'}. Per eliminare l'account, apri la sua scheda.`,
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
      dillo('Segnalazione chiusa: il contenuto resta.');
      await ridisegna();
    },
    guardo: async ({ id }) => {
      await chiama('adminResolveReport', { reportId: id, decision: 'reviewing' });
      dillo('Segnata come “in revisione”.');
      await ridisegna();
    },
  });
}
