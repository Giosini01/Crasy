'use strict';

/**
 * Le email di CRASY, scritte e mandate da noi.
 *
 * **Perche' non usiamo piu' quelle di Firebase.** L'indirizzo a cui portano i
 * suoi link — il campo `callbackUri` — su questo progetto **non si puo'
 * cambiare**: l'API risponde `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED` a qualunque
 * valore, e la console fallisce per lo stesso motivo. Provato con tre forme di
 * indirizzo, con il dominio email acceso, spento e rimosso del tutto: sempre
 * no. Cambiare il mittente invece funziona, quindi non e' un permesso mancante:
 * e' quel campo a essere chiuso.
 *
 * Il risultato era un'email che partiva dal nostro dominio e portava a una
 * pagina bianca ospitata sul vecchio nome del progetto.
 *
 * Girandoci intorno si arriva a una soluzione migliore di quella che si
 * voleva: **il codice lo chiediamo noi**, e attorno gli costruiamo il messaggio
 * che vogliamo. `generateEmailVerificationLink` e `generatePasswordResetLink`
 * non mandano niente a nessuno: costruiscono il link e lo restituiscono. Dentro
 * c'e' `oobCode`, il codice usa e getta. Lo prendiamo e lo rimettiamo dentro
 * **il nostro** indirizzo, che porta alla **nostra** pagina — quella che gia'
 * sa consegnarlo a Firebase e leggerne la risposta.
 *
 * Firebase resta quello che decide se il codice e' valido, cioe' la parte che
 * conta, e smette di decidere come appare CRASY.
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const crypto = require('crypto');
const nodemailer = require('nodemailer');

/**
 * La password della casella, che non sta nel codice e non passa da nessuna
 * parte dove si possa leggere.
 *
 * Si scrive una volta sola, dal terminale di chi tiene il progetto:
 *
 *     firebase functions:secrets:set SMTP_PASSWORD
 *
 * Il valore lo chiede a schermo senza mostrarlo, lo cifra e lo tiene Google.
 * **Non finisce nel repository, non finisce nei registri e non passa da una
 * chat.** Una password incollata dentro un messaggio e' una password da
 * cambiare.
 */
const SMTP_PASSWORD = defineSecret('SMTP_PASSWORD');

const CASELLA = 'register@crasyapp.com';
const SERVER = 'smtp.ionos.it';

/**
 * Le due porte, nell'ordine in cui si provano.
 *
 * **La 465 e' quella che IONOS documenta**: la connessione parte gia' cifrata.
 * La 587 fa la stessa cosa per un'altra strada — si parte in chiaro e si passa
 * subito a cifrato con STARTTLS — ed e' la porta di riserva indicata nella
 * stessa pagina.
 *
 * Si provano tutte e due invece di sceglierne una perche' **da qui non si puo'
 * sapere quale delle due passa**: la funzione gira dentro la rete di Google,
 * dove certe porte in uscita sono chiuse, e questo si scopre solo al primo
 * invio vero — cioe' addosso alla prima persona che si registra. Provarle tutte
 * e due costa un secondo nel caso peggiore e toglie di mezzo la domanda.
 */
const PORTE = [
  { port: 465, secure: true },
  { port: 587, secure: false },
];

/** Dove portano i link: la nostra pagina, non quella di Firebase. */
const PAGINA = 'https://crasy.web.app/conferma';

/**
 * Ogni quanti secondi si puo' rimandare la stessa email allo stesso indirizzo.
 *
 * **Sessanta.** Il tasto "rimandamela" e' li' per chi non l'ha ricevuta, e chi
 * non la riceve lo preme piu' volte: senza un freno, dieci tocchi sono dieci
 * email identiche — e dieci email identiche dallo stesso mittente sono il modo
 * piu' rapido per farsi mettere nello spam da Gmail, insieme a tutte quelle che
 * verranno dopo.
 */
const SECONDI_FRA_DUE_INVII = 60;

/**
 * Spedisce, provando le porte una dopo l'altra.
 *
 * Serve a tutte e due le email, e sta qui una volta sola: copiarlo avrebbe
 * voluto dire due versioni che si separano al primo cambiamento — si corregge
 * un tempo di attesa in una e resta vecchio nell'altra.
 */
async function spedisci(messaggio) {
  let ultimoGuaio = null;

  for (const porta of PORTE) {
    try {
      const postino = nodemailer.createTransport({
        host: SERVER,
        ...porta,
        auth: { user: CASELLA, pass: SMTP_PASSWORD.value() },
        // Senza un tetto, una porta chiusa non da' errore: **resta li' ad
        // aspettare**, e chi ha appena premuto il tasto guarda una rotellina
        // finche' la funzione non viene interrotta a meta'.
        connectionTimeout: 12000,
        greetingTimeout: 12000,
      });

      await postino.sendMail(messaggio);
      logger.info('email spedita', { porta: porta.port });

      return;
    } catch (guaio) {
      ultimoGuaio = guaio;
      logger.warn('porta non buona', {
        porta: porta.port,
        guaio: String(guaio).slice(0, 200),
      });
    }
  }

  throw new HttpsError('unavailable', 'La posta non e partita.', ultimoGuaio);
}

/**
 * Il vestito di ogni nostra email.
 *
 * **Tabelle e stili scritti dentro i tag**, che nel 2026 sembra assurdo: i
 * programmi di posta buttano via i fogli di stile e meta' delle regole di
 * impaginazione moderne. Quello che regge dappertutto e' l'HTML di vent'anni
 * fa, e un'email che si sfascia su Outlook e' un'email che non fa il suo
 * lavoro.
 */
function vestito({ titolo, testo, tasto, link, nota }) {
  return [
    '<!DOCTYPE html><html lang="it"><body style="margin:0;padding:0;background:#F7F5F2;">',
    '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F7F5F2;padding:32px 16px;"><tr><td align="center">',
    '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:420px;background:#FFFFFF;border-radius:16px;padding:32px;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica,Arial,sans-serif;">',
    '<tr><td style="font-size:22px;font-weight:800;letter-spacing:.14em;color:#111111;padding-bottom:28px;">CRASY<span style="color:#C8102E;">.</span></td></tr>',
    '<tr><td style="font-size:26px;font-weight:800;line-height:1.15;color:#111111;">' +
      titolo +
      '<span style="color:#C8102E;">.</span></td></tr>',
    '<tr><td style="font-size:15px;line-height:1.5;color:#555555;padding-top:10px;">' +
      testo +
      '</td></tr>',
    '<tr><td style="padding-top:26px;"><a href="' +
      link +
      '" style="display:block;background:#C8102E;color:#FFFFFF;text-decoration:none;text-align:center;font-size:15px;font-weight:700;letter-spacing:.06em;padding:16px;border-radius:12px;">' +
      tasto +
      '</a></td></tr>',
    '<tr><td style="font-size:12px;line-height:1.5;color:#999999;padding-top:22px;">' +
      nota +
      '</td></tr>',
    '<tr><td style="font-size:12px;color:#BBBBBB;padding-top:22px;border-top:1px solid #EEEEEE;">crasyapp.com</td></tr>',
    '</table></td></tr></table></body></html>',
  ].join('');
}

/** Il codice usa e getta, tirato fuori dal link che Firebase restituisce. */
function codiceDentro(link) {
  const codice = new URL(link).searchParams.get('oobCode');

  if (!codice) {
    throw new HttpsError('internal', 'Codice mancante.');
  }

  return codice;
}

function nostroLink(modo, codice) {
  return PAGINA + '?mode=' + modo + '&oobCode=' + encodeURIComponent(codice);
}

/**
 * Manda l'email di conferma a chi la chiede.
 *
 * La chiama l'app dopo la registrazione e dal tasto "rimandamela".
 *
 * **Chiede chi sei al gettone, non al messaggio.** L'indirizzo a cui scrivere
 * si legge dalla sessione di chi chiama, non da quello che manda: se arrivasse
 * da fuori, chiunque potrebbe farci scrivere a chiunque, e diventeremmo noi lo
 * strumento per infastidire qualcun altro.
 */
exports.mandaLaConferma = onCall(
  { secrets: [SMTP_PASSWORD], region: 'europe-west8' },
  async (request) => {
    const userId = request.auth?.uid;

    if (!userId) {
      throw new HttpsError('unauthenticated', 'Serve una sessione.');
    }

    const persona = await admin.auth().getUser(userId);

    if (!persona.email) {
      throw new HttpsError('failed-precondition', 'Nessun indirizzo.');
    }

    // Gia' confermato: non si manda niente, e non e' un errore. Capita a chi
    // conferma da un altro dispositivo e poi tocca "rimandamela" qui.
    if (persona.emailVerified) {
      return { mandata: false, motivo: 'gia confermato' };
    }

    const profilo = admin.firestore().collection('users').doc(userId);
    const ultima = (await profilo.get()).get('lastVerifyEmailAt')?.toDate?.();

    if (ultima && Date.now() - ultima.getTime() < SECONDI_FRA_DUE_INVII * 1000) {
      return { mandata: false, motivo: 'appena mandata' };
    }

    const link = nostroLink(
      'verifyEmail',
      codiceDentro(
        await admin
          .auth()
          .generateEmailVerificationLink(persona.email, {
            url: 'https://crasy.web.app/',
          })
      )
    );

    await spedisci({
      from: '"CRASY" <' + CASELLA + '>',
      to: persona.email,
      subject: 'Conferma il tuo indirizzo — CRASY',
      // **Anche la versione senza grafica.** Qualche programma di posta mostra
      // quella al posto dell'altra, e chi legge da un orologio o con un lettore
      // vocale ha solo questa: senza, riceverebbe un messaggio vuoto.
      text:
        'Conferma il tuo indirizzo per entrare in CRASY:' +
        '\n\n' +
        link +
        '\n\nIl link vale un ora. Se non ti sei registrato tu, ignora questa email.',
      html: vestito({
        titolo: 'CI SIAMO',
        testo:
          'Manca un tocco: conferma che questo indirizzo e&#39; tuo, e sei dentro.',
        tasto: 'CONFERMA L&#39;INDIRIZZO',
        link,
        nota:
          'Il link vale un&#39;ora sola. Se non ti sei registrato tu, questa ' +
          'email si butta: senza il tocco non succede niente.',
      }),
    });

    await profilo.set(
      { lastVerifyEmailAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );

    return { mandata: true };
  }
);

/**
 * Manda l'email per rifarsi la password.
 *
 * ## Questa la puo' chiamare chiunque, e cambia tutto
 *
 * Chi ha perso la password **non ha una sessione**: e' chiuso fuori, ed e'
 * esattamente il motivo per cui sta chiedendo. Quindi qui l'indirizzo arriva
 * dal messaggio, non dal gettone — e questo apre due porte che vanno chiuse
 * subito.
 *
 * **La prima: non si dice mai se un indirizzo esiste.** La risposta e'
 * identica in tutti i casi. Rispondere "questa email non e' registrata"
 * regalerebbe a chiunque un modo per scoprire chi sta su CRASY, provando
 * indirizzi finche' uno non risponde di si'. Chi ha sbagliato a scrivere se ne
 * accorge dal messaggio che non arriva.
 *
 * **La seconda: uno al minuto per indirizzo.** Senza, questa funzione sarebbe
 * un tasto per riempire la casella di chiunque, a spese nostre e con il nostro
 * nome sopra — cioe' il modo piu' rapido di far finire tutte le email di CRASY
 * nello spam.
 *
 * Il freno si tiene su un'impronta dell'indirizzo, non sull'indirizzo: se
 * qualcuno un giorno leggesse quella tabella, non ci troverebbe un elenco di
 * chi ha dimenticato la password.
 */
exports.mandaIlRecupero = onCall(
  { secrets: [SMTP_PASSWORD], region: 'europe-west8' },
  async (request) => {
    const indirizzo = String(request.data?.email || '')
      .trim()
      .toLowerCase();

    // Nemmeno un indirizzo: qui non c'e' niente da nascondere a nessuno,
    // perche' non e' stata fatta nessuna domanda su nessuno.
    if (!indirizzo || !indirizzo.includes('@')) {
      throw new HttpsError('invalid-argument', 'Indirizzo mancante.');
    }

    const impronta = crypto
      .createHash('sha256')
      .update(indirizzo)
      .digest('hex');

    const freno = admin.firestore().collection('recuperi').doc(impronta);
    const ultima = (await freno.get()).get('ultimoAt')?.toDate?.();

    // **Anche qui si risponde di si'.** Dire "aspetta un minuto" a chi non ha
    // un account su CRASY sarebbe comunque un modo per sapere che quell'account
    // esiste, solo piu' lento.
    if (ultima && Date.now() - ultima.getTime() < SECONDI_FRA_DUE_INVII * 1000) {
      return { fatto: true };
    }

    await freno.set(
      { ultimoAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );

    let link;

    try {
      link = nostroLink(
        'resetPassword',
        codiceDentro(
          await admin.auth().generatePasswordResetLink(indirizzo, {
            url: 'https://crasy.web.app/',
          })
        )
      );
    } catch (guaio) {
      // Indirizzo che non esiste, o scritto storto. **Si esce dicendo di si'**:
      // vedi sopra. Nel registro resta scritto, perche' a noi serve saperlo.
      logger.info('recupero per un indirizzo sconosciuto');

      return { fatto: true };
    }

    await spedisci({
      from: '"CRASY" <' + CASELLA + '>',
      to: indirizzo,
      subject: 'Rifai la tua password — CRASY',
      text:
        'Hai chiesto di rifare la password di CRASY:' +
        '\n\n' +
        link +
        '\n\nIl link vale un ora. Se non sei stato tu, ignora questa email: la password resta quella di prima.',
      html: vestito({
        titolo: 'RIFACCIAMOLA',
        testo:
          'Hai chiesto di rifare la password. Scegline una nuova da qui, e ci ' +
          'rientri subito.',
        tasto: 'SCEGLI UNA PASSWORD NUOVA',
        link,
        nota:
          'Il link vale un&#39;ora sola. Se non sei stato tu a chiederlo, ' +
          'ignora questa email: la tua password resta quella di prima, e ' +
          'nessuno l&#39;ha vista.',
      }),
    });

    return { fatto: true };
  }
);
