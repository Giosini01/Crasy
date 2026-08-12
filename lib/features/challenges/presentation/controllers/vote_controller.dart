import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final voteControllerProvider = Provider<VoteController>(VoteController.new);

/// Com'e' andata a finire una fiamma.
enum VoteOutcome {
  /// Fatto: il numero e' cambiato.
  done,

  /// Serve un account. Capita solo sulle challenge vere.
  needsAccount,
}

/// La fiamma.
///
/// Non e' un `AsyncNotifier` e non ha uno stato di caricamento, ed e' una
/// scelta: e' il gesto piu' frequente dell'app, e mettere una rotellina su una
/// fiamma la farebbe sembrare lenta anche quando e' istantanea. Il numero sullo
/// schermo arriva dallo stream, che si aggiorna da solo appena la scrittura e'
/// andata a segno.
class VoteController {
  const VoteController(this._ref);

  final Ref _ref;

  Future<VoteOutcome> toggle(
    ChallengeEntry entry, {
    required bool voted,
  }) async {
    final authState = _ref.read(authStateProvider);
    final signedIn = authState is AuthenticatedAuthState;
    final isDemo = entry.challengeId.startsWith(Challenge.demoIdPrefix);

    // Sulle challenge vere un ospite non vota: con dei soldi in palio un voto
    // senza nome non vale niente. Su quelle di esempio si', perche' vivono in
    // memoria e servono proprio a far provare il gesto prima di registrarsi.
    if (!signedIn && !isDemo) {
      return VoteOutcome.needsAccount;
    }

    final userId = signedIn ? authState.user.id : guestVoterId;

    // **La propria foto si puo' votare.** Sembra un buco e non lo e': tutti
    // possono farlo, quindi non sposta la classifica di un millimetro — e' un
    // voto in piu' per ciascuno, non un vantaggio per qualcuno. Vietarlo
    // servirebbe solo a far sembrare rotta l'app a chi tocca la propria foto e
    // non vede succedere niente.
    //
    // A tenere onesta la gara e' un'altra regola: chi lancia la challenge non
    // puo' parteciparvi.
    await _ref
        .read(challengeRepositoryProvider)
        .setVote(
          challengeId: entry.challengeId,
          entryId: entry.id,
          userId: userId,
          voted: voted,
        );

    return VoteOutcome.done;
  }
}
