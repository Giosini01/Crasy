import 'package:app_incontri/features/matches/domain/entities/match_person.dart';

abstract class MatchesRepository {
  /// I match di [userId], dal piu' recente.
  Stream<List<MatchPerson>> watchMatches(String userId);
}
