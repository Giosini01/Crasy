import 'package:app_incontri/core/services/firebase/firebase_providers.dart';
import 'package:app_incontri/core/utils/app_date_utils.dart';
import 'package:app_incontri/features/auth/presentation/providers/auth_providers.dart';
import 'package:app_incontri/features/daily/data/repositories/firebase_daily_repository.dart';
import 'package:app_incontri/features/daily/domain/entities/daily.dart';
import 'package:app_incontri/features/daily/domain/entities/daily_access.dart';
import 'package:app_incontri/features/daily/domain/repositories/daily_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dailyRepositoryProvider = Provider<DailyRepository>(
  (ref) => FirebaseDailyRepository(
    ref.watch(firebaseFirestoreProvider),
    ref.watch(firebaseStorageProvider),
  ),
);

/// Batte una volta al minuto.
///
/// Al minuto e non al secondo di proposito: serve solo a far scattare
/// l'apertura e la chiusura della finestra e il cambio di giornata. Il
/// countdown al secondo se lo gestisce il widget che lo mostra, cosi' una
/// schermata intera non si ricostruisce sessanta volte al minuto.
final minuteTickProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now(),
  );
});

/// Chiave della giornata corrente.
///
/// Ricalcolata a ogni minuto ma, essendo una stringa, notifica i dipendenti
/// solo quando cambia davvero: a mezzanotte.
final todayKeyProvider = Provider<String>((ref) {
  final now = ref.watch(minuteTickProvider).value ?? DateTime.now();

  return AppDateUtils.dateKey(now);
});

final todayDailiesProvider = StreamProvider<List<Daily>>((ref) {
  final authState = ref.watch(authStateProvider);

  if (authState is! AuthenticatedAuthState) {
    return Stream.value(const <Daily>[]);
  }

  return ref
      .watch(dailyRepositoryProvider)
      .watchDailiesForDay(authState.user.id, ref.watch(todayKeyProvider));
});

/// Stato di accesso corrente: se si puo' scattare e se il Per Te e' aperto.
///
/// `DailyAccess` implementa l'uguaglianza, quindi il battito al minuto non
/// fa ricostruire nulla finche' non cambia davvero qualcosa.
final dailyAccessProvider = Provider<DailyAccess>((ref) {
  final now = ref.watch(minuteTickProvider).valueOrNull ?? DateTime.now();
  final dailies = ref.watch(todayDailiesProvider).valueOrNull ?? const <Daily>[];

  return DailyAccess.resolve(now: now, todayDailies: dailies);
});

/// Quanto vive un'Istantanea prima che il server la cancelli.
const Duration dailyLifetime = Duration(hours: 24);

/// Quando scade l'Istantanea attiva piu' recente.
///
/// Il conto si fa qui e non sul server perche' la scadenza e' gia' decisa
/// dallo scatto: ventiquattro ore dopo, e non c'e' niente da chiedere a
/// nessuno. Nullo quando non c'e' un'Istantanea attiva.
final activeDailyExpiryProvider = Provider<DateTime?>((ref) {
  final dailies = ref.watch(todayDailiesProvider).valueOrNull ?? const <Daily>[];

  DateTime? latest;

  for (final daily in dailies) {
    final capturedAt = daily.capturedAt;

    if (!daily.isActive || capturedAt == null) {
      continue;
    }

    if (latest == null || capturedAt.isAfter(latest)) {
      latest = capturedAt;
    }
  }

  return latest?.add(dailyLifetime);
});


