import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/data/repositories/firestore_friends_repository.dart';
import 'package:crasy/features/friends/domain/entities/friendship.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:crasy/services/firebase/firebase_bootstrap_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Le gare aperte **lanciate dai miei amici**.
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

  // Le pubbliche piu' quelle che hanno riservato a noi. Le riservate non
  // passano dalla home — la home chiede solo le gare aperte a tutti — quindi se
  // non le raccogliessimo qui non si vedrebbero da nessuna parte.
  final riservate =
      ref.watch(reservedChallengesProvider).valueOrNull ?? const <Challenge>[];

  return [
    for (final challenge in live)
      if (loro.contains(challenge.createdByUserId)) challenge,
    for (final challenge in riservate)
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

/// Le gare **riservate** che posso vedere: le mie e quelle dei miei amici.
///
/// Una lettura sola per tutte e due: il filtro e' "il mio identificativo sta fra
/// i destinatari", e chi le ha lanciate si guarda dopo, in memoria. Due query
/// separate — le mie, le loro — sarebbero due ascolti su Firestore per una cosa
/// che il database sa gia' dire in uno.
final reservedChallengesProvider = StreamProvider<List<Challenge>>((ref) {
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) {
    return Stream.value(const <Challenge>[]);
  }

  return ref.watch(challengeRepositoryProvider).watchChallengesFor(userId);
});

/// Le missioni riservate che ho lanciato **io**.
final myFriendChallengesProvider = Provider<List<Challenge>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final riservate =
      ref.watch(reservedChallengesProvider).valueOrNull ?? const <Challenge>[];

  return [
    for (final challenge in riservate)
      if (challenge.createdByUserId == userId) challenge,
  ];
});
