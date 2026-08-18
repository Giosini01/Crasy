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
