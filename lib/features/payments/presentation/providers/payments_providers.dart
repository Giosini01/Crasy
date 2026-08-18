import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/payments/data/payments_service.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentsServiceProvider = Provider<PaymentsService>(
  (ref) => PaymentsService(ref.watch(firebaseFunctionsProvider)),
);

/// I premi che ho vinto e che non ho ancora incassato.
///
/// Sono le challenge chiuse in cui ho vinto e i cui soldi sono **ancora fermi
/// su CRASY**: quasi sempre perche' non mi sono ancora registrato per
/// riceverli. Finche' questa lista non e' vuota, il profilo ha qualcosa di
/// importante da dire.
final unclaimedPrizesProvider = Provider<List<Challenge>>((ref) {
  if (!paymentsEnabled) {
    return const [];
  }

  final myEntries = ref.watch(myEntriesProvider).valueOrNull ?? const [];
  final wonChallengeIds = {
    for (final entry in myEntries)
      if (entry.isWinner) entry.challengeId,
  };

  if (wonChallengeIds.isEmpty) {
    return const [];
  }

  final ended = ref.watch(endedChallengesProvider).valueOrNull ?? const [];

  return [
    for (final challenge in ended)
      if (wonChallengeIds.contains(challenge.id) &&
          challenge.prizeStatus.isEscrowed)
        challenge,
  ];
});
