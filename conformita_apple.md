# CRASY e la revisione di Apple

Linee guida contestate il 4 novembre 2026 sulla versione 1.0 (382): **5.1.2(i)** e **1.2**.

Questo documento dice cosa fa l'app, dove sta scritto nel codice e cosa va compilato o
fatto a mano. Se cambia un SDK o una regola, va aggiornato qui.

---

## 1. Tracking: CRASY non traccia, e ATT non serve

Apple chiama tracking due cose sole
([definizione](https://developer.apple.com/app-store/app-privacy-details/)): collegare i
dati raccolti dall'app a dati di terze parti per fare o misurare pubblicita', oppure
condividerli con un data broker. I dati dati a un data broker **solo** per frode o
sicurezza non contano.

CRASY non fa nessuna delle due: non ha pubblicita' e non manda dati a data broker. Per
questo **non usa App Tracking Transparency**, e non deve mostrare quel popup: chiedere il
permesso per una cosa che non si fa sarebbe a sua volta una dichiarazione falsa.

**Da dove veniva il rifiuto.** La schermata dei consensi aveva la voce "Contenuti su
misura": *"Analizzare come usi CRASY per mostrarti missioni e pubblicita' piu' vicine ai
tuoi gusti"*. Nessuna riga di codice usava quella scelta, e l'app non ha pubblicita'. La
voce e' stata tolta, dall'app e dall'informativa.

### Come e' stato verificato

| Cosa | Esito | Dove |
|---|---|---|
| Pacchetti Flutter | Nessun Analytics, Crashlytics, pubblicita' o attribuzione | `pubspec.lock` |
| Configurazione Firebase iOS | `IS_ANALYTICS_ENABLED` e `IS_ADS_ENABLED` a `false` | `ios/Runner/GoogleService-Info.plist` |
| Configurazione Firebase generale | Nessun `measurementId` | `lib/firebase_options.dart` |
| Sorgenti iOS dei plugin | Nessun `ASIdentifierManager`, `advertisingIdentifier`, `ATTrackingManager`, `AdSupport` | ricerca sui pacchetti scaricati |
| Dipendenze iOS di Firebase | Solo `Core`, `Auth`, `Firestore`, `Functions`, `Messaging`, `Storage` | podspec dei plugin |
| Manifesto della privacy | `NSPrivacyTracking` a `false`, nessun dominio di tracciamento | `ios/Runner/PrivacyInfo.xcprivacy` |
| Info.plist | Nessun `NSUserTrackingUsageDescription` | `ios/Runner/Info.plist` |
| Android | Permesso `AD_ID` tolto esplicitamente | `android/app/src/main/AndroidManifest.xml` |
| Sito | Nessun `gtag`, pixel o simili | `web/` |

**Il controllo non si fa una volta sola.** `test/core/legal/nessun_tracciamento_test.dart`
fallisce se qualcuno aggiunge uno di questi pacchetti o rimette una promessa di
profilazione nei testi.

**Limite di questa verifica:** i controlli qui sopra guardano sorgenti e configurazione.
Il binario iOS vero, con tutte le librerie compilate dentro, si puo' guardare solo su un
Mac: lo fa il passo "Nessun tracciamento nel binario" di `ios-testflight.yml`, che scrive
il risultato nel riepilogo della build. **Va letto prima di mandare la build in revisione.**

### Chi raccoglie cosa

| Servizio | Cosa riceve | Perche' | E' tracking? |
|---|---|---|---|
| Firebase Authentication | email, telefono, password cifrata | account | No |
| Cloud Firestore e Storage | profilo, foto, video, testi, attivita' | far funzionare l'app | No |
| Firebase Cloud Messaging | recapito del dispositivo | notifiche | No |
| Google Cloud Vision e Video Intelligence | foto e video caricati (dal server) | filtrare i contenuti vietati | No |
| OpenAI | solo il testo delle missioni, dal server, senza identificativi | valutare le missioni | No |
| Stripe | dati di pagamento, dati del dispositivo | pagamenti e antifrode | No: [Stripe dichiara](https://support.stripe.com/questions/stripe-ios-sdk-privacy-details) di non usarli per il tracking e di [non raccogliere l'ID pubblicitario](https://support.stripe.com/questions/3d-secure-2-device-information) |
| Resend / IONOS | indirizzo email | email di servizio | No |
| Raccolta `crashes` | riga di errore, sul nostro database | correggere i guasti | No |

### Se un giorno arriva un SDK di pubblicita'

Prima di aggiungerlo: integrare AppTrackingTransparency, mostrare il popup prima di far
partire l'SDK, aggiungere `NSUserTrackingUsageDescription`, aggiornare manifesto e
risposte su App Store Connect. Il test qui sopra ricordera' di farlo.

### Da compilare su App Store Connect (App Privacy)

**"Do you or your third-party partners use data for tracking?": No.** Se le risposte
attuali dichiarano un tracking, **e' probabilmente il secondo motivo del rifiuto**, e
vanno corrette. Da qui non si possono vedere: vanno controllate a mano.

Per tutti i dati: **collegati all'identita': si' / usati per il tracking: no**.

| Categoria Apple | Dato | Scopo |
|---|---|---|
| Contact Info → Email Address | email | App Functionality |
| Contact Info → Phone Number | telefono verificato | App Functionality |
| Contact Info → Name | nome di chi riceve un premio | App Functionality |
| Financial Info → Payment Info | IBAN | App Functionality |
| Financial Info → Other Financial Info | premi, saldo | App Functionality |
| Location → Coarse Location | zona approssimata | App Functionality |
| User Content → Photos or Videos | foto e video | App Functionality |
| User Content → Audio Data | audio dei video | App Functionality |
| User Content → Other User Content | commenti, didascalie, missioni, descrizione | App Functionality |
| Identifiers → User ID | account, nome utente | App Functionality |
| Identifiers → Device ID | recapito delle notifiche, dato del dispositivo di Stripe | App Functionality |
| Purchases → Purchase History | missioni pagate | App Functionality |
| Usage Data → Product Interaction | fiamme, partecipazioni | App Functionality, Analytics (Stripe dichiara di usarlo anche per l'analisi) |
| Diagnostics → Crash Data | errori | App Functionality |
| Other Data → Other Data Types | data di nascita, codice fiscale | App Functionality |

**Contacts: non si dichiara.** I numeri della rubrica arrivano al server solo per il tempo
della ricerca e non vengono conservati (`functions/rubrica.js`), e Apple chiama "collect"
solo cio' che si conserva piu' a lungo. Se si preferisce la massima prudenza, dichiararlo
non costa niente.

**Comunicazioni commerciali.** Il consenso `marketing` oggi viene solo registrato: nessuna
funzione manda promozioni in base a quello. Il giorno in cui partiranno, per l'email va
aggiunto lo scopo "Developer's Advertising or Marketing".

Queste risposte sono una proposta basata sul codice: **chi firma su App Store Connect
risponde di cio' che dichiara**, e un avvocato deve ancora rivedere i testi legali.

---

## 2. Contenuti degli utenti: cosa chiede Apple, dove sta

| Requisito | Dove | Come si prova |
|---|---|---|
| Termini accettati prima di registrarsi o entrare | `ConsentPage`, `sessionLandingRouteProvider`, `pendingConsentProvider` | installare, aprire: si vedono i Termini e non si passa senza le 4 spunte |
| Tolleranza zero scritta nei Termini | `lib/core/legal/legal_documents.dart`, versione 1.6 | "Leggi: Termini e Condizioni" |
| Accettazione registrata sul server | `users/{uid}/consents`, riga `kind: legale` con versione e ora del server | Firestore |
| Filtro su foto e video | SafeSearch e Video Intelligence, `moderateEntryPhoto` | `functions/index.js` |
| Filtro sulle foto profilo | SafeSearch, `controllaIlProfilo` | `functions/moderazione.js` |
| Filtro sui testi | `ContentPolicy` nell'app, `parole.js` sul server | commenti, didascalie, nomi, descrizioni, missioni |
| Segnalare | menu `...` su ogni foto, commento, missione e profilo | `report_sheet.dart` |
| Bloccare, con conferma | stesso menu, e dal profilo | `confirmAndBlock` |
| Contenuti spariti dal feed subito | `senzaBloccati`, `isVisibleTo` | home, gare finite, vincitori, notifiche, ricerca, classifiche |
| Interazioni impedite | `bloccoFra` in `firestore.rules`, `togliILegami` | commenti, fiamme, amicizia, sfide, notifiche |
| Avviso allo sviluppatore sul blocco | `bloccoArrivato`: email a info@crasyapp.com, notifica, sezione Blocchi | pannello |
| Risposta entro 24 ore | scadenza in ogni segnalazione, `sollecitaLeSegnalazioni` | pannello, email |
| Rimozione, sospensione, espulsione | `adminResolveReport`, `sospendi`, `eliminaAccount` | pannello |
| Storico delle azioni | `registroAdmin`, sezione Registro | pannello |
| Contatti | `info@crasyapp.com` in Privacy e consensi, `crasyapp.com/supporto` | app, sito |

### Le regole del blocco

- Chi blocca non vede piu' foto, video, missioni, commenti, vittorie e notifiche di chi ha bloccato.
- Fra i due, in **tutti e due i sensi**, non sono possibili commenti, fiamme, richieste di
  amicizia, sfide, notifiche, ne' partecipare alla gara dell'altro.
- Amicizia e "seguiti" si tolgono da soli.
- Il bloccato **non viene avvisato**, e continua a poter vedere i contenuti pubblici di chi
  l'ha bloccato: per non dirgli niente, l'elenco dei blocchi non lo legge nessuno.
- Le missioni **anonime** non si possono filtrare: da fuori non si sa di chi sono.
- Il blocco arriva al team ma **non e' una segnalazione**: nessun contenuto viene toccato.

### Le protezioni contro gli abusi

- Una segnalazione per persona e per contenuto (nome del documento e regole).
- Oltre 20 al giorno da una stessa persona: restano, ma in fondo alla coda e senza avvisi.
- Il team vede quante segnalazioni di una persona sono state respinte.
- Una persona bloccata non puo' sapere da chi: `blocked` e `reports` non si leggono.
- Chi ha pubblicato lo decide il contenuto vero, non il nome scritto da chi segnala.

### Rischi residui, noti

- **Video:** Video Intelligence riconosce i contenuti espliciti, non la violenza. Per i
  video violenti restano segnalazioni e pannello.
- **Filtro sui testi:** e' un elenco di parole: ferma il caso esplicito, non capisce il
  contesto. Si corregge dal pannello (Regole), senza pubblicare codice.
- **Chi ha segnalato una foto** e' scritto in `reporters` sulla partecipazione, che
  chiunque abbia l'app puo' leggere dal database. Non si vede in nessuna schermata, ma
  chi legge il database direttamente puo' saperlo. Era gia' cosi'; va spostato in un
  documento privato.
- **Le 24 ore dipendono da una persona.** Il sistema avvisa e richiama, ma qualcuno deve
  rispondere anche nei fine settimana.
- **Una persona si segnala una volta sola** da chi segnala, perche' il nome del documento e'
  fisso. Dopo, si possono segnalare i suoi contenuti, o bloccarla.

---

## 3. Da fare a mano

1. **Pubblicare**: un push su `main` e' un rilascio intero. Parte il server (regole, indici,
   funzioni, account di revisione), il sito, Android e la build per TestFlight. Gli indici
   nuovi si costruiscono in qualche minuto: nel frattempo il pannello legge alla vecchia
   maniera, e funziona lo stesso.
2. **Nominare gli amministratori** se non ci sono: `node functions/tool/nomina_admin.js`.
   Chi apre il pannello una volta entra fra chi riceve le notifiche sul telefono.
3. **Provare i cinque percorsi** su TestFlight, su un iPhone vero (sezione 5).
4. **Leggere il riepilogo della build**: il passo "Nessun tracciamento nel binario".
5. **App Store Connect → App Privacy**: controllare e correggere come da sezione 1.
6. **App Store Connect → Età**: nel questionario, controllare che siano dichiarati i contenuti
   generati dagli utenti e i concorsi.
7. **Dare al revisore cosa guardare**: almeno una foto di un'altra persona in una gara aperta
   visibile all'account di revisione, o non avra' niente da segnalare o da bloccare.
8. **Note per il revisore**: incollare il testo della sezione 4, scegliere la build nuova e
   rimandare in revisione, rispondendo anche al messaggio di Apple nel Resolution Center.
9. **Dopo l'approvazione**: alzare `minBuild` in `config/app`, per far aggiornare chi ha
   una versione vecchia: le vecchie non chiedono i Termini prima di entrare.
10. **Far rivedere i testi a un avvocato**: la versione 1.6 contiene impegni nuovi (24 ore,
    visibilita' del segnalante per il team).

---

## 4. Testo per le note al revisore (App Review Information)

```
Account: appreview@crasy.it / (password in App Store Connect)

1) Guideline 5.1.2(i): CRASY does not track users as defined by Apple. It has no ads, no
analytics or advertising SDKs, does not access the IDFA and shares no data with data
brokers, so it does not use the App Tracking Transparency framework. The previous build
showed an optional consent mentioning personalised ads: it was inaccurate and has been
removed. Our App Privacy answers state that no data is used for tracking.

2) Guideline 1.2:
- Terms: on first launch, before login or registration, the user must accept the Terms of
  Use, which state there is no tolerance for objectionable content or abusive users.
- Filtering: photos, videos and profile pictures are checked automatically (Google Cloud
  Vision SafeSearch and Video Intelligence); text is filtered by a word list and missions
  also by AI, before being published or right after.
- Reporting: open the "..." menu on any photo, comment, mission or profile and choose
  "Segnala" (Report), then a reason.
- Blocking: open the "..." menu on a user's profile or content and choose "Blocca" (Block).
  Their content disappears from the feed immediately and the developer is notified.
- Moderation: reports reach our team by email and in an admin panel, with a 24-hour
  deadline. We remove the content and suspend or remove the responsible account.

Contact: info@crasyapp.com
```

---

## 5. I cinque percorsi da provare

**Test 1, Termini.** Installare, aprire: compaiono i Termini e non c'e' modo di arrivare
all'accesso senza le quattro spunte. "Leggi: Termini e Condizioni" apre il testo con la
tolleranza zero. Accettare, registrarsi. In Firestore, `users/{uid}/consents` ha una riga
`kind: legale`, `version: 1.6`, `origine: prima-dell-accesso`, con l'ora del server. Uscire
e rientrare: i Termini si richiedono.

**Test 2, Segnalazione.** Con un account, su una foto di un altro: menu `...`, "Segnala", un
motivo, una nota, "Invia la segnalazione". La foto sparisce per chi ha segnalato. Nel
pannello (Segnalazioni) c'e', con autore, segnalante, motivo e scadenza; arrivano email e
notifica a chi modera. Rifarla da un altro punto: "L'avevi gia' segnalata".

**Test 3, Blocco.** Aprire il profilo di un altro: menu `...`, "Blocca", confermare. Foto e
missioni spariscono subito dal feed; il profilo dice "Hai bloccato". Chiudere e riaprire
l'app: resta. Nel pannello (Blocchi) c'e' l'evento; arriva l'email. Dall'altro account:
commentare, dare una fiamma o seguire non riesce.

**Test 4, Moderazione.** Nel pannello (`crasyapp.com/admin`), con un account amministratore:
aprire la segnalazione, "Togli la foto", scegliere "Sospendi 7 giorni". La foto esce dalla
gara, l'account non entra piu' e riceve l'email. In Registro c'e' la riga con chi e cosa.

**Test 5, Privacy.** Nel riepilogo della build: nessuna traccia di tracciamento. Sul
telefono, in Impostazioni → Privacy e sicurezza → Tracciamento, CRASY non compare mai.
