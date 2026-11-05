import 'dart:async';

import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/moderation/data/moderation_repository.dart';
import 'package:crasy/features/moderation/domain/report_reason.dart';
import 'package:crasy/services/firebase/firebase_bootstrap_result.dart';
import 'package:flutter/foundation.dart';
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

/// **I commenti segnalati in questa sessione**, che chi li ha segnalati non vede
/// piu'. Sono in memoria e non su Firestore: un commento non si modifica, e
/// scrivere sul documento chi l'ha segnalato lo farebbe leggere a tutti.
final commentiSegnalatiProvider = StateProvider<Set<String>>(
  (ref) => const <String>{},
);

/// **Toglie dalla lista quello che viene da chi ho bloccato, senza riaprire la
/// lettura.**
///
/// Serve dove la lista e' un ascolto su Firestore che dura tutta la sessione,
/// come la home: mettendo l'elenco dei bloccati fra le dipendenze, ogni blocco —
/// e ogni avvio, appena quell'elenco arriva — chiuderebbe e riaprirebbe
/// l'ascolto, con la schermata che lampeggia e le letture pagate due volte. Qui
/// l'ascolto resta quello, e la lista si rifiltra da sola: **chi blocca vede
/// sparire i contenuti nell'istante in cui conferma**.
Stream<List<T>> senzaBloccati<T>(
  Ref ref,
  Stream<List<T>> sorgente,
  bool Function(T elemento, Set<String> bloccati) daTogliere,
) {
  final uscita = StreamController<List<T>>();
  List<T>? ultima;

  void manda() {
    final lista = ultima;

    if (lista == null || uscita.isClosed) {
      return;
    }

    final bloccati = ref.read(blockedNowProvider);

    uscita.add(
      bloccati.isEmpty
          ? lista
          : [
              for (final elemento in lista)
                if (!daTogliere(elemento, bloccati)) elemento,
            ],
    );
  }

  final ascolto = sorgente.listen(
    (lista) {
      ultima = lista;
      manda();
    },
    onError: uscita.addError,
    onDone: uscita.close,
  );

  ref.listen<Set<String>>(blockedNowProvider, (prima, adesso) {
    if (!setEquals(prima, adesso)) {
      manda();
    }
  });

  ref.onDispose(() {
    ascolto.cancel();
    uscita.close();
  });

  return uscita.stream;
}

/// Se una gara va nascosta a chi ha bloccato [bloccati].
///
/// Lanciata da chi ho bloccato, o vinta da chi ho bloccato: nella home, fra le
/// gare finite e nelle facce dei vincitori. **Non le mie**, anche se ha vinto
/// una persona che ho bloccato: restano la mia missione e i miei soldi. Le
/// anonime non si possono filtrare, ed e' giusto: da fuori non si sa di chi sono.
bool garaDaNascondere(Challenge gara, Set<String> bloccati, String? io) {
  if (gara.createdByUserId == io && gara.createdByUserId.isNotEmpty) {
    return false;
  }

  return bloccati.contains(gara.createdByUserId) ||
      bloccati.contains(gara.winnerUserId);
}

/// Segnalare e bloccare.
class ModerationActions {
  ModerationActions(this._ref);

  final Ref _ref;

  /// Manda una segnalazione.
  Future<ReportOutcome> report(
    ReportTarget target, {
    required ReportReason reason,
    String note = '',
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    final repository = _ref.read(moderationRepositoryProvider);

    if (userId == null || repository == null) {
      return ReportOutcome.failed;
    }

    try {
      final esito = await repository.report(
        kind: target.kind,
        reporterId: userId,
        reportedUserId: target.reportedUserId,
        reason: reason,
        challengeId: target.challengeId,
        entryId: target.entryId,
        commentId: target.commentId,
        note: note.trim(),
        reportedUsername: target.reportedUsername,
        mediaUrl: target.mediaUrl,
        challengeTitle: target.challengeTitle,
        commentText: target.commentText,
      );

      if (target.kind == ReportTargetKind.comment) {
        final segnalati = _ref.read(commentiSegnalatiProvider.notifier);

        segnalati.state = {...segnalati.state, target.commentId};
      }

      return esito;
    } catch (_) {
      return ReportOutcome.failed;
    }
  }

  /// Blocca chi ha pubblicato [target]. Il contenuto da cui si parte finisce
  /// nell'evento che arriva al team: dice cosa ha fatto scattare il blocco.
  Future<bool> block(ReportTarget target) async {
    final userId = _ref.read(currentUserIdProvider);
    final repository = _ref.read(moderationRepositoryProvider);
    final otherId = target.reportedUserId;

    if (userId == null ||
        repository == null ||
        otherId.isEmpty ||
        userId == otherId) {
      return false;
    }

    try {
      await repository.block(
        userId: userId,
        otherId: otherId,
        origine: target.kind.name,
        challengeId: target.challengeId,
        entryId: target.entryId,
        commentId: target.commentId,
      );

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
