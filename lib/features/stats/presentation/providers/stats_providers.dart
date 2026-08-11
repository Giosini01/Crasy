import 'package:app_incontri/core/services/firebase/firebase_providers.dart';
import 'package:app_incontri/core/utils/app_date_utils.dart';
import 'package:app_incontri/features/auth/presentation/providers/auth_providers.dart';
import 'package:app_incontri/features/daily/presentation/providers/daily_providers.dart';
import 'package:app_incontri/features/stats/data/repositories/firestore_stats_repository.dart';
import 'package:app_incontri/features/stats/domain/entities/vibe_stats.dart';
import 'package:app_incontri/features/stats/domain/repositories/stats_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => FirestoreStatsRepository(ref.watch(firebaseFirestoreProvider)),
);

/// I numeri di oggi, che si aggiornano da soli mentre si guarda.
///
/// E' voluto: e' la parte che fa tornare. Il conteggio sale sotto gli occhi
/// senza dover riaprire niente.
final todayVibeProvider = StreamProvider<VibeDay>((ref) {
  final authState = ref.watch(authStateProvider);

  if (authState is! AuthenticatedAuthState) {
    return Stream.value(VibeDay.empty);
  }

  return ref
      .watch(statsRepositoryProvider)
      .watchDay(authState.user.id, ref.watch(todayKeyProvider));
});

final lifetimeVibeProvider = StreamProvider<VibeLifetime>((ref) {
  final authState = ref.watch(authStateProvider);

  if (authState is! AuthenticatedAuthState) {
    return Stream.value(VibeLifetime.empty);
  }

  return ref.watch(statsRepositoryProvider).watchLifetime(authState.user.id);
});

/// La striscia di giorni consecutivi, gia' verificata contro la data di oggi.
final streakProvider = Provider<int>((ref) {
  final lifetime = ref.watch(lifetimeVibeProvider).valueOrNull;

  if (lifetime == null) {
    return 0;
  }

  final today = ref.watch(todayKeyProvider);
  final yesterday = AppDateUtils.dateKey(
    DateTime.parse(today).subtract(const Duration(days: 1)),
  );

  return lifetime.aliveAt(today, yesterday);
});
