/*
 * **La prima schermata: cosa c'e' da fare, e com'e' messa CRASY.** Prima il lavoro,
 * perche' e' quello che qualcuno sta aspettando; poi i numeri.
 */
import { chiama, dollari, euro, html, metti, numero, pannello, quanti, testata } from './base.js';

function riga(valore, uno, tanti, dove) {
  return valore
    ? html`<a class="dafare__riga" href="${dove}">
        <b>${numero(valore)}</b>
        <span>${valore === 1 ? uno : tanti}</span>
        <span class="tenue" style="flex:none">→</span>
      </a>`
    : '';
}

function riquadro(etichetta, cifra, nota, { allarme = false, dove = '' } = {}) {
  const dentro = html`
    <div class="occhiello">${etichetta}</div>
    <div class="numero__cifra">${cifra}</div>
    ${nota ? html`<div class="numero__nota">${nota}</div>` : ''}
  `;

  return dove
    ? html`<a class="numero ${allarme ? 'numero--allarme' : ''}" href="${dove}">${dentro}</a>`
    : html`<div class="numero ${allarme ? 'numero--allarme' : ''}">${dentro}</div>`;
}

export async function mostraPanoramica(contenuto, _parametri, ancoraQui) {
  const n = await pannello('panoramica');

  if (!ancoraQui()) {
    return;
  }

  const { persone, missioni, lavoro, soldi, foto, ai } = n;

  const righe = [
    riga(missioni.daControllare, 'missione da controllare', 'missioni da controllare', '#/missioni/daControllare'),
    riga(missioni.daConfermare, 'missione da confermare', 'missioni da confermare', '#/missioni/daConfermare'),
    riga(lavoro.segnalazioni, 'segnalazione nuova', 'segnalazioni nuove', '#/segnalazioni'),
    riga(lavoro.revisioni, 'revisione chiesta', 'revisioni chieste', '#/foto/scartate'),
    riga(lavoro.prelievi, 'prelievo da pagare', 'prelievi da pagare', '#/soldi'),
  ].filter(Boolean);

  const dovuti = (soldi.inPalioCents || 0) + (soldi.custodiaCents || 0);
  const scoperto =
    soldi.stripe && soldi.inPalioCents !== null && soldi.custodiaCents !== null
      ? dovuti - (soldi.stripe.disponibile + soldi.stripe.inArrivo)
      : null;

  metti(
    contenuto,
    html`
      ${testata('CRASY senza veli')}

      ${missioni.soloAMano
        ? html`<div class="avviso">
            <strong>Solo a mano.</strong> Nessuna missione esce da sola: passano tutte da te.
            <a href="#/regole">Cambia</a>
          </div>`
        : ''}

      <div class="occhiello occhiello--rosso" style="margin-bottom:10px">Da fare</div>
      ${righe.length
        ? html`<div class="dafare">${righe}</div>`
        : html`<div class="tuttofatto">Niente da fare. Nessuno sta aspettando una risposta.</div>`}

      <div class="sezione">
        <h2>Le persone</h2>
        <div class="numeri">
          ${riquadro('Adesso', numero(persone.adesso), 'negli ultimi 15 minuti')}
          ${riquadro('Oggi', numero(persone.oggi), 'nelle ultime 24 ore')}
          ${riquadro('In 7 giorni', numero(persone.settimana), quanti(persone.nuovi, 'nuova', 'nuove'))}
          ${riquadro('Iscritte', numero(persone.iscritti), '', { dove: '#/persone' })}
        </div>
      </div>

      <div class="sezione">
        <h2>Le missioni</h2>
        <div class="numeri">
          ${riquadro('Pubbliche in gara', numero(missioni.pubbliche), '', { dove: '#/missioni/inGara' })}
          ${riquadro('Fra amici', numero(missioni.amici), '', { dove: '#/missioni/inGara' })}
          ${riquadro('Sfide 1 contro 1', numero(missioni.sfide), '', { dove: '#/missioni/inGara' })}
          ${riquadro('Partecipanti in gara', numero(missioni.partecipanti))}
          ${riquadro('Foto nelle 24 ore', numero(foto.oggi), '', { dove: '#/foto' })}
          ${riquadro('Fermate dal filtro', numero(missioni.bloccate), 'in 7 giorni', { dove: '#/missioni/bloccata' })}
        </div>
      </div>

      <div class="sezione">
        <h2>I soldi</h2>
        ${scoperto !== null && scoperto > 0
          ? html`<div class="avviso">
              <strong>Mancano ${euro(scoperto)} su Stripe.</strong>
              CRASY deve ${euro(dovuti)} (${euro(soldi.inPalioCents)} in palio e
              ${euro(soldi.custodiaCents)} in custodia) e sul saldo ce ne sono
              ${euro(soldi.stripe.disponibile + soldi.stripe.inArrivo)}.
            </div>`
          : ''}
        <div class="numeri">
          <a class="numero" href="#/soldi">
            <div class="occhiello occhiello--rosso">Guadagno, 30 giorni</div>
            <div class="numero__cifra rosso" id="guadagno30">…</div>
            <div class="numero__nota" id="guadagno30nota">Lo chiedo a Stripe</div>
          </a>
          <a class="numero" href="#/spese">
            <div class="occhiello">Stripe costa, 30 giorni</div>
            <div class="numero__cifra" id="stripe30">…</div>
            <div class="numero__nota" id="stripe30nota">Lo chiedo a Stripe</div>
          </a>
          ${riquadro(
            'AI, 30 giorni',
            ai ? dollari(ai.mese.dollari) : '—',
            ai ? quanti(ai.mese.giudizi, 'giudizio pagato', 'giudizi pagati') : 'non letto',
            { dove: '#/soldi' }
          )}
          ${riquadro(
            'Saldo Stripe',
            soldi.stripe ? euro(soldi.stripe.disponibile) : '—',
            soldi.stripe ? `più ${euro(soldi.stripe.inArrivo)} in arrivo` : 'Stripe non ha risposto',
            { dove: '#/soldi' }
          )}
          ${riquadro('In palio adesso', euro(soldi.inPalioCents), 'premi nelle gare aperte')}
          ${riquadro('Sui conti delle persone', euro(soldi.suiContiCents), 'la nostra copia, in Persone il saldo vero', { dove: '#/persone' })}
          ${riquadro('In custodia', euro(soldi.custodiaCents), 'ancora su CRASY, da spostare')}
          ${riquadro('Vinti da sempre', euro(soldi.vintiCents))}
          ${riquadro('Da pagare a mano', euro(soldi.prelieviCents), quanti(lavoro.prelievi, 'prelievo', 'prelievi'), {
            allarme: Boolean(lavoro.prelievi),
            dove: '#/soldi',
          })}
        </div>
      </div>
    `
  );

  // **Non si aspetta.** Stripe puo' metterci qualche secondo: il resto si legge subito, e
  // questi due numeri arrivano quando arrivano.
  Promise.all([chiama('adminGuadagni', { giorni: 30 }), pannello('contiStripe', { giorni: 30 })])
    .then(([guadagni, conti]) => {
      if (!ancoraQui()) {
        return;
      }

      const $ = (id) => contenuto.querySelector(`#${id}`);

      $('guadagno30').textContent = euro(guadagni.totali.guadagno - conti.altreSpese);
      $('guadagno30nota').textContent = guadagni.totali.guadagnoInAttesa
        ? `di cui ${euro(guadagni.totali.guadagnoInAttesa)} ancora in gara`
        : `su ${euro(guadagni.totali.incassato)} incassati`;
      $('stripe30').textContent = euro(guadagni.totali.speseStripe + conti.altreSpese);
      $('stripe30nota').textContent = 'commissioni e spese';
    })
    .catch(() => {
      if (!ancoraQui()) {
        return;
      }

      for (const [cifra, nota] of [['guadagno30', 'guadagno30nota'], ['stripe30', 'stripe30nota']]) {
        contenuto.querySelector(`#${cifra}`).textContent = '—';
        contenuto.querySelector(`#${nota}`).textContent = 'Stripe non ha risposto';
      }
    });
}
