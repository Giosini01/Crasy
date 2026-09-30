import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/features/friends/domain/entities/friendship.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/friends/presentation/widgets/friend_avatar.dart';
import 'package:crasy/features/friends/presentation/widgets/unfollow_dialog.dart';
import 'package:crasy/features/friends/presentation/widgets/verified_tick.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// **Seguiti: chi segui tu.**
///
/// L'altra meta' di Follower, e una domanda diversa: non "chi mi guarda" ma
/// "chi guardo". Ogni riga dice se quella persona ti segue anche lei — allora
/// siete amici — oppure no, e in quel caso da qui si smette di seguirla.
///
/// **Regge anche con duemila persone.** L'elenco dei nomi e' un elenco di
/// identificativi che l'app ha gia' in mano; le facce, i nomi e lo stato di
/// ogni riga si leggono solo per le righe che compaiono sullo schermo, mentre
/// si scorre. Duemila seguiti costano le letture delle dieci righe che si
/// vedono, non duemila.
class FollowingPage extends ConsumerWidget {
  const FollowingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // I piu' recenti in cima: l'elenco nel profilo cresce in coda.
    final seguiti = ref.watch(followedIdsProvider).reversed.toList();
    final totale = ref.watch(followingCountProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(totale > 0 ? 'Seguiti · $totale' : 'Seguiti'),
      ),
      body: AppBackground(
        child: seguiti.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: EmptyState(
                  title: 'Non segui ancora nessuno',
                  message:
                      'Segui chi conosci: vedi in quali gare sta, adesso. Se ti '
                      'segue anche lui siete amici, e potete sfidarvi.',
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  AppSpacing.xxl,
                ),
                itemCount: seguiti.length,
                itemBuilder: (context, index) =>
                    _FollowingRow(userId: seguiti[index]),
              ),
      ),
    );
  }
}

/// Una persona che segui: faccia, nome, e com'e' il rapporto.
///
/// Legge il profilo e lo stato solo quando la riga e' a schermo: i provider si
/// buttano via da soli appena la riga esce, e con loro l'ascolto sul database.
class _FollowingRow extends ConsumerWidget {
  const _FollowingRow({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final nome =
        ref.watch(publicProfileProvider(userId)).valueOrNull?.username ?? '';
    final stato =
        ref.watch(friendshipStatusProvider(userId)).valueOrNull ??
        FriendshipStatus.requestSent;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          FriendAvatar(userId: userId, username: nome),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.userProfileOf(userId)),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TickedName(
                    userId: userId,
                    text: nome.isEmpty ? '' : '@$nome',
                    style: texts.titleMedium,
                  ),
                  Text(
                    stato == FriendshipStatus.friends
                        ? 'VI SEGUITE · AMICI'
                        : 'NON TI SEGUE',
                    style: texts.labelSmall?.copyWith(
                      color: stato == FriendshipStatus.friends
                          ? palette.accent
                          : palette.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Si smette anche con gli amici: li' si chiede prima conferma, perche'
          // si perde l'amicizia. Con chi non ti segue e' un tocco e basta.
          TextButton(
            onPressed: () async {
              final azioni = ref.read(friendActionsProvider);

              if (stato != FriendshipStatus.friends) {
                await azioni.cancel(userId);

                return;
              }

              if (await confermaSmettiDiSeguire(context, username: nome)) {
                await azioni.unfollowFriend(userId);
              }
            },
            child: Text(
                'Smetti',
                style: texts.titleMedium?.copyWith(color: palette.textFaint),
              ),
            ),
        ],
      ),
    );
  }
}
