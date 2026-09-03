import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/widgets/count_dot.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// La campanella in cima alla home, con il numero di quello che e' successo.
///
/// Il pallino rosso e' l'unico posto dell'intestazione in cui compare il
/// colore, e deve restarlo: se ce l'avessero anche le altre icone smetterebbe
/// di voler dire "guarda qui" e vorrebbe dire "questa e' un'icona".
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider);

    return IconButton(
      onPressed: () => context.push(AppRoutes.notifications),
      tooltip: unread > 0 ? '$unread notifiche nuove' : 'Notifiche',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            unread > 0
                ? Icons.notifications_rounded
                : Icons.notifications_none_rounded,
          ),
          if (unread > 0)
            Positioned(top: -4, right: -6, child: CountDot(count: unread)),
        ],
      ),
    );
  }
}
