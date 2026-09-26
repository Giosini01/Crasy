import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/duel_status.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/data/repositories/contacts_repository.dart';
import 'package:crasy/features/friends/data/repositories/firestore_friends_repository.dart';
import 'package:crasy/features/friends/domain/entities/friendship.dart';
import 'package:crasy/features/friends/domain/entities/suggested_friend.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:crasy/services/firebase/firebase_bootstrap_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Le gare riservate vivono con le altre gare, in `challenge_providers`: il
// conto delle cinque partecipazioni del giorno deve poterle saltare, e quel
// conto sta li'. Si riesporta perche' la scheda degli amici e' il posto da cui
// si guardano, e chi la scrive non deve sapere in che cartella stanno.
export 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart'
    show reservedChallengesProvider;

/// Il repository delle amicizie.
///
/// Nullo senza Firebase configurato, e le schermate lo sanno: gli amici sono
/// **per definizione** una cosa fra dispositivi diversi, e non c'e' modo di
/// farli funzionare in memoria come le challenge di prova. Meglio dirlo che
/// fingere.
final friendsRepositoryProvider = Provider<FirestoreFriendsRepository?>((ref) {
  if (!ref.watch(firebaseBootstrapResultProvider).isConfigured) {
    return null;
  }

  return FirestoreFriendsRepository(ref.watch(firebaseFirestoreProvider));
});

/// Il profilo di chiunque, per identificativo.
final publicProfileProvider = StreamProvider.autoDispose
    .family<UserProfile?, String>((ref, userId) {
      final repository = ref.watch(friendsRepositoryProvider);

      if (repository == null) {
        return Stream.value(null);
      }

      return repository.watchProfile(userId);
    });

/// Gli amici di qualcuno.
final friendsOfProvider = StreamProvider.autoDispose
    .family<List<Friend>, String>((ref, userId) {
      final repository = ref.watch(friendsRepositoryProvider);

      if (repository == null) {
        return Stream.value(const <Friend>[]);
      }

      return repository.watchFriends(userId);
    });

/// I miei amici.
///
/// Ascolta il repository direttamente invece di appoggiarsi a
/// `friendsOfProvider(mioId)`: passando dal `future` di quello, l'elenco si
/// sarebbe fermato al primo valore — un amico accettato mentre la schermata e'
/// aperta non sarebbe mai comparso, e non ci sarebbe stato modo di accorgersene
/// se non riaprendo l'app.
final myFriendsProvider = StreamProvider<List<Friend>>((ref) {
  final repository = ref.watch(friendsRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (repository == null || userId == null) {
    return Stream.value(const <Friend>[]);
  }

  return repository.watchFriends(userId);
});

/// Le richieste che ho ricevuto e non ho ancora deciso.
final incomingRequestsProvider = StreamProvider<List<FriendRequest>>((ref) {
  final repository = ref.watch(friendsRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (repository == null || userId == null) {
    return Stream.value(const <FriendRequest>[]);
  }

  return repository.watchIncomingRequests(userId);
});

/// Che rapporto ho con questa persona.
final friendshipStatusProvider = StreamProvider.autoDispose
    .family<FriendshipStatus, String>((ref, otherId) {
      final repository = ref.watch(friendsRepositoryProvider);
      final meId = ref.watch(currentUserIdProvider);

      if (repository == null || meId == null) {
        return Stream.value(FriendshipStatus.none);
      }

      return repository.watchStatus(meId: meId, otherId: otherId);
    });

/// Le partecipazioni di una persona, per il suo profilo pubblico.
final entriesOfProvider = StreamProvider.autoDispose
    .family<List<ChallengeEntry>, String>((ref, userId) {
      return ref.watch(challengeRepositoryProvider).watchEntriesByUser(userId);
    });

/// Quanto ha vinto una persona, in centesimi.
///
/// Si somma sui suoi **trofei**, la stessa lista che riempie la bacheca appena
/// sotto: il riquadro "HA VINTO" e le figurine che gli stanno sotto devono dire
/// la stessa cosa, o una delle due sta mentendo.
///
/// **Prima passava dalle gare concluse, e per questo diceva quasi sempre zero.**
/// Quell'elenco copre una finestra di quarantotto ore e ne carica al massimo
/// cinquanta: una vittoria di tre giorni fa ne era gia' uscita, e si finiva con
/// un profilo pieno di trofei sopra un totale a zero. La query dei trofei cerca
/// per `winnerUserId`, campo che resta scritto sulla gara per sempre.
///
/// Si somma il **netto** — quello che finisce davvero in tasca — perche' e' la
/// cifra scritta su ogni singola figurina. Vedi `myPrizeCentsProvider`, che fa
/// lo stesso conto per chi sta guardando il proprio profilo.
final prizeCentsOfProvider = Provider.autoDispose.family<int, String>((
  ref,
  userId,
) {
  final trophies =
      ref.watch(trophiesOfProvider(userId)).valueOrNull ?? const <Challenge>[];

  var total = 0;

  for (final challenge in trophies) {
    total += challenge.payoutCents;
  }

  return total;
});

/// Le azioni sull'amicizia.
///
/// Stanno insieme perche' hanno tutte lo stesso preambolo — chi sono io, come
/// mi chiamo — e ripeterlo in ogni schermata sarebbe il modo piu' facile per
/// scrivere un nome sbagliato dentro l'amicizia di qualcun altro.
final friendActionsProvider = Provider<FriendActions>(FriendActions.new);

class FriendActions {
  const FriendActions(this._ref);

  final Ref _ref;

  String? get _meId => _ref.read(currentUserIdProvider);

  String get _meUsername =>
      _ref.read(currentUserProfileProvider).valueOrNull?.username ?? 'anonimo';

  FirestoreFriendsRepository? get _repository =>
      _ref.read(friendsRepositoryProvider);

  Future<void> send(String toUserId) async {
    final meId = _meId;
    final repository = _repository;

    if (meId == null || repository == null) {
      return;
    }

    await repository.sendRequest(
      fromUserId: meId,
      fromUsername: _meUsername,
      toUserId: toUserId,
    );
  }

  Future<void> cancel(String toUserId) async {
    final meId = _meId;
    final repository = _repository;

    if (meId == null || repository == null) {
      return;
    }

    await repository.cancelRequest(fromUserId: meId, toUserId: toUserId);
  }

  Future<void> accept(FriendRequest request) async {
    final meId = _meId;
    final repository = _repository;

    if (meId == null || repository == null) {
      return;
    }

    await repository.acceptRequest(
      meId: meId,
      meUsername: _meUsername,
      fromUserId: request.fromUserId,
      fromUsername: request.fromUsername,
    );
  }

  Future<void> reject(FriendRequest request) async {
    final meId = _meId;
    final repository = _repository;

    if (meId == null || repository == null) {
      return;
    }

    await repository.rejectRequest(meId: meId, fromUserId: request.fromUserId);
  }

  Future<void> remove(String otherId) async {
    final meId = _meId;
    final repository = _repository;

    if (meId == null || repository == null) {
      return;
    }

    await repository.removeFriend(meId: meId, otherId: otherId);
  }
}

/// Le gare pubbliche aperte **lanciate dai miei amici**.
///
/// Non costa una lettura in piu': le gare aperte l'app ce le ha gia' tutte in
/// mano per la home, e qui si tengono solo quelle scritte da qualcuno che
/// conosco. Filtrare in memoria evita una query per amico — con trenta amici
/// sarebbero trenta interrogazioni per riempire una schermata sola.
final friendChallengesProvider = Provider<List<Challenge>>((ref) {
  final friends = ref.watch(myFriendsProvider).valueOrNull ?? const <Friend>[];

  if (friends.isEmpty) {
    return const <Challenge>[];
  }

  final loro = {for (final amico in friends) amico.userId};
  final live = ref.watch(liveChallengesProvider).valueOrNull ?? const [];

  // Le private vivono nel PARTY: qui restano solo quelle pubbliche.
  // passano dalla home — la home chiede solo le gare aperte a tutti — quindi se
  // non le raccogliessimo qui non si vedrebbero da nessuna parte.
  return [
    for (final challenge in live)
      if (loro.contains(challenge.createdByUserId)) challenge,
  ];
});

/// Le foto con cui i miei amici sono **in gara adesso**.
///
/// Solo quelle nelle gare ancora aperte, e la ragione e' quello che uno ci fa:
/// da qui si accende una fiamma. Su una gara chiusa la fiamma non si puo' piu'
/// dare — i soldi sono gia' andati a qualcuno — e mostrare una foto su cui non
/// si puo' fare niente sarebbe una promessa non mantenuta.
///
/// Le piu' recenti in cima: e' l'ordine in cui si guarda cosa e' successo da
/// quando non si apriva l'app.
final friendEntriesProvider = Provider<List<ChallengeEntry>>((ref) {
  final friends = ref.watch(myFriendsProvider).valueOrNull ?? const <Friend>[];

  if (friends.isEmpty) {
    return const <ChallengeEntry>[];
  }

  final entries =
      ref
          .watch(
            entriesOfManyProvider(
              usersKey([for (final amico in friends) amico.userId]),
            ),
          )
          .valueOrNull ??
      const <ChallengeEntry>[];

  final aperte = {
    for (final challenge
        in ref.watch(liveChallengesProvider).valueOrNull ?? const <Challenge>[])
      challenge.id,
    // Le gare del party non passano dalla query pubblica della home. Sono
    // pero' gare aperte esattamente come le altre: se un amico ci manda una
    // foto, deve comparire anche in "IN GARA", non solo dentro "LE LORO".
    for (final challenge
        in ref.watch(reservedChallengesProvider).valueOrNull ??
            const <Challenge>[])
      if (challenge.isLiveAt(DateTime.now())) challenge.id,
  };

  final loro = {for (final amico in friends) amico.userId};

  // Si controlla **anche di chi e' la foto**, non solo in che gara sta. La
  // query chiede gia' soltanto le partecipazioni di queste persone, e questa
  // riga sembra quindi di troppo: serve perche' la garanzia stia qui dentro e
  // non dentro un `whereIn` scritto in un altro file. Il giorno in cui quella
  // query cambia, questa lista continua a contenere solo amici.
  final foto =
      [
        for (final entry in entries)
          if (loro.contains(entry.userId) && aperte.contains(entry.challengeId))
            entry,
      ]..sort((a, b) {
        // Una partecipazione senza data e' una che Firestore non ha ancora
        // timbrato: e' appena partita, e sta in cima con le piu' recenti.
        final quando = a.createdAt;
        final altra = b.createdAt;

        if (quando == null) return altra == null ? 0 : -1;
        if (altra == null) return 1;

        return altra.compareTo(quando);
      });

  return foto;
});

/// Cosa non ha funzionato, se non ha funzionato.
///
/// **Serve perche' il guasto si veda.** Le due liste qui sopra leggono con
/// `valueOrNull`: se la query fallisce — un indice che manca, una regola che
/// rifiuta, la rete che non c'e' — non tornano un errore, tornano **niente**, e
/// una lista vuota si legge come "i tuoi amici non stanno facendo niente".
/// Sono due frasi diverse, e l'utente ha diritto di sapere quale delle due sta
/// leggendo.
final friendActivityProblemProvider = Provider<Object?>((ref) {
  final friends = ref.watch(myFriendsProvider);

  if (friends.hasError) {
    return friends.error;
  }

  final loro = friends.valueOrNull ?? const <Friend>[];

  if (loro.isEmpty) {
    return null;
  }

  final entries = ref.watch(
    entriesOfManyProvider(usersKey([for (final amico in loro) amico.userId])),
  );

  if (entries.hasError) {
    return entries.error;
  }

  final live = ref.watch(liveChallengesProvider);

  return live.hasError ? live.error : null;
});

/// Le missioni riservate che ho lanciato **io**.
final myFriendChallengesProvider = Provider<List<Challenge>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final riservate =
      ref.watch(reservedChallengesProvider).valueOrNull ?? const <Challenge>[];

  // Senza le sfide mirate: quelle hanno una scheda tutta loro — LANCIATE —
  // e contarle anche qui vorrebbe dire la stessa sfida in due elenchi della
  // stessa schermata.
  return [
    for (final challenge in riservate)
      if (challenge.createdByUserId == userId && !challenge.isDuel) challenge,
  ];
});

/// Il party: tutte le missioni aperte riservate al mio gruppo di amici.
///
/// Non e' una nuova privacy da mantenere: sono esattamente le gare che il
/// database ha gia' deciso che posso vedere. Qui si cambia solo il modo di
/// presentarle, riunendo le mie e quelle degli amici in un posto esplicito.
final partyChallengesProvider = Provider<List<Challenge>>((ref) {
  final now = DateTime.now();
  final riservate =
      ref.watch(reservedChallengesProvider).valueOrNull ?? const <Challenge>[];

  // **Le sfide mirate non stanno qui.** Sono anche loro gare riservate, ma
  // hanno un destinatario solo e due schede tutte loro: lasciarle anche nel
  // party vorrebbe dire la stessa sfida in tre elenchi della stessa
  // schermata.
  final party = [
    for (final challenge in riservate)
      if (challenge.isForFriends &&
          !challenge.isDuel &&
          challenge.isLiveAt(now))
        challenge,
  ]..sort((a, b) => a.endsAt.compareTo(b.endsAt));

  return party;
});

/// **Le missioni del party appena finite**, con dentro chi ha vinto.
///
/// Sparivano nell'istante in cui scadevano — il party guarda solo le gare
/// aperte — cioe' proprio nel momento in cui uno le vuole guardare: com'e'
/// andata, chi l'ha presa, con che foto. Restavano nella bacheca dei trofei di
/// chi aveva vinto, che e' il posto giusto per ricordarsele **dopo**, ma il
/// giorno stesso il gruppo non aveva piu' niente da commentare.
///
/// Ventiquattro ore e poi via. Il party e' una cosa di oggi: un elenco che
/// cresce all'infinito smette di dire "guarda com'e' finita" e comincia a dire
/// "ecco l'archivio", che e' un'altra schermata e nessuno l'ha chiesta.
final recentlyClosedProvider = StreamProvider<List<Challenge>>((ref) {
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) {
    return Stream.value(const <Challenge>[]);
  }

  return ref.watch(challengeRepositoryProvider).watchRecentlyClosedFor(userId);
});

/// Le missioni del party finite oggi, in riga.
///
/// **Non le figurine.** Le figurine stanno sul profilo e solo li': sono la
/// bacheca di una persona, quello che ha vinto da quando esiste, e ripeterle
/// qui vorrebbe dire due posti in cui si colleziona la stessa cosa — con la
/// scheda del party che per un giorno mostra una figurina e il giorno dopo
/// no. Qui si guarda **com'e' finita**, che e' una riga: titolo, premio, e chi
/// se l'e' presa.
///
/// Senza il filtro sul trofeo: una missione chiusa senza vincitore e' comunque
/// una cosa successa al gruppo, e in riga si legge benissimo — era la cornice
/// vuota di una figurina a non stare in piedi.
final closedPartyProvider = Provider<List<Challenge>>((ref) {
  final now = DateTime.now();

  return [
    for (final challenge in _tutteLeChiuse(ref, now))
      if (!challenge.isDuel) challenge,
  ];
});

/// Tutto quello che e' finito, da **tutti e due i posti in cui puo' stare**.
///
/// **Le due letture del database portano una soglia scritta a mano**, e la
/// scrivono una volta sola: `endsAt > adesso` per le gare aperte, `endsAt <=
/// adesso` per quelle chiuse, dove *adesso* e' il momento in cui l'app si e'
/// messa in ascolto e non quello in cui si guarda. Con l'app aperta quelle due
/// soglie restano ferme mentre il tempo passa.
///
/// E' il motivo per cui una sfida giudicata restava fra le ricevute: il
/// verdetto le sposta la scadenza ad adesso, che e' **dopo** la soglia delle
/// aperte — quindi continuava a comparire li' — ed e' **dopo** anche quella
/// delle chiuse, quindi non compariva qui. Spariva da una parte sola.
///
/// Rifare le due letture a ogni minuto costerebbe una lettura del database a
/// ogni minuto per tutti. Guardare l'orologio qui non costa niente: si prendono
/// le gare da tutte e due gli elenchi e si tiene quello che a **questo** minuto
/// e' davvero finito.
List<Challenge> _tutteLeChiuse(Ref ref, DateTime now) {
  final chiuse =
      ref.watch(recentlyClosedProvider).valueOrNull ?? const <Challenge>[];
  final aperte =
      ref.watch(reservedChallengesProvider).valueOrNull ?? const <Challenge>[];

  final ieri = now.subtract(const Duration(hours: 24));
  final tutte = <String, Challenge>{};

  for (final challenge in [...chiuse, ...aperte]) {
    // Finita davvero: o il tempo e' scaduto, o qualcuno l'ha chiusa prima —
    // che su una sfida mirata vuol dire che e' arrivato il verdetto.
    final finita =
        !challenge.isLiveAt(now) || challenge.duelVerdict.isGiven;

    if (finita && challenge.endsAt.isAfter(ieri)) {
      tutte[challenge.id] = challenge;
    }
  }

  return tutte.values.toList()
    ..sort((a, b) => b.endsAt.compareTo(a.endsAt));
}

/// Le sfide mirate finite oggi: giudicate, valide o no.
///
/// **Senza questo elenco sparirebbero e basta.** Una sfida giudicata smette di
/// essere aperta nell'istante del verdetto — e' giusto, non c'e' piu' niente da
/// fare — e quindi esce dalle ricevute e dalle lanciate. Se non ricomparisse
/// qui, chi l'ha fatta vedrebbe la propria sfida svanire dal party senza sapere
/// com'e' andata.
///
/// Le rifiutate non stanno qui: quelle restano fra le ricevute per le loro
/// ventiquattro ore, perche' per cinque ore si puo' ancora tornare indietro e
/// una cosa su cui si puo' ancora agire non e' finita.
final closedDuelsProvider = Provider<List<Challenge>>((ref) {
  final now = DateTime.now();

  return [
    for (final challenge in _tutteLeChiuse(ref, now))
      if (challenge.isDuel) challenge,
  ];
});

/// **Le sfide che mi hanno lanciato**: Mario ha sfidato me.
///
/// Prima quelle a cui devo ancora rispondere, poi le altre. Non e' un ordine
/// cronologico ed e' voluto: una sfida in attesa e' una cosa da fare, e le
/// cose da fare stanno in cima a qualunque elenco le contenga. A parita' di
/// stato comanda la scadenza — chi ha meno tempo va prima.
final receivedDuelsProvider = Provider<List<Challenge>>((ref) {
  final meId = ref.watch(currentUserIdProvider);
  final riservate =
      ref.watch(reservedChallengesProvider).valueOrNull ?? const <Challenge>[];

  if (meId == null) {
    return const <Challenge>[];
  }

  return [
    for (final challenge in riservate)
      if (challenge.isDuel &&
          challenge.targetUserId == meId &&
          !challenge.duelVerdict.isGiven)
        challenge,
  ]..sort(_leDaFarePrima);
});

/// **Le sfide che ho lanciato io**: io ho sfidato Mario.
///
/// E' la meta' che mancava, ed e' il difetto che la scheda aveva: si lanciava
/// una sfida e non compariva da nessuna parte. Esce dalla stessa lettura delle
/// ricevute — una sola interrogazione per tutte e due — e si divide qui in
/// memoria guardando chi l'ha scritta.
final sentDuelsProvider = Provider<List<Challenge>>((ref) {
  final meId = ref.watch(currentUserIdProvider);
  final riservate =
      ref.watch(reservedChallengesProvider).valueOrNull ?? const <Challenge>[];

  if (meId == null) {
    return const <Challenge>[];
  }

  // **Senza quelle gia' giudicate.** Una sfida decisa non e' piu' una cosa da
  // fare ne' una cosa da aspettare: sta fra le chiuse. Il controllo e' sul
  // verdetto e non sulla scadenza perche' la lettura del database porta una
  // soglia scritta quando l'app si e' messa in ascolto, e una sfida chiusa
  // mezz'ora dopo la supera comunque — restava li' fino al riavvio.
  return [
    for (final challenge in riservate)
      if (challenge.isDuel &&
          challenge.createdByUserId == meId &&
          !challenge.duelVerdict.isGiven)
        challenge,
  ]..sort(_leDaFarePrima);
});

/// Le sfide ricevute a cui non ho ancora risposto.
///
/// E' il numero rosso della scheda: **quante persone stanno aspettando una mia
/// parola**. Non conta le accettate — quelle le ho gia' prese in carico — ne'
/// le scadute, su cui non c'e' piu' niente da decidere.
final pendingDuelsCountProvider = Provider<int>((ref) {
  final now = DateTime.now();

  return ref
      .watch(receivedDuelsProvider)
      .where((challenge) => challenge.duelStateAt(now) == DuelState.pending)
      .length;
});

/// Prima quelle su cui c'e' ancora qualcosa da fare, poi per scadenza.
int _leDaFarePrima(Challenge a, Challenge b) {
  final now = DateTime.now();
  final aperta = a.isDuelOpenAt(now);
  final altra = b.isDuelOpenAt(now);

  if (aperta != altra) {
    return aperta ? -1 : 1;
  }

  return a.endsAt.compareTo(b.endsAt);
}

/// Chi legge la rubrica e chiede al server chi di quei numeri e' su CRASY.
final contactsRepositoryProvider = Provider<ContactsRepository?>((ref) {
  if (!ref.watch(firebaseBootstrapResultProvider).isConfigured) {
    return null;
  }

  return ContactsRepository(ref.watch(firebaseFunctionsProvider));
});

/// **I suggeriti. Si caricano solo quando qualcuno li chiede.**
///
/// Non e' un provider che si accende da solo aprendo la schermata, e non per
/// prudenza tecnica: leggere la rubrica fa comparire la richiesta di permesso
/// del telefono, e una richiesta del genere che salta fuori da sola, senza che
/// l'utente abbia chiesto niente, e' il modo piu' rapido di prendersi un "no"
/// che poi resta per sempre. Prima si spiega, poi si chiede.
final suggestedFriendsProvider =
    AsyncNotifierProvider.autoDispose<SuggestedFriendsNotifier,
        List<SuggestedFriend>?>(SuggestedFriendsNotifier.new);

class SuggestedFriendsNotifier
    extends AutoDisposeAsyncNotifier<List<SuggestedFriend>?> {
  /// Null vuol dire "non li abbiamo ancora cercati", che e' diverso da una
  /// lista vuota — quella vuol dire "cercati, e non c'e' nessuno".
  @override
  Future<List<SuggestedFriend>?> build() async => null;

  Future<void> cerca() async {
    final repository = ref.read(contactsRepositoryProvider);

    if (repository == null) {
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(repository.suggeriti);
  }
}
