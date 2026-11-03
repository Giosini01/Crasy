/*
 * **I soldi di CRASY**: quanto guadagni, quanto spendi, i bonifici da fare a mano.
 *
 * Su Stripe arriva tutto insieme: premi di altri, spese e la parte di CRASY. Qui si
 * divide, incasso per incasso, con le spese vere lette da Stripe. L'AI si paga in dollari
 * e a parte, quindi non si sottrae: sommare due valute farebbe un numero che non e' vero.
 */
import {
  caricaIn,
  chiama,
  chiedi,
  dillo,
  dollari,
  euro,
  html,
  metti,
  nome,
  numero,
  pannello,
  quando,
  quanti,
  tasti,
  testata,
} from './base.js';

const PERIODI = [7, 30, 90, 365];

function nomePeriodo(giorni) {
  return giorni === 365 ? 'Un anno' : `${giorni} giorni`;
}

async function caricaGuadagni(dove, giorni) {
  await caricaIn(dove, async () => {
    const [{ totali: t, righe }, conti] = await Promise.all([
      chiama('adminGuadagni', { giorni }),
      pannello('contiStripe', { giorni }),
    ]);
    const tiResta = t.guadagno - conti.altreSpese;
    const costaStripe = t.speseStripe + conti.altreSpese;

    metti(
      dove,
      html`
        <div class="occhiello occhiello--rosso" style="margin-bottom:10px">Quanto guadagni</div>
        <div class="numeri">
          <div class="numero">
            <div class="occhiello occhiello--rosso">Ti resta</div>
            <div class="numero__cifra rosso">${euro(tiResta)}</div>
            ${t.guadagnoInAttesa ? html`<div class="numero__nota">di cui ${euro(t.guadagnoInAttesa)} su missioni ancora in gara: possono tornare indietro</div>` : html`<div class="numero__nota">tolte le spese di Stripe</div>`}
          </div>
          <div class="numero"><div class="occhiello">Hai incassato</div><div class="numero__cifra">${euro(t.incassato)}</div></div>
          <div class="numero"><div class="occhiello">Per i vincitori</div><div class="numero__cifra">${euro(t.aiVincitori)}</div><div class="numero__nota">${euro(conti.aiVincitori)} già girati ai loro conti</div></div>
          ${t.mance ? html`<div class="numero"><div class="occhiello">Mance</div><div class="numero__cifra">${euro(t.mance)}</div></div>` : ''}
          ${t.altro ? html`<div class="numero"><div class="occhiello">Altro, non guadagno</div><div class="numero__cifra">${euro(t.altro)}</div></div>` : ''}
          <div class="numero"><div class="occhiello">Mandati in banca</div><div class="numero__cifra">${euro(conti.inBanca)}</div></div>
        </div>

        <div class="occhiello occhiello--rosso" style="margin:22px 0 10px">Quanto spendi</div>
        <div class="numeri">
          <div class="numero">
            <div class="occhiello">Stripe</div>
            <div class="numero__cifra">${euro(costaStripe)}</div>
            <div class="numero__nota">${euro(t.speseStripe)} sugli incassi, ${euro(conti.altreSpese)} a parte</div>
          </div>
          <div class="numero">
            <div class="occhiello">Rimborsi fatti</div>
            <div class="numero__cifra">${euro(conti.rimborsi)}</div>
            <div class="numero__nota">soldi tornati, non è una spesa</div>
          </div>
          <div class="numero">
            <div class="occhiello">AI</div>
            <div class="numero__cifra">${dollari(conti.ai.dollari)}</div>
            <div class="numero__nota">${numero(conti.ai.giudizi)} giudizi pagati, ${numero(conti.ai.riusati)} riusati gratis</div>
          </div>
        </div>
        <p class="sotto-riga" style="margin:10px 0 18px">L'AI è in dollari e non è sottratta da “Ti resta”. La bolletta di Firebase e gli abbonamenti Apple e Google non sono qui: stanno sui loro siti.</p>

        ${righe.length
          ? html`<div class="tabella-giro" style="margin-top:14px"><table>
              <thead><tr>
                <th>Quando</th><th>Cosa</th><th class="num">Pagato</th><th class="num">Reso</th>
                <th class="num">Stripe</th><th class="num">Al vincitore</th><th class="num">Tuo</th><th>Stato</th>
              </tr></thead>
              <tbody>
                ${righe.map(
                  (r) => html`<tr>
                    <td class="nowrap">${quando(r.quando)}</td>
                    <td>${r.cosa}${r.titolo ? html`<div class="sotto-riga">${r.titolo}</div>` : ''}</td>
                    <td class="num">${euro(r.pagato)}</td>
                    <td class="num">${r.reso ? euro(r.reso) : '—'}</td>
                    <td class="num">${euro(r.stripe)}</td>
                    <td class="num">${r.alVincitore ? euro(r.alVincitore) : '—'}</td>
                    <td class="num"><b class="${r.tuo < 0 ? 'rosso' : ''}">${euro(r.tuo)}</b></td>
                    <td class="sotto-riga">${r.stato}</td>
                  </tr>`
                )}
              </tbody>
            </table></div>`
          : html`<p class="vuoto">Nessun incasso nel periodo.</p>`}
      `
    );
  });
}

async function caricaPrelievi(dove) {
  await caricaIn(dove, async () => {
    const { richieste } = await chiama('adminListPayouts');

    metti(
      dove,
      richieste.length
        ? html`<div class="carte">
            ${richieste.map(
              (r) => html`<article class="carta">
                <div class="premio">${euro(r.amountCents)}</div>
                <p style="margin:12px 0 0">
                  <b>${`${r.firstName} ${r.lastName}`.trim() || '—'}</b>
                  ${nome(r.userId, r.username)}
                </p>
                <p style="margin:8px 0 0"><code>${r.iban}</code></p>
                ${r.fiscalCode ? html`<p class="sotto-riga" style="margin:6px 0 0">${r.fiscalCode}</p>` : ''}
                <p class="sotto-riga" style="margin:6px 0 0">Chiesto ${quando(r.createdAt)}</p>
                <div class="comandi">
                  <button class="tasto tasto--nero" data-fai="pagato" data-id="${r.id}" data-quanto="${euro(r.amountCents)}">Bonifico fatto</button>
                  <button class="tasto" data-fai="nonRiuscito" data-id="${r.id}">Non riuscito</button>
                </div>
              </article>`
            )}
          </div>`
        : html`<p class="vuoto">Nessuno aspetta dei soldi.</p>`
    );
  });
}

async function caricaSpeseAI(dove) {
  await caricaIn(dove, async () => {
    const a = await pannello('speseAI');
    const perMille = a.allaMissione === null ? null : a.allaMissione * 1000;

    metti(
      dove,
      html`
        <div class="numeri">
          <div class="numero"><div class="occhiello">Oggi</div><div class="numero__cifra">${dollari(a.oggi.dollari)}</div><div class="numero__nota">${numero(a.oggi.giudizi)} giudizi</div></div>
          <div class="numero"><div class="occhiello">7 giorni</div><div class="numero__cifra">${dollari(a.settimana.dollari)}</div><div class="numero__nota">${numero(a.settimana.giudizi)} giudizi</div></div>
          <div class="numero"><div class="occhiello">30 giorni</div><div class="numero__cifra">${dollari(a.mese.dollari)}</div><div class="numero__nota">${numero(a.mese.giudizi)} giudizi</div></div>
          <div class="numero"><div class="occhiello">Da sempre</div><div class="numero__cifra">${dollari(a.sempre.dollari)}</div><div class="numero__nota">${numero(a.sempre.riusati)} riusati gratis</div></div>
          <div class="numero"><div class="occhiello">Mille missioni</div><div class="numero__cifra">${dollari(perMille)}</div><div class="numero__nota">al costo medio di quelle giudicate</div></div>
        </div>
        <p class="sotto-riga" style="margin:10px 0 14px">
          Modello ${a.modello}: $${a.prezzi.entrata} per milione di gettoni in entrata, $${a.prezzi.uscita} in uscita.
          È il conto sui gettoni dichiarati da OpenAI: la fattura vera sta su platform.openai.com.
        </p>
        ${a.giorni.length
          ? html`<div class="tabella-giro"><table>
              <thead><tr><th>Giorno</th><th class="num">Giudizi pagati</th><th class="num">Di cui prove</th><th class="num">Riusati</th><th class="num">Spesa</th></tr></thead>
              <tbody>
                ${a.giorni.map(
                  (g) => html`<tr>
                    <td class="nowrap">${g.giorno}</td>
                    <td class="num">${numero(g.giudizi)}</td>
                    <td class="num">${numero(g.prove)}</td>
                    <td class="num">${numero(g.riusati)}</td>
                    <td class="num">${dollari(g.dollari)}</td>
                  </tr>`
                )}
              </tbody>
            </table></div>`
          : html`<p class="vuoto">Nessun giudizio ancora.</p>`}
      `
    );
  });
}

async function caricaMance(dove) {
  await caricaIn(dove, async () => {
    const { mance, totaleCents } = await chiama('adminListMance');

    metti(
      dove,
      html`
        <p>In tutto <b class="rosso">${euro(totaleCents)}</b> da ${quanti(mance.length, 'mancia', 'mance')}.</p>
        ${mance.length
          ? html`<div class="righe">
              ${mance.map(
                (m) => html`<div style="display:flex;justify-content:space-between;gap:14px">
                  <div>
                    da ${nome(m.userId, m.username)}
                    ${m.beneficiarioUsername ? html` per @${m.beneficiarioUsername}` : ''}
                    ${m.verificato ? html` <span class="pastiglia pastiglia--rossa">sostenitore</span>` : ''}
                    <div class="sotto-riga">${quando(m.createdAt)}</div>
                  </div>
                  <b class="rosso nowrap">${euro(m.amountCents)}</b>
                </div>`
              )}
            </div>`
          : ''}
      `
    );
  });
}

export async function mostraSoldi(contenuto) {
  let giorni = 30;

  metti(
    contenuto,
    html`
      ${testata('Soldi')}

      <div>
        <h2>I conti</h2>
        <div class="schede" id="periodi">
          ${PERIODI.map(
            (g) => html`<button class="scheda ${g === giorni ? 'scelta' : ''}" data-fai="periodo" data-giorni="${g}">${nomePeriodo(g)}</button>`
          )}
        </div>
        <div id="guadagni"></div>
      </div>

      <div class="sezione">
        <h2>Prelievi da pagare</h2>
        <div id="prelievi"></div>
      </div>

      <div class="sezione">
        <h2>Quanto costa l'AI</h2>
        <div id="speseAI"></div>
      </div>

      <div class="sezione">
        <h2>Mance</h2>
        <div id="mance"></div>
      </div>
    `
  );

  const guadagni = contenuto.querySelector('#guadagni');
  const prelievi = contenuto.querySelector('#prelievi');

  tasti(contenuto.querySelector('#periodi'), {
    periodo: async ({ giorni: scelti }) => {
      giorni = Number(scelti);
      contenuto.querySelectorAll('#periodi .scheda').forEach((tasto) => {
        tasto.classList.toggle('scelta', Number(tasto.dataset.giorni) === giorni);
      });
      await caricaGuadagni(guadagni, giorni);
    },
  });

  tasti(prelievi, {
    pagato: async ({ id, quanto }) => {
      // Nessuna macchina puo' sapere se quel bonifico e' stato fatto davvero: lo dice chi
      // l'ha fatto, e resta scritto.
      const risposta = await chiedi({
        titolo: 'Il bonifico è partito?',
        testo: `Confermi di aver mandato ${quanto}.`,
        tasto: 'Sì, è partito',
      });

      if (risposta) {
        await chiama('adminMarkPayoutPaid', { id });
        dillo('Segnato.');
        window.dispatchEvent(new Event('pannello:cambiato'));
        await caricaPrelievi(prelievi);
      }
    },
    nonRiuscito: async ({ id }) => {
      const risposta = await chiedi({
        titolo: 'Bonifico non riuscito?',
        testo: 'I soldi tornano nel portafoglio di chi li ha chiesti.',
        tasto: 'Rimetti i soldi',
        pericolo: true,
      });

      if (risposta) {
        await chiama('adminMarkPayoutPaid', { id, rimborsa: true });
        dillo('Soldi rimessi.');
        window.dispatchEvent(new Event('pannello:cambiato'));
        await caricaPrelievi(prelievi);
      }
    },
  });

  // Ognuno per conto suo: Stripe puo' metterci qualche secondo, e non deve tenere
  // ferma la lista dei bonifici.
  caricaPrelievi(prelievi);
  caricaGuadagni(guadagni, giorni);
  caricaSpeseAI(contenuto.querySelector('#speseAI'));
  caricaMance(contenuto.querySelector('#mance'));
}
