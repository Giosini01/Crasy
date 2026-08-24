# CRASY

**DO SOMETHING CRAZY.**

Challenge fotografiche con un premio in denaro. Si guarda cosa c'e' in palio, si
partecipa con una foto, si vota quelle degli altri, e allo scadere del tempo chi
ha messo il premio sceglie chi se lo prende.

    €500  ·  GLOBAL
    DO SOMETHING CRAZY
    [ foto ]
    4h 32m · 243 partecipanti
    [ PARTECIPA ]

Il giro completo del prodotto e' uno solo, e tutto il resto viene dopo:

**challenge → partecipazione → contenuto → feed → fiamme → scelta → vincitore**

Tre regole, e non sono dettagli — sono il prodotto:

- **Si scatta sul momento.** Niente galleria. Una challenge chiede di fare
  qualcosa *adesso*; potendo pescare dal rullino si vincerebbe con la foto piu'
  bella che si ha in archivio, non con la piu' folle che si e' avuto il coraggio
  di fare.
- **Una foto sola a testa, e non si cambia.** Poter sostituire il proprio scatto
  dopo aver visto quante fiamme prende sarebbe cambiare la mano dopo aver
  guardato le carte degli altri.
- **Si vota con una fiamma**, non con un cuore e non con un pollice. Si da' con
  il doppio tocco sulla foto o dal contatore accanto.
- **A decidere chi vince e' chi ha messo i soldi.** Allo scadere del tempo il
  premio lo assegna chi ha lanciato la challenge, non il conteggio: sta
  commissionando una cosa precisa, e la piu' votata non e' sempre quella che
  aveva chiesto. Ha **ventiquattro ore**; passate quelle, il premio va da solo a
  chi ha preso piu' fiamme.

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

Le schede in fondo sono cinque — **Challenge, Amici, Cerca, Vincitori,
Profilo** — e ognuna risponde a una domanda diversa: *cosa c'e' in palio*, *chi
conosco*, *dov'e' quella cosa che cerco*, *chi ha vinto*, *come stanno andando le
mie*. Creare una challenge sta nell'intestazione della home: e' una cosa che si
fa una volta ogni tanto, non una sezione — ma il suo **+ e' rosso**, che e'
l'unica icona dell'app a esserlo.

**Si cambia scheda anche col dito.** Le schede stanno una accanto all'altra e si
scorrono, come su qualunque app con una barra in fondo: con il telefono in una
mano sola il pollice arriva al bordo dello schermo molto meglio che a un'icona in
fondo a sinistra. L'indirizzo segue il dito, quindi il tasto indietro del browser
e i link condivisi continuano a raccontare la stessa storia di quello che si
vede.

> Perche' funzioni, le cinque schede condividono **una sola chiave di pagina**.
> Con una chiave per rotta — cioe' quello che viene naturale — ogni cambio di
> scheda butta via l'impalcatura e ne costruisce un'altra: non resta in piedi
> niente su cui scorrere, e ogni scheda ricomincia da capo anche solo per averla
> sfiorata.

**Non c'e' un feed di tutti.** Le foto degli altri stanno dentro la loro
challenge, che e' il posto in cui hanno un senso — li' si confrontano fra loro e
li' si vota. Le proprie stanno nel profilo, e toccandone una si torna alla gara.

Due regole tengono onesta la competizione:

- **chi lancia una challenge non ci partecipa**: mette lui i soldi del premio, e
  una gara in cui chi paga puo' anche vincere non e' una gara;
- **la propria foto si puo' votare**. Sembra un buco e non lo e': possono farlo
  tutti, quindi e' un voto in piu' per ciascuno e non sposta la classifica.

### Il conto delle fiamme

Un voto si chiama `{challenge}__{partecipazione}`, e quel doppio trattino ha una
storia. Una partecipazione si chiama come chi l'ha mandata — una foto a testa
per challenge, e il nome del documento **e'** la regola scritta nella forma dei
dati. Ma la stessa persona partecipa a piu' gare, e in tutte la sua foto si
chiama allo stesso modo.

I voti stavano sotto quel nome soltanto. Conseguenza: bastava votare la foto di
qualcuno in una gara perche' la sua foto in **un'altra** risultasse gia' votata,
fiamma rossa senza averla toccata — e toccandola li', il conto di quella seconda
gara scendeva di uno senza essere mai salito. Con dei soldi in palio non e' un
difetto grafico: e' un voto spostato da una foto a un'altra.

**Il numero a schermo non si corregge: si congela.** Dal tocco alla conferma,
sotto la foto c'e' un numero deciso dal gesto — non il contatore del server piu'
un `+1`. La differenza sembra una sfumatura ed e' tutta la faccenda: il contatore
della foto e l'elenco di cosa ho votato sono scritti nella stessa transazione ma
**arrivano come due notizie separate**, e nell'istante fra l'una e l'altra il
contatore aveva gia' dentro il voto che la correzione stava per aggiungere di
nuovo. Sotto la foto compariva **+2**, e togliendo la fiamma `-2`. Chi lo vedeva
toccava di nuovo per rimettere le cose a posto, e quel tocco era un voto vero
nella direzione sbagliata: da li' "posso togliere due mi piace e aggiungerne uno".

Il prezzo, dichiarato: per quel paio di secondi le fiamme date **da altri** su
quella foto non si vedono arrivare. Nessuno guarda il contatore di una foto
aspettando che si muova da solo, e in cambio il proprio gesto e' esatto sempre.

### Chi decide chi vince

**Le fiamme non sono il verdetto.** Allo scadere del tempo il premio lo assegna
**chi ha lanciato la challenge**: ha messo dei soldi per far fare una cosa
precisa, e la foto piu' votata non e' sempre quella che aveva chiesto. Le fiamme
restano cio' che sono sempre state — il polso di chi guarda, e la faccia della
gara in home — ma la scelta e' sua.

Ha **ventiquattro ore** dalla fine. Il numero non e' a caso: e' la durata tipica
di una gara, quindi chi la lancia sa gia' quanto dura il suo impegno.

**Se non sceglie, il premio va da solo a chi ha piu' fiamme.** Una gara che
resta senza vincitore perche' chi l'ha lanciata si e' distratto e' la cosa che
fa perdere fiducia a tutti gli altri — a quel punto decide il conteggio, con le
stesse regole di sempre: piu' fiamme, a parita' chi ha mandato prima.

Sulla schermata dei vincitori le due cose **si distinguono**: *"scelto da
@luca"* oppure *"con piu' fiamme"*. Chi guarda ha diritto di sapere se quel
premio e' stato assegnato o e' semplicemente scaduto, e raccontarle uguali
toglierebbe valore proprio a quella che ne ha di piu'.

> Vale la pena dirlo: questa e' anche la struttura che rende CRASY piu'
> difendibile davanti al DPR 430/2001 — vedi [`legale.md`](legale.md). Il premio
> smette di essere il risultato di una votazione popolare e diventa il giudizio
> di chi ha commissionato l'opera, che e' esattamente il terreno
> dell'esclusione dei concorsi artistici. Non e' il motivo per cui e' stato
> fatto, ma e' un effetto che conta.

**Allo scadere del tempo le fiamme si fermano.** Il numero resta a schermo,
fisso, com'era all'ultimo secondo, e la fiamma smette di essere un comando: non
si tocca, non si accende, non si spegne. Non e' una scelta di interfaccia — la
classifica di quel momento e' quella che ha assegnato dei soldi, e un voto
arrivato dopo la sirena li sposterebbe da una persona a un'altra. Lo dicono
tutte e due le porte: l'app non lo fa nemmeno provare, e le regole di Firestore
lo **rifiutano** anche a chi scrivesse sul database direttamente. Costa una
lettura in piu' per fiamma, e li vale tutti.

Per la stessa ragione, **il messaggio della condivisione cambia**: a gara finita
non dice piu' "sono in gara, dammi una fiamma" — manderebbe chi lo riceve a
cercare un comando che non c'e' — ma "guarda com'e' finita".

### Cinque partecipazioni al giorno

**Cinque gare al giorno, e poi si aspetta domani.** Senza un tetto l'unica
strategia che paga e' partecipare a tutto: venti scatti fatti male sperando che
uno prenda delle fiamme per caso, e chi guarda si trova un elenco di roba
buttata li'. Con cinque in mano bisogna scegliere **a quali gare si tiene
davvero** — la stessa cosa che fanno le tre fiamme dall'altra parte del tavolo.

Il conto e' sul **giorno di calendario**, ora locale: a mezzanotte tornano tutte
e cinque. Non una finestra mobile di ventiquattro ore, che costringerebbe a
ricordarsi a che ora si e' partecipato ieri.

Si vedono in home, sotto il marchio e sopra le gare — cioe' nel punto esatto in
cui uno sta per decidere a quale partecipare — e **compaiono solo quando ne hai
gia' spesa una**: una riga che dice "ne hai cinque" tutti i giorni diventa
arredamento. Il controllo sta sia sul bottone che nel controller: la schermata
puo' restare aperta mentre le altre quattro si consumano altrove.

### Tre fiamme per gara

**Ognuno ne ha tre dentro una singola challenge, e poi ha finito.** Non e' un
limite tecnico: e' quello che trasforma il voto in una scelta. Potendo accendere
tutto, l'unica cosa che un voto misura e' quante foto uno ha avuto la pazienza
di guardare — e con dei soldi in palio, "mi piacciono tutte" non decide niente.
Con tre in mano bisogna guardarle davvero e mettere le proprie da parte.

Il conto e' **per gara**: finite qui, nella challenge accanto se ne hanno altre
tre. Resta ferma la regola di sempre, che e' un'altra cosa: **una sola fiamma per
foto**, scritta nella forma dei dati — il nome del voto — e garantita dal
database. E chi ci ripensa se la riprende: si contano quante ne stanno accese,
non quante volte si e' toccato.

Sopra le foto della gara ci sono **tre fiamme disegnate**, quelle spese spente.
Un numero si legge, tre segni si vedono — e su una schermata che si scorre col
pollice vale di piu'. Dove quel contatore non c'e' (il doppio tocco dalla home)
una riga in fondo allo schermo dice cosa e' successo: un gesto che non produce
niente sembra un'app rotta.

> **Questa regola vive dentro l'app.** Chi scrive sul database direttamente puo'
> superarla — e il conto costerebbe un documento in piu' per persona e per gara,
> piu' una lettura a ogni fiamma, per essere difeso anche li'. Vale la pena
> sapere **quanto** si rischia: chi la aggira torna alla regola di prima, cioe'
> una fiamma per foto e non una di piu'. Non puo' gonfiare una singola foto —
> quello lo impedisce il documento del voto — puo' solo distribuirne piu' di
> tre. E' un fastidio, non un furto.

I gesti sono due, e fanno due cose diverse:

- **doppio tocco sulla foto**: accende. Su una fiamma gia' accesa **non succede
  niente** — ne' la spegne, ne' rifa' l'animazione. Nessuno ripete lo stesso
  gesto per disfare quello che ha appena fatto;
- **tocco sulla fiamma accanto al numero**: ribalta. E' l'unico modo di togliere
  un voto, ed e' `-1`.

Attorno al contatore ci sono altre tre difese, tutte imparate sul campo:

- il contatore si **rilegge dentro la transazione** e si riscrive per intero.
  `FieldValue.increment(-1)` su una foto senza quel campo non lo porta a zero,
  lo crea a **meno uno**;
- i tocchi sulla stessa foto si mettono **in fila**. Due scritture in volo
  insieme leggono tutte e due il mondo di prima, e la seconda decide su uno
  stato che non esiste piu';
- la correzione ottimistica si spegne **solo quando il server dice la stessa
  cosa**. Spegnerla appena finita la scrittura lasciava un istante in cui la
  fiamma si spegneva da sola: chi lo vedeva toccava di nuovo, e quel secondo
  tocco era un voto vero nella direzione sbagliata.

### Le schermate

| Schermata | Cosa fa |
| --- | --- |
| Challenge (home) | Le challenge aperte: premio, titolo, consegna, tempo, chi l'ha lanciata, la foto in testa, comando |
| Dettaglio | Premio, consegna, regole, countdown, partecipazioni gia' inviate |
| Partecipa | Scatti o registri sul momento, guardi l'anteprima, mandi in gara |
| Amici | Le richieste ricevute e l'elenco di chi hai gia' |
| Cerca | Una challenge o una persona, nella stessa casella |
| Vincitori | Le challenge concluse e chi le ha vinte |
| Profilo | Scatti, vittorie, premi, amici, e la griglia delle proprie foto |
| Profilo altrui | Gli stessi quattro numeri, la sua griglia, e il comando dell'amicizia |
| Crea | Lancia una challenge: premio, titolo, consegna, **come si giudica**, dove, per quanto |
| Accesso | Email e password, e il modo di rifarsi la password se non ce la si ricorda |
| Verifica | Il muro: si sta qui finche' l'indirizzo non e' confermato |

### Foto o video

Chi lancia la challenge sceglie **cosa** deve arrivare: una foto o un video di
massimo trenta secondi. E' un vincolo, non un suggerimento — una gara in cui
qualcuno manda una foto e qualcun altro un video non e' una gara, sono due cose
che non si possono mettere in fila e confrontare, e alla fine si pagherebbe un
premio scegliendo fra mele e pere.

In tutti e due i casi vale la regola di sempre: **si registra sul momento**. La
galleria non si apre, ne' per le foto ne' per i video.

### Come si guarda un video

**Parte da solo, muto e in ciclo**, e senza nessun comando sopra. Un video che
chiede di premere play prima di mostrarsi viene saltato: si scorre una gara
guardando venti contenuti di fila, e chi guarda non sa nemmeno cosa sta
rifiutando finche' non lo vede muoversi. Il ciclo serve alla gara — trenta
secondi che ripartono lasciano il tempo di decidere se quella cosa merita una
fiamma.

> **Gli attributi prima dell'indirizzo.** iPhone decide se un video ha il
> diritto di partire da solo guardando gli attributi che ha addosso **quando
> comincia a caricarsi**. Scritti come proprieta' dopo `src` — cioe' come viene
> naturale — arrivano troppo tardi: il video risulta "con l'audio" per un
> istante, il permesso viene negato li', e non si riottiene mettendo `muted` un
> attimo dopo. E' il motivo per cui i video si vedevano ma restavano fermi.
>
> Restano due reti sotto: quando i dati arrivano si riprova, e se il browser
> dice di no lo stesso, **il primo tocco ovunque nella pagina** li sblocca tutti
> — dopo un'interazione nessun browser rifiuta piu' niente.

**Nell'elenco un video non ha nessun comando addosso, mai.** Niente barra dei
comandi come ripiego quando la partenza viene rifiutata — su una miniatura larga
due centimetri era una fascia grigia che copriva meta' della foto e faceva
sembrare l'app rotta — e **niente menu del browser**: tenendo il dito su un
video, Chrome offriva pausa, schermo intero, velocita' di riproduzione e
*scarica*. Nessuna di quelle voci ha senso dentro CRASY, e "scarica" su una foto
in gara e' proprio quella che non deve esserci.

Nelle griglie dei profili **un tocco apre il contenuto grande**, non la gara: nel
quadrato di due dita non si vede niente e un video non si sente nemmeno. La gara
resta a un tocco, scritta sopra la foto a schermo intero.

**Un tocco lo apre a schermo intero**, ed e' li' che diventa una cosa che si
guarda davvero: audio acceso e **la barra dei secondi**, per tornare indietro sul
momento in cui e' successo qualcosa. Sul web quella barra la disegna il browser,
che e' anche l'unico a saper aprire il lettore di sistema su iPhone; sull'app ci
sono la barra da trascinare e i due salti da dieci secondi, e spariscono da soli
dopo qualche istante per non stare sopra il video.

Nell'elenco suona **solo il video che si sta guardando**: quello che esce dallo
schermo si ferma da solo. Venti video che partono insieme sono venti file che
scendono insieme, e su un telefono e' la differenza fra un'app e un conto del
traffico.

Il **doppio tocco resta la fiamma**, anche sui video. Non era cosi': sul web un
video e' un elemento del browser e si prendeva tutti i gesti, quindi sulle foto
si poteva votare con due dita e sui video no.

> **I due tocchi li conta CRASY, non il browser.** Il primo tentativo si
> affidava all'evento `dblclick`, ed e' li' che si rompeva: sul telefono quel
> messaggio non arriva sempre, e quando manca restano due `click` normali. Il
> secondo faceva scadere l'attesa del primo, e invece della fiamma si apriva il
> video — a volte due volte di fila. Contando i tocchi per conto nostro il caso
> non esiste: se ne arriva un secondo mentre il primo sta ancora aspettando,
> **quello e' un doppio tocco**, e il singolo non parte piu'.

### Gli amici

Ogni profilo si puo' aprire, e ci si arriva da dove si e': dal nome sotto una
foto, dalla riga di chi ha lanciato una challenge, dall'elenco degli amici. **Si
incontra la gente guardando cosa combina**, non cercandola per nome — ed e'
ancora il modo principale in cui qui dentro ci si conosce.

Una ricerca pero' adesso c'e', e serve prima di tutto alle **challenge**: quando
le gare aperte diventano trenta, ritrovare *quella del cartello* scorrendo la
home e' il momento in cui uno smette di cercarla. La lente e' una **scheda in
fondo**, fra gli amici e i vincitori — il posto in cui il pollice la cerca senza
guardare — e cerca due cose nella stessa casella: una challenge o una persona,
perche' chi cerca sa la parola, non la categoria.

Le due meta' funzionano in modo diverso, e la differenza e' voluta:

- **le challenge** si cercano nel titolo, nella consegna, nel posto e nel nome di
  chi le ha lanciate, **dall'inizio di una parola** e da almeno due lettere.
  "Contiene" non andava bene e si vedeva alla prima lettera: cercando `h`
  uscivano tutte le gare del mondo, perche' quella lettera sta dentro
  *challenge*, dentro *che*, dentro mezza lingua italiana. Per parole e non solo
  dalla prima, pero': nessuno si ricorda una gara dalla sua parola iniziale —
  *"quella del cartello"* si cerca scrivendo `cartello`. Sono i quattro modi in cui uno si ricorda una gara vista
  passare, e la ricerca gira su quello che l'app ha gia' in casa: nessuna query
  in piu', risposta mentre si scrive;
- **le persone** si trovano solo per **nome esatto, dall'inizio**. Nessun
  suggerimento, nessun "forse cercavi", niente ricerca dentro le biografie. Chi
  sa come si chiama qualcuno lo trova; **sfogliare gli iscritti resta impossibile,
  ed e' chiuso apposta**.

Sotto la casella ci sono quattro parole — **TUTTO, APERTE, FINITE, PERSONE** —
e non servono a restringere i risultati: servono a dire **cosa si ha in testa**.
Chi scrive "milano" sta cercando una gara a cui partecipare stasera oppure una
persona che conosce, e sono due ricerche diverse che finirebbero mescolate nella
stessa lista. Le gare aperte e quelle finite stanno separate per la stessa
ragione: a una gara chiusa non si puo' piu' partecipare, e trovarsela in mezzo
alle altre e' una speranza sprecata.

Con un filtro sulle gare la ricerca delle persone **non parte nemmeno**: e' una
lettura su Firestore risparmiata a ogni parola scritta.

Un profilo mostra quattro numeri e **due sezioni di foto: in gara e vinte**.
Niente eta', niente elenco di cosa ha votato — e **niente raccolta di tutto
quello che ha mandato da quando esiste**: quella racconta la quantita', non la
persona, e dopo trenta gare sono trenta quadrati in cui le due che contano
stanno in fondo. Le due sezioni rispondono invece alle due domande che uno si fa
davvero guardando un profilo: **dove sta gareggiando adesso** e **cosa ha
vinto**.

"In gara" vuol dire che la challenge e' ancora aperta, non che la foto e' stata
mandata di recente: una di tre giorni fa in una gara che dura una settimana e'
ancora in gioco, una di stamattina in una gara chiusa non lo e' piu'.

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

  Dallo stesso indirizzo si **rifa' la password**, e per un po' non si poteva:
  chi la dimenticava restava fuori per sempre, senza che nemmeno noi potessimo
  farci niente dall'altra parte. La frase di conferma non dice mai **se quel
  conto esiste** — dirlo regalerebbe a chiunque un modo di scoprire chi sta su
  CRASY, provando indirizzi finche' uno non risponde — e nomina lo spam, che e'
  dove quel messaggio finisce meta' delle volte.
- **Si entra da diciotto anni.** Qui girano soldi veri e si chiede alla gente di
  uscire e fare qualcosa per vincerli: e' esattamente il tipo di spinta che a un
  ragazzino non va data. Il selettore della data non arriva oltre la soglia, e
  le regole rifiutano un profilo dichiaratamente minorenne.

  Va detto cosa questo **non** e': una data che uno si scrive da solo non e' una
  verifica dell'eta'. Ferma chi e' onesto, non chi mente. Una verifica vera vuole
  un documento, ed e' una decisione da prendere prima di aprire al pubblico.

### Le caselle usa-e-getta

Su un'app qualunque un indirizzo temporaneo e' una scocciatura. **Qui e' il modo
piu' semplice di rubare**: le challenge le decidono le fiamme, una per persona, e
"una persona" per CRASY vuol dire un account. Chi si fa cinque caselle in due
minuti su uno di quei siti si fa cinque account, e si vota cinque volte la
propria foto.

`lib/core/moderation/email_policy.dart` rifiuta i domini piu' diffusi **in
registrazione**, sottodomini compresi. Tre cose vanno dette:

- **vale solo a chi si registra, non a chi entra.** Chi si e' iscritto ieri con
  un dominio che oggi finisce nell'elenco deve poter continuare a entrare:
  chiudere fuori qualcuno che e' gia' dentro, magari con delle foto in gara, per
  una regola scritta dopo, e' una punizione retroattiva;
- **e' una prima porta, non un muro** — come per i testi. Ferma chi apre il
  primo sito che trova, non chi ne cerca uno che nell'elenco non c'e', e
  soprattutto vive **solo dentro l'app**: chi chiama l'API di Firebase
  direttamente la scavalca. Il muro vero e' una *blocking function* lato server,
  e richiede il piano a consumo;
- **meta' del problema lo copre gia' il muro dell'email confermata**: un dominio
  che non esiste non riceve niente, quindi nessuno conferma e nessuno entra. Qui
  si para l'altra meta', le caselle temporanee che la posta la ricevono davvero.

Due cose **non** si bloccano, di proposito: i relay di Apple
(`privaterelay.appleid.com`), che sono indirizzi veri e che il giorno
dell'accesso con Apple saremo obbligati ad accettare; e gli **alias con il piu'**
(`nome+crasy@gmail.com`), che sono un buco piu' largo di questo elenco e non si
chiudono con una lista di domini — serve tenere l'indirizzo ridotto alla sua
forma canonica e impedire che si ripeta. **E' un lavoro a se', e va fatto.**

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

## Le gare finite non si accumulano

Una gara chiusa smette di servire a qualcuno molto prima di smettere di occupare
spazio: chi voleva sapere chi ha vinto lo ha saputo il giorno stesso, e da li' in
poi restano soltanto documenti da leggere in ogni query e megabyte da pagare ogni
mese. Quindi:

- **le gare a cui non ha partecipato nessuno non si vedono affatto.** Una
  challenge senza foto non ha niente da raccontare — nessun vincitore, nessuna
  immagine — e in mezzo a chi ha vinto dei soldi resta una riga che dice "non ha
  partecipato nessuno". Su una schermata che esiste per rendere credibile la
  promessa e' esattamente il contrario di quello che serve. Sparire dalla vista
  non vuol dire sparire dai conti: vengono **chiuse lo stesso**, ed e' cosi' che
  il premio torna a chi l'aveva messo;
- **dopo due giorni spariscono tutte.** `Challenge.winnersWindow` decide da
  quanto indietro si leggono le gare finite, e la schermata dei vincitori non
  chiede nemmeno le altre;
- **e dopo due giorni il server le cancella davvero** — documenti,
  partecipazioni e file. Lo fa `purgeOldChallenges`, ogni ora, e i due numeri
  devono restare uguali: se il server cancellasse prima, la schermata mostrerebbe
  gare i cui file non ci sono piu'. Una gara con i soldi ancora fermi in cassa
  (`held`) non si tocca: cancellarla vorrebbe dire perdere le tracce di soldi
  veri.

> **Il taglio vale gia' adesso, la cancellazione no.** `purgeOldChallenges` e'
> una Cloud Function, e le Cloud Function richiedono il piano a consumo che il
> progetto non ha — come il controllo delle foto. Oggi le gare vecchie
> **spariscono dall'app** ma restano scritte sul database: lo spazio si libera
> davvero solo quando quella funzione viene accesa. Vale la pena saperlo prima
> di scoprirlo guardando la fattura.

---

## Lo spazio che occupano le foto

Una foto appena uscita da un telefono pesa fra i tre e gli otto megabyte. Mille
partecipazioni sono cinque gigabyte, e a quel punto lo spazio comincia a
costare piu' dei premi.

Si interviene in due punti, e il primo vale dieci volte il secondo.

**Prima di partire**, ogni foto viene portata a milleseicento punti sul lato
lungo e salvata all'ottantadue per cento: da quattro megabyte a tre decimi. Su
uno schermo da telefono non si vede nessuna differenza — quella foto verra'
guardata dentro un riquadro largo quattrocento punti — e resta abbastanza
grande da reggere l'ingrandimento a due dita. Su telefono `image_picker` faceva
gia' il grosso; **su web ignora quei parametri**, ed e' da li' che arrivava
tutto, perche' e' li' che CRASY vive oggi.

**Appena la gara finisce**, i file di chi non ha vinto vengono cancellati: alla
proclamazione resta solo la foto del vincitore. Il documento resta — chi ha
partecipato, quante fiamme ha preso — sparisce l'immagine. Lo fa il server, ed
e' l'unico che lo puo' fare: dare a un telefono il permesso di cancellare i file
di altre persone e' una porta che non si richiude piu'.

**Dopo sei mesi**, anche la foto del vincitore sparisce. E' una regola sul bucket, non
codice: i file sotto `entries/` piu' vecchi di centottanta giorni vengono
cancellati da Google. La partecipazione **resta scritta** — chi ha vinto, quante
fiamme, quanto ha preso — sparisce solo l'immagine, e al suo posto compare il
riquadro grigio con il nome di chi l'aveva mandata.

Sei mesi sono una scelta, non un vincolo: si cambia con una riga sulla
configurazione del bucket. I video non si possono rimpicciolire dal telefono, e
per quelli valgono i due limiti a monte: mezzo minuto e quaranta megabyte.

---

## Il design

Una sola regola, e tutto il resto ne discende: **bianco, nero, grigi, e il rosso
del fuoco**.

- `#FA0000` e' il rosso di CRASY, e non e' stato scelto a tavolino: e'
  **campionato dalla "sy" del logotipo**, la tinta piu' frequente dei suoi pixel
  rossi. Marchio e interfaccia usano letteralmente lo stesso colore.
- Compare in quattro posti soltanto: **il premio, la fiamma del voto, cio' che
  e' attivo**, e **il + che lancia una challenge**. Se compare altrove ha gia'
  smesso di significare qualcosa.
- Il **+** e' l'ultimo arrivato dei quattro, e ha una ragione: e' il gesto con
  cui si mettono dei soldi in palio, cioe' quello da cui nasce tutto il resto.
  Nero come le altre icone non si capiva a cosa servisse — sembrava un piu'
  qualunque in cima a una schermata piena di challenge, non il modo di
  lanciarne una.
- `#E00000` e' lo stesso rosso piu' scuro, e serve a un solo scopo: fare da
  riempimento sotto il testo bianco del bottone principale. Il rosso pieno su
  bianco sta a 4,2:1, abbastanza per un premio scritto a 64 punti ma non per
  un'etichetta a 14; qui si sale a 5,0:1. Non e' un secondo colore, e' la stessa
  tinta a una luminosita' diversa.
- Niente card, niente ombre, niente gradienti, niente badge. A separare le cose
  sono lo spazio bianco e, dove serve, un filetto da mezzo pixel.
- La gerarchia la fa la tipografia: dal 64 del premio all'11 dell'occhiello.
- **La propria foto ha una cornice rossa** dentro la gara e nel feed. In una
  griglia di dodici quadrati tutti uguali, ritrovare la propria vuol dire
  leggere dodici nomi: il riquadro la fa saltare fuori senza leggere niente. E'
  l'unico posto in cui il rosso non indica ne' un premio ne' una fiamma ma
  **te**, e va bene cosi' — in mezzo a quella griglia, tu sei la cosa che stai
  cercando.
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
- **Si torna indietro col dito, da qualunque punto, e lo si vede succedere.**
  La pagina scivola **sotto il dito** mentre la si trascina, e sotto rientra
  quella di prima: al rilascio, oltre meta' schermo si esce, prima si torna a
  posto. Non e' un vezzo — un gesto che non risponde mentre lo fai non si
  capisce che c'e', e chi lo prova conclude che l'app non lo abbia.

  > A muovere due schermate insieme e' l'animazione **della rotta**, non un
  > widget dentro di essa: il primo tentativo misurava il trascinamento e
  > chiamava `pop` al rilascio, e durante il gesto non succedeva niente.
  > `SwipeBackPage` fa guidare quell'animazione dal dito, che e' quello che fa
  > iPhone da sempre — solo che iPhone lo concede a chi parte dai venti punti
  > all'estrema sinistra, e qui vale da ovunque.

  La freccia in alto resta per chi la cerca, ma e' un accento sottile e non la
  freccia piena di Material: quella e' la cosa che fa sembrare "un'app Android"
  una schermata per il resto identica.

  Le due schermate in cui si ha in mano qualcosa di non salvato — **Partecipa**
  e **Crea** — tengono solo il gesto stretto del bordo: un gesto largo quanto lo
  schermo butterebbe via una foto appena scattata per un dito storto.

I token stanno in `lib/core/theme/`. Le schermate leggono da `AppPalette`, mai
dai colori grezzi.

L'app e' in italiano. Restano in inglese il nome e la tagline, che sono marchio.

---

## Dov'e'

**https://crasy.web.app**

Sta su Firebase Hosting, che e' gratis sul piano che il progetto ha gia'. Prima
girava su un tunnel temporaneo, e l'indirizzo cambiava a ogni riavvio: per una
app in cui le gare durano ventiquattro ore, un indirizzo che puo' morire nel
mezzo non e' un dettaglio.

Il dominio e' fra quelli autorizzati per l'accesso: senza, i link di conferma
dell'email arriverebbero e non funzionerebbero.

### Perche' l'app aggiornata si vede subito

Una PWA e' fatta per aprirsi senza rete, quindi tiene una copia di se stessa sul
telefono. Il rovescio e' che dopo una pubblicazione qualcuno continua a vedere la
versione di prima — e in un'app che cambia tutti i giorni e' il modo migliore di
farsi dire "e' ancora rotto" da chi sta guardando una correzione gia' fatta.

A tenerla fresca sono **due cose che devono valere insieme**, e per un po' ne
valeva una sola.

**Le intestazioni di Hosting.** Tutto viaggia con `no-cache`, che non vuol dire
"non tenerlo": vuol dire *tienilo, ma prima di usarlo chiedi se e' cambiato*. La
risposta e' un `304` da poche decine di byte quando non lo e', e la velocita' vera
non viene da qui — viene dal service worker, che serve i file dal telefono senza
rete. L'unica eccezione e' `canvaskit/`, che sta in un indirizzo diverso a ogni
versione e quindi si puo' tenere per sempre.

> **Le regole si leggono dall'ultima.** Quando piu' di una combacia con lo stesso
> file, Firebase applica **l'ultima**. Prima c'erano tre regole `no-cache` sui file
> d'ingresso e in fondo una che diceva "tutti i `.js` e i `.json` per una
> settimana": quella in fondo se le mangiava tutte e tre. Il risultato si vedeva
> chiedendolo al sito — `flutter_service_worker.js` rispondeva `max-age=604800` —
> e voleva dire che **il file che si occupa degli aggiornamenti era esso stesso
> vecchio di una settimana**. Per questo adesso la regola generale sta per prima e
> l'unica eccezione dopo: e' l'ordine che le rende vere.

**Il controllo dentro l'app.** `web/index.html` ascolta il service worker: appena
la versione nuova ha finito di installarsi — e solo se ce n'era gia' una che
controllava la pagina, cioe' se e' un aggiornamento e non una prima apertura — la
pagina si ricarica una volta sola. E siccome un'app installata puo' restare aperta
per giorni senza caricare nessuna pagina, il controllo si rifa' **ogni volta che
si torna sull'app**, che e' anche il momento meno peggio per ricaricarla.

> Il service worker generato da Flutter e' dichiarato deprecato e prima o poi
> sparira' dalle build. Quando succede, e' questa la parte da rifare.

### Farne un APK da mandare agli amici

Su Android non serve nessuno store: si compila e si manda il file.

```bash
flutter build apk --release --split-per-abi
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk   ~22 MB
```

`--split-per-abi` non e' un dettaglio: il pacchetto unico contiene tutte le
architetture e pesa **sessanta megabyte**, quello per `arm64` ne pesa ventidue
ed e' quello che gira su qualunque telefono Android degli ultimi otto anni.

Cosa serve sulla macchina, una volta sola:

- un **JDK 17** (`winget install Microsoft.OpenJDK.17`);
- l'**SDK Android**, che si prende senza installare Android Studio: bastano gli
  strumenti da riga di comando, e da li' `sdkmanager` scarica
  `platform-tools`, `platforms;android-36` e `build-tools;36.0.0` — Flutter
  3.44 vuole il 36;
- dire a Flutter dove sono: `flutter config --android-sdk <cartella>` e
  `flutter config --jdk-dir <cartella>`.

Due cose da sapere su quel file, prima di mandarlo in giro:

- **e' firmato con la chiave di debug**, perche' e' quella che la configurazione
  usa anche per la release. Si installa benissimo, ma non si puo' caricare sul
  Play Store — e il giorno in cui l'app vera arrivera' con una chiave vera, chi
  ha questa dovra' **disinstallarla prima**: due firme diverse non si
  aggiornano l'una sull'altra;
- **il pacchetto si chiama ancora `com.example.app_incontri`**, quindi per il
  telefono e' un'app diversa da quella che un giorno starà sullo store.

Chi la riceve deve dare al programma con cui apre il file — messaggistica,
gestore file, browser — il permesso di installare app; poi Play Protect avvisa
che l'app non viene dallo store, e si prosegue lo stesso. E' il giro normale di
qualunque beta fuori dallo store.

### Mandarla su TestFlight

**Ogni push su `main` diventa una build in TestFlight**, e da li' una notifica
sul telefono di chi la sta provando. Se ne occupa `codemagic.yaml`: un Mac in
affitto compila, firma e carica. Il Mac vero serve solo per il hot reload
mentre si sviluppa.

Tre cose una volta sola, e sono tutte fuori dal codice:

1. su **Codemagic**, accesso con GitHub e collegamento del repository;
2. una **chiave API di App Store Connect** (*Users and Access -> Integrations*),
   caricata su Codemagic come integrazione chiamata `appstore`. **La firma non
   si configura**: con quella chiave, certificati e profili se li crea e se li
   rinnova da solo — e' il pezzo che a mano fa perdere i pomeriggi;
3. su **App Store Connect**, la scheda dell'app: *Apps -> +* con bundle id
   `app.crasy.mobile`. Senza, il caricamento non ha dove atterrare.

Due scelte dentro quel file che vale la pena conoscere:

- **la versione di Flutter e' fissata**, non "stable". Una versione che cambia
  da sola sotto i piedi produce il guaio peggiore che ci sia: funziona sul
  proprio computer e si rompe sulla macchina che compila, senza che nessuno
  abbia toccato niente;
- **analisi e prove girano prima di compilare.** Dodici minuti di build per
  scoprire che un test era rosso sono dodici minuti buttati, e una versione
  rotta che arriva ai tester e' peggio di una versione che non arriva.

Il numero di build lo chiede ad App Store Connect — l'ultimo, piu' uno — cosi'
il conto regge anche quando una build parte dal Mac invece che dalla CI.

### E dal Mac, quando serve

Il giro a mano resta, e sta in un comando solo.

```bash
./tool/testflight.sh
```

Fa le quattro cose che si fanno ogni volta e che ogni volta si sbagliano: prende
il lavoro nuovo, **alza il numero di build**, compila, carica. A mano sarebbe:

```bash
git pull
flutter build ipa --release
open build/ios/archive/Runner.xcarchive
# Distribute App -> App Store Connect -> Upload
```

Prima volta, in Xcode: *Signing & Capabilities* con il **team a pagamento**
selezionato e la firma automatica accesa. Il nome del pacchetto e'
**`app.crasy.mobile`** e non si cambia piu' dopo il primo caricamento — e' quello
scritto in `project.pbxproj`, in `GoogleService-Info.plist` e in
`firebase_options.dart`: **i tre devono coincidere sempre**, e per un po' non lo
facevano (il codice Dart parlava ancora dell'app di prova). Accesso e database
funzionavano lo stesso, perche' dipendono dal progetto e non dal pacchetto, ma le
notifiche push si agganciano **per identificativo** e sarebbero andate a cercare
l'app sbagliata.

Perche' lo script carichi da solo servono le tre cose della **chiave API** di
App Store Connect (*Users and Access -> Integrations*): `APP_STORE_KEY_ID`,
`APP_STORE_ISSUER_ID` e il file `.p8` in `~/.appstoreconnect/private_keys/`.
Senza, compila lo stesso e apre la cartella del pacchetto: si trascina su
Transporter.

Su App Store Connect, una volta sola: *Apps -> +* con quel bundle id, poi
**TestFlight -> Internal Testing**, si aggiungono le persone e si sceglie la
build. Gli invitati installano **TestFlight** dall'App Store e da li' hanno
CRASY con un tasto *Installa*.

Due cose che fanno perdere un pomeriggio la prima volta:

- **il numero di build deve salire a ogni caricamento.** E' il `+1` di
  `version: 1.0.0+1` nel `pubspec.yaml`: ricaricare due volte lo stesso numero
  viene rifiutato, e il messaggio non lo dice chiaramente — si scopre venti
  minuti dopo, a compilazione finita. Lo script lo alza da solo, e **committa il
  numero nuovo**: lasciarlo sul proprio computer vuol dire ritrovarsi due build
  con lo stesso numero il giorno che si compila da un'altra parte;
- **la conformita' all'export.** App Store Connect la chiede a ogni build, e
  finche' non si risponde la build non arriva ai tester: si carica, si aspetta,
  e non succede niente. `ITSAppUsesNonExemptEncryption` a `false` nel
  `Info.plist` toglie la domanda per sempre — CRASY usa solo HTTPS, che rientra
  fra le esenzioni.

Le build durano **90 giorni**, non 7: quella scadenza era della firma gratuita.

### Provarla sull'iPhone, da un Mac

Non serve l'account sviluppatore da 99 euro per installarla sul **proprio**
telefono: basta un Mac, Xcode e un Apple ID qualunque. L'app resta installata
**sette giorni** e poi va reinstallata — e' il limite della firma gratuita, non
un difetto.

```bash
flutter pub get
open ios/Runner.xcworkspace    # il workspace, non il progetto
flutter run                     # con l'iPhone collegato e sbloccato
```

Due cose che vanno sistemate **una volta sola**, in Xcode, e che nessun errore
spiega bene:

- **La firma.** Signing & Capabilities → il proprio Apple ID come team. Il
  nome del pacchetto e' ancora `com.example.appIncontri`, e con la firma
  gratuita un identificativo che comincia per `com.example` viene quasi sempre
  rifiutato perche' qualcun altro l'ha gia' preso: va cambiato in qualcosa di
  proprio. **Firebase continua a funzionare lo stesso** — le chiavi arrivano da
  `firebase_options.dart`, non dal nome del pacchetto — quindi per una prova non
  serve registrare niente su Firebase.
- **Il telefono deve fidarsi.** La prima volta l'app non parte: Impostazioni →
  Generali → VPN e gestione dispositivo → il proprio account → *Autorizza*.

`GoogleService-Info.plist` non c'e' e **non serve** per accesso, database e
foto: quelle passano tutte dalle opzioni scritte nel codice. Servira' il giorno
delle notifiche.

### Installarla sul telefono

Non c'e' negozio, e per adesso non serve: e' una **PWA**, cioe' si installa
dalla pagina.

- **iPhone**: aprire l'indirizzo con Safari (non Chrome — su iOS solo Safari sa
  installare), poi *Condividi → Aggiungi alla schermata Home*.
- **Android**: Chrome propone *Installa app* da solo; altrimenti *menu →
  Aggiungi alla schermata Home*.

Da li' in poi e' un'icona come le altre: si apre a tutto schermo, senza barra
del browser. La fotocamera funziona, l'accesso resta salvato.

Quello che una PWA **non** fa e' arrivare con una notifica quando l'app e'
chiusa — su iOS le notifiche web hanno ancora dei limiti — ed e' il motivo per
cui prima o poi servira' l'app vera. Per l'App Store servono un Mac e un account
sviluppatore Apple; per il Play Store basta questo computer con l'SDK Android
installato.

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

> **Il progetto Firebase si chiama ancora `daily-dating-app`.** L'identificativo
> di un progetto Google non si rinomina — mai, in nessun modo. Il nome
> visualizzato e' gia' CRASY, il dominio e' `crasy.web.app`, e dentro il
> prodotto quel nome non compare da nessuna parte. Restano due punti in cui
> esce, e vanno detti:
>
> - **il link dentro l'email di conferma** punta a
>   `daily-dating-app.firebaseapp.com/__/auth/action`. Si cambia, ma **solo
>   dalla Console** — l'API risponde `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED` a
>   qualunque tentativo. Console → Authentication → Templates → la matita
>   accanto a "Verifica dell'indirizzo email" → *Personalizza URL azione* →
>   `https://crasy.web.app/__/auth/action`. Il dominio e' gia' autorizzato e la
>   pagina risponde: e' scelta da un elenco, non da scrivere;
> - **il mittente** e' `noreply@daily-dating-app.firebaseapp.com`. Per cambiarlo
>   serve un dominio proprio verificato o un server SMTP nostro — e' la stessa
>   cosa che serve per non finire nello spam, quindi si fanno insieme.
>
> Nel frattempo, chi conferma l'indirizzo **torna su `crasy.web.app`**: la
> pagina di Firebase mostra un collegamento di ritorno, che prima non c'era.
>
> L'app Android si chiama ancora `com.example.app_incontri`: cambiarla
> scollegherebbe `google-services.json`. Per rifare tutto da capo con un nome
> pulito serve un progetto Firebase nuovo, esportando utenti (`firebase
> auth:export`, le password si migrano), documenti e file.

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
di chiusura trova le challenge a cui nessuno ha assegnato il premio in tempo. Il premio e' in centesimi —
`50000` sono €500 — perche' un premio in denaro tenuto in virgola mobile prima o
poi diventa `499,99999`.

`scope` vale `global`, `country`, `local` o `private`. Con `local`, `place` e' la
citta' che si vede sulla scheda (`NAPOLI`).

### Un minuto, per provare

La durata si sceglie in **minuti**, da uno a millequattrocentoquaranta. Un
minuto non e' una gara — non ci sta il tempo di uscire di casa — ed e' li' per
una ragione sola: e' l'unico modo di vedere il giro intero senza restare seduti
ad aspettare. Si lancia, si partecipa, si vota, si chiude, si proclama, e il
premio compare nel portafoglio. Quando l'app sara' in mano a delle persone vere,
il minimo torna a un'ora.

E siccome la funzione che chiude le gare **non gira** senza il piano a
pagamento, a chiudere e' il primo che apre una gara scaduta — dal dettaglio o
dalla schermata dei vincitori. La classifica la calcola con le stesse regole del
server: piu' fiamme per prima, a parita' chi ha mandato prima, fuori chi non ha
passato il controllo.

Il permesso, nelle regole, e' legato a una condizione che **si spegne da sola**:
vale solo dove `prizeStatus` e' `unpaid`, cioe' dove CRASY non ha in cassa un
centesimo. Il giorno in cui i pagamenti si accendono, ogni gara visibile e'
pagata e da un telefono non si proclama piu' niente — senza che nessuno debba
ricordarsi di togliere la regola.

### La chiusura delle challenge

`functions/index.js` gira ogni cinque minuti, cerca le challenge **finite da piu'
di ventiquattro ore** a cui nessuno ha assegnato il premio, e lo da' alla foto
piu' votata. A parita' di voti vince chi ha mandato per primo: serve una regola
qualunque, ma serve che sia sempre la stessa.

Quelle ventiquattro ore devono restare uguali a `Challenge.decisionWindow`
nell'app: se il server fosse piu' impaziente, strapperebbe il verdetto di mano a
chi l'app dice che ha ancora tempo per decidere.

---

## I soldi

Il problema che questo pezzo risolve e' uno solo, ed e' quello che ucciderebbe
l'app: **le missioni finte**. Uno promette cinquecento euro, dieci persone
escono di casa e fanno qualcosa di assurdo, e lui non paga. Alla seconda volta
la voce gira, e l'unica cosa che CRASY promette — che i soldi ci siano davvero —
non vale piu' niente.

La risposta e' che **i soldi si pagano prima**, e li tiene CRASY:

1. Si crea la challenge. Nasce `prizeStatus: unpaid` e **non si vede da nessuna
   parte**, nemmeno a chi l'ha scritta. Non e' una bozza: e' una challenge che
   non esiste.
2. Si paga su una pagina di Stripe. I numeri di carta non passano mai da CRASY —
   e' la differenza fra dover rispettare lo standard PCI e non doverlo fare.
3. Stripe ci richiama, la challenge passa a `held` e **il cronometro riparte da
   quel momento**: chi ha impiegato dieci minuti a trovare la carta non deve
   trovarsi una gara di ventiquattro ore che ne dura ventitre e cinquanta.
4. Alla chiusura il server proclama il vincitore e fa partire il premio meno la
   percentuale. Se non ha partecipato nessuno, il premio **torna indietro
   intero**, commissioni comprese: sono pochi euro, e sono la differenza fra
   "non e' andata" e "mi hanno tenuto dei soldi per niente".
5. Il vincitore incassa. La prima volta deve registrarsi con nome, documento e
   IBAN: e' la legge sull'antiriciclaggio, vale per chiunque riceva denaro, e
   nessuna app la puo' saltare.

### Il portafoglio

I premi vinti **non partono subito verso la banca**: si fermano nel portafoglio,
in cima al profilo. E' una scelta che conviene a chi vince. Bonificando
all'istante servirebbe che il vincitore fosse gia' registrato con documento e
IBAN nel momento esatto in cui la gara si chiude — cioe' quasi mai — e il premio
resterebbe fermo in attesa di lui.

Cosi' invece i soldi sono suoi appena vince, si sommano a quelli delle volte
prima, e la registrazione la fa il giorno che decide di prelevare: una volta
sola, quando ne vale la pena. Il minimo per prelevare e' dieci euro.

Sotto il saldo c'e' scritto **dove sono quei soldi** — su CRASY, finche' non li
preleva — e non e' una nota legale: un portafoglio che mostra un numero senza
dire dove sta e' la cosa piu' vicina a una truffa che si possa costruire in
buona fede.

Il saldo e' un campo che **nessun telefono puo' scrivere**. A muoverlo e' solo
il server, e le regole di Firestore lo impongono: senza quella riga, regalarsi
mille euro sarebbe cambiare un numero.

### I conti

Su un premio di 500 euro:

| Voce | Quanto |
| --- | --- |
| Paga chi lancia | 507,87 |
| Va al vincitore | 450,00 |
| Trattiene CRASY | 50,00 (10%) |
| Trattiene Stripe | 7,87 (1,5% + 25 cent) |

Le commissioni le paga **chi lancia, in aggiunta**, e non si scalano dal premio.
La ragione non e' contabile: cosi' il numero grande scritto in home e' vero.
Scalandole, una challenge da 500 ne pagherebbe 442, e sarebbe di nuovo un premio
annunciato diverso da quello che arriva — la cosa che l'escrow serve a togliere.

Il conto e' meno ovvio di quanto sembri, perche' Stripe prende la sua
percentuale **sull'importo addebitato**, che contiene la commissione stessa:
aggiungere l'1,5% del premio lascerebbe scoperto l'1,5% dell'1,5%. Si risolve al
contrario, cercando l'addebito il cui netto e' esattamente il premio. Sta scritto
in [`prize_ledger.dart`](lib/features/payments/domain/prize_ledger.dart), con le
prove che il montepremi arriva intero su ogni cifra da 5 euro a un milione.

Gli stessi conti sono scritti una seconda volta in `functions/payments.js`, in
JavaScript. **Non e' una svista**: il telefono deve poter dire "paghi 507,87"
senza chiamare il server a ogni tasto, e il server non deve fidarsi di quello che
dice il telefono. Qui si calcola per mostrare, li' per addebitare.

### Perche' Stripe Connect e non dei bonifici

Tenere i soldi di altre persone in attesa di darli a terzi e' un'attivita'
regolamentata. Con Connect **l'istituto di pagamento e' Stripe**, non noi: CRASY
resta una piattaforma che incassa una commissione. Facendolo a mano, con un
conto corrente e dei bonifici, servirebbe una licenza.

### Adesso e' spento

Come il controllo sulle foto, e per motivi che si sommano:

- le Cloud Function richiedono il **piano Blaze** su Firebase;
- Stripe richiede un **account** e una **partita IVA**;
- e va deciso il nodo legale, vedi sotto.

Con l'interruttore spento CRASY si comporta come si e' sempre comportata: il
premio e' un patto fra chi lo mette e chi partecipa, e la schermata di creazione
lo dice apertamente invece di far finta di niente. Accendendolo **prima** che
Stripe esista, ogni challenge diventerebbe invisibile: nascono tutte non pagate,
e non ci sarebbe niente in grado di pagarle.

Per accenderlo:

```sh
# 1. Le chiavi, in Secret Manager e non nel codice
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET

# 2. Le funzioni (serve il piano Blaze)
firebase deploy --only functions

# 3. Su Stripe: un webhook verso l'indirizzo di `stripeWebhook`, con gli eventi
#    checkout.session.completed, charge.refunded, account.updated

# 4. Togliere dal commento la riga marcata in firestore.rules, che impedisce di
#    partecipare a una challenge non pagata
firebase deploy --only firestore:rules

# 5. L'app
flutter build web --release --dart-define=CRASY_PAYMENTS=true
```

### Il nodo legale, detto prima e non dopo

In Italia un premio in denaro assegnato **per voto del pubblico** rischia di
rientrare nei concorsi a premi (DPR 430/2001), che richiedono regolamento
depositato, cauzione e un funzionario che verifica l'assegnazione. L'esenzione
esiste quando il premio remunera una prestazione d'opera valutata sul merito, ed
e' discutibile che delle fiamme siano una valutazione di merito.

**Vale mezz'ora di un avvocato prima di incassare il primo euro, non dopo.** Il
codice e' scritto e funziona; questa e' l'unica cosa che il codice non puo'
risolvere.

Le domande da portargli — e la descrizione esatta di come funziona il prodotto,
con i riferimenti al codice perche' possa verificarla — stanno in
[`legale.md`](legale.md). In breve: la strada da far valutare e' l'esclusione
dei **concorsi artistici** (art. 6), e le tre domande che contano quanto quella
principale sono *chi e' il committente*, *se il voto del pubblico e' una
valutazione di merito*, e *chi trattiene le imposte* — perche' oggi nessuno le
trattiene.

Nel frattempo il prodotto fa gia' le cose che quell'esclusione richiede, e le fa
perche' sono giuste comunque: l'opera si realizza **sul momento** e per quella
commissione, **i criteri di valutazione sono obbligatori** e si scrivono quando
la challenge nasce, **non si possono piu' cambiare** dopo — le regole del
database lasciano toccare a una gara gia' nata solo il numero dei partecipanti e
il vincitore — la partecipazione e' gratuita, non c'e' un solo numero casuale
nella catena, e chi manda un'opera legge prima che **resta sua**.

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

## La campanella e i link

Due cose che tengono in piedi il giro, e nessuna delle due richiede un server
acceso.

**La campanella** in cima alla home dice cosa hanno fatto gli altri, e in cima
ha **due parole: missioni e fiamme**. Una delle due e' sempre scelta — il
"tutto" di prima rimetteva insieme proprio quello che le due sezioni servivano a
separare — e il rosso li' dice due cose che non si accavallano: **il colore
della parola** dice quale si sta guardando, **il numero accanto** quante notizie
nuove ci sono la' dentro. Le gia' lette non si contano: un numero che non cala
mai smette di voler dire qualcosa dopo due giorni.

**Le richieste di amicizia non ci sono piu'**, ed e' voluto: stanno gia' nella
scheda Amici, con i due comandi per accettare o rifiutare. Tenerne due elenchi
vuol dire doverli tenere d'accordo. E li' dentro, se le richieste in attesa sono
tante, **se ne vedono tre**: con cento in coda l'elenco degli amici finirebbe
due schermate piu' giu', e la scheda smetterebbe di servire a quello per cui
esiste.

Oltre la settimana una notizia non e' piu' una notizia: **le vecchie si chiudono
in una riga sola** in fondo, e si aprono con un tocco. Nessuno scorre la
campanella per rileggersi le fiamme del mese scorso.

Dentro ci finiscono cinque cose: chi partecipa alle tue challenge, chi accende
una fiamma sulle tue foto, quando vinci, **quando una gara a cui hai partecipato
e' finita e qualcuno sta scegliendo**, e **quando tocca a te scegliere**.

Le prime due **le scrive chi le provoca** — senza Cloud Function nessun altro
puo' accorgersene — e il nome del documento e' sempre lo stesso per la stessa
coppia persona-foto: chi toglie e rimette una fiamma venti volte manda una
notifica sola. **Le altre tre non stanno sul database affatto**: si ricavano da
dati che esistono gia', perche' una copia puo' andare fuori sincrono con la cosa
che racconta.

Quella per chi deve scegliere **si ripete**, ed e' il pezzo di cui vado piu'
fiero perche' non costa niente: la sua data non e' l'ora in cui la gara e'
finita, **avanza di sei ore in sei ore**. A ogni scatto torna a contare come non
letta, il pallino rosso sulla campanella si riaccende, e smette da sola nel
momento esatto in cui il premio viene assegnato — senza una riga scritta da
nessuna parte, senza una coda di avvisi da spedire, senza niente da ripulire se
uno sceglie prima.

**Il link a una foto** e' la porta d'ingresso dell'app. Da una foto a schermo
intero si condivide un indirizzo che porta *a quella foto*, non alla home. Chi
lo riceve la vede, e per accendere la fiamma deve registrarsi — e finita la
registrazione **torna esattamente li'**, non sulla home. Chi e' in gara ha un
motivo vero per portare gente dentro: non lo fa per farci un favore, lo fa
perche' vuole vincere.

---

## Cosa non c'e' ancora

Detto chiaramente, perche' un README che tace su questo fa perdere tempo:

- **Il pagamento dei premi e' scritto ma spento.** Il giro completo — incasso,
  soldi trattenuti, accredito al vincitore, rimborso se non partecipa nessuno —
  c'e' tutto (vedi *I soldi*), e gli mancano tre cose che il codice non puo'
  darsi da solo: il piano Blaze, un account Stripe con partita IVA, e una
  risposta al nodo legale dei concorsi a premi. Finche' e' spento, chi lancia
  una challenge paga di tasca propria e CRASY non fa da garante.
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
