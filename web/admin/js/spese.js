/*
 * **Tutte le spese di CRASY, per filo e per segno.**
 *
 * Ogni riga dice che tipo di numero e': vero (Stripe, e la fattura di Google quando e'
 * collegata), stimato (i consumi di Google per il listino, l'AI sui gettoni) o scritto a mano
 * (le spese fisse). Sommati fanno un totale solo perche' chi guarda vuole sapere quanto gli
 * resta: accanto c'e' sempre scritto cosa c'e' dentro.
 */
import {
  caricaIn,
  chiama,
  chiedi,
  dillo,
  dollari,
  euro,
  fidato,
  html,
  metti,
  numero,
  pannello,
  quando,
  tasti,
  testata,
} from './base.js';
import { caricaSpeseAI } from './soldi.js';

const PERIODI = [7, 30, 90, 365];
const OGNI = { mese: 'al mese', anno: 'all\'anno', una: 'una tantum' };

function nomePeriodo(giorni) {
  return giorni === 365 ? 'Un anno' : `${giorni} giorni`;
}

/** Euro con la virgola, per cifre che arrivano in euro e possono essere minuscole. */
function euroPreciso(valore) {
  if (valore === null || valore === undefined) {
    return '—';
  }

  if (valore > 0 && valore < 0.005) {
    return 'meno di €0,01';
  }

  return euro(Math.round(valore * 100));
}

function quantita(valore, unita) {
  const decimali = valore >= 100 || Number.isInteger(valore) ? 0 : 2;

  return `${Number(valore).toLocaleString('it-IT', { maximumFractionDigits: decimali })} ${unita}`;
}

function riassunto(s, t) {
  const tuaParte = t.guadagno + t.speseStripe;
  const resta = tuaParte - s.totale;
  const mancanti = [];

  if (s.parti.stripe === null) {
    mancanti.push('Stripe');
  }

  if (s.parti.google === null) {
    mancanti.push('Google');
  }

  return html`
    <div class="numeri">
      <div class="numero">
        <div class="occhiello">La tua parte</div>
        <div class="numero__cifra">${euro(tuaParte)}</div>
        <div class="numero__nota">quello che resta a CRASY sugli incassi, prima di ogni spesa${t.guadagnoInAttesa ? html`, di cui ${euro(t.guadagnoInAttesa)} ancora in gara` : ''}</div>
      </div>
      <div class="numero">
        <div class="occhiello">Tutte le spese</div>
        <div class="numero__cifra">${euro(s.totale)}</div>
        <div class="numero__nota">${mancanti.length ? `manca ${mancanti.join(' e ')}: non ha risposto` : s.googleVero ? 'Stripe e Google vere, AI stimata' : 'Stripe vera, Google e AI stimate'}</div>
      </div>
      <div class="numero numero--allarme">
        <div class="occhiello occhiello--rosso">Ti resta davvero</div>
        <div class="numero__cifra">${euro(resta)}</div>
        <div class="numero__nota">la tua parte, meno tutte le spese</div>
      </div>
    </div>
    <div class="numeri" style="margin-top:12px">
      <a class="numero" href="#stripe"><div class="occhiello">Stripe</div><div class="numero__cifra">${s.parti.stripe === null ? '—' : euro(s.parti.stripe)}</div><div class="numero__nota">vero</div></a>
      <a class="numero" href="#ai"><div class="occhiello">AI</div><div class="numero__cifra">${euro(s.parti.ai)}</div><div class="numero__nota">stima, ${dollari(s.ai.dollari)}</div></a>
      <a class="numero" href="#google"><div class="occhiello">Firebase e database</div><div class="numero__cifra">${s.parti.google === null ? '—' : euro(s.parti.google)}</div><div class="numero__nota">${s.googleVero ? 'vero' : 'stima, senza IVA'}</div></a>
      <a class="numero" href="#fisse"><div class="occhiello">Spese fisse</div><div class="numero__cifra">${euro(s.parti.fisse)}</div><div class="numero__nota">scritte da te</div></a>
    </div>
  `;
}

function sezioneStripe(st) {
  if (!st) {
    return html`<p class="vuoto">Stripe non ha risposto. Riprova tra poco.</p>`;
  }

  if (!st.voci.length) {
    return html`<p class="vuoto">Nessuna spesa di Stripe nel periodo.</p>`;
  }

  return html`
    <div class="tabella-giro"><table>
      <thead><tr><th>Voce</th><th class="num">Quante</th><th class="num">Quanto</th></tr></thead>
      <tbody>
        ${st.voci.map(
          (v) => html`<tr><td>${v.nome}</td><td class="num">${numero(v.quante)}</td><td class="num">${euro(v.cents)}</td></tr>`
        )}
        <tr><td><b>Totale</b></td><td></td><td class="num"><b>${euro(st.totale)}</b></td></tr>
      </tbody>
    </table></div>
    ${st.suRimborsati
      ? html`<p class="sotto-riga" style="margin-top:10px">Di cui ${euro(st.suRimborsati)} su pagamenti rimborsati per intero: Stripe non restituisce la sua parte.</p>`
      : ''}
    <details class="dettagli">
      <summary>Riga per riga (${numero(st.quanteRighe)})</summary>
      <div class="tabella-giro"><table>
        <thead><tr><th>Quando</th><th>Voce</th><th>Di cosa</th><th class="num">Quanto</th></tr></thead>
        <tbody>
          ${st.righe.map(
            (r) => html`<tr>
              <td class="nowrap">${quando(r.quando)}</td>
              <td>${r.voce}</td>
              <td class="sotto-riga">${r.dettaglio}</td>
              <td class="num">${euro(r.cents)}</td>
            </tr>`
          )}
        </tbody>
      </table></div>
      ${st.quanteRighe > st.righe.length
        ? html`<p class="sotto-riga">Qui ci sono le ultime ${numero(st.righe.length)}: le altre stanno su Stripe.</p>`
        : ''}
    </details>
  `;
}

/** Vicino alla quota gratis: e' da li' che arriva la prossima spesa. */
function quasiFinita(voce) {
  return voce.quotaPercento >= 70
    ? html`<div class="sotto-riga rosso">${Math.round(voce.quotaPercento)}% della quota gratis</div>`
    : '';
}

function tabellaConsumi(voci) {
  const gruppi = [...new Set(voci.map((v) => v.gruppo))];

  return html`<div class="tabella-giro"><table>
    <thead><tr>
      <th>Cosa</th><th class="num">Usato</th><th>Gratis</th><th>Prezzo</th>
      <th class="num">A pagamento</th><th class="num">Costo</th>
    </tr></thead>
    <tbody>
      ${gruppi.map(
        (gruppo) => html`
          <tr><td colspan="6"><b>${gruppo}</b></td></tr>
          ${voci
            .filter((v) => v.gruppo === gruppo)
            .map((v) =>
              v.nonLetta
                ? html`<tr><td>${v.nome}</td><td colspan="5" class="sotto-riga">Non letto: Google non ha risposto.</td></tr>`
                : html`<tr>
                    <td>${v.nome}${quasiFinita(v)}</td>
                    <td class="num nowrap">${quantita(v.usato, v.unita)}</td>
                    <td class="sotto-riga">${v.gratis}</td>
                    <td class="sotto-riga">${v.prezzo}</td>
                    <td class="num">${quantita(v.aPagamento, '')}</td>
                    <td class="num">${euroPreciso(v.costo)}</td>
                  </tr>`
            )}
        `
      )}
    </tbody>
  </table></div>`;
}

/** Il database giorno per giorno: letture, scritture e cancellazioni, e quanto sopra la quota. */
function giorniDelDatabase(voci) {
  const letture = voci.find((v) => v.nome === 'Letture' && v.giorni);
  const scritture = voci.find((v) => v.nome === 'Scritture' && v.giorni);
  const cancellazioni = voci.find((v) => v.nome === 'Cancellazioni' && v.giorni);

  if (!letture) {
    return '';
  }

  const di = (voce, giorno) => (voce && voce.giorni.find((p) => p.giorno === giorno)) || { valore: 0 };
  const giorni = [...letture.giorni].reverse();

  return html`<details class="dettagli">
    <summary>Il database giorno per giorno</summary>
    <div class="tabella-giro"><table>
      <thead><tr><th>Giorno</th><th class="num">Letture</th><th class="num">Scritture</th><th class="num">Cancellazioni</th></tr></thead>
      <tbody>
        ${giorni.map(
          (p) => html`<tr>
            <td class="nowrap">${p.giorno}</td>
            <td class="num ${p.valore > 50000 ? 'rosso' : ''}">${numero(p.valore)}</td>
            <td class="num">${numero(di(scritture, p.giorno).valore)}</td>
            <td class="num">${numero(di(cancellazioni, p.giorno).valore)}</td>
          </tr>`
        )}
      </tbody>
    </table></div>
    <p class="sotto-riga">In rosso i giorni oltre le 50.000 letture gratis.</p>
  </details>`;
}

function fatturaDaCollegare(vero) {
  const dataset = vero && vero.dataset ? vero.dataset : 'fatturazione';
  const daCreare = !vero || vero.perche === 'manca-il-dataset';

  return html`<div class="nota" style="margin-top:14px">
    <b>La fattura vera di Google non è ancora collegata.</b> Le cifre qui sotto sono una stima, IVA
    esclusa: consumi veri per il listino di Google. Per avere quelle della fattura, voce per voce:
    <ol style="margin:10px 0 10px 20px;padding:0">
      <li>Apri <a href="https://console.cloud.google.com/billing/export" target="_blank" rel="noopener">l'esportazione della fatturazione</a> e scegli il conto <b>Pagamento Firebase</b>.</li>
      <li>In <b>BigQuery export</b>, attiva <b>Standard usage cost</b> e scegli il progetto <b>daily-dating-app</b>.</li>
      <li>${daCreare
        ? html`Come dataset creane uno nuovo: nome <b>${dataset}</b>, posizione <b>multi-regione EU</b>. Il nome e la posizione devono essere proprio questi. Poi salva.`
        : html`Come dataset scegli <b>${dataset}</b>, e salva.`}</li>
    </ol>
    I primi dati arrivano nel giro di qualche ora, e fino a cinque giorni dopo c'è anche il mese
    scorso. Qui si aggiorna da solo.
  </div>`;
}

function fatturaVera(v) {
  if (v.inCorso) {
    return html`<p class="vuoto">La fattura di Google sta arrivando. Riprova tra un minuto.</p>`;
  }

  if (!v.righe.length) {
    return html`<p class="vuoto">Esportazione attiva: Google non ha ancora scritto niente per questo periodo.</p>`;
  }

  const servizi = [...new Set(v.righe.map((r) => r.servizio))];

  return html`
    <h3 style="margin:22px 0 6px">La fattura vera di Google</h3>
    <p class="sotto-riga" style="margin:0 0 10px">
      Cifre di Google: ${euroPreciso(v.costo)} di costo, ${euroPreciso(v.crediti)} di crediti, ${euroPreciso(v.netto)} da pagare, IVA esclusa.
      ${v.aggiornato ? html`Aggiornata a ${quando(v.aggiornato)}: Google scrive con qualche ora di ritardo.` : ''}
    </p>
    <div class="tabella-giro"><table>
      <thead><tr><th>Voce</th><th class="num">Quantità</th><th class="num">Costo</th><th class="num">Crediti</th><th class="num">Da pagare</th></tr></thead>
      <tbody>
        ${servizi.map((servizio) => {
          const righe = v.righe.filter((r) => r.servizio === servizio);
          const totale = righe.reduce((somma, r) => somma + r.netto, 0);

          return html`
            <tr><td colspan="4"><b>${servizio}</b></td><td class="num"><b>${euroPreciso(totale)}</b></td></tr>
            ${righe.map(
              (r) => html`<tr>
                <td>${r.voce}</td>
                <td class="num nowrap">${quantita(r.quantita, r.unita)}</td>
                <td class="num">${euroPreciso(r.costo)}</td>
                <td class="num">${euroPreciso(r.crediti)}</td>
                <td class="num">${euroPreciso(r.netto)}</td>
              </tr>`
            )}
          `;
        })}
      </tbody>
    </table></div>
    <details class="dettagli">
      <summary>Giorno per giorno</summary>
      <div class="tabella-giro"><table>
        <thead><tr><th>Giorno</th><th class="num">Da pagare</th></tr></thead>
        <tbody>
          ${v.giorni.map((g) => html`<tr><td class="nowrap">${g.giorno}</td><td class="num">${euroPreciso(g.netto)}</td></tr>`)}
        </tbody>
      </table></div>
    </details>
  `;
}

function sezioneGoogle(s) {
  return html`
    ${s.vero && s.vero.attivo ? fatturaVera(s.vero) : fatturaDaCollegare(s.vero)}
    <h3 style="margin:22px 0 6px">Consumi e stima</h3>
    ${s.consumi
      ? html`
          <p class="sotto-riga" style="margin:0 0 10px">
            Consumi letti da Google, al listino del ${s.consumi.listino}. In tutto ${euroPreciso(s.consumi.costo)}.
            Le voci minime, come la rete interna, stanno solo nella fattura.
          </p>
          ${tabellaConsumi(s.consumi.voci)}
          ${giorniDelDatabase(s.consumi.voci)}
        `
      : html`<p class="vuoto">Google non ha risposto. Riprova tra poco.</p>`}
  `;
}

function sezioneFisse(f, giorni) {
  return html`
    <p class="sotto-riga" style="margin:0 0 10px">
      Quello che non ha un posto da cui leggerlo: Apple Developer, Google Play, il dominio, le email,
      il commercialista. Gli abbonamenti si spalmano sul periodo scelto.
    </p>
    ${f.righe.length
      ? html`<div class="tabella-giro"><table>
          <thead><tr><th>Spesa</th><th class="num">Costa</th><th>Ogni</th><th class="num">In ${nomePeriodo(giorni).toLowerCase()}</th><th></th></tr></thead>
          <tbody>
            ${f.righe.map(
              (r) => html`<tr>
                <td>${r.nome}</td>
                <td class="num">${euro(r.cents)}</td>
                <td class="sotto-riga">${OGNI[r.ogni] || r.ogni}${r.ogni === 'una' ? html`, ${r.quando}` : ''}</td>
                <td class="num">${euro(r.nelPeriodo)}</td>
                <td class="num"><button class="tasto tasto--piccolo" data-fai="togli" data-id="${r.id}" data-nome="${r.nome}">Togli</button></td>
              </tr>`
            )}
          </tbody>
        </table></div>`
      : html`<p class="vuoto">Nessuna ancora.</p>`}
    <form id="nuova-spesa" style="display:flex;gap:10px;flex-wrap:wrap;align-items:flex-end;margin-top:16px">
      <label style="flex:2 1 220px">Spesa<input id="spesaNome" type="text" maxlength="80" required placeholder="Apple Developer"></label>
      <label style="flex:1 1 110px">Euro<input id="spesaEuro" type="number" min="0.01" step="0.01" required placeholder="99"></label>
      <label style="flex:1 1 140px">Ogni
        <select id="spesaOgni">
          <option value="anno">all'anno</option>
          <option value="mese">al mese</option>
          <option value="una">una tantum</option>
        </select>
      </label>
      <button class="tasto tasto--nero" type="submit">Aggiungi</button>
    </form>
  `;
}

async function carica(dove, giorni, ridisegna) {
  await caricaIn(dove, async () => {
    const [s, { totali: t }] = await Promise.all([
      pannello('spese', { giorni }),
      chiama('adminGuadagni', { giorni }),
    ]);

    metti(
      dove,
      html`
        ${riassunto(s, t)}

        <div class="sezione" id="stripe">
          <h2>Stripe</h2>
          <p class="sotto-riga" style="margin:0 0 10px">Cifre vere, lette da Stripe movimento per movimento.</p>
          ${sezioneStripe(s.stripe)}
        </div>

        <div class="sezione" id="ai">
          <h2>AI</h2>
          <p class="sotto-riga" style="margin:0 0 10px">
            Nel periodo ${dollari(s.ai.dollari)}, circa ${euro(s.parti.ai)} al cambio di ${String(s.cambio).replace('.', ',')}:
            ${numero(s.ai.giudizi)} giudizi pagati e ${numero(s.ai.riusati)} riusati gratis.
          </p>
          <div id="ai-dettagli"></div>
        </div>

        <div class="sezione" id="google">
          <h2>Firebase e database</h2>
          ${sezioneGoogle(s)}
        </div>

        <div class="sezione" id="fisse">
          <h2>Spese fisse</h2>
          ${sezioneFisse(s.fisse, giorni)}
        </div>
      `
    );

    caricaSpeseAI(dove.querySelector('#ai-dettagli'));

    tasti(dove.querySelector('#fisse'), {
      togli: async ({ id, nome }) => {
        const risposta = await chiedi({
          titolo: 'Togliere questa spesa?',
          testo: `“${nome}” non verrà più contata.`,
          tasto: 'Togli',
          pericolo: true,
        });

        if (risposta) {
          await pannello('togliSpesaFissa', { id });
          dillo('Tolta.');
          await ridisegna();
        }
      },
    });

    dove.querySelector('#nuova-spesa').addEventListener('submit', async (evento) => {
      evento.preventDefault();

      await pannello('aggiungiSpesaFissa', {
        nome: dove.querySelector('#spesaNome').value,
        euro: dove.querySelector('#spesaEuro').value,
        ogni: dove.querySelector('#spesaOgni').value,
      });
      dillo('Aggiunta.');
      await ridisegna();
    });
  });
}

export async function mostraSpese(contenuto) {
  let giorni = 30;

  metti(
    contenuto,
    html`
      ${testata('Spese', 'Quanto costa tenere in piedi CRASY, voce per voce.')}
      <div class="schede" id="periodi">
        ${PERIODI.map(
          (g) => html`<button class="scheda ${g === giorni ? 'scelta' : ''}" data-fai="periodo" data-giorni="${g}">${nomePeriodo(g)}</button>`
        )}
      </div>
      <div id="spese"></div>
    `
  );

  const dove = contenuto.querySelector('#spese');
  const ridisegna = () => carica(dove, giorni, ridisegna);

  tasti(contenuto.querySelector('#periodi'), {
    periodo: async ({ giorni: scelti }) => {
      giorni = Number(scelti);
      contenuto.querySelectorAll('#periodi .scheda').forEach((tasto) => {
        tasto.classList.toggle('scelta', Number(tasto.dataset.giorni) === giorni);
      });
      await ridisegna();
    },
  });

  await ridisegna();
}
