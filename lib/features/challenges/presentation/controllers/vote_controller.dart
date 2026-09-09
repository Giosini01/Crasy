import 'dart:async';

import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/notifications/data/repositories/firestore_notifications_repository.dart';
import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final voteControllerProvider = Provider<VoteController>(VoteController.new);

/// Com'e' andata a finire una fiamma.
enum VoteOutcome {
  /// Fatto: il numero e' cambiato.
  done,

  /// Serve un account. Capita solo sulle challenge vere.
  needsAccount,

  /// La gara e' finita: le fiamme sono quelle, e non si toccano piu'.
  closed,

  /// Le tre fiamme di questa gara sono finite.
  noFiresLeft,
}

/// Chi sta votando adesso.
///
/// Un provider a se' invece di leggere lo stato dell'accesso dove serve: cosi'
/// chi dipende dall'identita' si riaggiorna **solo quando l'identita' cambia**
/// davvero, e non a ogni notizia che riguarda l'account.
final voterIdProvider = Provider<String>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState is AuthenticatedAuthState ? authState.user.id : guestVoterId;
});

/// **Come deve vedersi una fiamma adesso**, mentre il server non ha ancora
/// risposto.
///
/// Non e' una correzione da sommare a quello che dice il server: e' il numero
/// per intero, fiamma accesa o spenta e conto gia' fatto. La differenza sembra
/// una sfumatura ed e' tutta la faccenda — sotto c'e' scritto perche'.
@immutable
class VoteIntent {
  const VoteIntent({required this.voted, required this.votes});

  final bool voted;
  final int votes;
}

/// Quello che l'utente ha appena chiesto, per partecipazione.
///
/// ## Perche' il numero si congela invece di correggersi
///
/// Prima qui c'era una correzione — `+1` mentre la scrittura era in volo — che
/// si sommava al contatore del server. Sembra la cosa giusta e non lo e', per
/// un motivo che si vede solo con due flussi aperti: **il contatore della foto
/// e l'elenco di cosa ho votato arrivano da due ascolti diversi**. Sono scritti
/// nella stessa transazione, ma consegnati come due notizie separate.
///
/// Nell'istante fra l'una e l'altra il contatore era gia' salito e l'elenco dei
/// voti diceva ancora di no: la correzione si aggiungeva a un numero che il
/// voto ce l'aveva gia' dentro, e sotto la foto compariva **+2**. Togliendo la
/// fiamma, `-2`. Chi lo vedeva toccava di nuovo per rimettere le cose a posto —
/// e quel tocco era un voto vero, nella direzione sbagliata. Da li' "posso
/// togliere due mi piace e aggiungerne uno".
///
/// Adesso la richiesta porta con se' **il numero finito**: dal tocco alla
/// conferma, sotto la foto c'e' quello e nient'altro. Non puo' sommarsi a
/// niente, quindi non puo' contare due volte, e non balla.
///
/// Il prezzo, dichiarato: per quel paio di secondi le fiamme date **da altri**
/// su quella foto non si vedono arrivare. Nessuno guarda il contatore di una
/// foto aspettando che si muova da solo, e in cambio il proprio gesto e' esatto
/// sempre.
///
/// La richiesta si cancella da sola quando il server dice la stessa cosa: da
/// quel momento il numero vero e quello congelato coincidono, e toglierla non
/// si vede.
class VoteIntents extends Notifier<Map<String, VoteIntent>> {
  @override
  Map<String, VoteIntent> build() {
    // **Le richieste appartengono a chi le ha fatte, e cambiando account non
    // valgono piu' niente.**
    //
    // Questa riga chiude un difetto vero: davo la fiamma con un account,
    // passavo a un altro, e la fiamma risultava data anche li'. La causa e' che
    // una richiesta si chiude solo quando il server conferma *quella stessa
    // cosa*; se l'account cambia prima della conferma, l'elenco dei voti che
    // arriva e' di un'altra persona e non la conferma mai — cosi' la richiesta
    // restava in memoria, e la fiamma di uno si vedeva accesa addosso a un
    // altro. Con dei soldi in palio, un voto attribuito alla persona sbagliata
    // e' fra le cose peggiori che possano succedere.
    //
    // Leggendo l'identita' qui dentro, il cambio di account ricostruisce questo
    // oggetto da zero: le richieste dell'account di prima spariscono nello
    // stesso istante in cui sparisce l'account.
    ref.watch(voterIdProvider);

    // L'elenco dei voti confermati e' l'unica cosa che puo' chiudere una
    // richiesta: e' la risposta del server alla domanda che si e' fatta.
    ref.listen(votedEntryIdsProvider, (_, next) => _settle(next.valueOrNull));

    return const {};
  }

  /// Da adesso questa foto si vede cosi'.
  void want(String voteKey, VoteIntent intent) {
    state = {...state, voteKey: intent};
  }

  /// La richiesta non vale piu': si torna a quello che dice il server.
  void forget(String voteKey) {
    if (!state.containsKey(voteKey)) {
      return;
    }

    state = {...state}..remove(voteKey);
  }

  void _settle(Set<String>? confirmed) {
    if (confirmed == null || state.isEmpty) {
      return;
    }

    final next = {...state}
      ..removeWhere(
        (voteKey, intent) => confirmed.contains(voteKey) == intent.voted,
      );

    if (next.length != state.length) {
      state = next;
    }
  }
}

final voteIntentsProvider =
    NotifierProvider<VoteIntents, Map<String, VoteIntent>>(VoteIntents.new);

/// La richiesta in corso su una foto, se c'e'.
final voteIntentProvider = Provider.family<VoteIntent?, String>(
  (ref, voteKey) => ref.watch(voteIntentsProvider)[voteKey],
);

/// Quante fiamme restano a chi guarda, **in questa gara**.
///
/// Si conta senza chiedere niente a nessuno: l'elenco dei voti confermati e'
/// gia' in casa — lo legge ogni fiamma sullo schermo — e le chiavi portano
/// dentro la gara (`{challenge}__{foto}`), quindi basta contare quelle che
/// cominciano per questa. Zero letture in piu' su Firestore.
///
/// Le richieste ancora in volo vincono su quello che dice il server: chi ha
/// appena acceso la terza deve vedere subito che ha finito, non fra mezzo
/// secondo.
final firesLeftProvider = Provider.autoDispose.family<int, String>((
  ref,
  challengeId,
) {
  final prefix = '${challengeId}__';
  final confirmed = ref.watch(votedEntryIdsProvider).valueOrNull ?? const {};
  final accese = {
    for (final key in confirmed)
      if (key.startsWith(prefix)) key,
  };

  ref.watch(voteIntentsProvider).forEach((key, intent) {
    if (!key.startsWith(prefix)) {
      return;
    }

    if (intent.voted) {
      accese.add(key);
    } else {
      accese.remove(key);
    }
  });

  final left = Challenge.firesPerChallenge - accese.length;

  return left < 0 ? 0 : left;
});

/// Se la fiamma di questa foto e' accesa **per come la vede l'utente**.
///
/// Quello che ha appena chiesto vince su quello che dice il server: fra il
/// tocco e la risposta di Firestore passa qualche decimo di secondo, e in quel
/// momento deve vedere il gesto fatto, non lo stato di prima.
final entryVotedProvider = Provider.family<bool, String>((ref, voteKey) {
  final intent = ref.watch(voteIntentProvider(voteKey));

  if (intent != null) {
    return intent.voted;
  }

  return ref.watch(votedEntryIdsProvider).valueOrNull?.contains(voteKey) ??
      false;
});

/// Il numero da scrivere sotto la foto, **o niente**.
///
/// **A gara aperta le fiamme non si vedono.** Torna `null`, e chi disegna
/// scrive un trattino al posto del numero.
///
/// Non e' pudore: e' quello che rende il voto un giudizio invece che un
/// accodamento. Con i numeri in chiaro succedono tre cose, tutte e tre brutte.
/// Si vota chi sta gia' vincendo, perche' nessuno vuole dare la fiamma a chi
/// perde. Chi e' indietro smette di provarci a meta' gara. E chi vuole comprare
/// dei voti sa **esattamente quanti gliene mancano** — che con dei soldi in
/// palio e' l'informazione piu' preziosa che gli si possa regalare.
///
/// Alla sirena si rivela tutto insieme, ed e' un momento che prima non
/// esisteva.
///
/// **Il proprio numero pero' si vede.** Mandare una foto e non ricevere niente
/// per ventiquattro ore e' come parlare a un muro, e la voglia di partecipare
/// la seconda volta nasce da quel numerino che sale. Sapere quante ne hai prese
/// tu non dice niente su quante ne hanno prese gli altri.
///
/// **Una fiamma sola per gesto, sempre.** O il numero congelato della richiesta
/// in corso, o quello del server — mai i due sommati, che era il difetto.
///
/// Sotto zero non si scende: nessuno puo' togliere un voto che non ha dato, e
/// un `-1` sotto una foto non vuol dire niente.
int? visibleVotes(WidgetRef ref, ChallengeEntry entry) {
  final live = ref.watch(challengeIsLiveProvider(entry.challengeId));
  final mia = entry.userId == ref.watch(currentUserIdProvider);

  if (live && !mia) {
    return null;
  }

  final intent = ref.watch(voteIntentProvider(entry.voteKey));
  final votes = intent?.votes ?? entry.votes;

  return votes < 0 ? 0 : votes;
}

/// Come si scrive un numero di fiamme che potrebbe essere nascosto.
///
/// Il trattino e non lo spazio vuoto: uno spazio sembra un difetto, un trattino
/// dice **"c'e' un numero, non te lo diciamo adesso"**.
String votesLabel(int? votes) => votes == null ? '–' : '$votes';

/// Accende o spegne la fiamma su una partecipazione.
///
/// Sta qui e non dentro i widget perche' la chiamano da quattro posti — il
/// doppio tocco sulla foto nell'elenco, la fiamma accanto al numero, il doppio
/// tocco a schermo intero e la fiamma li' sotto — e **tutti e quattro devono
/// passare per la stessa memoria**, altrimenti due gesti sulla stessa foto
/// contano due volte.
///
/// **Chiedere quello che c'e' gia' non fa niente.** E' la prima riga, ed e' la
/// regola scritta come la vuole chi tocca: il doppio tocco su una fiamma gia'
/// accesa non la spegne e non la riaccende — non succede niente. A spegnerla
/// c'e' un gesto solo, il tocco sulla fiamma rossa, e fa `-1`.
Future<VoteOutcome> giveFire(
  BuildContext context,
  WidgetRef ref,
  ChallengeEntry entry, {
  required bool voted,
}) async {
  final voteKey = entry.voteKey;
  final intents = ref.read(voteIntentsProvider.notifier);
  final messenger = ScaffoldMessenger.maybeOf(context);

  // **A gara finita non si vota**, e non si prova nemmeno a scrivere: la
  // classifica dell'ultimo secondo e' quella che ha assegnato dei soldi.
  // L'interfaccia la fiamma non la fa nemmeno toccare; questa riga vale per
  // tutte le altre strade — il doppio tocco, una schermata rimasta aperta
  // mentre il tempo scadeva.
  if (!ref.read(challengeIsLiveProvider(entry.challengeId))) {
    return VoteOutcome.closed;
  }

  if (ref.read(entryVotedProvider(voteKey)) == voted) {
    return VoteOutcome.done;
  }

  // **Tre per gara, e poi si e' finito.** Togliere una fiamma non consuma
  // niente — anzi, ne restituisce una — quindi il controllo vale solo quando se
  // ne sta accendendo una.
  if (voted && ref.read(firesLeftProvider(entry.challengeId)) <= 0) {
    // **Un gesto che non produce niente sembra un'app rotta.** Il doppio tocco
    // si fa anche dalla home, dove il contatore delle fiamme rimaste non si
    // vede: senza una riga che lo dica, chi ha finito le sue tre crede che la
    // fiamma non funzioni.
    messenger?.showSnackBar(
      const SnackBar(
        content: Text(
          'Hai finito le fiamme per questa challenge. In un\'altra ne hai '
          'altre tre.',
        ),
      ),
    );

    return VoteOutcome.noFiresLeft;
  }

  // Si parte da **quello che c'e' scritto adesso**, non dal numero del server:
  // se una richiesta e' gia' in corso, il gesto successivo si conta da li'.
  final shown = ref.read(voteIntentProvider(voteKey))?.votes ?? entry.votes;
  final wanted = voted ? shown + 1 : shown - 1;

  intents.want(
    voteKey,
    VoteIntent(voted: voted, votes: wanted < 0 ? 0 : wanted),
  );

  final VoteOutcome outcome;

  try {
    outcome = await ref
        .read(voteControllerProvider)
        .toggle(entry, voted: voted);
  } on Object {
    // **Se la scrittura fallisce, la fiamma torna com'era.** Prima lo stato
    // ottimistico restava acceso per sempre: uno credeva di aver votato,
    // riapriva l'app e il voto non c'era, senza che niente lo avesse detto.
    intents.forget(voteKey);

    rethrow;
  }

  if (outcome == VoteOutcome.needsAccount) {
    intents.forget(voteKey);

    if (context.mounted) {
      context.push(AppRoutes.auth);
    }
  }

  // **La gara si e' chiusa mentre il dito era in aria.**
  //
  // Il server ha rifiutato il voto perche' il tempo era scaduto — succede in
  // quel secondo di scarto fra il suo orologio e il nostro. Senza queste due
  // righe la fiamma **restava accesa per sempre**: la richiesta ottimistica si
  // chiude solo quando l'elenco dei voti confermati le da' ragione, e qui non
  // gliela dara' mai. Uno credeva di aver votato, e non aveva votato.
  //
  // Una riga sola e senza rosso: non e' un guasto, e' una gara finita.
  if (outcome == VoteOutcome.closed) {
    intents.forget(voteKey);

    messenger?.showSnackBar(
      const SnackBar(content: Text('Il tempo è scaduto: le fiamme sono chiuse.')),
    );
  }

  // A scrittura riuscita **non si tocca niente**: la richiesta si chiude da
  // sola quando l'elenco dei voti confermati arriva e dice la stessa cosa.
  // Chiuderla qui la spegnerebbe un istante prima che il server risponda, e in
  // quell'istante la fiamma si spegne da sola sotto gli occhi di chi ha appena
  // votato.
  return outcome;
}

/// La fiamma.
///
/// Non e' un `AsyncNotifier` e non ha uno stato di caricamento, ed e' una
/// scelta: e' il gesto piu' frequente dell'app, e mettere una rotellina su una
/// fiamma la farebbe sembrare lenta anche quando e' istantanea. Il numero sullo
/// schermo arriva dallo stream, che si aggiorna da solo appena la scrittura e'
/// andata a segno.
class VoteController {
  VoteController(this._ref);

  final Ref _ref;

  /// L'ultima scrittura ancora in volo per ogni partecipazione.
  ///
  /// Serve a metterle **in fila**. Senza, due tocchi rapidi sulla stessa foto
  /// aprono due transazioni contemporanee, e ognuna delle due legge il database
  /// prima che l'altra abbia scritto: partono tutte e due dallo stesso stato di
  /// partenza e la seconda decide in base a un mondo che non esiste piu'. Il
  /// risultato era il contatore che rimaneva indietro, o il cuore acceso su un
  /// voto che sul database non c'era.
  ///
  /// In fila, invece, ogni scrittura vede il risultato di quella prima e
  /// l'ultimo tocco vince — che e' esattamente quello che si aspetta chi tocca.
  final Map<String, Future<void>> _inFlight = {};

  Future<VoteOutcome> toggle(ChallengeEntry entry, {required bool voted}) {
    // In fila per **chiave di voto**, non per identificativo della
    // partecipazione: le foto si chiamano come chi le ha mandate, quindi la
    // stessa persona in due gare diverse aveva un'unica coda per due voti che
    // non c'entrano niente l'uno con l'altro.
    final previous = _inFlight[entry.voteKey] ?? Future<void>.value();
    final next = previous
        .then((_) => _write(entry, voted: voted))
        // La coda non si deve interrompere per un errore: se una scrittura
        // fallisce, il tocco successivo deve poter riprovare invece di restare
        // agganciato a una catena morta.
        .catchError((Object error) {
          _inFlight.remove(entry.voteKey);

          throw error;
        });

    _inFlight[entry.voteKey] = next.then((_) {}, onError: (Object _) {});

    return next;
  }

  Future<VoteOutcome> _write(
    ChallengeEntry entry, {
    required bool voted,
  }) async {
    final authState = _ref.read(authStateProvider);
    final signedIn = authState is AuthenticatedAuthState;
    final isDemo = entry.challengeId.startsWith(Challenge.demoIdPrefix);

    // Sulle challenge vere un ospite non vota: con dei soldi in palio un voto
    // senza nome non vale niente. Su quelle di esempio si', perche' vivono in
    // memoria e servono proprio a far provare il gesto prima di registrarsi.
    if (!signedIn && !isDemo) {
      return VoteOutcome.needsAccount;
    }

    final userId = signedIn ? authState.user.id : guestVoterId;

    // **La propria foto si puo' votare.** Sembra un buco e non lo e': tutti
    // possono farlo, quindi non sposta la classifica di un millimetro — e' un
    // voto in piu' per ciascuno, non un vantaggio per qualcuno.
    //
    // A tenere onesta la gara e' un'altra regola: chi lancia la challenge non
    // puo' parteciparvi.
    try {
      await _ref
          .read(challengeRepositoryProvider)
          .setVote(
            challengeId: entry.challengeId,
            entryId: entry.id,
            userId: userId,
            voted: voted,
          );
    } on FirebaseException catch (errore) {
      // **Un rifiuto qui vuol dire una cosa sola: e' scaduto il tempo.**
      //
      // Le regole non lasciano scrivere un voto su una gara chiusa — e' cio'
      // che rende vera la frase "vince chi ha piu' fiamme **allo scadere del
      // tempo**". L'app lo sa gia' e nasconde la fiamma appena la gara finisce,
      // ma fra il suo orologio e quello del server c'e' sempre un secondo di
      // scarto: chi tocca proprio sulla sirena passa di qui.
      //
      // Senza questo, quel secondo diventava **un messaggio rosso** che diceva
      // di chiudere e riaprire l'app. Per una fiamma arrivata tardi.
      if (errore.code == 'permission-denied') {
        return VoteOutcome.closed;
      }

      rethrow;
    }

    if (signedIn) {
      // L'avviso si scrive **dopo** che la fiamma e' stata scritta, e non si
      // aspetta: se fallisse, la fiamma resterebbe comunque data. E' un
      // dettaglio di contorno, non deve poter rompere il gesto principale
      // dell'app.
      //
      // **E se la fiamma si toglie, l'avviso se ne va con lei.** Prima restava
      // li': in campanella c'era la notizia di un mi piace che non esisteva
      // piu', e chi la leggeva apriva la propria foto per cercare una fiamma
      // che non avrebbe trovato. Un avviso che racconta una cosa falsa e'
      // peggio di nessun avviso — dopo due volte non lo si guarda piu'.
      //
      // Rimettendo la fiamma l'avviso torna, ed e' giusto cosi': quello che si
      // legge in campanella deve dire com'e' adesso, non com'e' stato.
      unawaited(_notifyAuthor(entry, actorId: userId, voted: voted));
    }

    return VoteOutcome.done;
  }

  Future<void> _notifyAuthor(
    ChallengeEntry entry, {
    required String actorId,
    required bool voted,
  }) async {
    final notifications = _ref.read(notificationsRepositoryProvider);

    if (notifications == null || entry.userId == actorId) {
      return;
    }

    // **Lo stesso nome ogni volta**, che sia per scrivere o per cancellare: e'
    // quello che lega l'avviso alla fiamma che lo ha provocato, e senza un nome
    // prevedibile togliendo la fiamma non si saprebbe quale riga togliere.
    final id = FirestoreNotificationsRepository.fireId(
      voteKey: entry.voteKey,
      actorId: actorId,
    );

    if (!voted) {
      await notifications.remove(toUserId: entry.userId, id: id);

      return;
    }

    final me = _ref.read(currentUserProfileProvider).valueOrNull;

    await notifications.push(
      toUserId: entry.userId,
      id: id,
      kind: NotificationKind.fire,
      actorId: actorId,
      actorUsername: me?.username ?? '',
      challengeId: entry.challengeId,
      challengeTitle: entry.challengeTitle,
    );
  }
}
