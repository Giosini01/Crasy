import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/data/repositories/demo_fallback_challenge_repository.dart';
import 'package:crasy/features/challenges/data/repositories/firestore_challenge_repository.dart';
import 'package:crasy/features/challenges/data/repositories/sample_challenge_repository.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
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

final challengeProvider = StreamProvider.family<Challenge?, String>((ref, id) {
  return ref.watch(challengeRepositoryProvider).watchChallenge(id);
});

final challengeEntriesProvider =
    StreamProvider.family<List<ChallengeEntry>, String>((ref, challengeId) {
      return ref.watch(challengeRepositoryProvider).watchEntries(challengeId);
    });

/// Il feed: le partecipazioni piu' recenti, di qualunque challenge.
final feedEntriesProvider = StreamProvider<List<ChallengeEntry>>((ref) {
  return ref.watch(challengeRepositoryProvider).watchLatestEntries(limit: 30);
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

/// Cosa ho gia' votato.
///
/// Un insieme e non un elenco: all'interfaccia serve rispondere a una domanda
/// sola — questa foto l'ho gia' votata? — e la risposta deve costare quanto una
/// ricerca in una tabella hash, perche' viene chiesta per ogni foto sullo
/// schermo a ogni ricostruzione.
final votedEntryIdsProvider = StreamProvider<Set<String>>((ref) {
  final authState = ref.watch(authStateProvider);

  if (authState is! AuthenticatedAuthState) {
    return Stream.value(const <String>{});
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
