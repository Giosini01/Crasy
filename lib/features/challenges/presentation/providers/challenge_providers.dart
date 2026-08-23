import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/data/repositories/demo_fallback_challenge_repository.dart';
import 'package:crasy/features/challenges/data/repositories/firestore_challenge_repository.dart';
import 'package:crasy/features/challenges/data/repositories/sample_challenge_repository.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
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
/// Si ottiene incrociando le challenge concluse con le mie partecipazioni: il
/// premio sta sulla challenge, la vittoria sulla partecipazione, e sommare
/// serve entrambe le cose.
///
/// Il conto copre le challenge concluse che l'app ha caricato — le ultime
/// cinquanta. E' un limite vero e va saputo: questo totale e' "quanto hai vinto
/// di recente", non un estratto conto.
final myPrizeCentsProvider = Provider<int>((ref) {
  final ended = ref.watch(endedChallengesProvider).valueOrNull ?? const [];
  final mine = ref.watch(myEntriesProvider).valueOrNull ?? const [];
  final mineByChallenge = {
    for (final entry in mine) entry.challengeId: entry.id,
  };

  var total = 0;

  for (final challenge in ended) {
    final winner = challenge.winnerEntryId;

    if (winner != null && mineByChallenge[challenge.id] == winner) {
      total += challenge.prizeCents;
    }
  }

  return total;
});
