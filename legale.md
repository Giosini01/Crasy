# CRASY e il DPR 430/2001

Documento da portare a un avvocato **prima di incassare il primo euro**, non
dopo. Non e' una consulenza e non pretende di esserlo: e' la descrizione esatta
di come funziona il prodotto oggi, con le domande a cui serve una risposta e
l'indicazione di dove ciascuna cosa e' scritta nel codice, cosi' che chi risponde
possa verificarla invece di fidarsi.

---

## Il problema in una riga

CRASY assegna **denaro vero** a chi realizza il contenuto che riceve **piu' voti
dal pubblico**. In Italia questo rischia di rientrare nei concorsi a premio
(DPR 430/2001), che richiedono regolamento depositato, cauzione e la verifica di
un funzionario pubblico.

L'esclusione che potrebbe riguardarci e' quella dei **concorsi artistici**:
l'art. 6 esclude dalla disciplina i concorsi indetti per la produzione di opere
letterarie, artistiche o scientifiche, dove il premio e' il corrispettivo della
prestazione d'opera oppure il riconoscimento del merito personale o un titolo
d'incoraggiamento.

## La domanda principale

> Possiamo strutturare CRASY come piattaforma di commissione e competizione di
> opere fotografiche e audiovisive, con partecipazione gratuita e premio in
> denaro quale corrispettivo o riconoscimento del merito dell'opera, rientrando
> nell'esclusione prevista dall'art. 6 del DPR 430/2001?

## Le tre domande che vengono dopo, e che contano quanto la prima

**1. Chi e' il committente?**

Oggi le challenge **non le indice CRASY**: le lancia un utente qualunque, con
soldi propri, e CRASY tiene i soldi fino alla fine e trattiene il 10%. Se
l'esclusione dell'art. 6 presuppone un committente che commissiona un'opera, un
privato che offre denaro a chi prende piu' voti dalla folla e' la stessa cosa?

E se la risposta e' no: cambia qualcosa se **CRASY diventa il committente**,
cioe' se le challenge con premio le indice e le paga la piattaforma?

**2. Il voto del pubblico e' una valutazione di merito?**

E' il punto piu' fragile. Oggi vince chi prende piu' fiamme, punto. Se questo non
basta, quale struttura basterebbe:

- criteri dichiarati prima + voto del pubblico che li applica (e' quello che
  facciamo adesso, vedi sotto);
- voto del pubblico **piu'** una valutazione della piattaforma (per esempio
  70/30);
- una giuria che decide, con il voto del pubblico come indicazione e non come
  verdetto.

Ognuna costa qualcosa al prodotto: la seconda e la terza spostano su CRASY la
responsabilita' di scegliere chi incassa. Prima di pagare quel prezzo serve
sapere se serve davvero.

**3. Che regime fiscale ha il premio, e chi trattiene?**

Questa domanda va fatta **anche al commercialista**, e oggi non ha risposta nel
codice: CRASY versa il premio meno la propria percentuale, e **non trattiene
niente a titolo fiscale**.

- se e' un **premio**, si parla di ritenuta alla fonte a titolo d'imposta;
- se e' il **corrispettivo di una prestazione d'opera occasionale**, si parla di
  ritenuta d'acconto, certificazione unica, e chi paga diventa **sostituto
  d'imposta**.

Il paradosso da mettere sul tavolo: la strada dell'art. 6 ci libera dagli
adempimenti del concorso a premi e ci carica di quelli del sostituto d'imposta.
E se il committente resta un privato, quel peso cade su di lui — cosa che non
sta in piedi.

---

## Come funziona CRASY, per chi deve dare la risposta

Tutto quello che segue e' verificabile nel codice: accanto a ogni punto c'e'
dove sta scritto.

### Cosa chiede a chi partecipa

- **Si realizza sul momento.** La galleria non si apre: l'app apre la fotocamera
  e basta. L'opera nasce **per quella commissione**, non viene pescata da un
  archivio (`participate_page.dart`, `MediaKind`).
- **Una sola opera a testa, e non si sostituisce.** Il nome del documento della
  partecipazione *e'* l'identificativo di chi l'ha mandata, e le regole del
  database non danno all'autore nessun permesso di modifica: una volta in gara,
  quello scatto non si tocca piu' (`firestore.rules`, sezione `entries`).
- **Partecipare e' gratuito.** Nessun acquisto, nessuna spesa, nessun credito da
  comprare. Non esiste in tutta l'app un modo di pagare per partecipare.
- **Da diciotto anni in su**, con data di nascita richiesta prima di entrare e
  rifiutata dalle regole del database se dichiara un minorenne.

### Come si sceglie chi vince

- **Non c'e' nessuna casualita'.** Non esiste una sola estrazione, un solo
  numero casuale, in nessun punto della catena. Il vincitore e' una funzione
  deterministica dei voti.
- **A parita' di voti vince chi ha mandato prima.** Regola fissa e verificabile,
  non un sorteggio (`functions/index.js`, `closeChallenge`).
- **I criteri di valutazione sono obbligatori e dichiarati prima.** Chi lancia
  una challenge deve scrivere come decidera' chi ha fatto meglio, e quel testo
  compare sulla scheda della gara **sopra** il comando per partecipare
  (`create_challenge_page.dart`, `challenge_detail_page.dart`).
- **Sono immutabili.** Le regole del database lasciano cambiare a una challenge
  gia' nata soltanto il numero dei partecipanti e il vincitore: titolo, consegna
  e criteri restano quelli che c'erano quando la gente ha deciso di partecipare
  (`firestore.rules`, `allow update` su `challenges`).
- **Allo scadere del tempo i voti si fermano davvero**, e non solo
  nell'interfaccia: un voto fuori tempo viene rifiutato dal database
  (`firestore.rules`, `allow update` su `entries`).
- **Chi lancia la challenge non puo' parteciparvi.**

### Cosa succede ai soldi

- Il premio si paga **prima** che la challenge sia visibile, e resta fermo su
  CRASY fino alla fine. L'istituto di pagamento e' Stripe (Connect), non noi.
- Su 500 euro di premio: 507,87 pagati da chi lancia, 450 al vincitore, 50 a
  CRASY (10%), 7,87 a Stripe. Le commissioni le paga chi lancia **in aggiunta**,
  perche' il numero scritto in home sia quello vero (`prize_ledger.dart`).
- Se non partecipa nessuno, il premio **torna indietro intero**.
- Il saldo di un utente non e' scrivibile da nessun telefono: lo muove solo il
  server.
- **Oggi tutto questo e' scritto ma spento**: senza il piano a consumo di
  Firebase e senza un account Stripe, il premio e' un patto diretto fra chi lo
  mette e chi partecipa, e la schermata di creazione lo dice apertamente.

### Cosa riceve chi paga

Da adesso, chi manda un'opera legge prima di mandarla che **l'opera resta sua**,
e che CRASY puo' mostrarla dentro l'app e usarla per raccontare com'e' finita
quella challenge. Niente di piu': nessuna pubblicita', nessuna vendita, nessun
uso fuori da qui.

> **Le parole esatte di questa riga vanno riscritte da chi risponde a queste
> domande.** Sono state messe perche' non averle affatto era peggio, ma sono
> parole nostre, non di un legale. Stanno in `participate_page.dart`.

E qui c'e' una domanda in piu': se il premio e' il **corrispettivo di una
prestazione d'opera**, e' coerente che chi paga i 500 euro non riceva nessun
diritto sull'opera che ha commissionato?

---

## La distinzione che terrei ferma da subito

**CRASY Challenge** — gare indipendenti, il premio lo mette una persona o la
piattaforma, nessun prodotto da promuovere. E' quello di cui parla questo
documento.

**CRASY Brand Challenge** — gare commissionate da un'azienda per promuovere un
prodotto. Qui c'e' marchio, prodotto, finalita' promozionale e premio: e' molto
piu' vicino alla manifestazione a premio come la descrive il MIMIT, e va
verificata **separatamente**. Oggi non esiste nel prodotto, e prima di farla
esistere serve quella seconda risposta.

---

## Cosa non abbiamo fatto, e perche'

Non abbiamo riscritto i testi dell'app per farli somigliare a una commissione
d'opera. Se il meccanismo reale resta "carica una foto, raccogli fiamme, chi ne
ha di piu' prende i soldi", chiamarlo corrispettivo non cambia la natura
dell'operazione — e un legale se ne accorge in trenta secondi, che e' esattamente
il motivo per cui gli si chiede.

Quello che abbiamo fatto e' rendere vere, nel prodotto, le cose che l'esclusione
richiede: opera realizzata su commissione, criteri dichiarati prima e non
modificabili dopo, partecipazione gratuita, nessuna casualita', diritti
dell'autore scritti. Se poi tanto basti, lo dice qualcun altro.
