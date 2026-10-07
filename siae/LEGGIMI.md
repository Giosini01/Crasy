# Deposito SIAE — CRASY

Cosa c'è in questa cartella, cosa devi masterizzare, e cosa devi aggiungere tu.

---

## 1. Il disco

Masterizza su un **CD-R o DVD-R**, non riscrivibile. Niente CD-RW: la SIAE lo
rifiuta, perché un supporto riscrivibile non prova niente sulla data.

Metti sul disco **questi tre file**, così come sono:

| File | Cos'è | Peso |
|---|---|---|
| `crasy-codice-sorgente.zip` | Tutto il codice sorgente, 595 file | 7,8 MB |
| `crasy-1.0.2-build4.apk` | L'applicativo compilato per Android | 74 MB |
| `contenuto-del-disco.md` | L'indice di cosa c'è dentro | 4 KB |

La richiesta ammette «il codice sorgente **o** l'applicativo, oppure entrambi».
Ci mettiamo **entrambi**: il sorgente è quello che viene davvero tutelato, e
l'applicativo dimostra che quel codice è un programma funzionante e non un
insieme di file.

**Il sorgente è pulito.** L'ho generato dal codice registrato in Git, quindi
contiene solo i file del progetto: niente cartelle di compilazione, niente
librerie scaricate. E soprattutto **nessuna chiave**: le chiavi di firma
(`.p8`), il certificato e le credenziali non sono nel pacchetto. Non è un
dettaglio — un disco depositato in SIAE è un documento che esce di mano, e le
chiavi di un'app che muove denaro non devono uscire mai.

Versione depositata: **1.0.2 (build 4)**
Revisione del codice: `1609bd43b9e685661b80938b425d45e06e69137f`

## 2. Cosa scrivere sul disco

Sul **frontespizio anteriore**, cioè la faccia stampata del disco, con un
**pennarello indelebile**:

```
CRASY
```

e sotto, **la tua firma**.

Il testo esatto e come disporlo è in `frontespizio-cd.md`. Scrivi piano e lascia
asciugare prima di infilarlo nella custodia: un pennarello fresco che si
imbratta sul cellophane rende illeggibile la firma, ed è la firma la cosa che
serve.

## 3. Cosa devi aggiungere tu

Queste tre cose non posso prepararle io. Servono tutte, e la pratica si ferma se
ne manca una.

**Documento d'identità in corso di validità** — del richiedente (tu) **e di
ciascun autore** del software. Se gli autori siete in più di uno, serve il
documento di tutti. Controlla la scadenza: «in corso di validità» viene preso
alla lettera.

**Copia del versamento** dell'importo per il servizio. Conserva la ricevuta
originale e porta la copia.

**Il modulo di domanda** compilato, che si scarica dal sito SIAE nella sezione
del Registro pubblico speciale per i programmi per elaboratore.

## 4. Una cosa da decidere prima di andare

Nel modulo devi dichiarare **chi è l'autore** e **chi è il titolare dei diritti**,
e non sono la stessa domanda.

Se CRASY è stata scritta da te ma i diritti devono stare in capo a **SY S.R.L.**,
va dichiarato lì — e serve l'atto che trasferisce i diritti alla società, o un
contratto che li attribuisca a lei fin dall'origine. Depositare a nome personale
e «sistemare dopo» è lo stesso problema dell'account Play: il deposito fotografa
una situazione a una data, e cambiarla dopo vuol dire un secondo atto.

Visto che la partita IVA della S.R.L. arriva a giorni, **vale la pena aspettarla
e depositare già a nome della società**, invece di depositare oggi a nome tuo e
dover poi dimostrare il passaggio.

## 5. Rifare il pacchetto

Se il codice cambia e vuoi depositare una versione più recente:

```
git archive --format=zip --prefix=crasy-codice-sorgente/ \
  -o siae/crasy-codice-sorgente.zip HEAD
```

Poi ricopia l'APK da `build/app/outputs/flutter-apk/app-release.apk` e aggiorna
il numero di versione in `contenuto-del-disco.md` e nel frontespizio.
