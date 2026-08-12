import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final voteControllerProvider = Provider<VoteController>(VoteController.new);

/// Il voto.
///
/// Non e' un `AsyncNotifier` e non ha uno stato di caricamento, ed e' una
/// scelta: il voto e' il gesto piu' frequente dell'app, e mettere una rotellina
/// su un cuore lo farebbe sembrare lento anche quando e' istantaneo. Il numero
/// sullo schermo arriva dallo stream, che si aggiorna da solo appena la
/// scrittura e' andata a segno.
///
/// Se la scrittura fallisce il conteggio semplicemente non cambia. Con un voto
/// e' la cosa giusta — non c'e' niente da recuperare e niente da spiegare.
class VoteController {
  const VoteController(this._ref);

  final Ref _ref;

  Future<void> toggle(ChallengeEntry entry, {required bool voted}) async {
    final authState = _ref.read(authStateProvider);

    if (authState is! AuthenticatedAuthState) {
      return;
    }

    // Nessuno vota se stesso. Con dei soldi in palio non e' una questione di
    // eleganza: e' il primo modo in cui si prova a barare.
    if (entry.userId == authState.user.id) {
      return;
    }

    await _ref
        .read(challengeRepositoryProvider)
        .setVote(
          challengeId: entry.challengeId,
          entryId: entry.id,
          userId: authState.user.id,
          voted: voted,
        );
  }
}
