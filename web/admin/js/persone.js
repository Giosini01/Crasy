/*
 * **Le persone: chi c'e', quanti soldi ha, cosa fa.**
 *
 * I soldi di una persona stanno in due posti. La **custodia** e' cio' che e' ancora sul
 * saldo di CRASY, in attesa di essere spostato; il **conto** e' il suo conto Stripe, e
 * il saldo vero lo sa solo Stripe. Nell'elenco si parte dalla nostra copia, e la si
 * sostituisce col numero vero appena arriva: una chiamata a persona, a gruppi.
 */
import {
  chiama,
  chiedi,
  dillo,
  euro,
  fa,
  faccia,
  FIAMMA,
  giorno,
  html,
  media,
  metti,
  numero,
  pannello,
  quando,
  quanti,
  tasti,
  testata,
} from './base.js';
import { cartaProposta } from './missioni.js';

const ORDINI = [
  { id: 'soldi', nome: 'Più soldi' },
  { id: 'recenti', nome: 'Viste di recente' },
  { id: 'nuovi', nome: 'Nuove' },
  { id: 'vincite', nome: 'Hanno vinto di più' },
  { id: 'follower', nome: 'Più seguite' },
];

function saldoVero(s) {
  return s && !s.errore ? (s.disponibile || 0) + (s.inArrivo || 0) : null;
}

function rigaPersona(p) {
  return html`<tr class="apribile" data-fai="apri" data-uid="${p.uid}">
    <td>
      <div class="chi">
        ${faccia(p.photoUrl)}
        <div style="min-width:0">
          <div><b>@${p.username || p.uid}</b>${p.verificato ? html` <span class="rosso" title="Sostenitore">✔</span>` : ''}${
            p.disabled ? html` <span class="pastiglia pastiglia--piena">sospesa</span>` : ''
          }</div>
          <div class="sotto-riga">${p.email || p.displayName || ''}</div>
        </div>
      </div>
    </td>
    <td class="num" data-conto="${p.uid}" data-copia="${p.stripeCents}">${
      p.conContoStripe ? euro(p.stripeCents) : html`<span class="fioco">senza conto</span>`
    }</td>
    <td class="num">${p.walletCents ? html`<span class="soldi">${euro(p.walletCents)}</span>` : html`<span class="fioco">—</span>`}</td>
    <td class="num">${euro(p.totalWonCents)}<span class="fioco"> · ${numero(p.totalWonCount)}</span></td>
    <td class="num">${numero(p.followersCount)}</td>
    <td class="num">${fa(p.lastSeenAt)}</td>
  </tr>`;
}

/** Sostituisce la nostra copia con il saldo vero, a gruppi, senza fermare la pagina. */
async function leggiISaldi(radice, persone, ancoraQui) {
  const conConto = persone.filter((p) => p.conContoStripe).map((p) => p.uid);

  for (let i = 0; i < conConto.length; i += 30) {
    if (!ancoraQui()) {
      return;
    }

    let saldi;

    try {
      ({ saldi } = await pannello('saldiConti', { uids: conConto.slice(i, i + 30) }));
    } catch (errore) {
      console.error(errore);

      return;
    }

    for (const [uid, saldo] of Object.entries(saldi)) {
      const cella = radice.querySelector(`[data-conto="${CSS.escape(uid)}"]`);

      if (!cella) {
        continue;
      }

      const vero = saldoVero(saldo);

      metti(
        cella,
        vero === null
          ? html`<span class="fioco" title="Stripe non ha risposto">${euro(Number(cella.dataset.copia))}?</span>`
          : html`<span class="soldi">${euro(vero)}</span>${
              saldo.inArrivo ? html`<div class="sotto-riga">${euro(saldo.inArrivo)} in arrivo</div>` : ''
            }`
      );
    }
  }
}

export async function mostraPersone(contenuto, parametri, ancoraQui) {
  const ordine = ORDINI.some((o) => o.id === parametri[0]) ? parametri[0] : 'soldi';

  metti(
    contenuto,
    html`
      ${testata('Persone', 'Quanti soldi hanno, quanto hanno vinto, chi le segue. Tocca una riga per vedere tutto.')}
      <form id="cerca" class="comandi" style="margin-bottom:14px;max-width:520px;flex-wrap:nowrap">
        <input id="q" type="search" placeholder="Cerca per nome utente" autocomplete="off">
        <button class="tasto tasto--nero" type="submit">Cerca</button>
      </form>
      <div class="schede">
        ${ORDINI.map(
          (o) => html`<a class="scheda ${o.id === ordine ? 'scelta' : ''}" href="#/persone/${o.id}">${o.nome}</a>`
        )}
      </div>
      <div id="elenco"><p class="carico">Carico…</p></div>
    `
  );

  const elenco = contenuto.querySelector('#elenco');
  let tutte = [];

  async function carica({ q, dopo } = {}) {
    const risposta = await pannello('persone', { ordine, q, dopo });

    if (!ancoraQui()) {
      return;
    }

    tutte = dopo ? [...tutte, ...risposta.persone] : risposta.persone;

    metti(
      elenco,
      tutte.length
        ? html`<div class="tabella-giro"><table>
            <thead><tr>
              <th>Persona</th><th class="num">Sul conto</th><th class="num">Custodia</th>
              <th class="num">Ha vinto</th><th class="num">Follower</th><th class="num">Vista</th>
            </tr></thead>
            <tbody>${tutte.map(rigaPersona)}</tbody>
          </table></div>
          ${risposta.ancora
            ? html`<div class="comandi" style="margin-top:14px"><button class="tasto" data-fai="ancora">Altre</button></div>`
            : ''}`
        : html`<p class="vuoto">Nessuna persona qui.</p>`
    );

    leggiISaldi(elenco, tutte, ancoraQui);
  }

  tasti(elenco, {
    apri: ({ uid }) => {
      location.hash = `#/persona/${encodeURIComponent(uid)}`;
    },
    ancora: () => carica({ dopo: tutte[tutte.length - 1].uid }),
  });

  contenuto.querySelector('#cerca').addEventListener('submit', (evento) => {
    evento.preventDefault();
    carica({ q: contenuto.querySelector('#q').value });
  });

  await carica();
}

const MOVIMENTI = {
  prize: 'Premio vinto',
  withdrawal: 'Prelievo',
  payout: 'Prelievo',
  refund: 'Rimborso',
  challenge: 'Missione pagata',
  addebito: 'Missione pagata col saldo',
};

function righeMovimenti(righe) {
  return righe.length
    ? html`<div class="righe">
        ${righe.map(
          (m) => html`<div style="display:flex;justify-content:space-between;gap:14px">
            <div>
              <div>${MOVIMENTI[m.kind] || m.kind}${m.challengeTitle ? html` <span class="tenue">· ${m.challengeTitle}</span>` : ''}</div>
              <div class="sotto-riga">${quando(m.quando)}</div>
            </div>
            <b class="nowrap ${m.amountCents > 0 ? 'rosso' : ''}">${euro(m.amountCents)}</b>
          </div>`
        )}
      </div>`
    : html`<p class="vuoto">Nessun movimento.</p>`;
}

/** Tutto quello che c'e' su una persona. */
export async function mostraPersona(contenuto, parametri, ancoraQui) {
  const uid = parametri[0];
  const scheda = await pannello('persona', { uid });

  if (!ancoraQui()) {
    return;
  }

  const { persona: p, profilo, numeri, stripe, sospensione, movimenti, registro, proposte, gare, foto } = scheda;
  const eta = profilo.birthDate
    ? Math.floor((Date.now() - profilo.birthDate) / (365.25 * 24 * 3600 * 1000))
    : null;
  const vero = saldoVero(stripe);
  const totale = (vero === null ? p.stripeCents : vero) + p.walletCents;

  metti(
    contenuto,
    html`
      <a class="indietro" href="#/persone">← Persone</a>
      <header class="persona-testa">
        ${faccia(p.photoUrl, 'faccia--grande')}
        <div style="min-width:0">
          <h1>@${p.username || p.uid}</h1>
          <div class="pastiglie">
            ${profilo.admin ? html`<span class="pastiglia pastiglia--piena">amministratore</span>` : ''}
            ${p.verificato ? html`<span class="pastiglia pastiglia--rossa">sostenitore</span>` : ''}
            ${sospensione
              ? html`<span class="pastiglia pastiglia--rossa">sospesa ${sospensione.fino ? `fino al ${giorno(sospensione.fino)}` : 'per sempre'}</span>`
              : ''}
          </div>
        </div>
      </header>

      ${sospensione && sospensione.motivo ? html`<div class="avviso" style="margin-top:18px">${sospensione.motivo}</div>` : ''}

      <div class="comandi" style="margin-top:18px">
        ${sospensione
          ? html`<button class="tasto tasto--nero" data-fai="riattiva">Riattiva</button>`
          : html`<button class="tasto tasto--bordo-rosso" data-fai="sospendi">Sospendi</button>`}
        <button class="tasto" data-fai="sostenitore">${p.verificato ? 'Togli sostenitore' : 'Fai sostenitore'}</button>
      </div>

      <div class="sezione">
        <h2>I soldi</h2>
        <div class="numeri">
          <div class="numero">
            <div class="occhiello occhiello--rosso">In tutto</div>
            <div class="numero__cifra rosso">${euro(totale)}</div>
          </div>
          <div class="numero">
            <div class="occhiello">Sul conto Stripe</div>
            <div class="numero__cifra">${p.conContoStripe ? (vero === null ? euro(p.stripeCents) : euro(vero)) : '—'}</div>
            <div class="numero__nota">${
              !p.conContoStripe
                ? 'Non ha un conto.'
                : vero === null
                ? 'Stripe non ha risposto: questa è la nostra copia.'
                : `${euro(stripe.disponibile)} disponibili, ${euro(stripe.inArrivo)} in arrivo`
            }</div>
          </div>
          <div class="numero">
            <div class="occhiello">In custodia su CRASY</div>
            <div class="numero__cifra">${euro(p.walletCents)}</div>
            <div class="numero__nota">In attesa di andare sul suo conto.</div>
          </div>
          <div class="numero">
            <div class="occhiello">Ha vinto</div>
            <div class="numero__cifra">${euro(p.totalWonCents)}</div>
            <div class="numero__nota">${quanti(p.totalWonCount, 'missione', 'missioni')}</div>
          </div>
        </div>
      </div>

      <div class="sezione">
        <h2>I numeri</h2>
        <div class="numeri">
          <div class="numero"><div class="occhiello">Fiamme ricevute</div><div class="numero__cifra">${numero(numeri.fiammeRicevute)}</div><div class="numero__nota">sulle foto ancora online</div></div>
          <div class="numero"><div class="occhiello">Fiamme date</div><div class="numero__cifra">${numero(numeri.fiammeDate)}</div></div>
          <div class="numero"><div class="occhiello">Follower</div><div class="numero__cifra">${numero(p.followersCount)}</div><div class="numero__nota">segue ${numero(p.followingCount)}</div></div>
          <div class="numero"><div class="occhiello">Amici</div><div class="numero__cifra">${numero(numeri.amici)}</div></div>
          <div class="numero ${numeri.segnalazioniContro ? 'numero--allarme' : ''}"><div class="occhiello">Segnalata</div><div class="numero__cifra">${numero(numeri.segnalazioniContro)}</div><div class="numero__nota">volte</div></div>
        </div>
      </div>

      <div class="sezione">
        <h2>Chi è</h2>
        <dl class="dati">
          <dt>Email</dt><dd>${p.email || '—'}${profilo.emailVerificata === false ? html` <span class="rosso">non verificata</span>` : ''}</dd>
          <dt>Telefono</dt><dd>${profilo.telefono || '—'}</dd>
          <dt>Nome</dt><dd>${p.displayName || '—'}</dd>
          <dt>Età</dt><dd>${eta === null ? '—' : `${eta} anni`}</dd>
          <dt>Città</dt><dd>${p.city || '—'}</dd>
          <dt>Bio</dt><dd>${scheda.profilo.bio || '—'}</dd>
          <dt>Iscritta</dt><dd>${giorno(p.createdAt)}</dd>
          <dt>Ultima volta</dt><dd>${fa(p.lastSeenAt)}</dd>
          <dt>Identificativo</dt><dd><code>${p.uid}</code></dd>
        </dl>
      </div>

      <div class="sezione">
        <h2>Missioni lanciate <span class="fioco">${numero(gare.length)}</span></h2>
        ${gare.length
          ? html`<div class="righe">
              ${gare.map(
                (g) => html`<div>
                  <a href="#/missione/${encodeURIComponent(g.id)}" class="titolo-riga">${g.title}</a>
                  <div class="sotto-riga">
                    ${g.prizeCents ? euro(g.prizeCents) : 'gratis'} · ${numero(g.participantsCount)} in gara
                    · ${g.anonimo ? 'in anonimo · ' : ''}${quando(g.createdAt)}
                  </div>
                </div>`
              )}
            </div>`
          : html`<p class="vuoto">Nessuna, fra quelle ancora nel database.</p>`}
      </div>

      <div class="sezione">
        <h2>Missioni proposte <span class="fioco">${numero(proposte.length)}</span></h2>
        ${proposte.length
          ? html`<div class="carte">${proposte.slice(0, 12).map((p) => cartaProposta(p, { soloLettura: true }))}</div>`
          : html`<p class="vuoto">Nessuna.</p>`}
      </div>

      <div class="sezione">
        <h2>Le foto <span class="fioco">${numero(foto.length)}</span></h2>
        ${foto.length
          ? html`<div class="griglia">
              ${foto.map(
                (f) => html`<figure class="foto ${f.moderation === 'rejected' ? 'foto--fuori' : ''}" style="margin:0">
                  ${media(f)}
                  <figcaption class="foto__sotto">
                    <span class="foto__fiamme">${FIAMMA} ${numero(f.votes)}</span>
                    <a class="foto__titolo" href="#/missione/${encodeURIComponent(f.challengeId)}">${f.challengeTitle}</a>
                  </figcaption>
                </figure>`
              )}
            </div>`
          : html`<p class="vuoto">Nessuna foto ancora online.</p>`}
      </div>

      <div class="sezione">
        <h2>I movimenti</h2>
        ${righeMovimenti(movimenti)}
      </div>

      <div class="sezione">
        <h2>L'estratto conto</h2>
        ${righeMovimenti(registro)}
      </div>
    `
  );

  const ridisegna = () => mostraPersona(contenuto, parametri, ancoraQui);

  tasti(contenuto, {
    sospendi: async () => {
      const risposta = await chiedi({
        titolo: `Sospendere @${p.username}?`,
        testo: 'Non può più entrare. Le arriva un\'email con il motivo, la durata e il modo di contestare.',
        tasto: 'Sospendi',
        pericolo: true,
        motivo: { etichetta: 'Motivo, lo legge nell\'email', obbligatorio: true },
        sospensione: true,
      });

      if (!risposta) {
        return;
      }

      if (risposta.sospendiGiorni === null) {
        dillo('Scegli per quanto tempo.', { errore: true });

        return;
      }

      await pannello('sospendi', { uid, giorni: risposta.sospendiGiorni, motivo: risposta.motivo });
      dillo('Sospesa.');
      await ridisegna();
    },
    riattiva: async () => {
      const risposta = await chiedi({
        titolo: `Riattivare @${p.username}?`,
        testo: 'Potrà rientrare subito.',
        tasto: 'Riattiva',
      });

      if (risposta) {
        await chiama('adminRiattiva', { userId: uid });
        dillo('Riattivata.');
        await ridisegna();
      }
    },
    sostenitore: async () => {
      await chiama('adminImpostaVerificato', { userId: uid, verificato: !p.verificato });
      dillo(p.verificato ? 'Tolta la spunta.' : 'Adesso è sostenitore.');
      await ridisegna();
    },
  });
}
