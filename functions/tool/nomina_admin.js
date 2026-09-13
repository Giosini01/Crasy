/**
 * Nomina (o revoca) un amministratore di CRASY.
 *
 *     node functions/tool/nomina_admin.js tua@email.it
 *     node functions/tool/nomina_admin.js tua@email.it --chiave C:\percorso\chiave.json
 *     node functions/tool/nomina_admin.js tua@email.it --togli
 *
 * Sta dentro `functions/` e non in `tool/` per una ragione noiosa e decisiva:
 * `firebase-admin` e' installato li'. Da `tool/` il `require` non lo
 * troverebbe, e lo script fallirebbe alla prima riga con un errore che non
 * c'entra niente con quello che sta facendo.
 *
 * **Perche' e' uno script sul computer e non una schermata dell'app.**
 *
 * Il permesso di amministratore e' un `custom claim` dentro il gettone di
 * accesso, e i custom claim li puo' scrivere **solo** l'SDK di amministrazione
 * — cioe' qualcosa che gira con le credenziali del progetto, non un telefono.
 * E' esattamente quello che li rende affidabili: il gettone lo firma Firebase,
 * quindi il claim non si puo' falsificare, non si puo' mettere da soli, e non
 * dipende da un documento che qualcuno possa scrivere sul database.
 *
 * Una schermata dentro l'app che nomini amministratori sarebbe una porta in
 * piu' su un permesso che ne vuole zero: la prima domanda diventerebbe "chi
 * puo' aprire quella schermata", e la risposta sarebbe un altro permesso da
 * proteggere. Qui la risposta e' gia' data — chi ha le credenziali del
 * progetto — e non c'e' nient'altro da difendere.
 *
 * ## Come si autentica
 *
 * Tre strade, e la prima che trova vince: `--chiave <file.json>`, la variabile
 * `GOOGLE_APPLICATION_CREDENTIALS`, oppure le credenziali predefinite
 * dell'ambiente (`gcloud auth application-default login`).
 *
 * `--chiave` esiste perche' senza `gcloud` installato le altre due sono un
 * giro lungo: si scarica il file dalla console e lo si passa qui, una volta.
 *
 * **Nessuna chiave sta nel repository, e nessuna deve starci.** Un file di
 * servizio apre il progetto intero — database, storage, account — e un file
 * cosi' dentro un repository e' un file che prima o poi finisce su un
 * computer che non e' il tuo. Tienilo fuori dalla cartella del progetto, e
 * cancellalo quando hai finito: rifarlo costa due clic.
 *
 * ## Dopo averlo nominato
 *
 * Il claim entra nel gettone al **rinnovo**, non subito: chi e' gia' collegato
 * deve uscire e rientrare, o aspettare l'ora scarsa che il gettone dura. La
 * dashboard lo dice, invece di lasciar credere che il permesso non sia
 * arrivato.
 */

const admin = require('firebase-admin');

const PROGETTO = 'daily-dating-app';

async function main() {
  const argomenti = process.argv.slice(2);
  const togli = argomenti.includes('--togli');
  // Il percorso della chiave e' un argomento senza trattini come l'email: si
  // salta guardando cosa lo precede, o si finirebbe a cercare un account con
  // il nome di un file.
  const indiceChiave = argomenti.indexOf('--chiave');
  const email = argomenti.filter(
    (voce, i) => !voce.startsWith('--') && i !== indiceChiave + 1,
  )[0];

  if (!email) {
    console.error(
      'Uso: node functions/tool/nomina_admin.js <email> [--chiave <file.json>] [--togli]',
    );
    process.exit(1);
  }

  // La chiave passata a mano vince su tutto: chi la scrive nel comando sta
  // dicendo esattamente con quale identita' vuole lavorare, e indovinare
  // diversamente sarebbe il modo piu' facile per scrivere sul progetto
  // sbagliato.
  const indice = argomenti.indexOf('--chiave');
  const chiave = indice >= 0 ? argomenti[indice + 1] : null;

  if (indice >= 0 && !chiave) {
    console.error('Manca il percorso dopo --chiave.');
    process.exit(1);
  }

  if (chiave) {
    admin.initializeApp({
      projectId: PROGETTO,
      credential: admin.credential.cert(require(require('path').resolve(chiave))),
    });
  } else {
    admin.initializeApp({ projectId: PROGETTO });
  }

  const utente = await admin.auth().getUserByEmail(email);

  // **Si riscrivono i claim esistenti, non si sovrascrive tutto alla cieca.**
  // Impostare `{ admin: true }` da solo cancellerebbe qualunque altro claim
  // quella persona abbia — oggi non ne ha nessuno, ma il giorno in cui ne avra'
  // uno questo script glielo toglierebbe in silenzio.
  const claims = { ...(utente.customClaims || {}) };

  if (togli) {
    delete claims.admin;
  } else {
    claims.admin = true;
  }

  await admin.auth().setCustomUserClaims(utente.uid, claims);

  console.log(
    (togli ? 'Tolto' : 'Messo') + ' il permesso di amministratore a ' + email,
  );
  console.log('uid: ' + utente.uid);
  console.log(
    'Il permesso entra nel gettone al prossimo accesso: esci e rientra.',
  );
}

main().catch((errore) => {
  const messaggio = errore.message || String(errore);

  console.error(messaggio);

  // **L'errore delle credenziali non si spiega da solo.** "Could not load the
  // default credentials" non dice a nessuno cosa fare, ed e' il primo muro che
  // incontra chiunque provi a nominare il primo amministratore: senza queste
  // due righe si finisce a cercare in rete una cosa che si risolve con un
  // comando.
  if (messaggio.includes('default credentials')) {
    console.error('');
    console.error('Mancano le credenziali del progetto. Una delle due:');
    console.error('  gcloud auth application-default login');
    console.error('  set GOOGLE_APPLICATION_CREDENTIALS=<chiave-di-servizio.json>');
    console.error('');
    console.error('La chiave di servizio si scarica dalla console Firebase:');
    console.error('  Impostazioni progetto > Account di servizio > Genera nuova chiave privata');
    console.error('Non va messa nel repository.');
  }

  process.exit(1);
});
