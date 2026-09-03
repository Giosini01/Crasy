'use strict';

/**
 * L'email di conferma, scritta e mandata da noi.
 *
 * **Perche' non usiamo piu' quella di Firebase.** L'indirizzo a cui portano i
 * suoi link — il campo `callbackUri` — su questo progetto **non si puo'
 * cambiare**: l'API risponde `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED` a qualunque
 * valore, e la console fallisce per lo stesso motivo. Provato con tre forme di
 * indirizzo, con il dominio email acceso, spento e rimosso del tutto: sempre
 * no. Chi si registrava riceveva quindi una mail dal nostro dominio con dentro
 * un link che portava a una pagina bianca di Firebase, ospitata sul vecchio
 * nome del progetto.
 *
 * Girandoci intorno si arriva a una soluzione migliore di quella che si
 * voleva: **il codice di conferma lo chiediamo noi**, e attorno gli
 * costruiamo il messaggio che vogliamo. Firebase resta quello che decide se il
 * codice e' valido — cioe' la parte che conta — e smette di decidere come
 * appare CRASY.
 *
 * ## Cosa vuol dire "chiediamo il codice"
 *
 * `generateEmailVerificationLink` non manda niente a nessuno: costruisce il
 * link e lo restituisce. Dentro c'e' `oobCode`, il codice usa e getta. Noi lo
 * prendiamo e lo rimettiamo dentro **il nostro** indirizzo, che porta alla
 * nostra pagina — la stessa che gia' sa consegnarlo a Firebase e leggerne la
 * risposta.
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
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

// **587 e non 465.** Sulla 465 la connessione parte gia' cifrata, sulla 587 si
// parte in chiaro e si passa subito a cifrato con STARTTLS. Fanno la stessa
// cosa, ma la 587 e' quella che i fornitori tengono aperta piu' spesso — e da
// dentro Google la 465 a volte non passa proprio.
const PORTA = 587;

/** Dove porta il link: la nostra pagina, non quella di Firebase. */
const PAGINA = 'https://crasy.web.app/conferma';

/**
 * Ogni quanti secondi la stessa persona puo' farsi rimandare l'email.
 *
 * **Sessanta.** Il tasto "rimandamela" e' li' per chi non l'ha ricevuta, e chi
 * non la riceve lo preme piu' volte: senza un freno, dieci tocchi sono dieci
 * email identiche — e dieci email identiche dallo stesso mittente sono il modo
 * piu' rapido per farsi mettere nello spam da Gmail, insieme a tutte quelle
 * che verranno dopo.
 */
const SECONDI_FRA_DUE_INVII = 60;

function corpo(link) {
  return [
    '<!DOCTYPE html><html lang="it"><body style="margin:0;padding:0;background:#F7F5F2;">',
    '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F7F5F2;padding:32px 16px;"><tr><td align="center">',
    '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:420px;background:#FFFFFF;border-radius:16px;padding:32px;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica,Arial,sans-serif;">',
    '<tr><td style="font-size:22px;font-weight:800;letter-spacing:.14em;color:#111111;padding-bottom:28px;">CRASY<span style="color:#C8102E;">.</span></td></tr>',
    '<tr><td style="font-size:26px;font-weight:800;line-height:1.15;color:#111111;">CI SIAMO<span style="color:#C8102E;">.</span></td></tr>',
    '<tr><td style="font-size:15px;line-height:1.5;color:#555555;padding-top:10px;">Manca un tocco: conferma che questo indirizzo e&#39; tuo, e sei dentro.</td></tr>',
    '<tr><td style="padding-top:26px;"><a href="' + link + '" style="display:block;background:#C8102E;color:#FFFFFF;text-decoration:none;text-align:center;font-size:15px;font-weight:700;letter-spacing:.06em;padding:16px;border-radius:12px;">CONFERMA L&#39;INDIRIZZO</a></td></tr>',
    '<tr><td style="font-size:12px;line-height:1.5;color:#999999;padding-top:22px;">Il link vale un&#39;ora sola. Se non ti sei registrato tu, questa email si butta: senza il tocco non succede niente.</td></tr>',
    '<tr><td style="font-size:12px;color:#BBBBBB;padding-top:22px;border-top:1px solid #EEEEEE;">crasyapp.com</td></tr>',
    '</table></td></tr></table></body></html>',
  ].join('');
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
    const adesso = Date.now();
    const ultima = (await profilo.get()).get('lastVerifyEmailAt')?.toDate?.();

    if (ultima && adesso - ultima.getTime() < SECONDI_FRA_DUE_INVII * 1000) {
      return { mandata: false, motivo: 'appena mandata' };
    }

    // Firebase costruisce il link e ce lo restituisce senza mandare niente.
    // `url` e' dove si torna dopo, e viaggia dentro il link come `continueUrl`.
    const linkDiFirebase = await admin
      .auth()
      .generateEmailVerificationLink(persona.email, {
        url: 'https://crasy.web.app/',
      });

    // Del link di Firebase ci serve una cosa sola: il codice.
    const codice = new URL(linkDiFirebase).searchParams.get('oobCode');

    if (!codice) {
      throw new HttpsError('internal', 'Codice mancante.');
    }

    const nostro =
      PAGINA + '?mode=verifyEmail&oobCode=' + encodeURIComponent(codice);

    const postino = nodemailer.createTransport({
      host: SERVER,
      port: PORTA,
      secure: false,
      auth: { user: CASELLA, pass: SMTP_PASSWORD.value() },
    });

    await postino.sendMail({
      from: '"CRASY" <' + CASELLA + '>',
      to: persona.email,
      subject: 'Conferma il tuo indirizzo — CRASY',
      // **Anche la versione senza grafica.** Qualche programma di posta mostra
      // quella al posto dell'altra, e chi legge da un orologio o con un
      // lettore vocale ha solo questa: senza, riceverebbe un messaggio vuoto.
      text:
        'Conferma il tuo indirizzo per entrare in CRASY:\n\n' +
        nostro +
        '\n\nIl link vale un ora. Se non ti sei registrato tu, ignora questa email.',
      html: corpo(nostro),
    });

    await profilo.set(
      { lastVerifyEmailAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );

    logger.info('conferma mandata', { userId });

    return { mandata: true };
  }
);
