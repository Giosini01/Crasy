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

**challenge → partecipazione → contenuto → feed → voto → vincitore**

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
| Challenge (home) | Le challenge aperte, una per schermata: premio, titolo, foto, tempo, comando |
| Dettaglio | Premio, consegna, regole, countdown, partecipazioni gia' inviate |
| Partecipa | Scatta o scegli dalla galleria, guarda l'anteprima, invia |
| Feed | Le partecipazioni piu' recenti di tutte le challenge, con il voto |
| Vincitori | Le challenge concluse e chi le ha vinte |
| Profilo | Partecipazioni, vittorie, premi, e la griglia delle proprie foto |
| Crea | La struttura di una challenge. L'invio non e' ancora aperto — vedi sotto |

---

## Il design

Una sola regola, e tutto il resto ne discende: **bianco, nero, grigi, e un
rosso**.

- `#FF2D1A` e' il rosso di CRASY. Compare in tre posti soltanto: **il premio,
  l'azione principale, cio' che e' attivo**. Se compare altrove ha gia' smesso
  di significare qualcosa.
- Niente card, niente ombre, niente gradienti, niente badge. A separare le cose
  sono lo spazio bianco e, dove serve, un filetto da mezzo pixel.
- La gerarchia la fa la tipografia: dal 64 del premio all'11 dell'occhiello.
- Una challenge occupa quasi tutta l'altezza dello schermo, quindi il bottone
  rosso resta uno solo alla volta.
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
**non hanno una foto**: al loro posto si vede un rettangolo grigio. Le foto vere
arrivano da Storage, che senza Firebase non c'e'.

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
  che prima o poi si dimentica di fare. Rimandare una foto sostituisce la
  propria, non ne aggiunge una seconda.
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

### Creare una challenge a mano

Finche' la creazione non e' aperta, le challenge si inseriscono dalla console.
Un documento in `challenges/`:

```json
{
  "title": "Do something crazy",
  "brief": "Fai la foto piu' pazza che riesci. Senza Photoshop.",
  "rules": ["Una sola foto a testa.", "Vince la piu' votata."],
  "prizeCents": 50000,
  "scope": "global",
  "place": "",
  "coverUrl": null,
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

- **Creare una challenge.** La schermata c'e' e i campi sono quelli veri, ma
  l'invio e' spento. Manca la parte che non e' codice: chi mette i soldi del
  premio, chi risponde se il premio non arriva, chi decide che una consegna e'
  accettabile.
- **Il pagamento dei premi.** Il vincitore viene proclamato; il bonifico no.
- **Moderazione dei contenuti.** Non c'e' nessun controllo su cosa viene
  caricato.
- **Le challenge geolocalizzate.** L'ambito e' un'etichetta scelta da chi crea la
  challenge. Il servizio di posizione (`lib/core/services/location/`) e' scritto
  e funziona, ma nessuna schermata lo usa ancora.
- **Profili altrui.** Si vede il nome sotto le foto, non c'e' una pagina da
  aprire.

---

CRASY e' minimal fuori. Dentro puo' succedere qualunque cosa.
