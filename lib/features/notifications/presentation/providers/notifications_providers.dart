import 'dart:async';

import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/notifications/data/push_registry.dart';
import 'package:crasy/features/notifications/data/repositories/firestore_notifications_repository.dart';
import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:crasy/services/firebase/firebase_bootstrap_result.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
/// Le vittorie e gli avvisi sulla scelta **non stanno sul database come
/// notifiche**: si ricavano da dati che esistono gia'. Scriverle sarebbe fare
/// una copia di qualcosa che puo' cambiare — una richiesta ritirata lascerebbe
/// in campanella l'avviso di una richiesta che non c'e' piu', e togliere quella
/// riga vorrebbe dire tenere sincronizzate due verita' invece di leggerne una.
final notificationsProvider = Provider<List<AppNotification>>((ref) {
  final stored = ref.watch(storedNotificationsProvider).valueOrNull ?? const [];
  final myEntries = ref.watch(myEntriesProvider).valueOrNull ?? const [];
  final ended = ref.watch(endedChallengesProvider).valueOrNull ?? const [];

  // Le gare finite che non hanno ancora un vincitore proclamato: dura un
  // istante, perche' la chiude il primo che le apre.
  final aspettano = [
    for (final challenge in ended)
      if (challenge.winnerEntryId == null) challenge,
  ];
  final partecipate = {for (final entry in myEntries) entry.challengeId};

  final all = <AppNotification>[
    ...stored,
    // **Chi ha partecipato sa che la gara e' chiusa.**
    //
    // Una gara che finisce e poi tace e' il modo piu' rapido di far pensare che
    // i soldi non arriveranno. Qui si dice che e' finita, e chi ha mandato una
    // foto va a vedere com'e' andata — che e' anche il momento in cui una
    // vittoria si scopre senza aspettare che qualcuno la comunichi.
    for (final challenge in aspettano)
      if (partecipate.contains(challenge.id))
        AppNotification(
          id: 'finita_${challenge.id}',
          kind: NotificationKind.ended,
          challengeId: challenge.id,
          challengeTitle: challenge.title,
          createdAt: challenge.endsAt,
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

/// Il registro dei dispositivi per le notifiche.
final pushRegistryProvider = Provider<PushRegistry?>((ref) {
  if (!ref.watch(firebaseBootstrapResultProvider).isConfigured) {
    return null;
  }

  return PushRegistry(
    ref.watch(firebaseFirestoreProvider),
    FirebaseMessaging.instance,
  );
});

/// Tiene il registro dei dispositivi allineato a chi e' collegato.
///
/// **Si accende e si spegne da solo**, seguendo la sessione: chi entra registra
/// il proprio telefono, chi esce lo toglie. Senza la seconda meta', il telefono
/// di chi ha fatto uscire l'account continuerebbe a ricevere le notifiche di
/// quella persona — anche mesi dopo, anche se nel frattempo lo usa qualcun
/// altro.
///
/// Il permesso si chiede qui e non all'avvio, ed e' una scelta che non si puo'
/// disfare: su iPhone la richiesta si fa **una volta sola** nella vita
/// dell'installazione. Chiederla prima che uno abbia capito cosa sia CRASY
/// vuol dire bruciarla.
final pushRegistrationProvider = Provider<void>((ref) {
  final registro = ref.watch(pushRegistryProvider);

  if (registro == null) {
    return;
  }

  final authState = ref.watch(authStateProvider);

  if (authState is! AuthenticatedAuthState) {
    return;
  }

  final userId = authState.user.id;

  unawaited(registro.register(userId));
  ref.onDispose(() => unawaited(registro.unregister(userId)));
});
