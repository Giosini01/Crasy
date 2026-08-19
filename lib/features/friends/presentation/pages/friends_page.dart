import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/features/friends/domain/entities/friendship.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/friends/presentation/widgets/friend_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Gli amici.
///
/// Due blocchi e nient'altro: **chi ti ha chiesto l'amicizia** e **chi ce
/// l'hai gia'**. Le richieste stanno in cima perche' sono l'unica cosa che
/// aspetta una risposta da te; gli amici stanno sotto perche' sono un elenco da
/// consultare, non da smaltire.
///
/// Non c'e' una ricerca per nome, e non e' una dimenticanza: qui le persone si
/// incontrano guardando le foto che mandano alle challenge, non digitando un
/// nome che si dovrebbe gia' conoscere.
class FriendsPage extends ConsumerWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final requests =
        ref.watch(incomingRequestsProvider).valueOrNull ?? const [];
    final friends = ref.watch(myFriendsProvider).valueOrNull ?? const [];

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.xxl,
            ),
            children: [
              const CrasyHeader(),
              const SizedBox(height: AppSpacing.lg),
              const HighlightedText(
                'Le persone che conosci, e cosa stanno combinando.',
                highlight: 'cosa stanno combinando',
              ),
              const SizedBox(height: AppSpacing.xl),
              if (requests.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      'TI HANNO CHIESTO',
                      style: context.texts.labelSmall?.copyWith(
                        color: palette.accent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${requests.length}',
                      style: context.texts.labelSmall?.copyWith(
                        color: palette.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final request in requests) _RequestRow(request: request),
                const SizedBox(height: AppSpacing.lg),
                Divider(color: palette.line),
                const SizedBox(height: AppSpacing.lg),
              ],
              // Il titolo della sezione e' grande e rosso, non una scritta
              // grigia in punta di piedi. E' la schermata delle persone che
              // uno conosce: senza il rosso e' un elenco di nomi, con il rosso
              // e' la parte di CRASY che gli appartiene.
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'I TUOI AMICI',
                    style: context.texts.headlineSmall?.copyWith(
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  if (friends.isNotEmpty)
                    Text(
                      '${friends.length}',
                      style: context.texts.titleMedium?.copyWith(
                        color: palette.textFaint,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (friends.isEmpty)
                const EmptyState(
                  title: 'Ancora nessun amico',
                  message:
                      'Tocca il nome sotto una foto per aprire il profilo di '
                      'chi l\'ha mandata, e da li\' chiedigli l\'amicizia.',
                )
              else
                for (final friend in friends) _FriendRow(friend: friend),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una richiesta: chi e', e le due risposte possibili.
///
/// Accetta e rifiuta stanno una accanto all'altra e hanno peso diverso — una e'
/// rossa, l'altra e' grigia. Non e' una scelta simmetrica: rifiutare non deve
/// costare un pensiero, ma nemmeno essere il gesto piu' facile per sbaglio.
class _RequestRow extends ConsumerWidget {
  const _RequestRow({required this.request});

  final FriendRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final actions = ref.read(friendActionsProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          FriendAvatar(
            userId: request.fromUserId,
            username: request.fromUsername,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  context.push(AppRoutes.userProfileOf(request.fromUserId)),
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: context.texts.titleMedium,
                  children: [
                    TextSpan(
                      text: '@',
                      style: TextStyle(color: palette.accent),
                    ),
                    TextSpan(text: request.fromUsername),
                  ],
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () => actions.reject(request),
            child: Text(
              'No',
              style: context.texts.titleMedium?.copyWith(
                color: palette.textFaint,
              ),
            ),
          ),
          TextButton(
            onPressed: () => actions.accept(request),
            child: Text(
              'Accetta',
              style: context.texts.titleMedium?.copyWith(color: palette.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend});

  final Friend friend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.userProfileOf(friend.userId)),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            FriendAvatar(userId: friend.userId, username: friend.username),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              // La chiocciola in rosso e il nome in nero: e' un segno piccolo
              // ripetuto molte volte, e sono i segni piccoli ripetuti a dare a
              // un elenco l'aria di appartenere a qualcosa.
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: context.texts.titleMedium,
                  children: [
                    TextSpan(
                      text: '@',
                      style: TextStyle(color: context.palette.accent),
                    ),
                    TextSpan(text: friend.username),
                  ],
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.palette.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}
