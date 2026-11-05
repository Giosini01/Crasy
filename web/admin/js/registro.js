/*
 * **Chi ha fatto cosa dal pannello.** Nel pannello entra piu' di una persona, e il
 * giorno in cui qualcuno chiede perche' una missione e' uscita si deve poterlo sapere.
 */
import { fa, html, metti, pannello, quando, testata } from './base.js';

const DECISIONI = {
  removed: 'Ha tolto il contenuto segnalato',
  fake: 'Ha respinto una segnalazione',
  reviewing: 'Ha preso in mano una segnalazione',
};

const MOTIVI = {
  danger: 'mette in pericolo qualcuno',
  sexual: 'contenuto sessualmente esplicito',
  violence: 'violenza',
  hate: 'molestie o bullismo',
  illegal: 'contenuto illegale',
  spam: 'spam o frode',
  minor: 'c’è un minore',
  other: 'altro',
};

const COSE = {
  entry: 'foto',
  comment: 'commento',
  challenge: 'missione',
  user: 'persona',
};

const AZIONI = {
  decidiSegnalazione: (d) =>
    `${DECISIONI[d.decisione] || d.decisione} (${COSE[d.kind] || d.kind}, ${MOTIVI[d.reason] || d.reason})` +
    `${d.insieme > 1 ? `, insieme a altre ${d.insieme - 1}` : ''}` +
    `${d.sospeso ? ` e ha sospeso l'autore ${d.sospeso.giorni ? `per ${d.sospeso.giorni} giorni` : 'per sempre'}` : ''}`,
  riattiva: () => 'Ha riattivato un account sospeso',
  eliminaAccount: (d) => `Ha eliminato l'account di @${d.username}: ${d.motivo}`,
  rimettiFoto: () => 'Ha rimesso in gara una foto',
  respingiRevisione: () => 'Ha respinto una richiesta di revisione',
  verificato: (d) => (d.verificato ? 'Ha fatto sostenitore una persona' : 'Ha tolto il segno di sostenitore'),
  segnaBlocco: (d) => `Ha guardato il blocco di @${d.bloccaNome} su @${d.bloccatoNome}`,
  togliCommento: (d) => `Ha tolto un commento: “${d.testo}”`,
  togliTesto: (d) => `Ha tolto un testo (${d.cosa}): “${d.testo}”`,
  togliFotoProfilo: () => 'Ha tolto una foto profilo',
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
