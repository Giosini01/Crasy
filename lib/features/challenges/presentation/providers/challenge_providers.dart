import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/data/repositories/demo_fallback_challenge_repository.dart';
import 'package:crasy/features/challenges/data/repositories/firestore_challenge_repository.dart';
import 'package:crasy/features/challenges/data/repositories/sample_challenge_repository.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/entry_comment.dart';
import 'package:crasy/features/challenges/domain/entities/entry_moderation.dart';
import 'package:crasy/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:crasy/services/firebase/firebase_bootstrap_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sampleChallengeRepositoryProvider = Provider<SampleChallengeRepository>((
  ref,
) {
  final repository = SampleChallengeRepository();
  ref.onDispose(repository.dispose);

  return repository;
});

/// Il repository delle challenge.
///
/// Senza Firebase configurato l'app gira **interamente** sulle challenge di
/// esempio: non e' una modalita' degradata con dei buchi, e' l'app completa con
/// dei dati che vivono in memoria. Serve a poterla aprire e provare senza un
/// progetto Firebase, ed e' anche cio' che permette ai test di girare senza
/// rete.
final challengeRepositoryProvider = Provider<ChallengeRepository>((ref) {
  final samples = ref.watch(sampleChallengeRepositoryProvider);

  if (!ref.watch(firebaseBootstrapResultProvider).isConfigured) {
    return samples;
  }

  return DemoFallbackChallengeRepository(
    FirestoreChallengeRepository(
      ref.watch(firebaseFirestoreProvider),
      ref.watch(firebaseStorageProvider),
    ),
    samples,
  );
});

final liveChallengesProvider = StreamProvider<List<Challenge>>((ref) {
  return ref.watch(challengeRepositoryProvider).watchLiveChallenges();
});

final endedChallengesProvider = StreamProvider<List<Challenge>>((ref) {
  return ref.watch(challengeRepositoryProvider).watchEndedChallenges();
});

/// Una challenge sola.
///
/// `autoDispose` non e' un dettaglio: questi due provider sono per famiglia e
/// la home li apre **uno per challenge visibile**. Senza, ogni scheda che passa
/// sotto il dito lascerebbe dietro di se' un ascoltatore su Firestore aperto
/// per sempre.
final challengeProvider = StreamProvider.autoDispose.family<Challenge?, String>(
  (ref, id) => ref.watch(challengeRepositoryProvider).watchChallenge(id),
);

/// Se su questa gara si vota ancora.
///
/// **A gara finita le fiamme si fermano**, e non e' un dettaglio di
/// interfaccia: la classifica di quel momento decide chi si prende i soldi, e
/// un voto arrivato dopo la sirena li sposterebbe da una persona a un'altra.
/// Il numero resta a schermo, fisso, com'era all'ultimo secondo.
///
/// Nel dubbio si lascia votare: se la gara non e' ancora arrivata — lo stream
/// sta caricando — bloccare tutto vorrebbe dire una fiamma morta ogni volta che
/// la rete e' lenta. A dire l'ultima parola sono le regole di Firestore, che un
/// voto fuori tempo lo rifiutano comunque.
final challengeIsLiveProvider = Provider.autoDispose.family<bool, String>((
  ref,
  challengeId,
) {
  final challenge = ref.watch(challengeProvider(challengeId)).valueOrNull;

  if (challenge == null) {
    return true;
  }

  return !challenge.hasEndedAt(DateTime.now());
});

/// Le partecipazioni a una challenge, gia' filtrate dal controllo.
///
/// Il filtro sta **qui e non nella query**: una foto in attesa deve continuare a
/// vedersi a chi l'ha mandata, e Firestore non sa chi sta guardando. Chi carica
/// vede il proprio scatto con l'etichetta "in verifica"; per tutti gli altri
/// semplicemente non c'e' ancora.
final challengeEntriesProvider = StreamProvider.autoDispose
    .family<List<ChallengeEntry>, String>((ref, challengeId) {
      final viewerId = ref.watch(currentUserIdProvider);

      return ref
          .watch(challengeRepositoryProvider)
          .watchEntries(challengeId)
          .map(
            (entries) =>
                entries.where((entry) => entry.isVisibleTo(viewerId)).toList(),
          );
    });

/// La foto in testa a una challenge: quella con piu' fiamme.
///
/// E' la vetrina della gara. Le partecipazioni arrivano gia' ordinate per voti,
/// quindi "la prima che ha una foto" e' esattamente "quella che sta vincendo".
///
/// In vetrina vanno **solo le foto gia' ammesse**: la vetrina la vedono tutti,
/// e una foto ancora in attesa di controllo non e' pronta per stare li'.
final challengeTopEntryProvider = Provider.autoDispose
    .family<ChallengeEntry?, String>((ref, challengeId) {
      final entries = ref
          .watch(challengeEntriesProvider(challengeId))
          .valueOrNull;

      return entries
          ?.where(
            (entry) =>
                entry.mediaUrl.isNotEmpty &&
                entry.moderation == EntryModeration.approved,
          )
          .firstOrNull;
    });

/// La foto che rappresenta una challenge: **quella con piu' fiamme**.
///
/// Non esiste una copertina scelta da chi crea la challenge, e non e' una
/// mancanza: chi la lancia mette dei soldi e detta una consegna, la faccia della
/// gara la mettono i partecipanti. Cosi' una challenge cambia aspetto man mano
/// che qualcuno fa di meglio, invece di restare ferma sull'immagine scelta il
/// primo giorno.
///
/// Nullo finche' non partecipa nessuno, e in quel caso la scheda e' premio,
/// titolo, consegna e comando.
final challengeCoverProvider = Provider.autoDispose.family<String?, String>(
  (ref, challengeId) =>
      ref.watch(challengeTopEntryProvider(challengeId))?.mediaUrl,
);

/// Sotto quale foto, di quale gara. Serve a chiedere i commenti.
///
/// E' un record e non due argomenti perche' le famiglie di Riverpod ne prendono
/// uno solo — e un record sa gia' confrontarsi per contenuto, quindi due
/// richieste per la stessa foto trovano lo stesso provider invece di aprirne
/// due sullo stesso pezzo di database.
typedef CommentTarget = ({String challengeId, String entryId});

/// I commenti sotto una foto.
///
/// `autoDispose` e' obbligatorio: si aprono da una foto guardata a tutto
/// schermo, e senza, ogni foto sfogliata lascerebbe dietro di se' un
/// ascoltatore su Firestore aperto per sempre.
final entryCommentsProvider = StreamProvider.autoDispose
    .family<List<EntryComment>, CommentTarget>((ref, target) {
      return ref
          .watch(challengeRepositoryProvider)
          .watchComments(
            challengeId: target.challengeId,
            entryId: target.entryId,
          );
    });

/// Chi sono, se ho fatto l'accesso.
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState is AuthenticatedAuthState ? authState.user.id : null;
});

/// Vero se questa challenge l'ho lanciata io.
///
/// Chi la lancia **non ci partecipa**: mette lui i soldi del premio, e una gara
/// in cui chi paga puo' anche vincere non e' una gara. La regola vale anche
/// dalla parte del database, non solo qui.
final isMyChallengeProvider = Provider.autoDispose.family<bool, String>((
  ref,
  challengeId,
) {
  final userId = ref.watch(currentUserIdProvider);
  final challenge = ref.watch(challengeProvider(challengeId)).valueOrNull;

  return userId != null &&
      challenge != null &&
      challenge.createdByUserId == userId;
});

/// La mia partecipazione a una challenge, se c'e'.
///
/// Nulla significa "non ho ancora partecipato", ed e' la sola cosa che decide
/// se il comando dice "Partecipa" o "Hai gia' partecipato".
final myEntryForChallengeProvider = Provider.autoDispose
    .family<ChallengeEntry?, String>((ref, challengeId) {
      final mine = ref.watch(myEntriesProvider).valueOrNull ?? const [];

      return mine
          .where((entry) => entry.challengeId == challengeId)
          .firstOrNull;
    });

final myEntriesProvider = StreamProvider<List<ChallengeEntry>>((ref) {
  final authState = ref.watch(authStateProvider);

  if (authState is! AuthenticatedAuthState) {
    return Stream.value(const <ChallengeEntry>[]);
  }

  return ref
      .watch(challengeRepositoryProvider)
      .watchEntriesByUser(authState.user.id);
});

/// L'identita' di chi guarda senza aver fatto l'accesso.
///
/// Le sue fiamme vivono **solo in memoria**, sulle challenge di esempio, e
/// spariscono chiudendo l'app. Serve a poter provare il gesto prima di
/// registrarsi: un'app in cui il primo tocco chiede un indirizzo email non la
/// prova nessuno.
const String guestVoterId = 'ospite-locale';

/// Cosa ho gia' votato.
///
/// Un insieme e non un elenco: all'interfaccia serve rispondere a una domanda
/// sola — questa foto l'ho gia' votata? — e la risposta deve costare quanto una
/// ricerca in una tabella hash, perche' viene chiesta per ogni foto sullo
/// schermo a ogni ricostruzione.
final votedEntryIdsProvider = StreamProvider<Set<String>>((ref) {
  final authState = ref.watch(authStateProvider);

  if (authState is! AuthenticatedAuthState) {
    // Per l'ospite si legge **solo** dal repository di esempio, mai da
    // Firestore: una richiesta su `users/ospite-locale/votes` verrebbe
    // respinta dalle regole, lo stream cadrebbe in errore, e nessuna fiamma
    // risulterebbe piu' accesa.
    return ref
        .watch(sampleChallengeRepositoryProvider)
        .watchVotedEntryIds(guestVoterId);
  }

  return ref
      .watch(challengeRepositoryProvider)
      .watchVotedEntryIds(authState.user.id);
});

/// I miei trofei: le gare che ho vinto.
///
/// Sono gare, non partecipazioni, e la differenza conta: la partecipazione
/// viene cancellata quarantotto ore dopo la fine, la gara con dentro la foto
/// vincente resta. E' il motivo per cui una vittoria si guarda da qui e non
/// dall'elenco delle proprie foto.
/// I trofei di chiunque, non solo i propri.
///
/// E' per famiglia perche' una bacheca serve **soprattutto guardata da fuori**:
/// il proprio profilo lo si conosce gia', quello di un altro e' dove si scopre
/// che qui si vince davvero.
final trophiesOfProvider = StreamProvider.family<List<Challenge>, String>((
  ref,
  userId,
) {
  return ref.watch(challengeRepositoryProvider).watchTrophiesOf(userId);
});

final myTrophiesProvider = StreamProvider<List<Challenge>>((ref) {
  final authState = ref.watch(authStateProvider);

  if (authState is! AuthenticatedAuthState) {
    return Stream.value(const <Challenge>[]);
  }

  return ref
      .watch(challengeRepositoryProvider)
      .watchTrophiesOf(authState.user.id);
});

/// Le gare che ho commissionato e che hanno prodotto qualcosa.
///
/// Chi mette i soldi non gareggia, quindi non vincera' mai niente: senza
/// questo, del gesto piu' impegnativo dell'app non resterebbe traccia da
/// nessuna parte.
final commissionsOfProvider = StreamProvider.family<List<Challenge>, String>((
  ref,
  userId,
) {
  return ref.watch(challengeRepositoryProvider).watchCommissionedBy(userId);
});

final myCommissionsProvider = StreamProvider<List<Challenge>>((ref) {
  final authState = ref.watch(authStateProvider);

  if (authState is! AuthenticatedAuthState) {
    return Stream.value(const <Challenge>[]);
  }

  return ref
      .watch(challengeRepositoryProvider)
      .watchCommissionedBy(authState.user.id);
});

/// Cosa stanno facendo adesso le persone che seguo.
///
/// **La schermata degli amici lo prometteva e non lo diceva.** In cima c'e'
/// scritto "cosa stanno combinando", e sotto c'era un elenco di nomi: la stessa
/// cosa che si vedrebbe in una rubrica del telefono. Questo e' il dato che
/// mancava — chi e' in gara adesso, e in quale.
///
/// Torna il **titolo della gara aperta** a cui ognuno sta partecipando, o
/// niente per chi in questo momento non e' in nessuna. Chi partecipa a piu'
/// gare compare con l'ultima: una riga sola per persona, o l'elenco degli
/// amici diventa l'elenco delle partecipazioni.
/// **La chiave e' una stringa, non una lista.** Due liste con dentro le stesse
/// persone, in Dart, non sono uguali fra loro: sono uguali solo a se stesse. Una
/// famiglia con una lista per chiave nasceva quindi **nuova a ogni ridisegno**
/// della schermata — con dentro un ascoltatore nuovo su Firestore, aperto sopra
/// quello di prima. Con una stringa la chiave e' la stessa e il provider e' lo
/// stesso: vedi [usersKey].
final friendsInGameProvider = Provider.family<Map<String, String>, String>((
  ref,
  userIds,
) {
  {
    if (userIds.isEmpty) {
      return const {};
    }

    final entries = ref.watch(entriesOfManyProvider(userIds)).valueOrNull;
    final live = ref.watch(liveChallengesProvider).valueOrNull;

    if (entries == null || live == null) {
      return const {};
    }

    final titoli = {
      for (final challenge in live) challenge.id: challenge.title,
    };
    final risultato = <String, String>{};

    for (final entry in entries) {
      final titolo = titoli[entry.challengeId];

      if (titolo != null) {
        risultato[entry.userId] = titolo;
      }
    }

    return risultato;
  }
});

/// Le persone di un gruppo, scritte come una chiave sola.
///
/// Ordinate e attaccate con una virgola: cosi' gli stessi amici, in qualunque
/// ordine arrivino, danno sempre la stessa chiave — e quindi lo stesso
/// provider, con lo stesso ascoltatore su Firestore.
String usersKey(Iterable<String> userIds) {
  final ordinati = userIds.toList()..sort();

  return ordinati.join(',');
}

/// Le partecipazioni di un gruppo di persone, in una lettura sola.
///
/// La chiave e' quella di [usersKey], non la lista: guarda [friendsInGameProvider]
/// per il perche'.
final entriesOfManyProvider = StreamProvider.autoDispose
    .family<List<ChallengeEntry>, String>((ref, userIds) {
      if (userIds.isEmpty) {
        return Stream.value(const <ChallengeEntry>[]);
      }

      return ref
          .watch(challengeRepositoryProvider)
          .watchEntriesByUsers(userIds.split(','));
    });

/// A quante gare posso ancora partecipare oggi.
///
/// Si conta su quello che l'app ha gia' in mano — le mie partecipazioni — senza
/// chiedere niente a Firestore. Il confine e' la **mezzanotte locale**: non una
/// finestra mobile di ventiquattro ore, che costringerebbe a ricordarsi a che
/// ora si e' partecipato ieri.
final livesLeftProvider = Provider<int>((ref) {
  final entries = ref.watch(myEntriesProvider).valueOrNull ?? const [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  var used = 0;

  for (final entry in entries) {
    final when = entry.createdAt;

    if (when != null && !when.isBefore(today)) {
      used++;
    }
  }

  final left = Challenge.livesPerDay - used;

  return left < 0 ? 0 : left;
});

/// Le mie partecipazioni che hanno vinto.
///
/// Si ricava dalle partecipazioni invece di essere un contatore sul profilo: un
/// numero salvato a parte e' un numero che prima o poi non torna con la realta',
/// e questo e' un filtro su una lista che l'app ha gia' in mano.
final myWinsProvider = Provider<List<ChallengeEntry>>((ref) {
  final entries = ref.watch(myEntriesProvider).valueOrNull ?? const [];

  return entries.where((entry) => entry.isWinner).toList();
});

/// Quanto ho vinto in tutto, in centesimi.
///
/// Si somma sui **trofei**, cioe' sulle gare che portano scritto il mio nome
/// come vincitore. E' la stessa lista che riempie la bacheca del profilo, ed e'
/// questo il punto: quello che si vede in bacheca e quello che si legge nel
/// portafoglio non possono raccontare due storie diverse.
///
/// **Prima passava dalle gare concluse, e per questo il saldo restava a zero.**
/// Quell'elenco vive una finestra di quarantotto ore — la stessa entro cui si
/// guardano i vincitori — e ne carica al massimo cinquanta: una vittoria di tre
/// giorni fa ne era gia' uscita. Chi aveva vinto tre gare vedeva tre trofei e
/// zero euro, che e' il modo piu' rapido di far pensare che l'app rubi. La
/// query dei trofei invece non ha finestra: cerca per `winnerUserId`, e quel
/// campo resta scritto sulla gara per sempre.
///
/// **E' un totale calcolato, non un saldo.** Il saldo vero e' `walletCents` sul
/// database, lo scrive solo il server quando incassa davvero, e nessun telefono
/// lo puo' toccare. Finche' i pagamenti sono spenti quel numero non esiste, e
/// questo conto e' l'unico modo onesto di dire quanto si e' vinto senza
/// scrivere da nessuna parte un numero che un domani varrebbe denaro vero.
///
/// Si somma il **netto**, non il premio in vetrina: e' la cifra che il server
/// accrediterebbe davvero — `PrizeLedger.payoutCents` — ed e' gia' quella
/// scritta sulla figurina del trofeo. Sommare il lordo qui vorrebbe dire un
/// portafoglio che promette piu' di ogni singolo trofeo che lo compone.
final myPrizeCentsProvider = Provider<int>((ref) {
  final trophies =
      ref.watch(myTrophiesProvider).valueOrNull ?? const <Challenge>[];

  var total = 0;

  for (final challenge in trophies) {
    total += challenge.payoutCents;
  }

  return total;
});
