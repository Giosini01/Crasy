/*
 * **Il fondo delle missioni automatiche.** Il numero grande e' quante missioni restano,
 * non quanti euro: gli euro costringono a fare una divisione a mente. Sotto, un
 * calendario e non un elenco: un elenco dice quando esce ogni missione, il calendario
 * dice com'e' fatta la settimana, che e' la domanda vera.
 */
import { chiama, chiedi, dillo, euro, html, metti, numero, quando, tasti, testata } from './base.js';

function calendario(prossime) {
  const giorni = [];
  const oggi = new Date().toLocaleDateString('sv-SE');

  for (const p of prossime || []) {
    const data = new Date(p.quando);
    const chiave = data.toLocaleDateString('sv-SE');
    let giorno = giorni.find((g) => g.chiave === chiave);

    if (!giorno) {
      giorno = {
        chiave,
        oggi: chiave === oggi,
        nome: data.toLocaleDateString('it-IT', { weekday: 'short', day: '2-digit', month: '2-digit' }),
        voci: [],
      };
      giorni.push(giorno);
    }

    giorno.voci.push({ p, ora: data.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' }) });
  }

  return giorni.length
    ? html`<div class="calendario">
        ${giorni.map(
          (g) => html`<div class="giorno ${g.oggi ? 'giorno--oggi' : ''}">
            <div class="giorno__testa">${g.nome}</div>
            ${g.voci.map(
              ({ p, ora }) => html`<div class="giorno__voce">
                <div class="sotto-riga"><b>${ora}</b> · ${p.mediaKind === 'video' ? 'video' : 'foto'} · ${p.source === 'archive' ? 'archivio' : 'adesso'}</div>
                <div class="titolo-riga">${p.titolo}</div>
                <div class="sotto-riga">${p.consegna}</div>
              </div>`
            )}
          </div>`
        )}
      </div>`
    : html`<p class="vuoto">Niente in coda: il fondo è fermo.</p>`;
}

function fondo(f) {
  const restano = f.premioCents ? Math.floor(f.fondoCents / f.premioCents) : 0;
  const messi = f.fondoCents + f.spesiCents;
  const andato = messi ? Math.round((f.spesiCents / messi) * 100) : 0;
  const fatteOggi = f.giorno === new Date().toLocaleDateString('sv-SE') ? f.fatte : 0;

  return html`<article class="carta" style="margin-bottom:18px">
    <div class="carta__cima">
      <div>
        <div class="occhiello">@${f.username}</div>
        <div class="premio" style="margin-top:8px">${numero(restano)}</div>
        <div class="tenue">missioni rimaste · ${euro(f.fondoCents)}</div>
      </div>
      <span class="pastiglia ${f.acceso ? 'pastiglia--piena' : 'pastiglia--rossa'}">
        ${f.acceso ? 'acceso' : `fermo${f.spentoPerche ? ` · ${f.spentoPerche}` : ''}`}
      </span>
    </div>
    <div class="barra"><div style="width:${andato}%"></div></div>
    <div class="fatti">
      <span>${euro(f.premioCents)} a missione</span>
      <span>${numero(f.maxPartecipanti)} posti</span>
      <span>${numero(f.oreDiGara)} ore</span>
      <span>${numero(f.alGiorno)} al giorno (oggi ${numero(fatteOggi)})</span>
      ${f.fino ? html`<span>fino al ${f.fino}</span>` : ''}
      <span>spesi ${euro(f.spesiCents)}</span>
    </div>
    <div class="comandi">
      <button class="tasto tasto--nero" data-fai="lancia" data-uid="${f.uid}">Lancia adesso</button>
      <button class="tasto" data-fai="salta" data-uid="${f.uid}">Salta la prossima</button>
      <button class="tasto ${f.acceso ? 'tasto--bordo-rosso' : ''}" data-fai="ferma" data-uid="${f.uid}" data-acceso="${f.acceso ? '1' : ''}">
        ${f.acceso ? 'Ferma tutto' : 'Riaccendi'}
      </button>
    </div>

    <div class="occhiello" style="margin:22px 0 10px">In arrivo</div>
    ${calendario(f.prossime)}

    <div class="occhiello" style="margin:22px 0 4px">Già uscite</div>
    ${f.ultime.length
      ? html`<div class="righe">
          ${f.ultime.map(
            (u) => html`<div style="display:flex;justify-content:space-between;gap:14px">
              <div>
                <a class="titolo-riga" href="#/missione/${encodeURIComponent(u.gara)}">${u.titolo}</a>
                <div class="sotto-riga">${quando(u.quando)}</div>
              </div>
              <b class="rosso nowrap">${euro(u.premioCents)}</b>
            </div>`
          )}
        </div>`
      : html`<p class="vuoto">Nessuna ancora.</p>`}
  </article>`;
}

export async function mostraAutomatiche(contenuto, parametri, ancoraQui) {
  const { fondi } = await chiama('adminFondo');

  if (!ancoraQui()) {
    return;
  }

  metti(
    contenuto,
    html`
      ${testata('Automatiche', 'Le missioni che partono da sole finché il fondo prepagato dura. Sono scritte da noi: non passano dal controllo.')}
      ${fondi.length
        ? fondi.map(fondo)
        : html`<p class="vuoto">Nessun fondo attivo. Si carica con <code>tool/carica_il_fondo.py</code>, dopo che i soldi sono arrivati davvero su Stripe.</p>`}
    `
  );

  const ridisegna = () => mostraAutomatiche(contenuto, parametri, ancoraQui);

  tasti(contenuto, {
    lancia: async ({ uid }) => {
      const esito = await chiama('adminLanciaDalFondo', { uid });

      // Si dice sempre com'e' andata, anche quando non e' partita.
      if (esito && esito.ok) {
        dillo('Lanciata.');
      } else {
        dillo(`Non lanciata: ${(esito && esito.reason) || 'non so perché'}`, { errore: true });
      }

      await ridisegna();
    },
    salta: async ({ uid }) => {
      await chiama('adminSaltaLaProssima', { uid });
      dillo('Rimandata in fondo al giro.');
      await ridisegna();
    },
    ferma: async ({ uid, acceso }) => {
      const eraAcceso = acceso === '1';

      if (eraAcceso) {
        const risposta = await chiedi({
          titolo: 'Fermare il fondo?',
          testo: 'Le gare già aperte vanno avanti: hanno un premio pagato e delle persone dentro. Non ne partono altre.',
          tasto: 'Ferma',
          pericolo: true,
        });

        if (!risposta) {
          return;
        }
      }

      await chiama('adminFermaIlFondo', { uid, acceso: !eraAcceso });
      await ridisegna();
    },
  });
}
