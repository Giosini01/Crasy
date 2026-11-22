/*
 * **Il gioco: sfide del giorno, traguardi e livelli.**
 *
 * Le regole stanno nel database (`config/gioco`) e si cambiano da qui, senza toccare il
 * codice. Sopra si leggono come tabelle; sotto c'e' il testo da modificare. Il server le
 * controlla tutte prima di salvarle (`valida` in `functions/gioco_regole.js`): una
 * soglia scritta male torna indietro con la frase che dice cosa non va, e il gioco
 * continua con quelle di prima.
 */
import { chiama, dillo, html, metti, nome, numero, tasti, testata } from './base.js';

function righe(elenco, giornaliere) {
  return elenco.length
    ? html`<div class="righe">
        ${elenco.map(
          (s) => html`<div style="display:flex;justify-content:space-between;gap:14px;${s.attiva === false ? 'opacity:.5' : ''}">
            <div>
              <div class="titolo-riga">${s.titolo}${s.attiva === false ? ' · spenta' : ''}</div>
              <div class="sotto-riga">${s.descrizione} · <code>${s.metrica}</code> ≥ ${numero(s.obiettivo)}${giornaliere ? ` · gruppo ${s.gruppo}` : ''}</div>
            </div>
            <b class="rosso nowrap">+${numero(s.xp)} XP</b>
          </div>`
        )}
      </div>`
    : html`<p class="vuoto">Nessuna.</p>`;
}

export async function mostraGioco(contenuto, parametri, ancoraQui) {
  const { regole, metriche, icone, classifica, perLivello } = await chiama('adminRegoleDelGioco');
  const massimo = Math.max(1, ...perLivello.map((l) => l.quanti));

  if (!ancoraQui()) {
    return;
  }

  metti(
    contenuto,
    html`
      ${testata(
        'Gioco',
        'Sfide del giorno, traguardi e livelli. Un cambio vale dal prossimo fatto contato; le sfide del giorno nuove arrivano da domani, perché quelle di oggi ognuno le ha già.'
      )}
      <article class="carta" style="margin-bottom:18px">
        <div class="occhiello" style="margin-bottom:10px">Quante persone per livello</div>
        <div class="righe">
          ${perLivello.map(
            (l) => html`<div style="display:flex;align-items:center;gap:12px">
              <div style="width:150px"><b>${l.numero}</b> ${l.nome}</div>
              <div class="barra" style="flex:1;margin:0"><div style="width:${Math.round((l.quanti / massimo) * 100)}%"></div></div>
              <b class="nowrap" style="width:60px;text-align:right">${numero(l.quanti)}</b>
            </div>`
          )}
        </div>
        <div class="occhiello" style="margin:22px 0 6px">Chi ha più XP</div>
        ${classifica.length
          ? html`<div class="righe">
              ${classifica.map(
                (c, i) => html`<div style="display:flex;justify-content:space-between;gap:14px">
                  <div><b>${i + 1}.</b> ${nome(c.uid, c.username)} <span class="fioco">· liv. ${numero(c.livello)}</span></div>
                  <b class="rosso nowrap">${numero(c.xp)} XP</b>
                </div>`
              )}
            </div>`
          : html`<p class="vuoto">Nessuno ha ancora XP.</p>`}
      </article>

      <article class="carta" style="margin-bottom:18px">
        <div class="occhiello" style="margin-bottom:6px">Sfide del giorno · ${numero(regole.giornaliere.quante)} a persona${regole.giornaliere.sempre.length ? ` · sempre: ${regole.giornaliere.sempre.join(', ')}` : ''}</div>
        ${righe(regole.giornaliere.elenco, true)}
        <div class="occhiello" style="margin:22px 0 6px">Traguardi</div>
        ${righe(regole.permanenti, false)}
        <div class="occhiello" style="margin:22px 0 6px">Livelli</div>
        <div class="fatti" style="margin:0">
          ${regole.livelli.map((l) => html`<span><b>${l.numero}</b> ${l.nome} · ${numero(l.xp)} XP</span>`)}
        </div>
      </article>

      <article class="carta">
        <label for="regoleGioco">Le regole (versione ${numero(regole.versione)})</label>
        <textarea id="regoleGioco" rows="26" spellcheck="false" style="font-family:ui-monospace,Menlo,Consolas,monospace;font-size:12px">${JSON.stringify(
          { giornaliere: regole.giornaliere, permanenti: regole.permanenti, livelli: regole.livelli },
          null,
          2
        )}</textarea>
        <div class="comandi"><button class="tasto tasto--nero" data-fai="salva">Salva le regole</button></div>
        <p class="sotto-riga" style="margin-top:8px">
          Cosa si può contare: ${Object.entries(metriche).map(([chiave, cosa]) => html`<code>${chiave}</code> (${cosa}) `)}.
          Le icone: ${icone.map((icona) => html`<code>${icona}</code> `)}.
          <code>serieRecord</code> e <code>giorniGiocati</code> vanno solo fra i traguardi. Per togliere una sfida senza perderne la storia, mettile <code>"attiva": false</code>.
        </p>
      </article>
    `
  );

  tasti(contenuto, {
    salva: async () => {
      let nuove;

      try {
        nuove = JSON.parse(document.getElementById('regoleGioco').value);
      } catch (errore) {
        dillo(`Il testo non è JSON valido: ${errore.message}`, { errore: true });

        return;
      }

      const esito = await chiama('adminRegoleDelGioco', { salva: true, regole: nuove });

      dillo(`Regole salvate: versione ${esito.regole.versione}.`);
      await mostraGioco(contenuto, parametri, ancoraQui);
    },
  });
}
