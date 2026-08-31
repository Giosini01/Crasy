import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/moderation/data/moderation_repository.dart';
import 'package:crasy/features/moderation/domain/report_reason.dart';
import 'package:crasy/services/firebase/firebase_bootstrap_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Il repository delle segnalazioni.
///
/// Nullo senza Firebase configurato — nelle prove e nella modalita' dimostrativa
/// — e le schermate lo sanno: segnalare una foto finta non ha senso, e
/// fingere che sia partita sarebbe peggio che non offrire il comando.
final moderationRepositoryProvider = Provider<ModerationRepository?>((ref) {
  if (!ref.watch(firebaseBootstrapResultProvider).isConfigured) {
    return null;
  }

  return ModerationRepository(ref.watch(firebaseFirestoreProvider));
});

/// Chi ho bloccato.
///
/// **Un ascolto solo, vivo per tutta la sessione.** Serve a ogni schermata che
/// mostra roba scritta da altri — foto, commenti, richieste di amicizia — e
/// caricarlo dove serve vorrebbe dire caricarlo dieci volte. E' un elenco corto
/// e cambia quasi mai.
///
/// Vuoto quando non c'e' nessuno collegato, cosi' chi lo legge non deve
/// chiedersi in che stato e'.
final blockedIdsProvider = StreamProvider<Set<String>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final repository = ref.watch(moderationRepositoryProvider);

  if (userId == null || repository == null) {
    return Stream.value(const <String>{});
  }

  return repository.watchBlocked(userId);
});

/// Comodo per chi deve solo filtrare: mai nullo, mai in attesa.
final blockedNowProvider = Provider<Set<String>>(
  (ref) => ref.watch(blockedIdsProvider).valueOrNull ?? const <String>{},
);

/// Segnalare e bloccare.
class ModerationActions {
  ModerationActions(this._ref);

  final Ref _ref;

  /// Manda una segnalazione. Torna `false` se non e' partita.
  Future<bool> report({
    required ReportTargetKind kind,
    required String reportedUserId,
    required ReportReason reason,
    String challengeId = '',
    String entryId = '',
    String commentId = '',
    String note = '',
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    final repository = _ref.read(moderationRepositoryProvider);

    if (userId == null || repository == null) {
      return false;
    }

    try {
      await repository.report(
        kind: kind,
        reporterId: userId,
        reportedUserId: reportedUserId,
        reason: reason,
        challengeId: challengeId,
        entryId: entryId,
        commentId: commentId,
        note: note,
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> block(String otherId) async {
    final userId = _ref.read(currentUserIdProvider);
    final repository = _ref.read(moderationRepositoryProvider);

    if (userId == null || repository == null || userId == otherId) {
      return false;
    }

    try {
      await repository.block(userId: userId, otherId: otherId);

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unblock(String otherId) async {
    final userId = _ref.read(currentUserIdProvider);
    final repository = _ref.read(moderationRepositoryProvider);

    if (userId == null || repository == null) {
      return false;
    }

    try {
      await repository.unblock(userId: userId, otherId: otherId);

      return true;
    } catch (_) {
      return false;
    }
  }
}

final moderationActionsProvider = Provider<ModerationActions>(
  ModerationActions.new,
);
