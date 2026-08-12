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

Le quattro schede in fondo sono **Challenge, Feed, Vincitori, Profilo**. Creare
una challenge sta nell'intestazione della home: e' una cosa che si fa una volta
ogni tanto, non una delle quattro sezioni.

### Le schermate

| Schermata | Cosa fa |
| --- | --- |
| Challenge (home) | Le challenge aperte: premio, titolo, consegna, tempo, chi l'ha lanciata, la foto in testa, comando |
| Dettaglio | Premio, consegna, regole, countdown, partecipazioni gia' inviate |
| Partecipa | Scatta sul momento, guarda l'anteprima, mandi in gara |
| Feed | Le partecipazioni piu' recenti di tutte le challenge, con la fiamma |
| Vincitori | Le challenge concluse e chi le ha vinte |
| Profilo | Partecipazioni, vittorie, premi, e la griglia delle proprie foto |
| Crea | Lancia una challenge: premio, titolo, consegna, dove, per quanto |

---

## Il design

Una sola regola, e tutto il resto ne discende: **bianco, nero, grigi, e il rosso
del fuoco**.

- `#FC3000` e' il rosso di CRASY, e non e' stato scelto a tavolino: e'
  **campionato dalle fiamme del logotipo**, la tinta piu' frequente dei quasi
  centomila pixel di fiamma di `assets/brand/crasy-wordmark.png`. Marchio e
  interfaccia usano letteralmente lo stesso colore.
- Compare in tre posti soltanto: **il premio, la fiamma del voto, cio' che e'
  attivo**. Se compare altrove ha gia' smesso di significare qualcosa.
- `#E02200` e' lo stesso fuoco piu' in fondo alla fiamma, e serve a un solo
  scopo: fare da riempimento sotto il testo bianco del bottone principale. Il
  rosso acceso su bianco sta a 3,8:1, abbastanza per un premio scritto a 64
  punti ma non per un'etichetta a 14; qui si sale a 4,8:1. Non e' un secondo
  colore, e' la stessa tinta a una profondita' diversa.
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

**Senza Firebase configurato l'app funziona lo stesso.** Gira su un set di
challenge di esempio che vivono in memoria: si puo' navigare tutto, partecipare
e votare, e alla chiusura sparisce. Serve a poter aprire il progetto appena
clonato e vedere cos'e', e a far girare i test senza rete.

Le challenge di esempio hanno un identificativo che comincia per `demo-` e
**non hanno una foto**: le si vede come premio, titolo e comando, senza immagine.
Le foto vere arrivano da Storage, che senza Firebase non c'e'.

Un limite della piattaforma da conoscere: su web `image_picker` non puo' imporre
la fotocamera, e il browser mostra comunque il selettore di file. La regola "si
scatta sul momento" vale sul telefono, dove l'app vive.

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

Challenge ed entries si leggono **senza aver fatto l'accesso**: chi apre CRASY
per la prima volta deve vedere subito cosa c'e' in palio. Registrarsi serve per
partecipare, votare e avere un profilo.

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
- **Moderazione dei contenuti.** Non c'e' nessun controllo su cosa viene
  caricato.
- **Le challenge geolocalizzate.** L'ambito e' un'etichetta scelta da chi crea la
  challenge. Il servizio di posizione (`lib/core/services/location/`) e' scritto
  e funziona, ma nessuna schermata lo usa ancora.
- **Profili altrui.** Si vede il nome sotto le foto, non c'e' una pagina da
  aprire.

---

CRASY e' minimal fuori. Dentro puo' succedere qualunque cosa.
