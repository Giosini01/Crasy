/*
 * **Come funziona il controllo, e il modo di cambiarlo senza pubblicare niente.**
 *
 * Le soglie, l'interruttore "solo a mano" per i giorni in cui si vuole guardare tutto,
 * e le parole: quando qualcuno trova un travestimento nuovo si chiude da qui in un
 * minuto, e quando il filtro si arrabbia con chi non ha fatto niente si riapre da qui.
 */
import { dillo, dollari, html, metti, numero, pannello, tasti, testata } from './base.js';

function comeElenco(testo) {
  return testo
    .split(/[\n,]/)
    .map((t) => t.trim())
    .filter(Boolean);
}

function comeTesto(elenco) {
  return (elenco || []).join('\n');
}

export async function mostraRegole(contenuto, parametri, ancoraQui) {
  const i = await pannello('impostazioni');

  if (!ancoraQui()) {
    return;
  }

  const larghezza = (da, a) => Math.max(a - da, 8);

  metti(
    contenuto,
    html`
      ${testata('Regole')}

      <div class="occhiello occhiello--rosso" style="margin-bottom:8px">Come passa una missione</div>
      <div class="scala" aria-hidden="true">
        <div class="scala__mano" style="flex:${larghezza(0, i.sogliaConferma)}">Sotto ${i.sogliaConferma}: la guardi tu</div>
        <div class="scala__conferma" style="flex:${larghezza(i.sogliaConferma, i.sogliaAuto)}">Conferma</div>
        <div class="scala__auto" style="flex:${larghezza(i.sogliaAuto, 100)}">Da ${i.sogliaAuto}: sola</div>
      </div>

      <div class="numeri" style="margin-top:18px">
        <div class="numero ${i.chiave ? '' : 'numero--allarme'}">
          <div class="occhiello">L'intelligenza artificiale</div>
          <div class="numero__cifra">${i.chiave ? 'Accesa' : 'Spenta'}</div>
          <div class="numero__nota">${i.chiave ? i.modello : 'Manca la chiave di OpenAI: tutte le missioni passano da te.'}</div>
        </div>
        <div class="numero">
          <div class="occhiello">Giudizi di oggi</div>
          <div class="numero__cifra">${numero(i.giudiziOggi)}<small> / ${numero(i.tettoGiudizi)}</small></div>
          <div class="numero__nota">Oltre il tetto le missioni vanno da te, e il conto non cresce.</div>
        </div>
        <a class="numero" href="#/soldi">
          <div class="occhiello">Spesi per l'AI, 30 giorni</div>
          <div class="numero__cifra">${i.spese ? dollari(i.spese.mese.dollari) : '—'}</div>
          <div class="numero__nota">Il dettaglio sta in Soldi.</div>
        </a>
      </div>

      <form id="regole" class="sezione" style="display:grid;gap:26px;max-width:620px">
        <label class="interruttore">
          <input id="soloAMano" type="checkbox" ${i.soloAMano ? html`checked` : ''}>
          <span><b>Solo a mano.</b> Nessuna missione esce da sola, qualunque voto prenda. Per i giorni in cui vuoi guardarle tutte.</span>
        </label>

        <div class="soglie">
          <div>
            <label for="sogliaAuto">Esce da sola da</label>
            <input id="sogliaAuto" type="number" min="1" max="100" value="${i.sogliaAuto}" required>
          </div>
          <div>
            <label for="sogliaConferma">Chiede conferma da</label>
            <input id="sogliaConferma" type="number" min="0" max="99" value="${i.sogliaConferma}" required>
          </div>
          <div>
            <label for="tettoGiudizi">Giudizi al giorno, al massimo</label>
            <input id="tettoGiudizi" type="number" min="0" max="20000" value="${i.tettoGiudizi}" required>
          </div>
        </div>

        <div>
          <label for="rosse">Parole rosse aggiunte, fermano subito</label>
          <textarea id="rosse" spellcheck="false" placeholder="Una per riga">${comeTesto(i.rosseAggiunte)}</textarea>
          <p class="sotto-riga" style="margin:6px 0 0">Si riconoscono anche travestite (numeri, simboli, lettere ripetute), dall'inizio della parola.</p>
        </div>

        <div>
          <label for="gialle">Parole gialle aggiunte, mandano da te</label>
          <textarea id="gialle" spellcheck="false" placeholder="Una per riga">${comeTesto(i.gialleAggiunte)}</textarea>
        </div>

        <div>
          <label for="consentite">Falsi allarmi, da non considerare più</label>
          <textarea id="consentite" spellcheck="false" placeholder="Una per riga">${comeTesto(i.consentite)}</textarea>
          <p class="sotto-riga" style="margin:6px 0 0">Scrivi la parola esattamente come la mostra la missione fermata.</p>
        </div>

        <div class="comandi">
          <button class="tasto tasto--nero" data-fai="salva">Salva</button>
        </div>
      </form>
    `
  );

  const valore = (id) => contenuto.querySelector(`#${id}`).value;

  tasti(contenuto.querySelector('#regole'), {
    salva: async () => {
      await pannello('scriviImpostazioni', {
        sogliaAuto: Number(valore('sogliaAuto')),
        sogliaConferma: Number(valore('sogliaConferma')),
        tettoGiudizi: Number(valore('tettoGiudizi')),
        soloAMano: contenuto.querySelector('#soloAMano').checked,
        rosseAggiunte: comeElenco(valore('rosse')),
        gialleAggiunte: comeElenco(valore('gialle')),
        consentite: comeElenco(valore('consentite')),
      });
      dillo('Salvato. Vale da entro un minuto.');
      window.dispatchEvent(new Event('pannello:cambiato'));
      await mostraRegole(contenuto, parametri, ancoraQui);
    },
  });
}
