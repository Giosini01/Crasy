import 'dart:async';

import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/notifications/data/repositories/firestore_notifications_repository.dart';
import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
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
/// Chiave: `ChallengeEntry.voteKey`, non l'identificativo della partecipazione.
/// Due gare diverse sono due voti diversi anche se la foto e' della stessa
/// persona — vedi `voteKey` per il perche'.
final pendingVoteProvider = StateProvider.family<bool?, String>(
  (ref, voteKey) => null,
);

/// Se la fiamma di questa foto e' accesa **per come la vede l'utente**.
///
/// Quello che ha appena chiesto vince su quello che dice il server: fra il tocco
/// e la risposta di Firestore passa qualche decimo di secondo, e in quel momento
/// deve vedere il gesto fatto, non lo stato di prima.
final entryVotedProvider = Provider.family<bool, String>((ref, voteKey) {
  final confirmed =
      ref.watch(votedEntryIdsProvider).valueOrNull?.contains(voteKey) ?? false;

  return ref.watch(pendingVoteProvider(voteKey)) ?? confirmed;
});

/// Di quanto va corretto il contatore che arriva dal server.
///
/// Zero quando il server e' gia' allineato. Vale uno solo nell'attimo in cui la
/// scrittura e' in volo: il numero che abbiamo in mano non comprende ancora il
/// nostro voto, e glielo aggiungiamo noi.
final entryVoteDeltaProvider = Provider.family<int, String>((ref, voteKey) {
  final confirmed =
      ref.watch(votedEntryIdsProvider).valueOrNull?.contains(voteKey) ?? false;
  final pending = ref.watch(pendingVoteProvider(voteKey));

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
  VoteController(this._ref);

  final Ref _ref;

  /// L'ultima scrittura ancora in volo per ogni partecipazione.
  ///
  /// Serve a metterle **in fila**. Senza, due tocchi rapidi sulla stessa foto
  /// aprono due transazioni contemporanee, e ognuna delle due legge il database
  /// prima che l'altra abbia scritto: partono tutte e due dallo stesso stato di
  /// partenza e la seconda decide in base a un mondo che non esiste piu'. Il
  /// risultato era il contatore che rimaneva indietro, o il cuore acceso su un
  /// voto che sul database non c'era.
  ///
  /// In fila, invece, ogni scrittura vede il risultato di quella prima e
  /// l'ultimo tocco vince — che e' esattamente quello che si aspetta chi tocca.
  final Map<String, Future<void>> _inFlight = {};

  Future<VoteOutcome> toggle(ChallengeEntry entry, {required bool voted}) {
    final previous = _inFlight[entry.id] ?? Future<void>.value();
    final next = previous
        .then((_) => _write(entry, voted: voted))
        // La coda non si deve interrompere per un errore: se una scrittura
        // fallisce, il tocco successivo deve poter riprovare invece di restare
        // agganciato a una catena morta.
        .catchError((Object error) {
          _inFlight.remove(entry.id);

          throw error;
        });

    _inFlight[entry.id] = next.then((_) {}, onError: (Object _) {});

    return next;
  }

  Future<VoteOutcome> _write(
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

    if (voted && signedIn) {
      // L'avviso parte **dopo** che la fiamma e' stata scritta, e non aspetta:
      // se la notifica fallisse, la fiamma resterebbe comunque data. E' un
      // dettaglio di contorno, non deve poter rompere il gesto principale
      // dell'app.
      //
      // Non si avvisa quando la fiamma si toglie: nessuno vuole leggere che
      // qualcuno ci ha ripensato.
      unawaited(_notifyAuthor(entry, actorId: userId));
    }

    return VoteOutcome.done;
  }

  Future<void> _notifyAuthor(
    ChallengeEntry entry, {
    required String actorId,
  }) async {
    final notifications = _ref.read(notificationsRepositoryProvider);

    if (notifications == null || entry.userId == actorId) {
      return;
    }

    final me = _ref.read(currentUserProfileProvider).valueOrNull;

    await notifications.push(
      toUserId: entry.userId,
      // Lo stesso nome ogni volta: chi toglie e rimette la fiamma venti volte
      // non manda venti notifiche, manda venti volte la stessa — e le regole
      // ne accettano solo la prima.
      id: FirestoreNotificationsRepository.fireId(
        voteKey: entry.voteKey,
        actorId: actorId,
      ),
      kind: NotificationKind.fire,
      actorId: actorId,
      actorUsername: me?.username ?? '',
      challengeId: entry.challengeId,
      challengeTitle: entry.challengeTitle,
    );
  }
}
