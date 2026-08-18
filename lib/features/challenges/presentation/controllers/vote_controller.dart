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

/// La fiamma che l'utente ha appena chiesto, finche' il server non conferma.
///
/// **Sta in un provider e non dentro un widget**, ed e' la correzione di un bug
/// vero: il doppio tocco sulla foto e il tocco sulla fiamma sotto erano due
/// comandi con due memorie separate. Chi faceva doppio tocco e poi toccava la
/// fiamma vedeva il numero salire di due, perche' il secondo comando non sapeva
/// niente del primo.
///
/// Ora la memoria e' una sola, per partecipazione, e qualunque gesto la
/// aggiorna: due gesti sulla stessa foto sono lo stesso gesto.
final pendingVoteProvider = StateProvider.family<bool?, String>(
  (ref, entryId) => null,
);

/// Se la fiamma di questa foto e' accesa **per come la vede l'utente**.
///
/// Quello che ha appena chiesto vince su quello che dice il server: fra il tocco
/// e la risposta di Firestore passa qualche decimo di secondo, e in quel momento
/// deve vedere il gesto fatto, non lo stato di prima.
final entryVotedProvider = Provider.family<bool, String>((ref, entryId) {
  final confirmed =
      ref.watch(votedEntryIdsProvider).valueOrNull?.contains(entryId) ?? false;

  return ref.watch(pendingVoteProvider(entryId)) ?? confirmed;
});

/// Di quanto va corretto il contatore che arriva dal server.
///
/// Zero quando il server e' gia' allineato. Vale uno solo nell'attimo in cui la
/// scrittura e' in volo: il numero che abbiamo in mano non comprende ancora il
/// nostro voto, e glielo aggiungiamo noi.
final entryVoteDeltaProvider = Provider.family<int, String>((ref, entryId) {
  final confirmed =
      ref.watch(votedEntryIdsProvider).valueOrNull?.contains(entryId) ?? false;
  final pending = ref.watch(pendingVoteProvider(entryId));

  if (pending == null || pending == confirmed) {
    return 0;
  }

  return pending ? 1 : -1;
});

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
    // voto in piu' per ciascuno, non un vantaggio per qualcuno.
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
