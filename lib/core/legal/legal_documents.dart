/// I testi legali di CRASY e i consensi che si chiedono all'ingresso.
///
/// ## Cosa sono questi testi, detto chiaro
///
/// **Sono una bozza, e vanno fatti rivedere da un avvocato prima di aprire
/// l'app al pubblico.** Sono scritti sui dati che CRASY raccoglie davvero — non
/// copiati da un'altra app — e coprono la struttura giusta: finalita', basi
/// giuridiche, tempi di conservazione, destinatari, diritti. Ma un testo scritto
/// bene non e' un testo firmato da chi se ne assume la responsabilita'
/// professionale, e in caso di contestazione e' la seconda cosa che conta.
///
/// Servono a far risparmiare tempo e soldi a chi li rivedera': correggere una
/// bozza precisa costa una frazione di scriverne una da zero.
///
/// La versione porta la parola `bozza` apposta. Quando arriva il testo
/// dell'avvocato si mette `1.0`, e siccome **cambiare versione fa richiedere di
/// nuovo il consenso a tutti** (vedi [LegalTexts.version]), nessuno resta
/// legato a una versione che nel frattempo e' stata sostituita.
library;

/// Le cose che si spuntano prima di entrare.
///
/// **Non e' un unico "accetto tutto", ed e' il punto.** Il GDPR non ammette il
/// consenso in blocco quando i trattamenti sono diversi: chi accetta le regole
/// del servizio non sta accettando la pubblicita' personalizzata, e mettere le
/// due cose sotto la stessa spunta rende **invalide tutte e due**.
///
/// Le prime quattro sono obbligatorie e non sono tutte "consenso" in senso
/// tecnico: termini ed eta' sono condizioni del contratto, l'informativa
/// privacy si **prende visione** (non si consente), e l'uso dei contenuti e' la
/// licenza che serve a far funzionare il servizio. Le ultime due sono consenso
/// vero, quindi facoltative e revocabili in qualunque momento.
enum LegalConsent {
  terms(
    label: 'Termini e Condizioni',
    required: true,
    explanation:
        'Regolano l\'uso dell\'app, la partecipazione alle missioni, la '
        'pubblicazione dei contenuti e i rapporti fra te e CRASY.',
  ),

  privacy(
    label: 'Informativa Privacy',
    required: true,
    explanation:
        'Dichiari di aver letto come trattiamo i tuoi dati ai sensi del '
        'Regolamento UE 2016/679: account, partecipazione alle missioni, '
        'sicurezza della piattaforma e pagamento dei premi.',
  ),

  content(
    label: 'Uso di foto e video',
    required: true,
    explanation:
        'Autorizzi CRASY a ospitare e mostrare dentro l\'app i contenuti che '
        'carichi, solo per far funzionare le missioni. Restano tuoi.',
  ),

  age(
    label: 'Ho almeno 18 anni',
    required: true,
    explanation:
        'Qui girano soldi veri. Dichiari di essere maggiorenne e che i dati '
        'che ci dai sono veri.',
  ),

  /// **Facoltativo.** Deve poter essere rifiutato senza perdere niente: un
  /// consenso che se non lo dai non entri non e' libero, quindi non e' valido.
  marketing(
    label: 'Comunicazioni commerciali',
    required: false,
    explanation:
        'Ricevere da CRASY novita\', offerte e contenuti promozionali. Puoi '
        'toglierlo quando vuoi dal tuo profilo.',
  ),

  /// **Facoltativo.** L'analisi del comportamento per personalizzare contenuti
  /// e pubblicita' e' profilazione, e per il Garante richiede una scelta
  /// separata e specifica.
  profiling(
    label: 'Contenuti su misura',
    required: false,
    explanation:
        'Analizzare come usi CRASY per mostrarti missioni e pubblicita\' piu\' '
        'vicine ai tuoi gusti. Puoi toglierlo quando vuoi.',
  );

  const LegalConsent({
    required this.label,
    required this.required,
    required this.explanation,
  });

  final String label;

  /// Se senza questa spunta non si entra.
  final bool required;

  /// La riga sotto l'etichetta: cosa stai accettando, in parole tue.
  final String explanation;

  /// Il documento che questa spunta apre, quando ce n'e' uno.
  LegalDocument? get document => switch (this) {
    LegalConsent.terms => LegalTexts.terms,
    LegalConsent.privacy => LegalTexts.privacy,
    LegalConsent.content => LegalTexts.contentLicense,
    _ => null,
  };

  static List<LegalConsent> get mandatory =>
      values.where((consent) => consent.required).toList();

  static List<LegalConsent> get optional =>
      values.where((consent) => !consent.required).toList();
}

/// Un documento da leggere per esteso.
class LegalDocument {
  const LegalDocument({required this.title, required this.body});

  final String title;

  /// Il testo, gia' a capo dove serve. Niente markup: si legge in un foglio
  /// che sale dal basso, non in una pagina web.
  final String body;
}

abstract final class LegalTexts {
  /// **La versione del pacchetto legale.**
  ///
  /// E' una stringa sola per tutti e tre i documenti, di proposito: se cambia
  /// anche solo una riga della privacy, cambia la versione, e l'app **richiede
  /// il consenso a tutti** prima di lasciarli rientrare. Tenere tre versioni
  /// separate sembra piu' preciso ma introduce il caso peggiore — qualcuno che
  /// resta legato a un testo che non esiste piu' perche' nessuno si e' ricordato
  /// di alzare il suo numero.
  ///
  /// Con la parola `bozza` dentro finche' i testi non sono quelli di un legale.
  static const String version = '0.2-bozza';

  /// Chi risponde di questi dati. **Da completare con i dati veri prima di
  /// aprire al pubblico**: senza titolare identificabile l'informativa non e'
  /// valida.
  static const String controller =
      'CRASY — titolare del trattamento: [ragione sociale, indirizzo, P.IVA]\n'
      'Contatto per la privacy: [indirizzo email dedicato]';

  static const String draftWarning =
      'Documento in versione di prova per la fase beta. Il testo definitivo '
      'sara\' pubblicato prima dell\'apertura al pubblico, e ti verra\' chiesto '
      'di prenderne visione.';

  static const terms = LegalDocument(
    title: 'Termini e Condizioni',
    body:
        '''
$draftWarning

1. COS'E' CRASY
CRASY e' un'applicazione in cui una persona lancia una missione mettendo in
palio del denaro e altre persone vi partecipano con una foto o un video. Alla
scadenza il premio va all'opera che ha ricevuto piu' apprezzamenti dagli altri
utenti. Non e' un gioco
di sorte e non e' una scommessa: l'esito dipende dal valore riconosciuto
all'opera, non dal caso, e non si paga nulla per partecipare.

2. CHI PUO' ISCRIVERSI
Solo chi ha compiuto 18 anni. Un account per persona, con dati veri. Un account
puo' essere sospeso o chiuso se i dati sono falsi, se si creano piu' account per
la stessa persona o se si violano queste regole.

3. PARTECIPARE
La partecipazione e' gratuita. Ogni giorno si puo' partecipare a un numero
limitato di missioni e si dispone di un numero limitato di fiamme per missione:
i limiti sono indicati nell'app e possono cambiare.
E' vietato partecipare con contenuti non propri, con contenuti che ritraggono
altre persone senza il loro consenso, con contenuti illegali, violenti, sessuali,
diffamatori o che mettano in pericolo chi li realizza.

4. IL PREMIO
Chi lancia la missione mette in palio una somma e la paga tramite Stripe,
l'istituto di pagamento di cui CRASY si serve. Fino alla chiusura della
missione la somma resta sul conto di pagamento di CRASY presso Stripe. Alla
scadenza il premio va alla partecipazione che ha ricevuto piu' fiamme dagli
altri utenti; a parita' di fiamme vince chi ha inviato per primo.

CRASY riceve il premio **in nome e per conto di chi lo ha messo in palio**, al
solo scopo di consegnarlo al vincitore. Quelle somme non sono ricavi di CRASY e
restano di chi le ha versate fino al momento in cui vengono trasferite al
vincitore. Il corrispettivo di CRASY e' unicamente la percentuale trattenuta
sul premio, indicata nell'app prima del pagamento; il resto va al vincitore.

Le somme ricevute dal vincitore sono corrispettivi per un'opera: possono avere
rilevanza fiscale per chi le riceve, ed e' responsabilita' del percettore
dichiararle secondo la normativa applicabile.

5. IL CONTO PER RICEVERE I PREMI
Per partecipare alle missioni con un premio in denaro serve un conto di
pagamento a proprio nome presso Stripe (servizio Stripe Connect). Si apre una
volta, fornendo i dati richiesti dalla legge per chi riceve denaro: identita',
codice fiscale, IBAN e, quando Stripe lo richiede, un documento d'identita'. Il
conto e' intestato a chi lo apre ed e' regolato dalle condizioni di Stripe, che
si accettano aprendolo.

CRASY non custodisce le somme vinte. Alla chiusura della missione il premio, al
netto della percentuale di CRASY, viene trasferito sul conto Stripe del
vincitore. Da li' il vincitore puo' trasferirlo sul proprio conto bancario a
partire dall'importo minimo indicato nell'app. Le somme possono diventare
disponibili alcuni giorni dopo la vittoria, secondo i tempi di Stripe.

Se il trasferimento non e' possibile, per esempio perche' il conto non e'
ancora stato aperto, CRASY tiene la somma in nome e per conto del vincitore
finche' il trasferimento diventa possibile, oppure gliela versa con bonifico
sul conto bancario da lui indicato.

6. USARE I PREMI PER LANCIARE UNA MISSIONE
Chi ne da' espresso consenso nell'app autorizza CRASY ad addebitare sul proprio
conto Stripe l'importo del premio di una missione che sceglie di pagare con il
proprio saldo: solo nel momento in cui lo sceglie, e solo per quella missione.
Il consenso si puo' revocare in qualunque momento scrivendo al contatto
indicato; la revoca non riguarda le missioni gia' pagate.

7. QUANDO IL PREMIO TORNA INDIETRO
Se alla missione non partecipa nessuno, il premio torna per intero a chi lo
aveva messo, spese comprese.

Se invece e' chi ha lanciato la missione a cancellarla, torna indietro il
premio: restano fuori le spese del pagamento, gia' sostenute e non
recuperabili, e la percentuale di CRASY. Una missione non si puo' cancellare
dal momento in cui qualcuno vi ha partecipato.

I rimborsi vengono disposti subito ma l'accredito sulla carta dipende dalla
banca di chi lo riceve, e richiede di norma alcuni giorni lavorativi.

8. LE MISSIONI VIETATE
Non si possono lanciare missioni che chiedano di compiere reati, di mettersi in
pericolo, di farsi del male, di molestare o riprendere persone che non hanno
acconsentito, o che abbiano contenuto sessuale. CRASY puo' rimuovere una
missione e restituire il premio a chi l'ha messo.

9. MODERAZIONE
CRASY puo' rimuovere contenuti e sospendere account che violano queste regole,
anche senza preavviso quando il contenuto e' gravemente lesivo. Chi ritiene la
rimozione sbagliata puo' contestarla scrivendo al contatto indicato.

10. RESPONSABILITA'
CRASY mette a disposizione una piattaforma. Quello che le persone fanno per
partecipare lo fanno sotto la propria responsabilita': CRASY non e' il datore di
lavoro di nessuno e non e' presente quando un contenuto viene realizzato.
CRASY non risponde di danni derivanti da condotte imprudenti o illecite di chi
partecipa, ne' dei rapporti fra utenti.
Nulla in queste condizioni esclude o limita la responsabilita' che la legge non
consente di escludere, in particolare verso i consumatori.

11. CHIUDERE L'ACCOUNT
Si puo' chiudere il proprio account in qualunque momento. Le somme gia'
maturate restano dovute: quelle sul conto Stripe restano del titolare del
conto, e vanno trasferite sul proprio conto bancario prima della chiusura. I
contenuti gia' pubblicati vengono rimossi secondo quanto indicato
nell'informativa privacy.

12. MODIFICHE
Queste condizioni possono cambiare. Le modifiche rilevanti vengono comunicate e
richiedono una nuova accettazione prima di continuare a usare l'app.

13. LEGGE E FORO
Si applica la legge italiana. Per i consumatori resta ferma la competenza del
giudice del luogo di residenza o domicilio.
''',
  );

  static const privacy = LegalDocument(
    title: 'Informativa Privacy',
    body:
        '''
$draftWarning

TITOLARE DEL TRATTAMENTO
$controller

QUALI DATI TRATTIAMO
- Dati di account: indirizzo email, password (custodita in forma cifrata da
  Firebase Authentication), nome utente, data di nascita.
- Dati di profilo, se li inserisci: una riga di descrizione, la citta', la foto
  profilo.
- Contenuti che carichi: foto e video mandati alle missioni, con la loro data.
- Attivita' nell'app: missioni lanciate, partecipazioni, fiamme date, amicizie,
  notifiche.
- Dati di pagamento: gestiti dal fornitore del servizio di pagamento. CRASY non
  conserva i numeri delle carte.
- Dati tecnici: registri di accesso e di errore necessari a far funzionare e
  proteggere il servizio.

Non chiediamo e non vogliamo categorie particolari di dati (articolo 9 GDPR):
salute, convinzioni religiose, opinioni politiche, orientamento sessuale, dati
biometrici. Non caricare contenuti che li rivelino.

PERCHE' LI TRATTIAMO, E CON QUALE BASE GIURIDICA
- Creare e gestire il tuo account, farti partecipare alle missioni, pagarti i
  premi: esecuzione del contratto (art. 6.1.b).
- Verificare che tu sia maggiorenne: obbligo di legge e tutela dei minori
  (art. 6.1.c e 6.1.f).
- Sicurezza, prevenzione di frodi e di account multipli, moderazione dei
  contenuti: legittimo interesse a un servizio onesto (art. 6.1.f).
- Obblighi fiscali e contabili sui pagamenti: obbligo di legge (art. 6.1.c).
- Comunicazioni commerciali e contenuti personalizzati: **consenso** (art.
  6.1.a), facoltativo e revocabile in qualunque momento senza perdere l'accesso
  al servizio.

CHI PUO' VEDERE COSA
Il tuo nome utente, la foto profilo, i contenuti che mandi alle missioni e i
premi che vinci sono visibili agli altri iscritti. L'indirizzo email e la data
di nascita non sono mai visibili ad altri utenti.

A CHI COMUNICHIAMO I DATI
A fornitori che trattano i dati per nostro conto, nominati responsabili ai sensi
dell'art. 28 GDPR: Google (Firebase: autenticazione, database, archiviazione
file, hosting) e il fornitore dei pagamenti. Alcuni di questi possono trattare
dati fuori dallo Spazio economico europeo: in quel caso il trasferimento avviene
sulla base delle clausole contrattuali tipo approvate dalla Commissione europea.
Non vendiamo i tuoi dati a nessuno.

PER QUANTO TEMPO LI TENIAMO
- Account e profilo: finche' l'account esiste.
- Foto e video delle missioni: le partecipazioni che non hanno vinto vengono
  cancellate poco dopo la chiusura della missione. La foto vincitrice resta come
  trofeo nel profilo di chi ha vinto e di chi ha commissionato la missione.
- Dati di pagamento e documenti contabili: per il tempo imposto dalla legge
  fiscale.
- Registri tecnici di sicurezza: per il tempo necessario a individuare abusi.
Chiudendo l'account i dati vengono cancellati, salvo quelli che siamo obbligati
a conservare per legge.

I TUOI DIRITTI
Puoi chiedere in qualunque momento di accedere ai tuoi dati, correggerli,
cancellarli, limitarne il trattamento, riceverli in formato leggibile
(portabilita') e opporti a trattamenti fondati sul legittimo interesse. Puoi
revocare i consensi facoltativi dal tuo profilo, con la stessa facilita' con cui
li hai dati.
Se ritieni che i tuoi dati siano trattati in modo scorretto puoi rivolgerti al
Garante per la protezione dei dati personali (www.garanteprivacy.it) o
all'autorita' giudiziaria.

DECISIONI AUTOMATIZZATE
Il vincitore di una missione e' determinato dal conteggio delle preferenze
espresse dagli altri utenti, non da un programma che valuta i tuoi dati
personali. Non analizziamo il tuo comportamento per decidere l'esito di una
missione.
''',
  );

  static const contentLicense = LegalDocument(
    title: 'Uso di foto e video',
    body:
        '''
$draftWarning

I CONTENUTI RESTANO TUOI
Le foto e i video che carichi restano tuoi. Non ne acquistiamo la proprieta' e
non li vendiamo.

COSA CI AUTORIZZI A FARE
Ci autorizzi a conservarli, mostrarli e renderli visibili agli altri iscritti
dentro CRASY, per il tempo necessario a far funzionare la missione a cui li hai
mandati e le funzioni collegate — la classifica, il profilo, i trofei. E'
un'autorizzazione gratuita, non esclusiva e limitata a questo scopo.

CHI HA COMMISSIONATO LA MISSIONE
Se la tua opera vince, resta visibile anche nel profilo di chi ha lanciato la
missione, indicata come opera commissionata da lui e realizzata da te. E' la
sostanza di quello che e' successo: qualcuno ha chiesto un'opera, tu l'hai fatta
e sei stato pagato.

FUORI DA CRASY
Non usiamo i tuoi contenuti in pubblicita' o su altri canali senza chiedertelo
prima con un consenso specifico.

COSA GARANTISCI TU
Che il contenuto e' opera tua, che hai il diritto di caricarlo, e che le persone
eventualmente riconoscibili hanno acconsentito a comparirvi. Rispondi tu se non
e' cosi'.

QUANDO SPARISCONO
Puoi chiedere in qualunque momento la rimozione di un tuo contenuto. Le
partecipazioni che non hanno vinto vengono cancellate poco dopo la fine della
missione; la foto vincitrice resta come trofeo finche' non ne chiedi la
rimozione o chiudi l'account.
''',
  );

  /// **Il regolamento delle missioni, da leggere dentro l'app.**
  ///
  /// Lo chiede Apple a chi fa gare con dei premi: le regole ufficiali devono
  /// stare nell'app e dire chiaramente che Apple non e' sponsor e non c'entra
  /// (linea guida 5.3.2). Google chiede lo stesso.
  ///
  /// **Non e' un documento in piu' da accettare.** Racconta in ordine le regole
  /// che l'app applica gia' — chi partecipa, come si vince, dove va il premio —
  /// e per tutto il resto rimanda ai Termini. Per questo non sta nel pacchetto
  /// di [version]: cambiarlo non chiede di nuovo il consenso a nessuno.
  /// Quello che dice deve restare vero rispetto al codice: chi cambia una
  /// regola delle gare cambia anche questa pagina.
  static const regolamento = LegalDocument(
    title: 'Regolamento delle missioni',
    body:
        '''
$draftWarning

1. CHI ORGANIZZA
Le missioni si svolgono su CRASY, che ne stabilisce le regole, raccoglie le
partecipazioni, conta i voti e consegna i premi.
Organizzatore: CRASY — [ragione sociale, indirizzo, P.IVA].

2. APPLE E GOOGLE NON C'ENTRANO
Apple Inc. e Google LLC non sono sponsor delle missioni e non sono coinvolte in
alcun modo nella loro organizzazione, nella scelta dei vincitori o nella
consegna dei premi. Per qualunque domanda sulle missioni ci si rivolge a CRASY.

3. CHI PUO' PARTECIPARE
Chi ha compiuto 18 anni e ha un account CRASY. Partecipare e' gratuito: non si
paga nulla per entrare in una missione. Chi lancia una missione non puo'
parteciparvi. Ogni giorno si puo' partecipare a un numero limitato di missioni,
indicato nell'app, e a ogni missione si partecipa una volta sola.

4. COME SI PARTECIPA
Si manda una foto o un video entro la scadenza, seguendo la consegna della
missione. Il contenuto dev'essere proprio e rispettare i Termini e Condizioni
(punto 3). Finche' la missione e' aperta si puo' ritirare la propria
partecipazione.

5. COME SI VINCE
Per ogni missione ognuno ha un numero limitato di fiamme da dare alle foto
degli altri; alla propria non si puo' dare. Alla scadenza vince la
partecipazione con piu' fiamme; a parita' di fiamme vince chi l'ha inviata per
prima. Non c'e' nessuna estrazione e nessun elemento di sorte.
Casi particolari:
- se partecipa una sola persona, chi ha lanciato la missione ha 48 ore per dire
  se la foto vale; se non risponde, vince chi ha partecipato;
- nelle missioni fra amici il vincitore lo sceglie chi le ha lanciate, entro 48
  ore; se non sceglie, decidono le fiamme;
- nelle sfide a una persona, chi le ha lanciate ha 24 ore per dire se la foto
  vale; se non risponde e la sfida ha un premio, il premio va a chi l'ha
  portata a termine.
Una partecipazione tolta dalla moderazione non puo' vincere.

6. IL PREMIO
Il premio lo mette chi lancia la missione, e lo paga prima che la missione
parta. Al vincitore va il premio meno la percentuale di CRASY, indicata
nell'app prima del pagamento. Il premio arriva sul conto di pagamento a nome
del vincitore presso Stripe (Termini e Condizioni, punto 5); da li' si
trasferisce sul proprio conto bancario a partire dall'importo minimo indicato
nell'app. Se nessuno partecipa, il premio torna per intero a chi l'aveva messo.

7. MODERAZIONE
Le foto possono essere controllate in automatico e segnalate dagli altri
utenti. Chi si vede togliere una foto riceve un avviso con il motivo e puo'
chiedere che la riguardi una persona del team.

8. IL RESTO
Per tutto quello che non e' scritto qui valgono i Termini e Condizioni.
''',
  );
}
