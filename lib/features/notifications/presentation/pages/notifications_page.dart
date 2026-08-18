import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/presentation/widgets/friend_avatar.dart';
import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// La campanella.
///
/// Un elenco e basta: chi ha fatto cosa, quando, e dove porta. Non ci sono
/// sezioni, non c'e' "oggi" e "questa settimana", non c'e' niente da
/// archiviare — sono poche righe che si leggono in tre secondi e poi non
/// servono piu'.
///
/// Si segna tutto come visto **aprendo la pagina**, non riga per riga. Chi apre
/// la campanella le ha viste: chiedergli anche di toccarne una per volta
/// sarebbe dargli un lavoro per un problema che non ha.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();

    // Dopo la prima frame, non durante: qui si scrive sul database, e farlo
    // mentre l'albero dei widget si sta costruendo e' il modo classico di
    // ritrovarsi un errore che non c'entra niente con la causa.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repository = ref.read(notificationsRepositoryProvider);
      final userId = ref.read(currentUserIdProvider);

      if (repository != null && userId != null) {
        repository.markSeen(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifiche')),
      body: AppBackground(
        child: notifications.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: EmptyState(
                  title: 'Ancora niente',
                  message:
                      'Qui finisce quello che fanno gli altri: chi partecipa '
                      'alle tue challenge, chi accende una fiamma sulle tue '
                      'foto, chi ti chiede l\'amicizia.',
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                  vertical: AppSpacing.md,
                ),
                itemCount: notifications.length,
                itemBuilder: (context, index) =>
                    _Row(notification: notifications[index]),
              ),
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.notification});

  final AppNotification notification;

  void _open(BuildContext context) {
    if (notification.kind == NotificationKind.friendRequest) {
      context.push(AppRoutes.friends);

      return;
    }

    if (notification.challengeId.isNotEmpty) {
      context.push(AppRoutes.challengeDetailOf(notification.challengeId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final seenAt = ref.watch(notificationsSeenAtProvider).valueOrNull;
    final unread = notification.isUnreadSince(seenAt);
    final createdAt = notification.createdAt;
    final isWin = notification.kind == NotificationKind.win;

    return GestureDetector(
      onTap: () => _open(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isWin)
              Icon(Icons.emoji_events, size: 36, color: palette.accent)
            else
              FriendAvatar(
                userId: notification.actorId,
                username: notification.actorUsername,
                size: 36,
              ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.message,
                    style: isWin
                        ? texts.titleMedium?.copyWith(color: palette.accent)
                        : texts.bodyMedium,
                  ),
                  if (notification.challengeTitle.isNotEmpty)
                    Text(
                      notification.challengeTitle.toUpperCase(),
                      style: texts.labelSmall?.copyWith(
                        color: palette.textFaint,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            if (createdAt != null)
              Text(
                AppDateUtils.shortTimeAgo(createdAt),
                style: texts.labelSmall?.copyWith(color: palette.textFaint),
              ),
            // Il pallino sta a destra e non a sinistra: a sinistra sposterebbe
            // il testo di ogni riga non letta, e l'elenco non sarebbe piu'
            // allineato con se stesso.
            if (unread) ...[
              const SizedBox(width: AppSpacing.xs),
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
