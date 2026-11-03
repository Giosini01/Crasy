/*
 * **Le missioni: quelle che aspettano una decisione, e quelle in gara.**
 *
 * Il tasto dice cosa succede davvero. Una missione con un premio approvata non esce
 * subito: chi l'ha scritta riceve l'avviso e paga, e solo allora parte. Una rifiutata
 * non costa niente a nessuno: non ha mai pagato.
 */
import {
  chiedi,
  chiama,
  dillo,
  durata,
  euro,
  fa,
  faccia,
  FIAMMA,
  html,
  indirizzo,
  media,
  metti,
  nome,
  numero,
  pannello,
  quando,
  quanti,
  restano,
  tasti,
  testata,
} from './base.js';

const SCHEDE = [
  { id: 'daControllare', nome: 'Da controllare', bollo: 'daControllare' },
  { id: 'daConfermare', nome: 'Da confermare', bollo: 'daConfermare' },
  { id: 'bloccata', nome: 'Fermate dal filtro' },
  { id: 'inGara', nome: 'In gara' },
  { id: 'finite', nome: 'Finite' },
  { id: 'approvata', nome: 'Approvate' },
  { id: 'rifiutata', nome: 'Rifiutate' },
];

/** Le frasi pronte per un rifiuto: chi l'ha scritta le legge cosi' come sono. */
const MOTIVI = [
  'Mette in pericolo chi la fa',
  'Può fare male a qualcun altro',
  'Chiede contenuti sessuali',
  'Riguarda dei minori',
  'Chiede di commettere un reato',
  'Riprende persone senza il loro consenso',
  'Contiene odio o insulti',
];

const TIPI = { pubblica: 'Pubblica', amici: 'Fra amici', sfida: 'Sfida 1 contro 1' };
const STATI_PREMIO = {
  held: 'premio incassato',
  paidOut: 'premio pagato al vincitore',
  unpaid: 'non pagata',
  refunded: 'premio rimborsato',
};

function ambito(scope, target) {
  if (target) return `Sfida a @${target}`;

  return scope === 'friends' ? 'Fra amici' : 'Pubblica';
}

function classeVoto(voto) {
  if (voto === null || voto === undefined) return 'voto--niente';
  if (voto < 80) return 'voto--basso';

  return voto < 90 ? 'voto--medio' : 'voto--alto';
}

function bollinoVoto(voto, grande = false) {
  return voto === null || voto === undefined
    ? html`<div class="voto voto--niente">senza voto</div>`
    : html`<div class="voto ${classeVoto(voto)} ${grande ? 'voto--enorme' : ''}">${voto}<small>/100</small></div>`;
}

const GUASTI = {
  'chiave-non-valida': 'la chiave di OpenAI non è valida',
  'chiave-senza-permessi': 'la chiave di OpenAI non ha i permessi',
  'credito-finito': 'il credito di OpenAI è finito',
  'modello-non-trovato': 'il modello non è disponibile',
  'troppe-richieste': 'troppe richieste insieme',
  'tempo-scaduto': 'ci ha messo troppo',
  rete: 'problema di rete',
  rifiuto: 'il modello si è rifiutato di rispondere: guardala con attenzione',
};

/** Perche' e' arrivata fin qui, nella lingua di chi deve decidere. */
function ilPerche(p) {
  const g = p.giudizio;
  const parole = p.filtro && p.filtro.gialle ? p.filtro.gialle : [];
  const rossa = p.filtro && p.filtro.rossa;
  const tagliato = g && Number.isInteger(g.punteggio) && p.voto !== g.punteggio;

  return html`
    ${rossa
      ? html`<p class="perche">
          <b>Fermata dal filtro:</b> ha trovato <span class="rosso"><b>${rossa.termine}</b></span>
          (${rossa.categoria}) in “${rossa.testo}”.
        </p>`
      : ''}
    ${g && g.esito === 'fatto'
      ? html`<p class="perche">
          <b>L'AI${tagliato ? html` dice ${g.punteggio}` : ''}:</b> ${g.motivo || 'nessun motivo'}
          ${g.categoria && g.categoria !== 'nessuna' ? html`<span class="fioco"> · ${g.categoria}</span>` : ''}
        </p>`
      : ''}
    ${g && g.esito === 'guasto'
      ? html`<p class="perche"><b>L'AI non ha risposto:</b> ${GUASTI[g.perche] || g.perche}. Decidi tu.</p>`
      : ''}
    ${g && g.esito === 'spento'
      ? html`<p class="perche"><b>L'AI è spenta.</b> Finché manca la chiave passano tutte da qui.</p>`
      : ''}
    ${g && g.esito === 'tetto'
      ? html`<p class="perche"><b>Tetto dei giudizi di oggi raggiunto.</b> Decidi tu.</p>`
      : ''}
    ${parole.length
      ? html`<div class="pastiglie">
          ${parole.map((w) => html`<span class="pastiglia pastiglia--rossa">${w.termine}</span>`)}
        </div>`
      : ''}
  `;
}

function cartaProposta(p, { soloLettura = false } = {}) {
  const decidibile = ['daControllare', 'daConfermare', 'bloccata'].includes(p.stato);
  const urgente = p.stato === 'daControllare';

  return html`<article class="carta ${urgente ? 'carta--urgente' : ''}">
    <div class="carta__cima">
      <div class="premio ${p.prizeCents ? '' : 'premio--gratis'}">${p.prizeCents ? euro(p.prizeCents) : 'GRATIS'}</div>
      ${bollinoVoto(p.voto)}
    </div>
    <h3 class="gara">${p.title}</h3>
    <p class="consegna">${p.brief}</p>
    ${p.duelMessage ? html`<p class="riga-sfida">“${p.duelMessage}”</p>` : ''}
    <div class="fatti">
      <span>di ${nome(p.uid, p.username)}${p.anonimo ? ' (in anonimo)' : ''}</span>
      <span>${ambito(p.scope, p.targetUsername)}</span>
      <span>${p.mediaKind === 'video' ? 'video' : 'foto'}</span>
      <span>${durata(p.minutes)}</span>
      ${p.maxParticipants ? html`<span>${p.maxParticipants} posti</span>` : ''}
      <span>${fa(p.createdAt)}</span>
    </div>
    ${p.tentativiBloccati > 1
      ? html`<div class="pastiglie">
          <span class="pastiglia pastiglia--rossa">Già fermata ${p.tentativiBloccati} volte, questa persona</span>
        </div>`
      : ''}
    ${ilPerche(p)}
    ${p.stato === 'rifiutata' && p.motivoDecisione
      ? html`<p class="perche"><b>Rifiutata:</b> ${p.motivoDecisione}${p.decisaDa ? html` <span class="fioco">· ${p.decisaDa}, ${quando(p.decisaIl)}</span>` : ''}</p>`
      : ''}
    ${p.stato === 'approvata'
      ? html`<p class="perche">
          ${p.fonte === 'ai' ? html`<b>Uscita da sola.</b>` : html`<b>Approvata</b>${p.decisaDa ? html` da ${p.decisaDa}` : ''}.`}
          ${p.challengeId ? html` <a href="#/missione/${encodeURIComponent(p.challengeId)}">Apri la gara</a>` : html` Aspetta il pagamento.`}
        </p>`
      : ''}
    ${soloLettura
      ? decidibile
        ? html`<p class="perche"><a href="#/missioni/${p.stato}">Decidi in Missioni</a></p>`
        : ''
      : html`<div class="comandi">
      ${decidibile
        ? html`
            <button class="tasto ${p.stato === 'daConfermare' ? 'tasto--nero' : 'tasto--rosso'}" data-fai="approva" data-id="${p.id}"
              data-premio="${p.prizeCents}" data-voto="${p.voto === null ? '' : p.voto}" data-stato="${p.stato}">
              ${p.stato === 'daConfermare' ? 'Conferma' : p.stato === 'bloccata' ? 'Falso allarme: approva' : 'Manda in gara'}
            </button>
            ${p.stato === 'bloccata'
              ? ''
              : html`<button class="tasto" data-fai="rifiuta" data-id="${p.id}" data-titolo="${p.title}">Rifiuta</button>`}
          `
        : ''}
      ${p.stato === 'rifiutata'
        ? html`<button class="tasto" data-fai="approva" data-id="${p.id}" data-premio="${p.prizeCents}" data-voto="${p.voto === null ? '' : p.voto}" data-stato="${p.stato}">Ci ho ripensato: approva</button>`
        : ''}
      ${p.stato === 'approvata' && !p.challengeId
        ? html`<button class="tasto" data-fai="rifiuta" data-id="${p.id}" data-titolo="${p.title}">Ritira l'approvazione</button>`
        : ''}
    </div>`}
  </article>`;
}

function righeGare(gare) {
  return html`<div class="tabella-giro"><table>
    <thead><tr>
      <th>Missione</th><th>Di</th><th class="num">Premio</th><th class="num">In gara</th>
      <th class="num">Fiamme</th><th class="num">Voto</th><th class="num">Fine</th>
    </tr></thead>
    <tbody>
      ${gare.map(
        (g) => html`<tr class="apribile" data-fai="apri" data-id="${g.id}">
          <td>
            <div class="titolo-riga">${g.title}</div>
            <div class="sotto-riga">${TIPI[g.tipo] || g.tipo}${g.anonimo ? ' · anonima' : ''}${g.daCrasy ? ' · CRASY' : ''}${
              g.prizeCents && g.prizeStatus !== 'held' && g.prizeStatus !== 'paidOut'
                ? html` · <span class="rosso">${STATI_PREMIO[g.prizeStatus] || g.prizeStatus}</span>`
                : ''
            }</div>
          </td>
          <td class="nowrap">${g.autoreId ? html`@${g.autore || g.autoreId.slice(0, 6)}` : '—'}</td>
          <td class="num">${g.prizeCents ? html`<span class="soldi">${euro(g.prizeCents)}</span>` : 'gratis'}</td>
          <td class="num">${numero(g.participantsCount)}${g.maxParticipants ? html`<span class="fioco"> / ${g.maxParticipants}</span>` : ''}</td>
          <td class="num"><b>${numero(g.fiamme)}</b></td>
          <td class="num ${g.voto !== null && g.voto < 80 ? 'rosso' : ''}">${g.voto === null ? html`<span class="fioco">—</span>` : g.voto}</td>
          <td class="num">${g.endsAt > Date.now() ? restano(g.endsAt) : quando(g.endsAt)}</td>
        </tr>`
      )}
    </tbody>
  </table></div>`;
}

export async function mostraMissioni(contenuto, parametri, ancoraQui) {
  const scelta = SCHEDE.some((s) => s.id === parametri[0]) ? parametri[0] : 'daControllare';
  const numeri = await pannello('bolli').catch(() => null);

  if (!ancoraQui()) {
    return;
  }

  const bollo = (s) => (numeri && s.bollo && numeri.missioni[s.bollo]) || 0;

  metti(
    contenuto,
    html`
      ${testata(
        'Missioni',
        numeri
          ? `Da ${numeri.missioni.sogliaAuto} in su escono da sole, da ${numeri.missioni.sogliaConferma} a ${
              numeri.missioni.sogliaAuto - 1
            } chiedono una conferma, sotto le guardi tu. Finché non decidi non esce niente e nessuno paga.`
          : ''
      )}
      <div class="schede">
        ${SCHEDE.map(
          (s) => html`<a class="scheda ${s.id === scelta ? 'scelta' : ''}" href="#/missioni/${s.id}">
            ${s.nome}${bollo(s) ? html`<span class="bollo">${bollo(s)}</span>` : ''}
          </a>`
        )}
        <a class="scheda" href="#/prove">Banco di prova</a>
      </div>
      <div id="lista"><p class="carico">Carico…</p></div>
    `
  );

  const lista = contenuto.querySelector('#lista');
  const ridisegna = () => mostraMissioni(contenuto, parametri, ancoraQui);

  if (scelta === 'inGara' || scelta === 'finite') {
    const { gare } = await pannello('gare', { filtro: scelta });

    if (!ancoraQui()) {
      return;
    }

    metti(lista, gare.length ? righeGare(gare) : html`<p class="vuoto">Nessuna missione qui.</p>`);
    tasti(lista, {
      apri: ({ id }) => {
        location.hash = `#/missione/${encodeURIComponent(id)}`;
      },
    });

    return;
  }

  const { proposte } = await pannello('proposte', { stato: scelta });

  if (!ancoraQui()) {
    return;
  }

  metti(
    lista,
    proposte.length
      ? html`<div class="carte">${proposte.map(cartaProposta)}</div>`
      : html`<p class="vuoto">${
          scelta === 'daControllare' || scelta === 'daConfermare'
            ? 'Niente da decidere: nessuno sta aspettando.'
            : 'Nessuna missione qui.'
        }</p>`
  );

  tasti(lista, {
    approva: async ({ id, premio, voto, stato }) => {
      const conPremio = Number(premio) > 0;
      const seguito = conPremio
        ? "Chi l'ha scritta riceve l'avviso, paga il premio, e allora parte."
        : 'Esce subito.';

      // **Un tocco solo dove l'AI era d'accordo.** Dove ha trovato un rischio si chiede
      // ancora una volta, dicendo quale: e' li' che un tocco distratto fa danni.
      if (stato !== 'daConfermare') {
        const risposta = await chiedi({
          titolo: 'Mandarla in gara?',
          testo:
            (voto !== '' ? `L'AI le ha dato ${voto} su 100. ` : '') +
            'Sarà visibile a chi la può vedere e qualcuno la farà davvero. ' +
            seguito,
          tasto: 'Sì, approva',
          pericolo: true,
        });

        if (!risposta) {
          return;
        }
      }

      await pannello('decidiProposta', { id, decisione: 'approva' });
      dillo(conPremio ? 'Approvata: aspetta il pagamento.' : 'Approvata: è in gara.');
      window.dispatchEvent(new Event('pannello:cambiato'));
      await ridisegna();
    },
    rifiuta: async ({ id, titolo }) => {
      const risposta = await chiedi({
        titolo: 'Rifiutare la missione?',
        testo: `“${titolo}” non uscirà. Non ha pagato niente, quindi non c'è niente da rimborsare. Il motivo arriva a chi l'ha scritta, e la stessa missione non tornerà in coda.`,
        tasto: 'Rifiuta',
        pericolo: true,
        motivo: { etichetta: 'Motivo, lo legge chi l\'ha scritta', obbligatorio: true, scelte: MOTIVI },
        sospensione: true,
      });

      if (!risposta) {
        return;
      }

      await pannello('decidiProposta', {
        id,
        decisione: 'rifiuta',
        motivo: risposta.motivo,
        ...(risposta.sospendiGiorni === null ? {} : { sospendiGiorni: risposta.sospendiGiorni }),
      });
      dillo('Rifiutata.');
      window.dispatchEvent(new Event('pannello:cambiato'));
      await ridisegna();
    },
  });
}

function fotoInGara(f, garaId) {
  const fuori = f.moderation === 'rejected';

  return html`<figure class="foto ${fuori ? 'foto--fuori' : ''}" style="margin:0">
    ${media(f)}
    <figcaption class="foto__sotto">
      <div style="display:flex;justify-content:space-between;gap:8px">
        ${nome(f.userId, f.authorName)}
        <span class="foto__fiamme">${FIAMMA} ${numero(f.votes)}</span>
      </div>
      ${f.caption ? html`<div class="tenue">${f.caption}</div>` : ''}
      <div class="pastiglie">
        ${fuori ? html`<span class="pastiglia pastiglia--rossa">fuori dalla gara</span>` : ''}
        ${f.moderation === 'pending' ? html`<span class="pastiglia">in controllo</span>` : ''}
        ${f.segnalazioni ? html`<span class="pastiglia pastiglia--rossa">${quanti(f.segnalazioni, 'segnalazione', 'segnalazioni')}</span>` : ''}
      </div>
      <div class="comandi">
        ${fuori
          ? html`<button class="tasto tasto--piccolo" data-fai="rimetti" data-gara="${garaId}" data-foto="${f.entryId}">Rimetti</button>`
          : html`<button class="tasto tasto--piccolo tasto--bordo-rosso" data-fai="togliFoto" data-gara="${garaId}" data-foto="${f.entryId}">Togli</button>`}
      </div>
    </figcaption>
  </figure>`;
}

/** Una missione per intero: il testo, chi l'ha lanciata, tutte le foto e le fiamme. */
export async function mostraGara(contenuto, parametri, ancoraQui) {
  const id = parametri[0];
  const { gara: g, foto, proposta, giudizio, segnalazioni } = await pannello('gara', { id });

  if (!ancoraQui()) {
    return;
  }

  const finita = g.endsAt <= Date.now();
  const voto = proposta ? proposta.voto : giudizio ? giudizio.punteggio : null;
  const vincitrice = g.winnerEntryId
    ? foto.find((f) => f.entryId === g.winnerEntryId)
    : null;

  metti(
    contenuto,
    html`
      <a class="indietro" href="#/missioni/${finita ? 'finite' : 'inGara'}">← Missioni</a>
      <article class="carta" style="max-width:720px">
        <div class="carta__cima">
          <div class="premio ${g.prizeCents ? '' : 'premio--gratis'}">${g.prizeCents ? euro(g.prizeCents) : 'GRATIS'}</div>
          ${bollinoVoto(voto)}
        </div>
        <h3 class="gara">${g.title}</h3>
        <p class="consegna">${g.brief}</p>
        ${g.duelMessage ? html`<p class="riga-sfida">“${g.duelMessage}”</p>` : ''}
        <div class="fatti">
          <span>di ${g.daCrasy ? 'CRASY' : nome(g.autoreId, g.autore)}${g.anonimo ? ' (in anonimo)' : ''}</span>
          <span>${TIPI[g.tipo] || g.tipo}${g.targetUsername ? ` a @${g.targetUsername}` : ''}</span>
          <span>${g.mediaKind === 'video' ? 'video' : 'foto'}</span>
          ${g.tipo !== 'pubblica' ? html`<span>${numero(g.audienceCount)} la vedono</span>` : ''}
          <span>${finita ? `finita ${quando(g.endsAt)}` : `finisce fra ${restano(g.endsAt)}`}</span>
          ${g.prizeCents ? html`<span>${STATI_PREMIO[g.prizeStatus] || g.prizeStatus}${g.pagataDalFondo ? ' dal fondo' : g.pagataDalSaldo ? ' dal saldo' : ''}</span>` : ''}
          ${segnalazioni ? html`<span class="rosso">${quanti(segnalazioni, 'segnalazione', 'segnalazioni')}</span>` : ''}
        </div>
        ${proposta
          ? ilPerche(proposta)
          : giudizio && giudizio.motivo
          ? html`<p class="perche"><b>L'AI:</b> ${giudizio.motivo}</p>`
          : g.daCrasy || g.pagataDalFondo
          ? html`<p class="perche fioco">Scritta da noi: non passa dal controllo.</p>`
          : html`<p class="perche fioco">Uscita prima del controllo: nessun voto.</p>`}
        <div class="comandi">
          ${!proposta && !g.daCrasy && !g.pagataDalFondo && !(giudizio && Number.isInteger(giudizio.punteggio))
            ? html`<button class="tasto" data-fai="valuta">Fai giudicare dall'AI</button>`
            : ''}
          ${finita
            ? ''
            : html`<button class="tasto" data-fai="chiudi">Chiudi adesso</button>`}
          <button class="tasto tasto--bordo-rosso" data-fai="togli">Togli la missione</button>
        </div>
      </article>

      <div class="sezione">
        <h2>Le foto <span class="fioco">${numero(foto.length)}</span></h2>
        ${vincitrice
          ? html`<p>Ha vinto ${nome(vincitrice.userId, vincitrice.authorName)} con ${numero(vincitrice.votes)} fiamme.</p>`
          : ''}
        ${foto.length
          ? html`<div class="griglia">${foto.map((f) => fotoInGara(f, g.id))}</div>`
          : g.winnerMediaUrl && indirizzo(g.winnerMediaUrl)
          ? html`<p class="tenue">Le altre foto sono già state ripulite, resta quella che ha vinto.</p>`
          : html`<p class="vuoto">Nessuna foto.</p>`}
      </div>
    `
  );

  const ridisegna = () => mostraGara(contenuto, parametri, ancoraQui);

  tasti(contenuto, {
    valuta: async () => {
      const e = await pannello('valutaGara', { id: g.id });

      if (e.filtro && e.filtro.rossa) {
        dillo(`Il filtro la fermerebbe: ${e.filtro.rossa.termine}.`, { errore: true });

        return;
      }

      if (!e.giudizio || e.giudizio.esito !== 'fatto') {
        dillo("L'AI non ha risposto.", { errore: true });

        return;
      }

      dillo(`L'AI le dà ${e.giudizio.punteggio} su 100.`);
      await ridisegna();
    },
    chiudi: async () => {
      const risposta = await chiedi({
        titolo: 'Chiuderla adesso?',
        testo:
          'Si ferma il tempo: vince chi ha più fiamme in questo momento, e il premio segue la strada di sempre. Si chiude entro cinque minuti.',
        tasto: 'Chiudi',
        pericolo: true,
      });

      if (risposta) {
        await pannello('chiudiGara', { id: g.id });
        dillo('Si chiude entro cinque minuti.');
        await ridisegna();
      }
    },
    togli: async () => {
      const risposta = await chiedi({
        titolo: 'Togliere la missione?',
        testo: `Sparisce con ${foto.length === 1 ? 'la sua foto' : `tutte le sue ${foto.length} foto`}, e non si torna indietro.${
          g.prizeStatus === 'held' ? ' Il premio torna a chi l\'ha messo, senza le spese.' : ''
        }`,
        tasto: 'Togli',
        pericolo: true,
        motivo: { etichetta: 'Motivo', obbligatorio: true, scelte: MOTIVI },
        sospensione: !g.daCrasy,
      });

      if (risposta) {
        await pannello('togliGara', {
          id: g.id,
          motivo: risposta.motivo,
          ...(risposta.sospendiGiorni === null ? {} : { sospendiGiorni: risposta.sospendiGiorni }),
        });
        dillo('Missione tolta.');
        location.hash = `#/missioni/${finita ? 'finite' : 'inGara'}`;
      }
    },
    togliFoto: async ({ gara, foto: entryId }) => {
      const risposta = await chiedi({
        titolo: 'Togliere la foto dalla gara?',
        testo: 'Non può più vincere, e chi l\'ha mandata riceve un avviso con il motivo. Si può sempre rimettere.',
        tasto: 'Togli',
        pericolo: true,
      });

      if (risposta) {
        await pannello('togliFoto', { challengeId: gara, entryId, motivo: 'altro' });
        dillo('Foto tolta.');
        await ridisegna();
      }
    },
    rimetti: async ({ gara, foto: entryId }) => {
      await chiama('adminRimettiFoto', { challengeId: gara, entryId });
      dillo('Foto rimessa in gara.');
      await ridisegna();
    },
  });
}

// Per le altre sezioni, che mostrano le stesse cose.
export { bollinoVoto, cartaProposta, faccia, ilPerche };
