import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_source.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';
import 'package:crasy/features/payments/domain/prize_ledger.dart';

/// Una challenge: una consegna, una scadenza, dei soldi in palio.
///
/// E' l'oggetto attorno a cui gira tutto il prodotto, e ha volutamente pochi
/// campi. Le quattro cose che l'utente deve capire in due secondi — **quanto si
/// vince, cosa bisogna fare, quanto tempo resta, quanti stanno gia' giocando** —
/// sono quattro campi qui dentro, e nessuno di essi e' calcolato altrove o
/// nascosto in una mappa di metadati.
class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.brief,
    required this.prizeCents,
    required this.scope,
    required this.startsAt,
    required this.endsAt,
    this.place = '',
    this.rules = const [],
    this.mediaKind = MediaKind.photo,
    this.source = ChallengeSource.instant,
    this.createdByUsername = '',
    this.createdByUserId = '',
    this.participantsCount = 0,
    this.winnerEntryId,
    this.winnerUserId = '',
    this.winnerUsername = '',
    this.winnerMediaUrl = '',
    this.winnerMediaKind = MediaKind.photo,
    this.winnerVotes = 0,
    this.prizeStatus = PrizeStatus.unpaid,
    this.isDaily = false,
    this.audience = const [everyone],
    this.maxParticipants = 0,
  });

  /// L'identificativo dell'account di CRASY.
  ///
  /// Non e' un utente vero e **non esiste nessuna password che ci entri**: e'
  /// un nome scritto dentro le sfide del giorno perche' abbiano una faccia e un
  /// profilo come tutti gli altri. Il documento del profilo lo scrive lo
  /// strumento che genera le sfide, con l'icona dell'app come fotografia.
  static const String crasyUserId = 'crasy';

  /// A quante gare si puo' partecipare **in un giorno**.
  ///
  /// **Cinque, e poi si aspetta domani.** Senza un tetto, l'unica strategia che
  /// paga e' partecipare a tutto: si mandano venti scatti fatti male sperando
  /// che uno prenda delle fiamme per caso, e chi guarda si trova un elenco di
  /// roba buttata li'. Con cinque in mano bisogna scegliere **a quali gare
  /// tiene davvero**, che e' la stessa cosa che fanno le tre fiamme dall'altra
  /// parte del tavolo.
  ///
  /// Il conto e' sul giorno di calendario, ora locale: a mezzanotte tornano
  /// tutte e cinque. Non e' una finestra mobile di ventiquattro ore — quella
  /// costringerebbe a ricordarsi a che ora si e' partecipato ieri, e nessuno lo
  /// fa.
  static const int livesPerDay = 5;

  /// Quante fiamme ha ciascuno **dentro una singola gara**.
  ///
  /// **Tre, e poi si e' finito.** Non e' un limite tecnico: e' quello che
  /// trasforma il voto in una scelta. Potendo accendere tutto, l'unica cosa
  /// che un voto misura e' quante foto uno ha avuto la pazienza di guardare —
  /// e con dei soldi in palio, "mi piacciono tutte" non decide niente. Con tre
  /// in mano bisogna guardarle davvero e mettere le proprie da parte.
  ///
  /// Il conto e' **per gara**: finite qui, nella challenge accanto se ne hanno
  /// altre tre. E resta ferma la regola di sempre — **una sola per foto**, che
  /// non e' questa: quella e' scritta nella forma dei dati, il nome del voto,
  /// e la garantisce il database.
  ///
  /// Chi toglie una fiamma se la riprende: il conto e' di quante ne stanno
  /// accese, non di quante volte si e' toccato.
  static const int firesPerChallenge = 3;

  /// **A decidere chi vince sono le fiamme, e solo quelle.**
  ///
  /// C'e' stato un periodo in cui sceglieva chi aveva messo i soldi, con
  /// ventiquattro ore di tempo. L'idea reggeva sulla carta — chi paga sta
  /// commissionando una cosa precisa, e la piu' votata non e' sempre quella che
  /// aveva chiesto — e non reggeva nell'uso: fra la fine della gara e il
  /// verdetto passava un giorno intero di silenzio, chi aveva partecipato non
  /// sapeva se e quando, e chi aveva lanciato la gara si dimenticava. Il premio
  /// finiva comunque al piu' votato, ma dopo ventiquattro ore di niente.
  ///
  /// Adesso la gara si chiude quando finisce, e vince chi ha piu' fiamme.
  /// Le fiamme tornano a essere la cosa che decide, il che le rende anche il
  /// motivo per cui vale la pena guardare le foto degli altri.

  /// Per quanto una gara finita resta visibile fra i vincitori.
  ///
  /// **Due giorni, e poi sparisce.** Non e' una scelta estetica: una gara
  /// chiusa e' un pezzo di storia che non serve piu' a nessuno — chi voleva
  /// vedere chi ha vinto lo ha visto — e tenerle tutte vuol dire una schermata
  /// che si allunga per sempre e un database che cresce senza che niente lo
  /// svuoti mai.
  ///
  /// Lo stesso numero decide **due cose diverse**, e devono restare la stessa:
  /// quanto si vedono qui, e dopo quanto il server le cancella davvero insieme
  /// alle foto. Se la seconda fosse piu' corta della prima, la schermata
  /// mostrerebbe gare i cui file non ci sono piu'. Vedi `purgeOldChallenges`
  /// in `functions/index.js`.
  static const Duration winnersWindow = Duration(hours: 48);

  final String id;

  /// Il titolo, corto e in maiuscolo nell'interfaccia: `DO SOMETHING CRAZY`.
  final String title;

  /// La consegna per esteso: cosa bisogna fare, in una frase.
  final String brief;

  /// **Chi puo' vedere questa gara.**
  ///
  /// `['*']` vuol dire tutti. Una gara riservata porta invece dentro di se'
  /// l'elenco di chi la puo' leggere — chi l'ha lanciata piu' i suoi amici del
  /// momento in cui l'ha lanciata.
  ///
  /// **Sta scritto nel documento e non calcolato al momento**, e la ragione e'
  /// che le regole di Firestore devono poter decidere guardando **solo quel
  /// documento**: andare a leggere altrove l'elenco degli amici, per ogni gara
  /// di ogni schermata, costerebbe una lettura in piu' a testa e sfonderebbe i
  /// limiti che Firestore mette alle regole. Con l'elenco dentro, ogni query
  /// chiede esattamente quello che ha diritto di vedere.
  final List<String> audience;

  /// Il valore che, dentro [audience], vuol dire "la vedono tutti".
  static const String everyone = '*';

  /// I tetti fra cui si sceglie quando si lancia una gara.
  ///
  /// **Tre scelte, e nessuna senza limite.** Lasciato libero, uno scrive tre e
  /// un altro cinquecento: il primo fa una gara che si chiude prima che
  /// qualcuno la veda, il secondo rimette in piedi il problema che il tetto
  /// doveva risolvere.
  ///
  /// Anche "senza limite" era quel secondo caso, scritto con altre parole: con
  /// cinquecento foto non le guarda nessuno fino in fondo, si vota fra le prime
  /// che capitano, e vince la posizione nella lista invece di quello che uno ha
  /// fatto. Lo zero resta un valore valido — le gare lanciate prima ce l'hanno
  /// dentro e continuano a funzionare — ma non si puo' piu' scegliere.
  static const List<int> participantCaps = [10, 25, 50];

  /// **La sfida del giorno di CRASY: gratis, e non consuma una partecipazione.**
  ///
  /// E' l'unica gara che non nasce da una persona. Non ha un premio in denaro, e
  /// non e' una scelta di risparmio: **una societa' che promette un premio fa un
  /// concorso a premi**, con comunicazione al ministero, cauzione, verbale e
  /// ritenuta. Senza premio non c'e' niente da notificare, e resta quello per
  /// cui esiste — un appuntamento, uguale per tutti, che cambia a mezzanotte.
  ///
  /// Non toglie nessuna delle cinque del giorno, e anche questo e' voluto: le
  /// cinque servono a far scegliere fra gare in cui girano soldi. Questa non e'
  /// una di quelle, e farla pesare quanto loro vorrebbe dire far pagare in
  /// occasioni vere una cosa fatta per divertimento.
  final bool isDaily;

  /// Il premio in **centesimi**.
  ///
  /// Interi e non decimali: un premio in denaro tenuto in `double` prima o poi
  /// diventa `499.99999`, ed e' il numero piu' letto dell'app.
  final int prizeCents;

  final ChallengeScope scope;

  /// Il luogo, quando ce n'e' uno: `NAPOLI`, `MILANO`.
  final String place;

  /// Le regole, una per riga. Poche e secche.
  final List<String> rules;

  /// Cosa bisogna mandare: una foto o un video.
  ///
  /// Lo decide chi lancia la challenge, e vale per tutti: una gara in cui
  /// arrivano foto e video insieme non e' confrontabile, e alla fine si
  /// pagherebbe un premio scegliendo fra mele e pere.
  final MediaKind mediaKind;

  /// **Da dove deve arrivare la roba: scattata adesso, o presa dall'archivio.**
  ///
  /// La decide chi lancia la gara, e chi partecipa non la puo' aggirare: in una
  /// istantanea la galleria non si apre, in una d'archivio la fotocamera non si
  /// apre. Vedi [ChallengeSource], dove sta scritto perche' le due strade non
  /// si mescolano mai.
  final ChallengeSource source;

  /// Il nome di chi ha lanciato la challenge.
  ///
  /// Chi la crea **non allega nessuna foto**: mette in palio dei soldi e detta
  /// una consegna, e basta. La faccia della gara la mettono i partecipanti — e'
  /// la foto in testa a decidere come si presenta la challenge, e cambia da sola
  /// man mano che qualcuno fa di meglio.
  final String createdByUsername;

  /// L'identificativo di chi l'ha creata, per quando ci sara' una pagina da
  /// aprire. Vuoto per le challenge lanciate da CRASY.
  final String createdByUserId;

  bool get hasCreator => createdByUsername.isNotEmpty;

  /// L'ha lanciata CRASY.
  bool get byCrasy => createdByUserId == crasyUserId;

  /// **Quante persone possono partecipare, al massimo.** Zero vuol dire senza
  /// limite.
  ///
  /// Non e' un limite tecnico, e' il cuore del gioco. Con cinquecento foto
  /// nessuno vota il merito: si guardano le prime cinque, si da' la fiamma li'
  /// e si scorre — e il vincitore lo decide la posizione nella lista, non
  /// quello che ha fatto. Con dieci si guardano tutte, e il voto torna a
  /// significare qualcosa.
  ///
  /// E c'e' l'altra meta': **un euro fra dieci persone e' una scommessa, un
  /// euro fra cinquecento e' una presa in giro.** Chi partecipa se ne accorge
  /// alla seconda volta, e alla terza non partecipa piu'.
  ///
  /// In cambio arriva l'urgenza: "restano tre posti" e' il motivo piu' forte
  /// che esista per partecipare adesso invece che stasera.
  final int maxParticipants;

  /// Quanti posti restano, o `null` se non c'e' un tetto.
  int? get spotsLeft {
    if (maxParticipants <= 0) {
      return null;
    }

    final left = maxParticipants - participantsCount;

    return left < 0 ? 0 : left;
  }

  /// Non si puo' piu' entrare: i posti sono finiti.
  bool get isFull => spotsLeft == 0;

  /// La gara e' finita.
  bool get isOver => hasEndedAt(DateTime.now());

  /// Quanti sono in gara, e quanti posti restano: `7 IN GARA · 3 POSTI`.
  ///
  /// **Si scrive dove prima c'era la classifica.** A gara aperta chi guarda
  /// vuole sapere due cose per decidere se entrare — quanta concorrenza c'e' e
  /// se c'e' ancora posto — e nessuna delle due dice come sta andando a
  /// qualcuno.
  String get crowdLabel {
    final quanti = '$participantsCount IN GARA';
    final posti = spotsLeft;

    if (posti == null) {
      return quanti;
    }

    return posti == 0 ? '$quanti · AL COMPLETO' : '$quanti · $posti POSTI';
  }

  /// E' riservata agli amici di chi l'ha lanciata.
  bool get isForFriends => scope == ChallengeScope.friends;

  final DateTime startsAt;
  final DateTime endsAt;

  final int participantsCount;

  /// La partecipazione vincente, quando la challenge e' chiusa e il vincitore
  /// e' stato proclamato. Nulla prima.
  final String? winnerEntryId;

  /// Chi ha vinto, e con cosa. **Copiato qui dentro apposta.**
  ///
  /// Sono gli stessi dati che stanno gia' nella partecipazione vincente, e la
  /// duplicazione e' il punto: quarantotto ore dopo la fine, la gara sparisce
  /// dalla vetrina e le partecipazioni vengono cancellate insieme alle foto —
  /// e con loro sparirebbe **la prova di aver vinto**. Uno si porta a casa
  /// cinquanta euro e due giorni dopo nel suo profilo non c'e' piu' niente che
  /// lo dica.
  ///
  /// Ricopiando qui la foto che ha vinto, il trofeo vive nel documento della
  /// gara e non nella partecipazione: si tiene **una foto per gara** invece di
  /// quaranta, e nessuna pulizia se la porta via.
  final String winnerUserId;
  final String winnerUsername;
  final String winnerMediaUrl;
  final MediaKind winnerMediaKind;

  /// Le fiamme che quella foto aveva alla fine. Congelate: dopo la
  /// proclamazione non si vota piu', quindi e' un numero definitivo.
  final int winnerVotes;

  /// Se questa gara ha prodotto un trofeo da mettere in bacheca.
  ///
  /// Non basta che sia chiusa: una gara a cui non ha partecipato nessuno si
  /// chiude con il vincitore vuoto, ed e' giusto che non lasci niente.
  bool get hasTrophy =>
      (winnerEntryId ?? '').isNotEmpty && winnerMediaUrl.isNotEmpty;

  /// Quanto e' finito davvero in tasca a chi ha vinto: il premio meno la
  /// percentuale di CRASY. E' il numero che va sulla figurina, perche' e'
  /// quello che uno ha incassato — non quello che era scritto in vetrina.
  int get payoutCents => PrizeLedger.payoutCents(prizeCents);

  /// Dove sono i soldi del premio.
  ///
  /// Lo scrive il server e nessun altro. E' il campo che separa una challenge
  /// vera da una promessa: [PrizeStatus.held] vuol dire che quei soldi sono
  /// gia' stati tolti a qualcuno e stanno fermi fino alla fine della gara.
  final PrizeStatus prizeStatus;

  /// Se questa challenge si puo' mostrare.
  ///
  /// A pagamenti spenti si mostra tutto, perche' non esiste ancora niente che
  /// possa pagare una challenge e nasconderle tutte vorrebbe dire un'app vuota.
  /// Acceso l'interruttore, una challenge non pagata non compare da nessuna
  /// parte — nemmeno a chi l'ha scritta, che la ritrova solo pagando.
  bool get isPayable => !paymentsEnabled || prizeStatus.isVisible;

  /// Il premio gia' scritto: `€500`, o `GRATIS` per la sfida del giorno.
  ///
  /// Sta al posto della cifra e non accanto: quel numero rosso e' la prima cosa
  /// che si legge di una gara, e su questa la risposta alla domanda "quanto si
  /// vince" e' che non si vince niente — si gioca.
  String get prizeLabel =>
      prizeCents == 0 ? 'GRATIS' : AppMoney.format(prizeCents);

  /// L'etichetta dell'ambito: il luogo se c'e', altrimenti la parola di
  /// ripiego dell'ambito.
  String get scopeLabel => place.isNotEmpty ? place : scope.defaultLabel;

  bool isLiveAt(DateTime now) =>
      !now.isBefore(startsAt) && now.isBefore(endsAt);

  bool isUpcomingAt(DateTime now) => now.isBefore(startsAt);

  bool hasEndedAt(DateTime now) => !now.isBefore(endsAt);

  /// Quanto manca alla chiusura. Zero, mai negativo, a challenge conclusa.
  Duration timeLeftAt(DateTime now) {
    final remaining = endsAt.difference(now);

    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Vero per le challenge di esempio, quelle che l'app mostra quando il
  /// database e' ancora vuoto.
  ///
  /// Il segno sta nell'identificativo e non in un campo a parte perche' deve
  /// sopravvivere al passaggio da una schermata all'altra, dove viaggia solo
  /// l'id: chi riceve `demo-global-500` sa gia' che quella challenge non e' su
  /// Firestore, senza doverla ricaricare per scoprirlo.
  /// La gara e' finita e il vincitore non e' ancora stato proclamato.
  ///
  /// Dura un istante: il primo che apre la gara dopo la scadenza la chiude.
  bool awaitingWinnerAt(DateTime moment) =>
      hasEndedAt(moment) && winnerEntryId == null;

  bool get isDemo => id.startsWith(demoIdPrefix);

  static const String demoIdPrefix = 'demo-';

  Challenge copyWith({
    String? id,
    String? title,
    String? brief,
    int? prizeCents,
    ChallengeScope? scope,
    String? place,
    List<String>? rules,
    MediaKind? mediaKind,
    ChallengeSource? source,
    String? createdByUsername,
    String? createdByUserId,
    DateTime? startsAt,
    DateTime? endsAt,
    int? participantsCount,
    String? winnerEntryId,
    String? winnerUserId,
    String? winnerUsername,
    String? winnerMediaUrl,
    MediaKind? winnerMediaKind,
    int? winnerVotes,
    PrizeStatus? prizeStatus,
    bool? isDaily,
    List<String>? audience,
    int? maxParticipants,
  }) {
    return Challenge(
      id: id ?? this.id,
      title: title ?? this.title,
      brief: brief ?? this.brief,
      prizeCents: prizeCents ?? this.prizeCents,
      scope: scope ?? this.scope,
      place: place ?? this.place,
      rules: rules ?? this.rules,
      mediaKind: mediaKind ?? this.mediaKind,
      source: source ?? this.source,
      createdByUsername: createdByUsername ?? this.createdByUsername,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      participantsCount: participantsCount ?? this.participantsCount,
      winnerEntryId: winnerEntryId ?? this.winnerEntryId,
      winnerUserId: winnerUserId ?? this.winnerUserId,
      winnerUsername: winnerUsername ?? this.winnerUsername,
      winnerMediaUrl: winnerMediaUrl ?? this.winnerMediaUrl,
      winnerMediaKind: winnerMediaKind ?? this.winnerMediaKind,
      winnerVotes: winnerVotes ?? this.winnerVotes,
      prizeStatus: prizeStatus ?? this.prizeStatus,
      isDaily: isDaily ?? this.isDaily,
      audience: audience ?? this.audience,
      maxParticipants: maxParticipants ?? this.maxParticipants,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Challenge &&
        other.id == id &&
        other.title == title &&
        other.brief == brief &&
        other.prizeCents == prizeCents &&
        other.scope == scope &&
        other.place == place &&
        other.mediaKind == mediaKind &&
        other.source == source &&
        other.createdByUsername == createdByUsername &&
        other.createdByUserId == createdByUserId &&
        other.startsAt == startsAt &&
        other.endsAt == endsAt &&
        other.participantsCount == participantsCount &&
        other.winnerEntryId == winnerEntryId &&
        other.prizeStatus == prizeStatus;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    brief,
    prizeCents,
    scope,
    place,
    mediaKind,
    source,
    createdByUsername,
    createdByUserId,
    startsAt,
    endsAt,
    participantsCount,
    winnerEntryId,
    prizeStatus,
  );
}
