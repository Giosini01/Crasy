import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';

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
    this.createdByUsername = '',
    this.createdByUserId = '',
    this.participantsCount = 0,
    this.chosenByCreator = false,
    this.winnerEntryId,
    this.prizeStatus = PrizeStatus.unpaid,
  });

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

  /// Quanto tempo ha chi ha lanciato la gara per scegliere il vincitore.
  ///
  /// **A decidere chi vince e' chi ha messo i soldi**, non il conteggio delle
  /// fiamme. Le fiamme restano quello che sono sempre state — il polso di chi
  /// guarda, e la faccia della gara in home — ma il verdetto e' di chi ha
  /// commissionato l'opera. Con un premio in denaro ha senso: chi paga sta
  /// chiedendo una cosa precisa, e la cosa piu' votata non e' sempre quella che
  /// ha chiesto.
  ///
  /// Ventiquattro ore, e non sono un numero a caso: sono la durata tipica di una
  /// gara, quindi chi la lancia sa gia' quanto dura il suo impegno. Passate
  /// quelle **il premio va da solo a chi ha piu' fiamme**: una gara che resta
  /// senza vincitore perche' chi l'ha lanciata si e' distratto e' esattamente
  /// la cosa che fa perdere fiducia a tutti gli altri, ed e' il motivo per cui
  /// questa strada automatica esiste.
  static const Duration decisionWindow = Duration(hours: 24);

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

  final DateTime startsAt;
  final DateTime endsAt;

  final int participantsCount;
  final bool chosenByCreator;

  /// Se il vincitore l'ha **scelto chi ha lanciato la gara**.
  ///
  /// Falso quando il premio e' andato in automatico a chi aveva piu' fiamme,
  /// perche' nessuno ha deciso in tempo. La differenza si scrive sulla
  /// schermata dei vincitori: chi guarda ha diritto di sapere se quel premio
  /// e' stato assegnato o e' semplicemente scaduto.

  /// La partecipazione vincente, quando la challenge e' chiusa e il vincitore
  /// e' stato proclamato. Nulla prima.
  final String? winnerEntryId;

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

  /// Il premio gia' scritto: `€500`.
  String get prizeLabel => AppMoney.format(prizeCents);

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
  /// Entro quando chi ha lanciato la gara puo' scegliere.
  DateTime get decisionDeadline => endsAt.add(decisionWindow);

  /// La gara e' finita e **si aspetta che chi l'ha lanciata scelga**.
  bool waitsForChoiceAt(DateTime moment) {
    return hasEndedAt(moment) &&
        winnerEntryId == null &&
        moment.isBefore(decisionDeadline);
  }

  /// Il tempo scaduto anche per scegliere: da qui il premio va da solo a chi ha
  /// piu' fiamme.
  bool choiceExpiredAt(DateTime moment) {
    return hasEndedAt(moment) &&
        winnerEntryId == null &&
        !moment.isBefore(decisionDeadline);
  }

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
    String? createdByUsername,
    String? createdByUserId,
    DateTime? startsAt,
    DateTime? endsAt,
    int? participantsCount,
    bool? chosenByCreator,
    String? winnerEntryId,
    PrizeStatus? prizeStatus,
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
      createdByUsername: createdByUsername ?? this.createdByUsername,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      participantsCount: participantsCount ?? this.participantsCount,
      chosenByCreator: chosenByCreator ?? this.chosenByCreator,
      winnerEntryId: winnerEntryId ?? this.winnerEntryId,
      prizeStatus: prizeStatus ?? this.prizeStatus,
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
    createdByUsername,
    createdByUserId,
    startsAt,
    endsAt,
    participantsCount,
    winnerEntryId,
    prizeStatus,
  );
}
