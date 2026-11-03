/**
 * **Prova il giudizio dell'intelligenza artificiale con la chiave vera.**
 *
 *     OPENAI_API_KEY=la-tua-chiave node functions/tool/prova_giudice.js
 *
 * Le prove di `npm test` il modello non lo chiamano mai: controllano cosa succede a
 * ogni risposta, non quanto sono giuste le risposte. Questa si', ed e' da rifare ogni
 * volta che si cambiano le istruzioni o il modello in `giudice.js`.
 *
 * **Costa soldi veri**, pochi centesimi in tutto: il conto esatto lo scrive in fondo.
 * Per confrontare un altro modello o un altro sforzo: `PROVA_MODELLO=gpt-6.1-terra`,
 * `PROVA_SFORZO=low`.
 *
 * Per ogni missione dice il voto, che strada prenderebbe e se e' quella che ci si
 * aspetta. La colonna che conta e' **"SBAGLIO PERICOLOSO"**: una missione rischiosa
 * che sarebbe uscita da sola. Una sola riga cosi' vuol dire che non si va in
 * produzione finche' non si sono sistemate le istruzioni.
 */

const { controlla } = require('../parole');
const { costoInDollari, giudica, stradaDi, MODELLO } = require('../giudice');
const { PROVE } = require('../prove_missioni');

const SOGLIE = { sogliaAuto: 90, sogliaConferma: 80 };

async function main() {
  const chiave = process.env.OPENAI_API_KEY;
  const modello = process.env.PROVA_MODELLO || MODELLO;
  const sforzo = process.env.PROVA_SFORZO;

  if (!chiave) {
    console.error('Manca la chiave: OPENAI_API_KEY=la-tua-chiave node functions/tool/prova_giudice.js');
    process.exit(1);
  }

  console.log(`Modello: ${modello}${sforzo ? `, sforzo ${sforzo}` : ''}\n`);

  let pericolosi = 0;
  let inutili = 0;
  let guasti = 0;
  let entrata = 0;
  let inMemoria = 0;
  let uscita = 0;
  let tempo = 0;
  let giudizi = 0;

  for (const [atteso, titolo, consegna] of PROVE) {
    const filtro = controlla([titolo, consegna]);

    if (filtro.rossa) {
      const bene = atteso === 'persona';

      console.log(`${bene ? 'ok ' : '!! '} filtro   ${titolo} -> ${filtro.rossa.termine}`);

      if (!bene) {
        inutili += 1;
      }

      continue;
    }

    const giudizio = await giudica({ titolo, consegna }, { chiave, modello, sforzo });
    const { voto, strada } = stradaDi({ giudizio, gialle: filtro.gialle, soglie: SOGLIE });

    if (giudizio.esito !== 'fatto') {
      guasti += 1;
      console.log(`??  guasto   ${titolo} -> ${giudizio.perche || giudizio.esito}`);
      continue;
    }

    entrata += giudizio.gettoni.entrata;
    inMemoria += giudizio.gettoni.inMemoria;
    uscita += giudizio.gettoni.uscita;
    tempo += giudizio.ms;
    giudizi += 1;

    const usciva = strada === 'inGara';
    const pericoloso = atteso === 'persona' && usciva;
    const inutile = atteso === 'sola' && !usciva;

    pericolosi += pericoloso ? 1 : 0;
    inutili += inutile ? 1 : 0;

    const segno = pericoloso ? 'XX ' : inutile ? '!! ' : 'ok ';

    console.log(
      `${segno} ${String(giudizio.punteggio).padStart(3)} -> ${String(voto).padStart(3)}  ` +
        `${strada.padEnd(13)} ${titolo}${pericoloso ? '   <-- SBAGLIO PERICOLOSO' : ''}\n` +
        `        ${giudizio.motivo}`
    );
  }

  // Con un altro modello il conto non torna: i prezzi sono quelli di `PREZZI`.
  const dollari = costoInDollari({ entrata, inMemoria, uscita });

  console.log(
    `\n${PROVE.length} prove. Sbagli pericolosi: ${pericolosi}. ` +
      `Innocue che chiederebbero una persona: ${inutili}. Guasti: ${guasti}.`
  );
  const giudicate = Math.max(giudizi, 1);

  console.log(
    `Gettoni a missione: ${Math.round(entrata / giudicate)} in entrata, ${Math.round(uscita / giudicate)} in uscita. ` +
      `Mille missioni costerebbero circa ${((dollari / giudicate) * 1000).toFixed(2)} $.`
  );
  console.log(
    `Costo di questa prova: circa ${dollari.toFixed(4)} $. ` +
      `Tempo medio di una risposta: ${Math.round(tempo / giudicate)} ms.`
  );

  process.exit(pericolosi > 0 ? 1 : 0);
}

main();
