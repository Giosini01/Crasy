'use strict';

/**
 * **Il salvadanaio: missioni che partono da sole finche' i soldi durano.**
 *
 * ## A cosa serve, e per quanto
 *
 * All'inizio su CRASY non lancia nessuno. Non per cattiveria: partecipare e'
 * **reagire** — l'idea l'ha messa un altro — mentre lanciare e' **inventare**,
 * e per di piu' si paga. Un'app che il primo giorno e' vuota non da' a nessuno
 * il motivo per riempirla.
 *
 * Qui due persone mettono dei soldi da parte e il server lancia per loro,
 * qualche missione al giorno, finche' quei soldi non finiscono. Poi smette da
 * sola.
 *
 * **E' una spinta per far partire il motore, non una funzione dell'app.** Se
 * resta accesa per sempre, nessuno ha piu' motivo di lanciare: c'e' gia' tutto
 * da fare, gratis. Per questo il salvadanaio ha un fondo e non si ricarica da
 * solo: quando finisce, finisce, ed e' una decisione presa adesso invece che
 * rimandata.
 *
 * ## Come fa a essere vera
 *
 * Non c'e' niente di finto in queste gare: hanno un autore vero, un premio
 * vero pagato con soldi veri, e chi vince incassa come in tutte le altre.
 * L'unica cosa che cambia e' **chi preme il tasto**.
 *
 * Il premio si paga con `pagaDalPortafoglio`, la stessa identica funzione del
 * tasto nell'app. Non una copia: la stessa. Cosi' il saldo cala, il movimento
 * si scrive, la riga finisce nel registro e la gara risulta pagata nello
 * stesso modo di tutte le altre — e il giorno in cui qualcuno dovra' far
 * tornare i conti non trovera' una categoria a parte da capire.
 *
 * Il salvadanaio quindi **e' il portafoglio**: non c'e' un secondo borsellino
 * da tenere d'accordo con il primo. Si caricano dei soldi veri sul saldo di
 * chi lancia (vedi `tool/carica_il_salvadanaio.py`) e quel saldo si consuma.
 *
 * ## Dove si accende
 *
 * In `salvadanai/{uid}`, un documento per persona:
 *
 * - `acceso` — false ferma tutto all'istante, senza pubblicare niente;
 * - `alGiorno` — quante missioni al giorno, al massimo;
 * - `premioCents` — quanto mettere in palio ogni volta;
 * - `oreDiGara` — quanto dura ognuna;
 * - `fino` — la data dopo la quale si ferma comunque.
 *
 * Nessuno di questi lo puo' scrivere un telefono: le regole non lasciano
 * leggere ne' scrivere quella collezione. Si toccano da qui o dagli strumenti.
 */

const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

const pagamenti = require('./payments');

const db = admin.firestore();

/**
 * **Le missioni che il server lancia, in ordine.**
 *
 * Non sono le stesse che l'app propone a chi scrive da se', e non e' una
 * svista: quelle sono un menu da cui scegliere, queste sono una sequenza che
 * si srotola nel tempo. Una fila da sfogliare puo' permettersi dodici cose
 * simili; una sequenza che esce una al giorno deve **alternare** — una da
 * casa, una da fuori, una col video — o dopo tre giorni sembra sempre la
 * stessa.
 *
 * Si gira in tondo: finite, si ricomincia. Con una ventina di righe e due
 * lanci al giorno, la stessa missione tocca di nuovo dopo dieci giorni, e a
 * quel punto chi l'aveva saltata la ritrova — che e' un bene, non un difetto.
 */
const MISSIONI = [
  {
    titolo: "COM'È MESSA LA TUA SCRIVANIA",
    consegna:
      'Fotografa la scrivania dove sei adesso, così com\'è. Vietato ' +
      'sistemare niente prima.',
  },
  {
    titolo: 'LA TUA FACCIA ADESSO',
    consegna:
      'Un selfie in questo momento, com\'è venuto. Niente filtri e niente ' +
      'secondo tentativo.',
  },
  {
    titolo: 'BALLA PER DIECI SECONDI',
    consegna:
      'Un video dove balli, dove sei adesso. Più è fuori luogo il posto, ' +
      'meglio è.',
    mediaKind: 'video',
  },
  {
    titolo: "COSA C'È NEL TUO FRIGO",
    consegna: 'Apri il frigo e scatta. Vince il più disperato.',
  },
  {
    titolo: 'LA FOTO PIÙ BRUTTA CHE HAI IN GALLERIA',
    consegna: 'Cercala davvero. Quella che non hai mai fatto vedere a nessuno.',
    source: 'archive',
  },
  {
    titolo: 'LA SCARPA PIÙ DISTRUTTA CHE HAI',
    consegna:
      'Vai a prenderla, mettila a terra e fotografala. Più è messa male ' +
      'meglio è.',
  },
  {
    titolo: 'IMITA QUALCUNO CHE CONOSCIAMO TUTTI',
    consegna:
      'Dieci secondi di imitazione. Non dire chi è: si capisce o non si ' +
      'capisce.',
    mediaKind: 'video',
  },
  {
    titolo: 'IL TUO ANIMALE MENTRE FA UNA COSA STUPIDA',
    consegna:
      'Aspetta il momento e scatta. Se non hai un animale, va bene anche ' +
      'quello di qualcun altro.',
  },
  {
    titolo: 'TU, DIECI ANNI FA',
    consegna: 'Una foto vecchia di te. Più è imbarazzante più vale.',
    source: 'archive',
  },
  {
    titolo: 'COME SEI VESTITO IN QUESTO MOMENTO',
    consegna:
      'Una foto di quello che hai addosso adesso. Non vale cambiarsi, e si ' +
      'vede.',
  },
  {
    titolo: 'VESTITI COME TUA MADRE',
    consegna:
      'Mettiti addosso qualcosa che metterebbe lei e fatti una foto. ' +
      'L\'imitazione conta più dei vestiti.',
  },
  {
    titolo: 'IL POSTO PIÙ BELLO DOVE SEI STATO',
    consegna:
      'Una foto fatta da te, non presa da internet. Si vede la differenza.',
    source: 'archive',
  },
];

/** Il giorno di oggi in Italia, come lo scrivono le sfide: `2026-10-31`. */
function oggiInItalia() {
  return new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Rome' });
}

/**
 * Scrive la gara, con **lo stesso corpo** che scriverebbe l'app.
 *
 * I campi sono quelli di `ChallengeMapper.toCreateMap`: se qui ne mancasse
 * uno, quella gara sparirebbe dalle query che filtrano su di lui — e il modo
 * in cui se ne accorgerebbe qualcuno e' che la missione non compare da nessuna
 * parte, senza nessun errore.
 *
 * Nasce **non pagata**, come tutte: a renderla viva e' il pagamento, un
 * istante dopo. Se quello fallisce resta li' spenta e non la vede nessuno.
 */
async function scriviLaGara(chi, missione, scelte) {
  const adesso = admin.firestore.Timestamp.now();
  const ore = scelte.oreDiGara || 24;

  const gara = await db.collection('challenges').add({
    title: missione.titolo,
    brief: missione.consegna,
    prizeCents: scelte.premioCents,
    scope: 'global',
    source: missione.source || 'instant',
    audience: ['everyone'],
    maxParticipants: scelte.maxPartecipanti || 0,
    place: '',
    rules: [],
    mediaKind: missione.mediaKind || 'photo',
    createdByUsername: chi.username,
    createdByUserId: chi.userId,
    startsAt: adesso,
    endsAt: admin.firestore.Timestamp.fromMillis(
      adesso.toMillis() + ore * 60 * 60 * 1000
    ),
    participantsCount: 0,
    winnerEntryId: null,
    targetUserId: '',
    targetUsername: '',
    duelMessage: '',
    duelStatus: 'pending',
    respondedAt: null,
    prizeStatus: 'unpaid',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    // **Il segno che l'ha lanciata il salvadanaio.** Non si vede nell'app e
    // non deve: la gara e' vera e l'autore e' vero. Serve a noi, per sapere
    // quali sono partite da sole il giorno in cui i conti non tornano o
    // bisogna fermarle tutte insieme.
    dalSalvadanaio: true,
  });

  return gara;
}

/**
 * Lancia le missioni di chi ha il salvadanaio acceso.
 *
 * **Tre volte al giorno e non una**, cosi' le missioni non escono tutte
 * insieme all'alba: una gara lanciata alle nove e una lanciata alle nove e un
 * secondo si fanno concorrenza fra loro, e chi ha cinque vite al giorno le
 * spende sulla prima che vede.
 *
 * Gli orari sono quelli in cui il telefono e' in mano: mattina, pausa pranzo,
 * dopo cena.
 */
exports.lanciaLeMissioni = onSchedule(
  { schedule: '0 10,14,20 * * *', timeZone: 'Europe/Rome' },
  async () => {
    const oggi = oggiInItalia();
    const salvadanai = await db
      .collection('salvadanai')
      .where('acceso', '==', true)
      .get();

    if (salvadanai.empty) {
      return;
    }

    for (const salvadanaio of salvadanai.docs) {
      try {
        await lanciaPerUno(salvadanaio, oggi);
      } catch (errore) {
        // Un salvadanaio rotto non deve fermare gli altri: sono persone
        // diverse con soldi diversi.
        logger.error('salvadanaio non riuscito', {
          chi: salvadanaio.id,
          errore: String(errore).slice(0, 300),
        });
      }
    }
  }
);

async function lanciaPerUno(salvadanaio, oggi) {
  const userId = salvadanaio.id;
  const scelte = salvadanaio.data() || {};
  const premio = scelte.premioCents || 0;

  if (premio <= 0) {
    logger.warn('salvadanaio senza premio, saltato', { userId });

    return;
  }

  // **La data di fine, decisa quando si accende.** Una spinta per far partire
  // il motore deve avere una fine scritta da qualche parte, o diventa una
  // funzione dell'app — e a quel punto nessuno ha piu' motivo di lanciare,
  // perche' c'e' gia' tutto da fare gratis.
  if (scelte.fino && oggi > scelte.fino) {
    await salvadanaio.ref.update({ acceso: false, spentoPerche: 'scaduto' });
    logger.info('salvadanaio scaduto', { userId, fino: scelte.fino });

    return;
  }

  // Quante ne sono gia' uscite oggi. Il conteggio sta nel documento e non si
  // ricava contando le gare: contarle vorrebbe dire una lettura di tutte le
  // gare di oggi a ogni giro, e sbagliare per una gara cancellata a mano.
  const fatteOggi = scelte.giorno === oggi ? scelte.fatte || 0 : 0;
  const alGiorno = scelte.alGiorno || 1;

  if (fatteOggi >= alGiorno) {
    return;
  }

  const utente = await db.collection('users').doc(userId).get();

  if (!utente.exists) {
    logger.warn('salvadanaio di un account che non c e piu', { userId });

    return;
  }

  const saldo = utente.get('walletCents') || 0;

  // **Finiti i soldi, si spegne e si dice perche'.** Lasciarlo acceso vorrebbe
  // dire provare e fallire tre volte al giorno per sempre, riempiendo i
  // registri di errori che non sono errori.
  if (saldo < premio) {
    await salvadanaio.ref.update({ acceso: false, spentoPerche: 'finiti' });
    logger.info('salvadanaio finito', { userId, saldo, premio });

    return;
  }

  const quante = scelte.lanciate || 0;
  const missione = MISSIONI[quante % MISSIONI.length];

  const gara = await scriviLaGara(
    { userId, username: utente.get('username') || '' },
    missione,
    scelte
  );

  const esito = await pagamenti.pagaDalPortafoglio(userId, gara.id);

  if (!esito.ok) {
    // **Non pagata vuol dire non nata.** Una gara con il premio a zero in
    // mezzo alle altre e' peggio di una gara in meno: chi partecipa non puo'
    // saperlo, e scopre di aver speso una delle sue cinque di oggi per
    // niente.
    await gara.ref.delete();
    logger.warn('gara del salvadanaio non pagata, tolta', {
      userId,
      motivo: esito.reason,
    });

    return;
  }

  await salvadanaio.ref.update({
    giorno: oggi,
    fatte: fatteOggi + 1,
    lanciate: quante + 1,
    ultima: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.info('missione lanciata dal salvadanaio', {
    userId,
    gara: gara.id,
    titolo: missione.titolo,
    premio,
  });
}

exports.MISSIONI = MISSIONI;
