import 'package:app_incontri/core/services/firebase/firebase_providers.dart';
import 'package:app_incontri/features/auth/presentation/providers/auth_providers.dart';
import 'package:app_incontri/features/matches/data/repositories/firestore_matches_repository.dart';
import 'package:app_incontri/features/matches/domain/entities/match_person.dart';
import 'package:app_incontri/features/matches/domain/repositories/matches_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final matchesRepositoryProvider = Provider<MatchesRepository>(
  (ref) => FirestoreMatchesRepository(ref.watch(firebaseFirestoreProvider)),
);

final matchesProvider = StreamProvider<List<MatchPerson>>((ref) {
  final authState = ref.watch(authStateProvider);

  if (authState is! AuthenticatedAuthState) {
    return Stream.value(const <MatchPerson>[]);
  }

  return ref.watch(matchesRepositoryProvider).watchMatches(authState.user.id);
});
