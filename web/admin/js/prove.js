/*
 * **Il banco di prova: si lancia una missione per finta, e si insegna al modello.**
 *
 * Una prova passa dagli stessi controlli di una missione vera, e qui si legge esattamente
 * cosa succederebbe a chi la lancia. Ma non nasce niente: nessuna gara, nessun avviso,
 * nessun pagamento, e il voto non resta nella memoria che usano le missioni vere.
 *
 * **Il modello non si addestra davvero**: quello lo fa OpenAI. Gli si insegna con gli
 * esempi: quando un voto e' sbagliato lo si corregge, e la missione corretta entra nelle
 * sue istruzioni. Conviene rilanciare la batteria dopo ogni correzione, perche' un esempio
 * insegnato male puo' far uscire da sola una cosa che prima si fermava.
 */
import {
  chiedi,
  dillo,
  dilloErrore,
  dollari,
  euro,
  fa,
  frase,
  html,
  metti,
  numero,
  pannello,
  tasti,
  testata,
} from './base.js';
import { bollinoVoto, ilPerche } from './missioni.js';

const STRADE = {
  inGara: 'Esce da sola',
  daConfermare: 'Chiede una conferma',
  daControllare: 'La guarda una persona',
  bloccata: 'Fermata subito dal filtro',
};

/** Cosa vede chi lancia la missione, e quando si prendono i soldi. */
function cosaSuccede(e, premio) {
  if (e.precedente === 'rifiutata') {
    return {
      vede: `“Abbiamo già controllato questa missione e non può uscire${e.motivoPrecedente ? `: ${e.motivoPrecedente}` : ''}.”`,
      soldi: 'Non paga niente.',
    };
  }

  if (e.strada === 'bloccata' && e.precedente !== 'approvata') {
    return {
      vede: `“${e.filtro.rossa.messaggio}”`,
      soldi: 'Non paga niente: la missione non nasce, e può riscriverla.',
    };
  }

  if (e.strada === 'inGara' || e.precedente === 'approvata') {
    return {
      vede: premio > 0 ? '“Missione approvata: ora paghi il premio e parte.”' : 'La missione è subito in gara.',
      soldi: premio > 0 ? `Si apre il pagamento di ${euro(premio)} di premio, e i soldi si prendono lì. Il tempo parte quando paga.` : 'È gratis: nessun pagamento.',
    };
  }

  return {
    vede: '“È in controllo. Una persona del team la guarda. Non paghi niente finché non è approvata. Ti avvisiamo appena c’è una risposta.”',
    soldi:
      premio > 0
        ? `Niente adesso. Se la approvi gli arriva l'avviso, paga ${euro(premio)} di premio, e allora parte. Se la rifiuti non paga mai.`
        : 'È gratis: se la approvi parte subito.',
  };
}

function esitoProva(e, dati) {
  const premio = dati.prizeCents;
  const { vede, soldi } = cosaSuccede(e, premio);

  return html`<article class="carta" style="max-width:620px">
    <div class="carta__cima">
      <div>
        <div class="occhiello occhiello--rosso">Cosa succederebbe</div>
        <h2 style="margin:6px 0 0">${e.precedente ? `Già ${e.precedente}` : e.menu ? 'Viene dai consigli' : STRADE[e.strada] || e.strada}</h2>
      </div>
      ${bollinoVoto(e.voto, true)}
    </div>
    ${ilPerche({ filtro: e.filtro, giudizio: e.giudizio, voto: e.voto })}
    ${e.precedente === 'approvata'
      ? html`<p class="perche">Una persona ha già approvato questo stesso testo: non passa di nuovo dal controllo.</p>`
      : e.menu
      ? html`<p class="perche">È uno dei consigli di CRASY, scritto così com'è: non passa dal modello e non costa niente. Basta cambiare una parola e torna al controllo.</p>`
      : ''}
    <p class="perche"><b>Chi la lancia legge:</b> ${vede}</p>
    <p class="perche"><b>I soldi:</b> ${soldi}</p>
    <p class="sotto-riga" style="margin:12px 0 0">Non è nato niente: nessuna gara, nessun avviso, nessun pagamento.${
      e.costo ? ` Questa prova è costata ${dollari(e.costo)}.` : ''
    }</p>

    <form id="insegna" style="display:grid;gap:10px;margin-top:16px;padding-top:16px;border-top:1px solid var(--riga)">
      <div class="occhiello">Il voto è sbagliato? Insegnaglielo</div>
      <div style="max-width:190px">
        <label for="votoGiusto">Il voto giusto era</label>
        <input id="votoGiusto" type="number" min="0" max="100" value="${e.voto === null ? '' : e.voto}" required>
      </div>
      <div>
        <label for="motivoGiusto">Perché, lo legge il modello</label>
        <input id="motivoGiusto" type="text" maxlength="200" placeholder="Per esempio: serve il consenso di un'altra persona" required>
      </div>
      <div><button class="tasto tasto--nero" type="submit">Insegna</button></div>
    </form>
  </article>`;
}

function elencoEsempi(esempi, massimo) {
  return esempi.length
    ? html`<div class="righe">
        ${esempi.map(
          (x) => html`<div style="display:flex;justify-content:space-between;gap:14px;align-items:center">
            <div style="min-width:0">
              <div><b>${x.voto}</b> · <span class="titolo-riga">${x.title}</span></div>
              ${x.brief ? html`<div class="sotto-riga">${x.brief}</div>` : ''}
              <div class="sotto-riga">${x.motivo}${x.il ? ` · ${fa(x.il)}` : ''}</div>
            </div>
            <button class="tasto tasto--piccolo" data-fai="dimentica" data-id="${x.id}">Dimentica</button>
          </div>`
        )}
      </div>
      <p class="sotto-riga" style="margin-top:10px">${numero(esempi.length)} su ${numero(massimo)}. Ogni esempio allunga le istruzioni e costa qualche frazione di centesimo in più su ogni giudizio.</p>`
    : html`<p class="vuoto">Ancora niente. Il modello usa solo le istruzioni di partenza.</p>`;
}

const ESITI = {
  ok: ['ok', ''],
  pericoloso: ['USCIREBBE DA SOLA', 'rosso'],
  prudente: ['troppo prudente', 'tenue'],
  guasto: ['non ha risposto', 'tenue'],
};

function esitoBatteria(b) {
  const pericolosi = b.righe.filter((r) => r.esito === 'pericoloso');

  return html`
    <div class="numeri" style="margin-top:14px">
      <div class="numero ${pericolosi.length ? 'numero--allarme' : ''}">
        <div class="occhiello ${pericolosi.length ? 'occhiello--rosso' : ''}">Sbagli pericolosi</div>
        <div class="numero__cifra">${numero(pericolosi.length)}</div>
        <div class="numero__nota">${pericolosi.length ? 'Non pubblicare modifiche finché non sono zero.' : 'Nessuna missione pericolosa uscirebbe da sola.'}</div>
      </div>
      <div class="numero"><div class="occhiello">Troppo prudente</div><div class="numero__cifra">${numero(b.righe.filter((r) => r.esito === 'prudente').length)}</div><div class="numero__nota">innocue che chiederebbero una persona</div></div>
      <div class="numero"><div class="occhiello">Giuste</div><div class="numero__cifra">${numero(b.righe.filter((r) => r.esito === 'ok').length)}</div><div class="numero__nota">su ${numero(b.righe.length)}</div></div>
      <div class="numero"><div class="occhiello">Costo della prova</div><div class="numero__cifra">${dollari(b.costo)}</div><div class="numero__nota">mille missioni: ${dollari(b.perMille)}</div></div>
    </div>
    <div class="tabella-giro" style="margin-top:14px"><table>
      <thead><tr><th>Missione</th><th class="num">Voto</th><th>Dovrebbe</th><th>Risultato</th></tr></thead>
      <tbody>
        ${[...b.righe]
          .sort((x, y) => Number(y.esito === 'pericoloso') - Number(x.esito === 'pericoloso') || Number(y.esito === 'prudente') - Number(x.esito === 'prudente'))
          .map(
            (r) => html`<tr>
              <td>
                <div class="titolo-riga">${r.title}</div>
                <div class="sotto-riga">${r.brief}</div>
                ${r.motivo ? html`<div class="sotto-riga">${r.motivo}</div>` : ''}
              </td>
              <td class="num ${r.esito === 'pericoloso' ? 'rosso' : ''}"><b>${r.voto === null ? '—' : r.voto}</b></td>
              <td class="nowrap">${r.atteso === 'sola' ? 'uscire da sola' : 'passare da te'}${r.insegnata ? html`<div class="sotto-riga">insegnata da te</div>` : ''}</td>
              <td class="nowrap ${ESITI[r.esito][1]}"><b>${ESITI[r.esito][0]}</b></td>
            </tr>`
          )}
      </tbody>
    </table></div>
  `;
}

export async function mostraProve(contenuto, _parametri, ancoraQui) {
  metti(
    contenuto,
    html`
      ${testata(
        'Banco di prova',
        "Qui lanci una missione per finta. Passa dagli stessi controlli di una vera e vedi cosa succederebbe, ma non nasce niente: nessuna gara, nessun avviso, nessun pagamento."
      )}

      <form class="prova" id="modulo-prova">
        <div><label for="provaTitolo">Titolo</label><input id="provaTitolo" type="text" maxlength="60" required></div>
        <div><label for="provaConsegna">Consegna</label><textarea id="provaConsegna" maxlength="280"></textarea></div>
        <div><label for="provaRiga">Messaggio di una sfida, se vuoi</label><input id="provaRiga" type="text" maxlength="140"></div>
        <div style="max-width:190px"><label for="provaPremio">Premio in euro</label><input id="provaPremio" type="number" min="0" max="100" step="0.5" value="5"></div>
        <div><button class="tasto tasto--rosso" type="submit">Lancia la prova</button></div>
      </form>
      <div id="prova-esito" class="prova__esito"></div>

      <div class="sezione">
        <h2>Cosa gli hai insegnato</h2>
        <p class="tenue" style="margin-top:0">
          Il modello non si addestra davvero: gli insegni con gli esempi. Ogni correzione entra nelle sue istruzioni, per le prove e per le missioni vere, entro un minuto.
        </p>
        <div id="esempi"><p class="carico">Carico…</p></div>
      </div>

      <div class="sezione">
        <h2>La batteria</h2>
        <p class="tenue" style="margin-top:0">
          Tutte le missioni di prova insieme, comprese quelle che gli hai insegnato: pericoli scritti bene, gergo, tentativi di imbrogliarlo. Rifalla dopo ogni correzione. Costa meno di un centesimo di dollaro e ci mette circa mezzo minuto.
        </p>
        <button class="tasto tasto--nero" id="lancia-batteria">Lancia la batteria</button>
        <div id="batteria"></div>
      </div>
    `
  );

  const $ = (id) => contenuto.querySelector(`#${id}`);

  async function caricaEsempi() {
    const { esempi, massimo } = await pannello('esempi');

    if (ancoraQui()) {
      metti($('esempi'), elencoEsempi(esempi, massimo));
    }
  }

  tasti($('esempi'), {
    dimentica: async ({ id }) => {
      const risposta = await chiedi({
        titolo: 'Dimenticare questo esempio?',
        testo: 'Il modello non lo userà più, e i voti già dati si rifaranno.',
        tasto: 'Dimentica',
      });

      if (risposta) {
        await pannello('dimentica', { id });
        dillo('Dimenticato.');
        await caricaEsempi();
      }
    },
  });

  let ultima = null;

  async function lancia(evento) {
    evento.preventDefault();

    const uscita = $('prova-esito');
    const tasto = $('modulo-prova').querySelector('button');
    const dati = {
      title: $('provaTitolo').value,
      brief: $('provaConsegna').value,
      duelMessage: $('provaRiga').value,
      prizeCents: Math.round(Number($('provaPremio').value || 0) * 100),
    };

    tasto.disabled = true;
    metti(uscita, html`<p class="carico">Sto giudicando…</p>`);

    try {
      const e = await pannello('provaLancio', dati);

      ultima = dati;
      metti(uscita, esitoProva(e, dati));
      uscita.querySelector('#insegna').addEventListener('submit', insegna);
    } catch (errore) {
      console.error(errore);
      metti(uscita, html`<p class="errore">${frase(errore)}</p>`);
    } finally {
      tasto.disabled = false;
    }
  }

  async function insegna(evento) {
    evento.preventDefault();

    const tasto = evento.currentTarget.querySelector('button');

    tasto.disabled = true;

    try {
      await pannello('insegna', {
        title: ultima.title,
        brief: ultima.brief,
        duelMessage: ultima.duelMessage,
        voto: Number($('votoGiusto').value),
        motivo: $('motivoGiusto').value,
      });
      dillo('Insegnato: rifai la batteria per controllare.');
      await caricaEsempi();
    } catch (errore) {
      dilloErrore(errore);
    } finally {
      tasto.disabled = false;
    }
  }

  $('modulo-prova').addEventListener('submit', lancia);

  $('lancia-batteria').addEventListener('click', async (evento) => {
    const tasto = evento.currentTarget;
    const uscita = $('batteria');

    tasto.disabled = true;
    metti(uscita, html`<p class="carico">La sto facendo: ci vuole circa mezzo minuto…</p>`);

    try {
      const b = await pannello('batteria');

      if (ancoraQui()) {
        metti(uscita, esitoBatteria(b));
      }
    } catch (errore) {
      console.error(errore);
      metti(uscita, html`<p class="errore">${frase(errore)}</p>`);
    } finally {
      tasto.disabled = false;
    }
  });

  await caricaEsempi();
}
