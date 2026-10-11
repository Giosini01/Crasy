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
 * I soldi sono entrati per davvero, **tutti insieme e prima**: un pagamento
 * con la carta su Stripe, con la sua ricevuta. Da li' in poi ogni missione ne
 * consuma un pezzo. E' un prepagato che si scala, non un pagamento finto —
 * come la ricarica del telefono: paghi una volta e poi fai venti telefonate,
 * e nessuna e' gratis.
 *
 * ## Perche' il fondo e non il portafoglio
 *
 * Il primo tentativo metteva quei soldi nel portafoglio di chi lancia. Due
 * cose non andavano.
 *
 * **La prima: li avrebbero visti tutti.** Il numero del portafoglio vive
 * dentro la scheda del profilo, e quella scheda la legge chiunque abbia fatto
 * l'accesso — serve per il nome e la foto. Firestore protegge i documenti,
 * non i campi dentro: venticinque euro li' dentro sono venticinque euro
 * scritti in pubblico.
 *
 * **La seconda: non sono soldi suoi da spendere.** Sono messi da parte per i
 * premi. Nel portafoglio si sarebbero confusi con quelli vinti, che invece si
 * possono prelevare.
 *
 * Quindi il fondo sta in `salvadanai/{uid}`, una collezione che nessun
 * telefono puo' nemmeno aprire. La gara che ne esce resta **indistinguibile**
 * da una pagata con la carta: stesso stato, stesso orologio, stessa riga nel
 * registro, stesso conteggio nella classifica di chi fa giocare.
 *
 * ## Dove si accende
 *
 * In `salvadanai/{uid}`, un documento per persona:
 *
 * - `acceso` — false ferma tutto all'istante, senza pubblicare niente;
 * - `fondoCents` — quanto resta da spendere. Scende a ogni missione;
 * - `alGiorno` — quante missioni al giorno, al massimo;
 * - `premioCents` — quanto mettere in palio ogni volta;
 * - `oreDiGara` — quanto dura ognuna;
 * - `maxPartecipanti` — quanti posti ha ogni gara;
 * - `fino` — la data dopo la quale si ferma comunque.
 *
 * Nessuno di questi lo puo' scrivere un telefono: le regole non lasciano
 * leggere ne' scrivere quella collezione. Si toccano da qui o dagli strumenti.
 */

const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

const pagamenti = require('./payments');
const posta = require('./posta');

const db = admin.firestore();

/**
 * **Le missioni che il server lancia, in ordine.**
 *
 * Non sono quelle che l'app propone a chi scrive da se', e non e' una svista:
 * quelle sono un menu da cui scegliere, queste sono una sequenza che si
 * srotola nel tempo. Una fila da sfogliare puo' permettersi dodici cose
 * simili; una sequenza che esce tre volte al giorno deve **alternare** — una
 * da casa, una che mette in imbarazzo, una col video — o dopo due giorni
 * sembra sempre la stessa.
 *
 * ## Come sono scelte
 *
 * La regola e' una: **le deve poter fare chiunque, adesso, senza prepararsi.**
 * Una missione che chiede di andare da qualche parte, di avere una cosa
 * precisa in casa o di saper fare qualcosa la fanno in tre, e una gara con tre
 * foto e' peggio di nessuna gara.
 *
 * Poi, in ordine di importanza:
 *
 * - **imbarazzanti, non difficili.** Chi guarda vuole vedere qualcuno che ci
 *   ha provato, non qualcuno che e' bravo. "La tua faccia adesso" la mandano
 *   tutti; "la foto piu' bella che sai fare" la manda chi ha una reflex;
 * - **si capiscono dal titolo**, che spesso e' l'unica cosa che si legge;
 * - **fanno venire voglia di vedere le altre.** E' la meta' che si dimentica:
 *   una missione riuscita non e' una a cui e' bello partecipare, e' una in cui
 *   e' bello **guardare cosa hanno fatto gli altri**.
 *
 * Si gira in tondo: finite, si ricomincia.
 */
const MISSIONI = [
  {
    titolo: 'LA TUA FACCIA ADESSO, COM’È',
    consegna:
      'Un selfie in questo momento. Niente filtri, niente luce buona, niente '
      + 'secondo tentativo: il primo che viene.',
  },
  {
    titolo: 'APRI IL FRIGO E SCATTA',
    consegna: 'Così com’è. Vince il più disperato, non il più pieno.',
  },
  {
    titolo: 'FAI LA FACCIA DI TUA MADRE QUANDO SI ARRABBIA',
    consegna: 'Un selfie con quella faccia lì. La riconosciamo tutti.',
  },
  {
    titolo: 'IL CASINO PEGGIORE CHE HAI IN CASA',
    consegna:
      'Trova l’angolo più messo male e fotografalo. Vietato sistemare '
      + 'niente prima: si vede.',
  },
  {
    titolo: 'DIECI SECONDI DI BALLO, DOVE SEI ADESSO',
    consegna:
      'Non serve saper ballare, serve farlo lì dove sei. Più è fuori luogo il '
      + 'posto, meglio è.',
    mediaKind: 'video',
  },
  {
    titolo: 'COSA C’È SOTTO IL TUO LETTO',
    consegna: 'Guarda sotto e fotografa quello che trovi. Senza togliere niente.',
  },
  {
    titolo: 'LA COSA PIÙ VECCHIA CHE HAI ADDOSSO',
    consegna:
      'Una maglietta di dieci anni fa, le scarpe distrutte, il braccialetto '
      + 'del 2015. Fotografala addosso a te.',
  },
  {
    titolo: 'FATTI FOTOGRAFARE DA QUALCUNO SENZA DIRGLI PERCHÉ',
    consegna:
      'Chiedi a chi hai vicino di farti una foto e non spiegare niente. '
      + 'Manda quella che ha fatto lui.',
  },
  {
    titolo: 'IMITA QUALCUNO CHE CONOSCIAMO TUTTI',
    consegna:
      'Dieci secondi. Non dire chi è: o si capisce o non si capisce, e questo '
      + 'è il bello.',
    mediaKind: 'video',
  },
  {
    titolo: 'IL TUO ANIMALE MENTRE FA UNA COSA STUPIDA',
    consegna:
      'Aspetta il momento, non metterlo in posa. Se non ne hai uno, va bene '
      + 'quello di qualcun altro.',
  },
  {
    titolo: 'FA’ FINTA DI ESSERE RICCO CON QUELLO CHE HAI IN CASA',
    consegna:
      'Una foto dove sembri uno che se la passa benissimo. Si può usare solo '
      + 'quello che hai lì.',
  },
  {
    titolo: 'COSA STAI MANGIANDO, ANCHE SE FA SCHIFO',
    consegna:
      'Fotografa quello che hai davanti adesso. Soprattutto se non è una cosa '
      + 'da far vedere.',
  },
  {
    titolo: 'METTITI UNA COSA DI UN TUO PARENTE',
    consegna:
      'Un giubbotto di tuo padre, gli occhiali di tua nonna, una felpa di tuo '
      + 'fratello. Addosso a te, e si vede che non è tua.',
  },
  {
    titolo: 'IL POSTO PIÙ BRUTTO DOVE SEI STATO OGGI',
    consegna: 'Una foto di adesso o di oggi. Più è squallido più vale.',
  },
  {
    titolo: 'DI’ UNA BUGIA GUARDANDO IN CAMERA',
    consegna:
      'Dieci secondi. Raccontaci una cosa falsa con la faccia più seria che '
      + 'hai: vediamo chi ci crede.',
    mediaKind: 'video',
  },
  {
    titolo: 'LA TUA SCRIVANIA O IL TUO TAVOLO, ADESSO',
    consegna:
      'Scatta senza spostare niente. La prima cosa che si vede è quanto ci '
      + 'hai provato a non sistemare.',
  },
  {
    titolo: 'FATTI UNA FOTO COME SE FOSSE UNA COPERTINA DI UN DISCO',
    consegna:
      'Posa seria, sguardo lontano, quello che hai intorno. Il titolo lo '
      + 'immaginiamo noi.',
  },
  {
    titolo: 'LA FOTO PIÙ BRUTTA CHE HAI IN GALLERIA',
    consegna:
      'Cercala davvero: quella che non hai mai fatto vedere a nessuno e che '
      + 'non hai mai avuto il coraggio di cancellare.',
    source: 'archive',
  },
  {
    titolo: 'TU DA PICCOLO',
    consegna: 'Una foto di quando eri bambino. Più è imbarazzante più vale.',
    source: 'archive',
  },
  {
    titolo: 'LE SCARPE CHE HAI AI PIEDI ADESSO',
    consegna:
      'Guarda in basso e scatta. Si vede tutto: dove sei stato e quanto le '
      + 'tieni bene.',
  },
];

/**
 * **Chi puo' avere un fondo, scritto qui e in nessun altro posto.**
 *
 * Due persone, per nome e cognome. Non un permesso, non un campo da
 * accendere: un elenco chiuso dentro il codice.
 *
 * Sembra eccessivo visto che quella collezione nessun telefono la puo'
 * scrivere, e infatti non difende da un telefono: difende da **noi**. Un
 * documento scritto per sbaglio con l'identificativo sbagliato, una riga di
 * strumento lanciata con il nome di un altro, e il server comincerebbe a
 * lanciare missioni a nome di una persona che non ne sa niente. Non e' un
 * attacco, e' un errore di battitura — e gli errori di battitura capitano,
 * mentre questo elenco no.
 */
const PADRONI = [
  'vlwARzcTJUO71knlvXJEc5b711y1', // giosyni
  'zialfmbJK7XawXbBUWcXKGff2xj2', // franksy
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
    // **L'asterisco, non la parola.** Chi la puo' vedere viaggia dentro la
    // gara, e la home chiede `audience` che contiene `'*'` — vedi
    // `Challenge.everyone` nell'app. Scrivendoci `'everyone'` la gara nasce
    // giusta in tutto il resto e **non compare da nessuna parte**: nessun
    // errore, nessun avviso, semplicemente non c'e'. E' successo.
    audience: ['*'],
    // **Dieci posti, salvo diverso.** Zero vorrebbe dire senza limite, ed e'
    // il ripiego sbagliato per queste: con dieci foto si guardano tutte e il
    // voto vale qualcosa, e un premio diviso per una possibilita' su dieci
    // resta una scommessa vera. Senza tetto, chi arriva ultimo sa gia' di non
    // vincere e non manda niente.
    maxParticipants: scelte.maxPartecipanti || 10,
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
  });

  return gara;
}

/**
 * Lancia le missioni di chi ha il salvadanaio acceso.
 *
 * **Tre volte al giorno e non tutte insieme.** Due gare che si aprono nello
 * stesso istante si fanno concorrenza fra loro: chi ha cinque vite al giorno
 * le spende sulla prima che vede, e la seconda resta mezza vuota.
 *
 * Le dieci, le due, le sette: mattina, pausa, rientro. Durando ventiquattro
 * ore, si chiudono alle stesse ore — tutte e tre in orari in cui il telefono
 * e' in mano, e nessuna si decide alle quattro di notte quando il risultato
 * non lo vede nessuno.
 *
 * Restano **tre gare aperte insieme** in ogni momento: abbastanza perche' chi
 * apre l'app trovi sempre qualcosa, poche perche' i dieci posti di ognuna si
 * riempiano davvero.
 */
exports.lanciaLeMissioni = onSchedule(
  { schedule: '0 10,14,19 * * *', timeZone: 'Europe/Rome' },
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
      if (!PADRONI.includes(salvadanaio.id)) {
        logger.error('salvadanaio di qualcuno che non e nell elenco', {
          chi: salvadanaio.id,
        });

        continue;
      }

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
  const premio = scelte.premioCents || 100;

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
    return { ok: false, reason: 'tetto-di-oggi' };
  }

  const utente = await db.collection('users').doc(userId).get();

  if (!utente.exists) {
    logger.warn('salvadanaio di un account che non c e piu', { userId });

    return;
  }

  // **Il fondo sta qui dentro, non nel portafoglio.**
  //
  // Nel portafoglio no per una ragione precisa: quel numero vive dentro la
  // scheda del profilo, e la scheda del profilo la legge chiunque abbia fatto
  // l'accesso — serve per il nome e la foto. Firestore protegge i documenti,
  // non i campi dentro: mettere li' venticinque euro vorrebbe dire dirlo a
  // tutti.
  //
  // E poi non sono soldi di chi lancia, da spendere come vuole: sono soldi
  // messi da parte per i premi, pagati una volta con la carta. Tenerli
  // separati e' anche piu' onesto.
  const fondo = scelte.fondoCents || 0;

  // **Finiti i soldi, si spegne e si dice perche'.** Lasciarlo acceso vorrebbe
  // dire provare e fallire tre volte al giorno per sempre, riempiendo i
  // registri di errori che non sono errori.
  if (fondo < premio) {
    await salvadanaio.ref.update({ acceso: false, spentoPerche: 'finiti' });
    await avvisaCheFinisce(utente, fondo, premio, true);
    logger.info('fondo finito', { userId, fondo, premio });

    return { ok: false, reason: 'fondo-finito' };
  }

  const quante = scelte.lanciate || 0;
  const missione = MISSIONI[quante % MISSIONI.length];

  const gara = await scriviLaGara(
    { userId, username: utente.get('username') || '' },
    missione,
    scelte
  );

  const esito = await pagaDalFondo(salvadanaio, userId, gara, premio);

  if (!esito.ok) {
    // **Non pagata vuol dire non nata.** Una gara con il premio a zero in
    // mezzo alle altre e' peggio di una gara in meno: chi partecipa non puo'
    // saperlo, e scopre di aver speso una delle sue cinque di oggi per
    // niente.
    await gara.delete();
    logger.warn('gara del salvadanaio non pagata, tolta', {
      userId,
      motivo: esito.reason,
    });

    return;
  }

  // **La traccia sta qui dentro, non sulla gara.**
  //
  // All'inizio il segno era un campo sulla gara stessa, `dalSalvadanaio`. Era
  // sbagliato: le gare **le legge chiunque abbia fatto l'accesso** — e' cosi'
  // che si vedono nella home — quindi quel campo raccontava a tutti quali
  // missioni erano partite da sole. Non lo mostrava nessuna schermata, ma il
  // dato c'era, e un dato che c'e' prima o poi qualcuno lo legge.
  //
  // Qui invece sta dentro `salvadanai`, che nessun telefono puo' nemmeno
  // aprire. Serve lo stesso scopo — sapere quali sono partite da sole quando
  // i conti non tornano, o doverle fermare tutte insieme — senza dirlo a
  // nessun altro.
  await salvadanaio.ref
      .collection('lanciate')
      .doc(gara.id)
      .set({
        titolo: missione.titolo,
        premioCents: premio,
        quando: admin.firestore.FieldValue.serverTimestamp(),
      });

  logger.info('missione lanciata dal fondo', {
    userId,
    gara: gara.id,
    titolo: missione.titolo,
    premio,
    restano: esito.restano,
  });

  // Tre missioni alla fine: il momento in cui serve saperlo per fare in tempo
  // a decidere, non quando e' gia' spento.
  if (esito.restano === premio * 3) {
    await avvisaCheFinisce(utente, esito.restano, premio, false);
  }

  return { ok: true, gara: gara.id, titolo: missione.titolo, restano: esito.restano };
}


/**
 * **Scala il premio dal fondo e segna la gara come pagata.**
 *
 * Tutto dentro una transazione sola: o scende il fondo e la gara diventa viva,
 * o non succede niente. Senza, un errore a meta' lascerebbe una gara pubblica
 * con un premio che nessuno ha pagato — oppure il contrario, soldi scalati per
 * una gara che non parte.
 *
 * La gara che ne esce e' **indistinguibile** da una pagata con la carta:
 * stesso `prizeStatus`, stesso orologio che riparte, stessa riga nel registro
 * di chi l'ha lanciata, stesso conteggio nella classifica di chi fa giocare.
 * L'unica differenza e' `pagataDalFondo`, che non serve all'app ma a chi un
 * giorno dovra' far quadrare i conti e trovera' una gara pagata senza un
 * incasso Stripe suo. L'incasso c'e' — e' quello da venticinque euro di
 * settimane prima — ma copre venticinque gare, e senza questo segno non si
 * capirebbe.
 */
async function pagaDalFondo(salvadanaio, userId, gara, premio) {
  const oggi = oggiInItalia();

  const esito = await db.runTransaction(async (transaction) => {
    const fresco = await transaction.get(salvadanaio.ref);
    const dati = fresco.data() || {};
    const fondo = dati.fondoCents || 0;

    // Si rilegge dentro la transazione: fra il controllo di prima e adesso
    // puo' essere passato un lancio a mano dalla pagina di amministrazione.
    if (fondo < premio) {
      return { ok: false, reason: 'fondo-finito' };
    }

    const adesso = admin.firestore.Timestamp.now();

    transaction.update(gara, {
      prizeStatus: 'held',
      paidAt: adesso,
      pagataDalFondo: true,
      startsAt: adesso,
    });

    transaction.update(salvadanaio.ref, {
      fondoCents: admin.firestore.FieldValue.increment(-premio),
      spesiCents: admin.firestore.FieldValue.increment(premio),
      giorno: oggi,
      fatte: (dati.giorno === oggi ? dati.fatte || 0 : 0) + 1,
      lanciate: (dati.lanciate || 0) + 1,
      ultima: admin.firestore.FieldValue.serverTimestamp(),
    });

    // La classifica di chi fa giocare: questi soldi li ha messi davvero.
    transaction.update(db.collection('users').doc(userId), {
      totalStakedCents: admin.firestore.FieldValue.increment(premio),
      totalStakedCount: admin.firestore.FieldValue.increment(1),
    });

    return { ok: true, restano: fondo - premio };
  });

  if (esito.ok) {
    await pagamenti.scriviNelRegistro(userId, `pagamento_${gara.id}`, {
      kind: 'challengePayment',
      amountCents: -premio,
      challengeId: gara.id,
      challengeTitle: (await gara.get()).get('title') || '',
      source: 'card',
      note: 'Premio messo in palio, pagato col fondo delle missioni',
    });
  }

  return esito;
}

/**
 * Avvisa per email che il fondo sta per finire.
 *
 * **Senza questo, "come faccio a capire che stanno finendo" resta una cosa da
 * ricordarsi di andare a guardare** — e non se la ricorda nessuno, perche'
 * finche' funziona non si va a controllare. Il giorno in cui smette, le
 * missioni semplicemente non escono piu' e non lo sa nessuno.
 *
 * Si manda a tre missioni dalla fine, non all'ultima: serve il tempo di
 * decidere se ricaricare, non un necrologio.
 */
async function avvisaCheFinisce(utente, fondo, premio, finito) {
  const email = utente.get('email');

  if (!email) {
    return;
  }

  const restano = Math.floor(fondo / premio);
  const quanti = (fondo / 100).toFixed(2).replace('.', ',');

  try {
    await posta.spedisci({
      from: '"CRASY" <' + posta.CASELLA + '>',
      to: email,
      subject: finito
        ? 'Il fondo delle missioni è finito — CRASY'
        : 'Il fondo delle missioni sta finendo — CRASY',
      text: finito
        ? 'Il fondo e finito e le missioni automatiche si sono fermate. '
          + 'Nessuna gara in corso e stata toccata.'
        : 'Nel fondo restano ' + quanti + ' euro, cioe ' + restano
          + ' missioni. Poi si ferma da solo.',
      html: posta.vestito({
        titolo: finito ? 'IL FONDO È FINITO' : 'IL FONDO STA FINENDO',
        testo: finito
          ? 'Le missioni automatiche si sono fermate. Le gare già aperte '
            + 'restano aperte e si chiuderanno da sole: nessuna è stata '
            + 'toccata.'
          : 'Restano ' + quanti + ' €, cioè ' + restano
            + ' missioni. Quando finiscono si ferma da solo.',
        tasto: 'APRI CRASY',
        link: 'https://crasyapp.com/',
        nota:
          'Questa email la ricevi perché hai un fondo per le missioni '
          + 'automatiche. La riceve solo chi ce l\'ha.',
        a: email,
      }),
    });
  } catch (errore) {
    // Un avviso che non parte non deve fermare le missioni: quelle sono la
    // cosa importante, questa e' la cortesia.
    logger.warn('avviso del fondo non partito', {
      errore: String(errore).slice(0, 200),
    });
  }
}

/**
 * Lancia una missione adesso, per il tasto della pagina di amministrazione.
 *
 * E' la stessa strada della funzione a orario — stesso tetto giornaliero,
 * stesso fondo, stessa sequenza di missioni — perche' un tasto che prende una
 * scorciatoia prova una cosa diversa da quella che poi gira da sola.
 */
async function lanciaOra(salvadanaio) {
  if (!PADRONI.includes(salvadanaio.id)) {
    return { ok: false, reason: 'non-in-elenco' };
  }

  return lanciaPerUno(salvadanaio, oggiInItalia());
}

exports.lanciaOra = lanciaOra;
exports.MISSIONI = MISSIONI;
exports.pagaDalFondo = pagaDalFondo;
