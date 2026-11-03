/*
 * **Chi ha fatto cosa dal pannello.** Nel pannello entra piu' di una persona, e il
 * giorno in cui qualcuno chiede perche' una missione e' uscita si deve poterlo sapere.
 */
import { fa, html, metti, pannello, quando, testata } from './base.js';

const AZIONI = {
  decidiProposta: (d) =>
    `${d.decisione === 'approva' ? 'Ha approvato' : 'Ha rifiutato'} una missione${d.motivo ? `: ${d.motivo}` : ''}`,
  togliGara: (d) => `Ha tolto la missione “${d.titolo}”: ${d.motivo}`,
  chiudiGara: (d) => `Ha chiuso prima del tempo “${d.titolo}”`,
  togliFoto: (d) => `Ha tolto una foto dalla gara (${d.motivo})`,
  sospendi: (d) =>
    `Ha sospeso una persona ${d.giorni ? `per ${d.giorni} giorni` : 'per sempre'}: ${d.motivo}`,
  insegna: (d) => `Ha insegnato al modello: “${d.title}” vale ${d.voto}, ${d.motivo}`,
  dimentica: () => 'Ha fatto dimenticare un esempio al modello',
  spesaFissa: (d) => `Ha aggiunto la spesa “${d.nome}”`,
  togliSpesaFissa: (d) => `Ha tolto la spesa “${d.nome}”`,
  impostazioni: (d) =>
    `Ha cambiato le regole: uscita da ${d.sogliaAuto}, conferma da ${d.sogliaConferma}${d.soloAMano ? ', solo a mano' : ''}`,
};

export async function mostraRegistro(contenuto, _parametri, ancoraQui) {
  const { righe } = await pannello('registro');

  if (!ancoraQui()) {
    return;
  }

  metti(
    contenuto,
    html`
      ${testata('Registro', 'Le ultime azioni fatte dal pannello. Si legge e basta: nessuno lo può correggere.')}
      ${righe.length
        ? html`<div class="righe">
            ${righe.map((r) => {
              const scritta = AZIONI[r.azione] ? AZIONI[r.azione](r.dettagli) : r.azione;

              return html`<div>
                <div>${scritta}</div>
                <div class="sotto-riga">
                  @${r.chi} · ${quando(r.il)} · ${fa(r.il)}
                  ${r.dettagli && r.dettagli.uid ? html` · <a href="#/persona/${encodeURIComponent(r.dettagli.uid)}">la persona</a>` : ''}
                  ${r.dettagli && r.dettagli.id && r.azione === 'chiudiGara' ? html` · <a href="#/missione/${encodeURIComponent(r.dettagli.id)}">la missione</a>` : ''}
                </div>
              </div>`;
            })}
          </div>`
        : html`<p class="vuoto">Ancora niente.</p>`}
    `
  );
}
