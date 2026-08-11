import 'package:app_incontri/features/stats/domain/entities/vibe_stats.dart';

abstract class StatsRepository {
  /// I numeri di una giornata precisa.
  Stream<VibeDay> watchDay(String userId, String dateKey);

  /// I totali di sempre e la striscia.
  Stream<VibeLifetime> watchLifetime(String userId);
}
