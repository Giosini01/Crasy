# CRASY

**DO SOMETHING CRAZY.**

Challenge fotografiche con un premio in denaro. Si guarda cosa c'e' in palio, si
partecipa con una foto, si vota quelle degli altri, allo scadere del tempo vince
la piu' votata.

    €500  ·  GLOBAL
    DO SOMETHING CRAZY
    [ foto ]
    4h 32m · 243 partecipanti
    [ PARTECIPA ]

Il giro completo del prodotto e' uno solo, e tutto il resto viene dopo:

**challenge → partecipazione → contenuto → feed → fiamme → vincitore**

Tre regole, e non sono dettagli — sono il prodotto:

- **Si scatta sul momento.** Niente galleria. Una challenge chiede di fare
  qualcosa *adesso*; potendo pescare dal rullino si vincerebbe con la foto piu'
  bella che si ha in archivio, non con la piu' folle che si e' avuto il coraggio
  di fare.
- **Una foto sola a testa, e non si cambia.** Poter sostituire il proprio scatto
  dopo aver visto quante fiamme prende sarebbe cambiare la mano dopo aver
  guardato le carte degli altri.
- **Si vota con una fiamma**, non con un cuore e non con un pollice. Si da' con
  il doppio tocco sulla foto o dal contatore accanto. La foto con piu' fiamme
  allo scadere del tempo si prende i soldi.

---

## Il progetto in due minuti

Flutter, Riverpod, go_router, Firebase. Architettura a feature, con dentro
ognuna i tre soliti strati:

    lib/
      core/                  tema, widget di base, utilita', rotte
      features/
        auth/                accesso con email e password
        onboarding/          nome utente, e basta
        challenges/          il cuore: challenge, partecipazioni, voti, feed
        profile/             profilo social e statistiche
        home/                impalcatura con le quattro schede, splash
      routing/               router e regole di accesso

Le tre schede in fondo sono **Challenge, Vincitori, Profilo**, e ognuna risponde
a una domanda diversa: *cosa c'e' in palio*, *chi ha vinto*, *come stanno andando
le mie*. Creare una challenge sta nell'intestazione della home: e' una cosa che
si fa una volta ogni tanto, non una sezione.

**Non c'e' un feed di tutti.** Le foto degli altri stanno dentro la loro
challenge, che e' il posto in cui hanno un senso — li' si confrontano fra loro e
li' si vota. Le proprie stanno nel profilo, e toccandone una si torna alla gara.

Due regole tengono onesta la competizione:

- **chi lancia una challenge non ci partecipa**: mette lui i soldi del premio, e
  una gara in cui chi paga puo' anche vincere non e' una gara;
- **la propria foto si puo' votare**. Sembra un buco e non lo e': possono farlo
  tutti, quindi e' un voto in piu' per ciascuno e non sposta la classifica.

### Le schermate

| Schermata | Cosa fa |
| --- | --- |
| Challenge (home) | Le challenge aperte: premio, titolo, consegna, tempo, chi l'ha lanciata, la foto in testa, comando |
| Dettaglio | Premio, consegna, regole, countdown, partecipazioni gia' inviate |
| Partecipa | Scatti o registri sul momento, guardi l'anteprima, mandi in gara |
| Amici | Le richieste ricevute e l'elenco di chi hai gia' |
| Vincitori | Le challenge concluse e chi le ha vinte |
| Profilo | Scatti, vittorie, premi, amici, e la griglia delle proprie foto |
| Profilo altrui | Gli stessi quattro numeri, la sua griglia, e il comando dell'amicizia |
| Crea | Lancia una challenge: premio, titolo, consegna, dove, per quanto |
| Accesso | Email e password. Alla registrazione parte il messaggio di conferma |
| Verifica | Il muro: si sta qui finche' l'indirizzo non e' confermato |

### Foto o video

Chi lancia la challenge sceglie **cosa** deve arrivare: una foto o un video di
massimo trenta secondi. E' un vincolo, non un suggerimento — una gara in cui
qualcuno manda una foto e qualcun altro un video non e' una gara, sono due cose
che non si possono mettere in fila e confrontare, e alla fine si pagherebbe un
premio scegliendo fra mele e pere.

In tutti e due i casi vale la regola di sempre: **si registra sul momento**. La
galleria non si apre, ne' per le foto ne' per i video.

### Gli amici

Ogni profilo si puo' aprire, e ci si arriva da dove si e': dal nome sotto una
foto, dalla riga di chi ha lanciato una challenge, dall'elenco degli amici. **Si
incontra la gente guardando cosa combina**, non cercandola per nome — per questo
non c'e' una ricerca.

Un profilo pubblico mostra quattro numeri e la griglia delle sue foto: scatti,
vittorie, premi vinti, amici. Niente eta', niente elenco di cosa ha votato.

L'amicizia si chiede e si accetta. Sul database e' fatta di due documenti, uno
per parte:

```
users/{id}/friends/{amico}           l'amicizia, scritta da tutte e due le parti
users/{id}/friendRequests/{da}       le richieste ricevute
```

Sembra una duplicazione ed e' la scelta che tiene in piedi tutto: "chi sono i
miei amici" diventa la lettura di una cartella sola invece di una ricerca su
tutto il database. Le due righe nascono insieme, in un lotto: un'amicizia
scritta da una parte sola e' lo stato che poi nessuno sa piu' come rimettere a
posto.

Le regole non chiedono "e' casa tua" ma **"esiste la richiesta che lo
giustifica"**: senza un documento che quella persona ha ricevuto, nessuna delle
due righe si puo' scrivere. E' quello a rendere impossibile aggiungersi da soli
fra gli amici di qualcuno.

---

## Chi entra, e cosa si puo' chiedere

Quattro porte in fila, e si passano in quest'ordine: **accesso**, **email
confermata**, **profilo con data di nascita**, poi l'app. Ognuna esiste per un
motivo che ha a che fare con i soldi in palio.

- **Non si guarda niente da fuori.** Senza sessione completa non si vede una
  challenge, una foto, un vincitore. Vale anche nelle regole di Firestore, non
  solo nell'interfaccia.
- **L'email va confermata.** Senza un indirizzo vero non c'e' modo di far avere
  a nessuno il premio che ha vinto, ne' di riconoscere chi torna dopo essere
  stato allontanato.
- **Si entra da diciotto anni.** Qui girano soldi veri e si chiede alla gente di
  uscire e fare qualcosa per vincerli: e' esattamente il tipo di spinta che a un
  ragazzino non va data. Il selettore della data non arriva oltre la soglia, e
  le regole rifiutano un profilo dichiaratamente minorenne.

  Va detto cosa questo **non** e': una data che uno si scrive da solo non e' una
  verifica dell'eta'. Ferma chi e' onesto, non chi mente. Una verifica vera vuole
  un documento, ed e' una decisione da prendere prima di aprire al pubblico.

### Cosa non si puo' chiedere

`lib/core/moderation/content_policy.dart` rifiuta le consegne che chiedono
autolesionismo, violenza, nudita' o cose che possono finire male davvero — e
i test in `test/core/content_policy_test.dart` sono l'elenco delle frasi che
**non devono poter essere pubblicate**.

Il motivo per cui questa e' la parte piu' importante: una challenge non e' un
post, e' **un incarico con un premio in denaro**. "Tagliati le vene" pubblicato
qui non e' un contenuto discutibile, e' una persona che si fa male perche'
gliel'ha chiesto la nostra app, in cambio di soldi nostri.

E' un elenco di parole, quindi ferma il caso esplicito e non chi cerca di
aggirarlo. E' la prima di tre porte: l'app, poi le regole di Firestore che
rifiutano i casi piu' espliciti anche a chi scrivesse saltando l'app, poi un
controllo automatico sul server. **In fondo alla catena serve qualcuno che
guardi**, e va messo in conto prima di aprire al pubblico.

### Le foto

Nudita' e contenuti sessuali non sono ammessi. Il controllo e' scritto e sta in
`functions/index.js`: ogni foto appena caricata passa da SafeSearch di Google
Vision prima che qualcun altro possa vederla, e finche' non e' stata guardata la
vede **solo chi l'ha mandata**, con scritto "in verifica".

> **Adesso e' spento, e va detto invece che nascosto.** Le Cloud Function
> richiedono il piano a consumo su Firebase, che non e' attivo: senza, la
> funzione non gira e una foto in attesa resterebbe in attesa per sempre. Con
> l'interruttore spento le foto nascono gia' ammesse — cioe' **oggi non c'e'
> nessun controllo automatico sulle immagini**.
>
> Per accenderlo servono tre cose: il piano Blaze, la Vision API abilitata, e
> il deploy delle funzioni. Poi si compila con
> `--dart-define=CRASY_PHOTO_MODERATION=true` e nel codice non cambia altro.

---

## Il design

Una sola regola, e tutto il resto ne discende: **bianco, nero, grigi, e il rosso
del fuoco**.

- `#FA0000` e' il rosso di CRASY, e non e' stato scelto a tavolino: e'
  **campionato dalla "sy" del logotipo**, la tinta piu' frequente dei suoi pixel
  rossi. Marchio e interfaccia usano letteralmente lo stesso colore.
- Compare in tre posti soltanto: **il premio, la fiamma del voto, cio' che e'
  attivo**. Se compare altrove ha gia' smesso di significare qualcosa.
- `#E00000` e' lo stesso rosso piu' scuro, e serve a un solo scopo: fare da
  riempimento sotto il testo bianco del bottone principale. Il rosso pieno su
  bianco sta a 4,2:1, abbastanza per un premio scritto a 64 punti ma non per
  un'etichetta a 14; qui si sale a 5,0:1. Non e' un secondo colore, e' la stessa
  tinta a una luminosita' diversa.
- Niente card, niente ombre, niente gradienti, niente badge. A separare le cose
  sono lo spazio bianco e, dove serve, un filetto da mezzo pixel.
- La gerarchia la fa la tipografia: dal 64 del premio all'11 dell'occhiello.
- **Le foto compaiono solo se esistono.** Una challenge senza immagine e' premio,
  titolo, consegna e comando — non un rettangolo grigio, che non e' una foto
  mancante ma una schermata che sembra rotta.
- **Chi crea una challenge non allega nessuna foto**: mette in palio dei soldi e
  detta una consegna. La faccia della gara la mettono i partecipanti — la
  copertina e' sempre la foto con piu' fiamme, quindi una challenge cambia
  aspetto man mano che qualcuno fa di meglio invece di restare ferma
  sull'immagine scelta il primo giorno.
- Tema chiaro e basta, anche su un dispositivo in tema scuro: le foto devono
  cadere sempre sullo stesso fondo.

I token stanno in `lib/core/theme/`. Le schermate leggono da `AppPalette`, mai
dai colori grezzi.

L'app e' in italiano. Restano in inglese il nome e la tagline, che sono marchio.

---

## Farla partire

```bash
flutter pub get
flutter run
```

**L'app nasce vuota.** Non ci sono challenge di esempio, e non e' una
dimenticanza: challenge finte in mezzo a quelle vere confondono e basta. La
prima schermata dice che non c'e' ancora niente, e il **+** in alto la riempie.

**Senza Firebase configurato l'app funziona lo stesso.** Il repository diventa
quello in memoria: si lancia una challenge, si partecipa, si vota, e alla
chiusura sparisce tutto. Serve ad aprire il progetto appena clonato e vederlo
girare, e a far correre i test senza rete ne' credenziali. In quel caso le foto
non salgono da nessuna parte — restano nell'indirizzo dell'immagine, quindi si
vedono ma solo su quel dispositivo.

Due limiti della piattaforma web da conoscere:

- `image_picker` non puo' imporre la fotocamera, e il browser mostra comunque il
  selettore di file. La regola "si scatta sul momento" vale sul telefono, dove
  l'app vive;
- Flutter scarica le immagini con `fetch` e le disegna sulla tela, il che
  richiede le intestazioni CORS che il bucket di Firebase Storage non manda
  finche' non gliele si configura. `MediaFrame` usa
  `WebHtmlElementStrategy.fallback`, che in quel caso ripiega su un vero
  elemento `<img>`. La soluzione pulita resta configurare il CORS del bucket.

### Con Firebase

Appena su Firestore compare una challenge vera, gli esempi spariscono del tutto:
le due sorgenti non si mescolano mai. Se ne occupa
`DemoFallbackChallengeRepository`.

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
cd functions && npm install && firebase deploy --only functions
```

I dati stanno cosi':

    challenges/{challengeId}
    challenges/{challengeId}/entries/{userId}
    users/{userId}
    users/{userId}/votes/{entryId}

Due scelte da conoscere prima di toccare qualcosa:

- **La partecipazione ha per identificativo l'utente.** E' la regola "una foto a
  testa per challenge" scritta nella forma dei dati invece che in un controllo
  che prima o poi si dimentica di fare. Il secondo invio viene rifiutato dentro
  una transazione, e le regole non danno all'autore nessun permesso di
  aggiornamento: una volta in gara, quella foto non si tocca piu'.
- **I voti stanno sotto chi li ha dati**, non sotto la foto votata. Cosi' "cosa
  ho gia' votato" e' una lettura sola, e nessuno puo' sapere chi ha votato cosa.

**Niente si legge senza aver fatto l'accesso**, ne' dall'app ne' chiamando il
database direttamente. Le foto che la gente manda sono di persone vere che si
mettono in gioco: non stanno in una vetrina aperta a chiunque passi.

> **Il progetto Firebase si chiama ancora `daily-dating-app`**, e l'app Android
> ancora `com.example.app_incontri`. Sono rimasti apposta: l'identificativo di un
> progetto Firebase non si puo' rinominare, e cambiare il nome del pacchetto
> Android scollegherebbe `google-services.json` — accesso e database
> smetterebbero di funzionare finche' non si registra la nuova app dalla console.
> Sono nomi che non si vedono da nessuna parte nel prodotto. Per cambiarli
> davvero serve creare un progetto Firebase nuovo e rigenerare
> `firebase_options.dart` con `flutterfire configure`.

### Creare una challenge

Dall'app, con il **+** nell'intestazione della home. Serve un account.

Volendo inserirla a mano dalla console, un documento in `challenges/` fatto
cosi':

```json
{
  "title": "Do something crazy",
  "brief": "Fai la foto piu' pazza che riesci. Senza Photoshop.",
  "rules": ["Una sola foto a testa.", "Vince la piu' votata."],
  "prizeCents": 50000,
  "scope": "global",
  "place": "",
  "createdByUsername": "crasy",
  "createdByUserId": "",
  "startsAt": "<timestamp>",
  "endsAt": "<timestamp>",
  "participantsCount": 0,
  "winnerEntryId": null
}
```

`winnerEntryId` **deve esserci e valere `null`**: e' il campo su cui la funzione
di chiusura trova le challenge ancora da proclamare. Il premio e' in centesimi —
`50000` sono €500 — perche' un premio in denaro tenuto in virgola mobile prima o
poi diventa `499,99999`.

`scope` vale `global`, `country`, `local` o `private`. Con `local`, `place` e' la
citta' che si vede sulla scheda (`NAPOLI`).

### La chiusura delle challenge

`functions/index.js` gira ogni cinque minuti, cerca le challenge scadute senza
vincitore e proclama la foto piu' votata. A parita' di voti vince chi ha mandato
per primo: serve una regola qualunque, ma serve che sia sempre la stessa.

---

## Test

```bash
flutter analyze
flutter test
```

I test coprono le regole del dominio (stato nel tempo di una challenge, formato
del premio, validazione del nome utente), il comportamento del repository di
esempio (una foto a testa, voto che non si conta due volte) e l'avvio dell'app
fino alla prima challenge sullo schermo.

---

## Cosa non c'e' ancora

Detto chiaramente, perche' un README che tace su questo fa perdere tempo:

- **Il pagamento dei premi.** Il vincitore viene proclamato; il bonifico no.
  Chi lancia una challenge paga di tasca propria e CRASY non fa da garante: la
  schermata di creazione lo dice, ma resta un patto sulla fiducia. E' il buco
  piu' grosso che il prodotto ha adesso.
- **Moderazione delle challenge.** Chiunque abbia un account puo' lanciarne una
  e promettere qualunque cifra. Le regole controllano che il documento sia ben
  formato, non che dietro ci siano davvero i soldi — nessuna regola di database
  puo' controllare quello.
- **Il controllo automatico sulle immagini.** E' scritto ma spento: servono il
  piano Blaze e il deploy delle funzioni (sopra c'e' come). I testi invece si
  controllano gia', sia nell'app che nelle regole.
- **Il video non viene controllato affatto.** SafeSearch guarda le immagini; un
  video passa senza che nessuno lo apra.
- **Le challenge geolocalizzate.** L'ambito e' un'etichetta scelta da chi crea la
  challenge. Il servizio di posizione (`lib/core/services/location/`) e' scritto
  e funziona, ma nessuna schermata lo usa ancora.

---

CRASY e' minimal fuori. Dentro puo' succedere qualunque cosa.
