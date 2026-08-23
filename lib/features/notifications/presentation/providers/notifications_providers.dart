import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/notifications/data/repositories/firestore_notifications_repository.dart';
import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:crasy/services/firebase/firebase_bootstrap_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationsRepositoryProvider =
    Provider<FirestoreNotificationsRepository?>((ref) {
      if (!ref.watch(firebaseBootstrapResultProvider).isConfigured) {
        return null;
      }

      return FirestoreNotificationsRepository(
        ref.watch(firebaseFirestoreProvider),
      );
    });

/// Le notifiche scritte da altri: partecipazioni e fiamme.
final storedNotificationsProvider = StreamProvider<List<AppNotification>>((
  ref,
) {
  final repository = ref.watch(notificationsRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (repository == null || userId == null) {
    return Stream.value(const <AppNotification>[]);
  }

  return repository.watch(userId);
});

/// Quando si e' aperta la campanella l'ultima volta.
final notificationsSeenAtProvider = StreamProvider<DateTime?>((ref) {
  final repository = ref.watch(notificationsRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (repository == null || userId == null) {
    return Stream.value(null);
  }

  return repository.watchSeenAt(userId);
});

/// Tutte le notifiche, quelle scritte e quelle ricavate, in un elenco solo.
///
/// Le richieste di amicizia e le vittorie **non stanno sul database come
/// notifiche**: si ricavano da dati che esistono gia'. Scriverle sarebbe fare
/// una copia di qualcosa che puo' cambiare — una richiesta ritirata lascerebbe
/// in campanella l'avviso di una richiesta che non c'e' piu', e togliere quella
/// riga vorrebbe dire tenere sincronizzate due verita' invece di leggerne una.
final notificationsProvider = Provider<List<AppNotification>>((ref) {
  final stored = ref.watch(storedNotificationsProvider).valueOrNull ?? const [];
  final requests = ref.watch(incomingRequestsProvider).valueOrNull ?? const [];
  final myEntries = ref.watch(myEntriesProvider).valueOrNull ?? const [];
  final me = ref.watch(currentUserIdProvider);
  final ended = ref.watch(endedChallengesProvider).valueOrNull ?? const [];
  final now = DateTime.now();

  // Le gare finite che aspettano ancora una scelta. Una sola lettura per tutte
  // e due le notizie qui sotto.
  final aspettano = [
    for (final challenge in ended)
      if (challenge.winnerEntryId == null) challenge,
  ];
  final partecipate = {for (final entry in myEntries) entry.challengeId};

  final all = <AppNotification>[
    ...stored,
    for (final request in requests)
      AppNotification(
        id: 'amicizia_${request.fromUserId}',
        kind: NotificationKind.friendRequest,
        actorId: request.fromUserId,
        actorUsername: request.fromUsername,
        createdAt: request.createdAt,
      ),
    // **Chi ha partecipato sa che si sta decidendo.** Una gara che finisce e
    // poi tace per un giorno intero e' il modo piu' rapido di far pensare che
    // i soldi non arriveranno: qui si dice chi sta decidendo, e sulla scheda
    // della gara c'e' anche entro quando.
    for (final challenge in aspettano)
      if (partecipate.contains(challenge.id) && challenge.createdByUserId != me)
        AppNotification(
          id: 'scelta_${challenge.id}',
          kind: NotificationKind.choosing,
          actorId: challenge.createdByUserId,
          actorUsername: challenge.createdByUsername,
          challengeId: challenge.id,
          challengeTitle: challenge.title,
          createdAt: challenge.endsAt,
        ),
    // **A chi deve scegliere si ricorda, e si ricorda di nuovo.**
    //
    // La data non e' quella in cui la gara e' finita: avanza di sei ore in sei
    // ore. E' cio' che rende questo avviso **ripetuto** senza scrivere niente
    // da nessuna parte — a ogni scatto torna a contare come non letto, il
    // pallino rosso sulla campanella si riaccende, e smette da solo nel momento
    // esatto in cui il premio viene assegnato.
    for (final challenge in aspettano)
      if (challenge.createdByUserId == me && me != null)
        AppNotification(
          id: 'devi_scegliere_${challenge.id}',
          kind: NotificationKind.mustChoose,
          challengeId: challenge.id,
          challengeTitle: challenge.title,
          createdAt: _reminderAt(challenge.endsAt, now),
        ),
    for (final entry in myEntries)
      if (entry.isWinner)
        AppNotification(
          id: 'vittoria_${entry.challengeId}',
          kind: NotificationKind.win,
          challengeId: entry.challengeId,
          challengeTitle: entry.challengeTitle,
          createdAt: entry.createdAt,
        ),
  ];

  all.sort((a, b) {
    final at = a.createdAt;
    final bt = b.createdAt;

    if (at == null && bt == null) {
      return 0;
    }

    if (at == null) {
      return -1;
    }

    if (bt == null) {
      return 1;
    }

    return bt.compareTo(at);
  });

  return all;
});

/// Ogni quanto il promemoria di scegliere torna a farsi vivo.
const _reminderEvery = Duration(hours: 6);

/// Il momento a cui far risalire il promemoria.
///
/// Scatta a blocchi di sei ore dalla fine della gara: la data cambia, quindi
/// chi ha gia' aperto la campanella se la ritrova **non letta** al giro dopo.
/// Nessuna scrittura, nessuna coda di avvisi da spedire: e' la stessa cosa che
/// dice il database, letta in un altro modo.
DateTime _reminderAt(DateTime endsAt, DateTime now) {
  final passate = now.difference(endsAt);

  if (passate.isNegative) {
    return endsAt;
  }

  final scatti = passate.inMinutes ~/ _reminderEvery.inMinutes;

  return endsAt.add(_reminderEvery * scatti);
}

/// Quante notifiche sono arrivate dall'ultima occhiata.
///
/// E' il numero rosso sulla campanella, e si ferma a nove: oltre, il numero
/// preciso non aiuta a decidere niente e un pallino largo mezza icona da'
/// fastidio.
final unreadNotificationsProvider = Provider<int>((ref) {
  final seenAt = ref.watch(notificationsSeenAtProvider).valueOrNull;

  return ref
      .watch(notificationsProvider)
      .where((notification) => notification.isUnreadSince(seenAt))
      .length;
});
