/*
 * **Il portafoglio delle missioni automatiche.**
 *
 * Uno solo: si ricarica qui con la carta, le missioni partono da sole a nome di chi
 * presta la faccia, e quelle andate a vuoto rimettono qui il premio. Il numero grande
 * e' quanto c'e' dentro; sotto, il calendario: un elenco dice quando esce ogni
 * missione, il calendario dice com'e' fatta la settimana — chi, cosa, quanto.
 *
 * Le regole stanno tutte sul server (`functions/salvadanaio.js`): questa pagina chiede
 * e mostra, e il calendario che fa vedere e' quello che il server calcola con le
 * stesse regole con cui poi lancia.
 */
import { chiama, chiedi, dillo, euro, html, metti, nome, numero, quando, tasti, testata } from './base.js';

/** Chi presta la faccia, se non e' ancora stato scelto nessuno. */
const FACCE_PROPOSTE = [
  'franksy', 'giosyni', 'ilariap', 'francesco', 'saba2k',
  'orsola', 'enne_', 'vincenzo', 'giovannidio',
];

const PERCHE = {
  nuovo: 'mai acceso',
  'a mano': 'fermato a mano',
  finiti: 'soldi finiti',
  scaduto: 'data di fine passata',
  ricaricato: 'ricaricato, da riaccendere',
};

const NO = {
  'nessun-fondo': 'il fondo non esiste ancora: ricaricalo',
  'tetto-di-oggi': 'oggi sono già uscite tutte quelle previste',
  'fondo-finito': 'i soldi non bastano per la prossima',
  'nessuna-faccia': 'nessuno in fila per lanciare',
  'nessuna-missione': 'non ci sono missioni in elenco',
  scaduto: 'la data di fine è passata',
};

function dataLunga(giorno) {
  const [a, m, g] = giorno.split('-').map(Number);

  return new Date(a, m - 1, g).toLocaleDateString('it-IT', { weekday: 'short', day: '2-digit', month: '2-digit' });
}

function calendario(prossime) {
  const giorni = [];
  const oggi = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Rome' });

  for (const p of prossime || []) {
    let giorno = giorni.find((g) => g.chiave === p.giorno);

    if (!giorno) {
      giorno = { chiave: p.giorno, oggi: p.giorno === oggi, voci: [], soldi: 0 };
      giorni.push(giorno);
    }

    giorno.soldi += p.premioCents;
    giorno.voci.push({
      p,
      ora: new Date(p.quando).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit', timeZone: 'Europe/Rome' }),
    });
  }

  return giorni.length
    ? html`<div class="calendario">
        ${giorni.map(
          (g) => html`<div class="giorno ${g.oggi ? 'giorno--oggi' : ''}">
            <div class="giorno__testa">${dataLunga(g.chiave)} · ${euro(g.soldi)}</div>
            ${g.voci.map(
              ({ p, ora }) => html`<div class="giorno__voce">
                <div class="sotto-riga"><b>${ora}</b> · <b class="rosso">${euro(p.premioCents)}</b> · ${p.mediaKind === 'video' ? 'video' : 'foto'} · ${p.source === 'archive' ? 'archivio' : 'adesso'}</div>
                <div class="titolo-riga">${p.titolo}</div>
                <div class="sotto-riga">${p.consegna}</div>
                <div class="sotto-riga" style="margin-top:4px">${p.autoreId ? html`lancia ${nome(p.autoreId, p.autore)}` : html`<span class="rosso">nessuno in fila</span>`}</div>
              </div>`
            )}
          </div>`
        )}
      </div>`
    : html`<p class="vuoto">Niente in programma: mancano i soldi, le missioni, o la data di partenza è dopo la fine.</p>`;
}

function saldo(f) {
  const andato = f.ricaricatiCents ? Math.min(100, Math.round((f.spesiCents / f.ricaricatiCents) * 100)) : 0;
  const quante = f.prossime.length >= 60 ? '60+' : numero(f.prossime.length);
  const perche = f.acceso ? 'acceso' : `fermo · ${PERCHE[f.spentoPerche] || f.spentoPerche || 'fermo'}`;

  return html`<article class="carta" style="margin-bottom:18px">
    <div class="carta__cima">
      <div>
        <div class="occhiello">Nel portafoglio</div>
        <div class="premio" style="margin-top:8px">${euro(f.fondoCents)}</div>
        <div class="tenue">${quante} missioni in programma${f.dal ? ` · parte il ${f.dal}` : ''}${f.fino ? ` · fino al ${f.fino}` : ''}</div>
      </div>
      <span class="pastiglia ${f.acceso ? 'pastiglia--piena' : 'pastiglia--rossa'}">${perche}</span>
    </div>
    <div class="barra"><div style="width:${andato}%"></div></div>
    <div class="fatti">
      <span>caricati ${euro(f.ricaricatiCents)}</span>
      <span>spesi ${euro(f.spesiCents)}</span>
      <span>oggi ${numero(f.fatteOggi)} su ${numero(f.alGiorno)}</span>
      <span>${numero(f.missioniInElenco)} missioni in elenco</span>
    </div>

    <div class="comandi" style="margin-top:18px;align-items:flex-end">
      <div>
        <label for="ricaricaEuro">Ricarica (€)</label>
        <input id="ricaricaEuro" type="number" min="5" max="500" step="1" value="100" style="width:120px">
      </div>
      <button class="tasto tasto--nero" data-fai="ricarica">Ricarica con la carta</button>
    </div>
    <p class="sotto-riga" style="margin-top:6px">Si apre la pagina di Stripe. Nel portafoglio entra quello che arriva davvero, tolte le commissioni (circa 1,5% + 0,25 € con una carta europea).</p>

    <div class="comandi">
      <button class="tasto ${f.acceso ? 'tasto--bordo-rosso' : 'tasto--nero'}" data-fai="accendi" data-acceso="${f.acceso ? '1' : ''}">
        ${f.acceso ? 'Ferma tutto' : 'Accendi'}
      </button>
      <button class="tasto" data-fai="lancia">Lancia adesso</button>
      <button class="tasto" data-fai="salta">Salta la prossima</button>
    </div>
  </article>`;
}

function regole(f) {
  return html`<article class="carta" style="margin-bottom:18px">
    <div class="occhiello" style="margin-bottom:12px">Regole</div>
    <div class="soglie">
      <div>
        <label for="alGiorno">Missioni al giorno</label>
        <select id="alGiorno">
          ${[1, 2, 3, 4, 5].map((n) => html`<option value="${n}" ${n === f.alGiorno ? 'selected' : ''}>${n} · fino alle ${['10', '13', '16', '19', '21'][n - 1]}:00</option>`)}
        </select>
      </div>
      <div>
        <label for="dal">Parte il (giorno dell'uscita)</label>
        <input id="dal" type="date" value="${f.dal}">
      </div>
      <div>
        <label for="fino">Finisce il (vuoto: finché ci sono soldi)</label>
        <input id="fino" type="date" value="${f.fino}">
      </div>
      <div>
        <label for="premioBase">Premio se la missione non ne dice uno (€)</label>
        <input id="premioBase" type="number" min="0.5" max="100" step="0.5" value="${(f.premioCents / 100).toString()}">
      </div>
      <div>
        <label for="posti">Posti per missione</label>
        <input id="posti" type="number" min="2" max="50" step="1" value="${f.maxPartecipanti}">
      </div>
      <div>
        <label for="ore">Ore di gara</label>
        <input id="ore" type="number" min="1" max="24" step="1" value="${f.oreDiGara}">
      </div>
    </div>
    <div class="comandi"><button class="tasto tasto--nero" data-fai="salvaRegole">Salva le regole</button></div>
    <p class="sotto-riga" style="margin-top:6px">Parte alle 10, 13, 16, 19 e 21: con meno missioni al giorno si usano le prime ore. Prima del giorno di partenza non esce niente da sola.</p>
  </article>`;
}

function facce(f) {
  const nomi = f.autori.length ? f.autori.map((a) => a.username) : FACCE_PROPOSTE;

  return html`<article class="carta" style="margin-bottom:18px">
    <div class="occhiello" style="margin-bottom:8px">Chi lancia, a turno</div>
    ${f.autori.length
      ? html`<div class="fatti" style="margin:0 0 12px">${f.autori.map((a) => html`<span>${nome(a.uid, a.username)}</span>`)}</div>`
      : html`<p class="vuoto" style="margin:0 0 12px">Nessuno ancora: salva l'elenco qui sotto.</p>`}
    <label for="nomi">Un nome per riga, o separati da virgole</label>
    <textarea id="nomi" rows="4">${nomi.join(', ')}</textarea>
    <div class="comandi"><button class="tasto tasto--nero" data-fai="salvaFacce">Salva chi lancia</button></div>
    <p class="sotto-riga" style="margin-top:6px">Sulla missione compaiono nome e foto della persona, con accanto “premio di CRASY”. Chi è in questo elenco, e chi ha fondato CRASY, non può partecipare alle missioni del fondo. Se un account viene sospeso o cancellato, il turno passa al successivo.</p>
  </article>`;
}

function uscite(f) {
  return html`<div class="occhiello" style="margin:22px 0 4px">Già uscite</div>
    ${f.ultime.length
      ? html`<div class="righe">
          ${f.ultime.map(
            (u) => html`<div style="display:flex;justify-content:space-between;gap:14px">
              <div>
                <a class="titolo-riga" href="#/missione/${encodeURIComponent(u.gara)}">${u.titolo}</a>
                <div class="sotto-riga">${quando(u.quando)}${u.autore ? ` · @${u.autore}` : ''}</div>
              </div>
              <b class="rosso nowrap">${euro(u.premioCents)}</b>
            </div>`
          )}
        </div>`
      : html`<p class="vuoto">Nessuna ancora.</p>`}`;
}

function ricariche(f) {
  return html`<div class="occhiello" style="margin:22px 0 4px">Ricariche</div>
    ${f.ricariche.length
      ? html`<div class="righe">
          ${f.ricariche.map(
            (r) => html`<div style="display:flex;justify-content:space-between;gap:14px">
              <div>
                <div class="titolo-riga">${r.tipo === 'trasferimento' ? 'Dal fondo vecchio' : 'Carta'}</div>
                <div class="sotto-riga">${quando(r.quando)}${r.commissioneCents ? ` · pagati ${euro(r.lordoCents)}, commissioni ${euro(r.commissioneCents)}` : ''}</div>
              </div>
              <b class="nowrap">+${euro(r.nettoCents)}</b>
            </div>`
          )}
        </div>`
      : html`<p class="vuoto">Nessuna ancora.</p>`}`;
}

function vecchi(f) {
  if (!f.vecchi.length) {
    return '';
  }

  return html`<article class="carta carta--urgente" style="margin-bottom:18px">
    <div class="occhiello" style="margin-bottom:8px">Fondi vecchi con dei soldi dentro</div>
    <p class="sotto-riga" style="margin:0 0 10px">Prima c'era un fondo per persona. Non lanciano più: sposta quello che resta nel portafoglio.</p>
    <div class="righe">
      ${f.vecchi.map(
        (v) => html`<div style="display:flex;justify-content:space-between;align-items:center;gap:14px">
          <div>${nome(v.uid, v.username)} · <b>${euro(v.fondoCents)}</b></div>
          <button class="tasto" data-fai="unisci" data-uid="${v.uid}">Sposta nel portafoglio</button>
        </div>`
      )}
    </div>
  </article>`;
}

export async function mostraAutomatiche(contenuto, parametri, ancoraQui) {
  const f = await chiama('adminFondo');

  if (!ancoraQui()) {
    return;
  }

  metti(
    contenuto,
    html`
      ${testata('Automatiche', 'Il portafoglio delle missioni automatiche: lo ricarichi qui, le missioni partono da sole a nome di chi presta la faccia, e quelle andate a vuoto rimettono qui il premio.')}
      ${vecchi(f)}
      ${saldo(f)}
      <div class="occhiello" style="margin:22px 0 10px">In arrivo</div>
      ${calendario(f.prossime)}
      <div style="height:22px"></div>
      ${facce(f)}
      ${regole(f)}
      ${uscite(f)}
      ${ricariche(f)}
    `
  );

  const ridisegna = () => mostraAutomatiche(contenuto, [], ancoraQui);
  const valore = (id) => document.getElementById(id).value;

  // **Di ritorno da Stripe.** Il saldo lo scrive il webhook, che arriva qualche
  // secondo dopo: si dice cosa sta succedendo e si riguarda fra poco.
  if (parametri[0] === 'ricaricato') {
    dillo('Pagamento fatto: il saldo si aggiorna appena Stripe conferma.');
    history.replaceState(null, '', '#/automatiche');
    setTimeout(() => ancoraQui() && ridisegna(), 6000);
  }

  tasti(contenuto, {
    ricarica: async () => {
      const euroScelti = Number(valore('ricaricaEuro'));

      if (!(euroScelti >= 5 && euroScelti <= 500)) {
        dillo('Una ricarica va da 5 a 500 euro.', { errore: true });

        return;
      }

      const { url } = await chiama('adminRicaricaIlFondo', { euro: euroScelti, origine: location.origin });

      location.href = url;
    },
    accendi: async ({ acceso }) => {
      const eraAcceso = acceso === '1';

      if (eraAcceso) {
        const si = await chiedi({
          titolo: 'Fermare il fondo?',
          testo: 'Le gare già aperte vanno avanti: hanno un premio pagato e delle persone dentro. Non ne partono altre.',
          tasto: 'Ferma',
          pericolo: true,
        });

        if (!si) {
          return;
        }
      } else {
        const si = await chiedi({
          titolo: 'Accendere il fondo?',
          testo: f.dal
            ? `Le missioni partono da sole dal ${f.dal}, alle ore in calendario, finché ci sono soldi.`
            : 'Non c\'è una data di partenza: la prossima missione esce alla prossima ora in calendario.',
          tasto: 'Accendi',
        });

        if (!si) {
          return;
        }
      }

      await chiama('adminFermaIlFondo', { acceso: !eraAcceso });
      await ridisegna();
    },
    lancia: async () => {
      const si = await chiedi({
        titolo: 'Lanciare adesso?',
        testo: 'Esce subito la prossima del calendario, vera e pubblica, anche se il fondo è spento o la data di partenza non è arrivata. Conta nelle missioni di oggi.',
        tasto: 'Lancia',
      });

      if (!si) {
        return;
      }

      const esito = await chiama('adminLanciaDalFondo');

      if (esito && esito.ok) {
        dillo(`Lanciata a nome di @${esito.autore}.`);
      } else {
        dillo(`Non lanciata: ${NO[esito && esito.reason] || (esito && esito.reason) || 'non so perché'}`, { errore: true });
      }

      await ridisegna();
    },
    salta: async () => {
      await chiama('adminSaltaLaProssima');
      dillo('Rimandata al giro dopo.');
      await ridisegna();
    },
    salvaRegole: async () => {
      await chiama('adminImpostaIlFondo', {
        alGiorno: Number(valore('alGiorno')),
        dal: valore('dal'),
        fino: valore('fino'),
        premioCents: Math.round(Number(valore('premioBase')) * 100),
        maxPartecipanti: Number(valore('posti')),
        oreDiGara: Number(valore('ore')),
      });
      dillo('Regole salvate.');
      await ridisegna();
    },
    salvaFacce: async () => {
      const nomi = valore('nomi').split(/[\s,;]+/).filter(Boolean);
      const esito = await chiama('adminAutoriDelFondo', { nomi });

      if (!esito.ok) {
        dillo(`Non trovo: ${esito.mancano.map((n) => '@' + n).join(', ')}. Non ho salvato niente.`, { errore: true });

        return;
      }

      dillo(`Salvati: ${esito.autori.length} account in fila.`);
      await ridisegna();
    },
    unisci: async ({ uid }) => {
      const esito = await chiama('adminUnisciIlFondo', { uid });

      dillo(`Spostati ${euro(esito.spostati)} nel portafoglio.`);
      await ridisegna();
    },
  });
}
