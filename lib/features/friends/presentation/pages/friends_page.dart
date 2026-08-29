import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
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
class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({super.key});

  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends ConsumerState<FriendsPage> {
  /// Quante richieste si vedono prima del "vedi le altre".
  ///
  /// Tre: abbastanza per accorgersi che ci sono, poche perche' gli amici
  /// restino sopra la piega dello schermo.
  static const int _initiallyShown = 3;

  int _requestsShown = _initiallyShown;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final requests =
        ref.watch(incomingRequestsProvider).valueOrNull ?? const [];
    final friends = ref.watch(myFriendsProvider).valueOrNull ?? const [];
    // Una lettura sola per tutti: chiedendo amico per amico sarebbero venti
    // richieste ogni volta che questa scheda si apre.
    final inGara = ref.watch(
      friendsInGameProvider([for (final amico in friends) amico.userId]),
    );

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CrasyHeaderBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.sm,
                    AppSpacing.page,
                    AppSpacing.xxl,
                  ),
                  children: [
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
                      // **Non tutte, se sono tante.** Con cento richieste in attesa
                      // l'elenco degli amici finisce due schermate piu' giu', e la
                      // scheda smette di servire a quello per cui esiste. Se ne
                      // vedono tre, e le altre stanno dietro un tocco.
                      for (final request in requests.take(_requestsShown))
                        _RequestRow(request: request),
                      if (requests.length > _requestsShown) ...[
                        const SizedBox(height: AppSpacing.xs),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _requestsShown = requests.length),
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            'VEDI LE ALTRE ${requests.length - _requestsShown}',
                            style: context.texts.labelSmall?.copyWith(
                              color: palette.accent,
                            ),
                          ),
                        ),
                      ],
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
                        // Due parole, due pesi: "I TUOI" e' la premessa, "AMICI" e'
                        // la cosa. Il rosso sta sulla seconda, come il punto rosso in
                        // fondo ai titoli dell'app — un accento, non una vernice.
                        Text.rich(
                          TextSpan(
                            style: context.texts.headlineSmall,
                            children: [
                              const TextSpan(text: 'I TUOI '),
                              TextSpan(
                                text: 'AMICI',
                                style: TextStyle(color: palette.accent),
                              ),
                            ],
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
                      for (final friend in friends)
                        _FriendRow(
                          friend: friend,
                          // **Cosa sta combinando adesso.** In cima a questa
                          // scheda c'e' scritto proprio quello, e sotto c'era
                          // un elenco di nomi: la stessa cosa che si vede nella
                          // rubrica del telefono. Questa riga e' la differenza
                          // fra una rubrica e una scheda che vale la pena
                          // aprire.
                          inGame: inGara[friend.userId],
                        ),
                  ],
                ),
              ),
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
              child: Text(
                '@${request.fromUsername}',
                style: context.texts.titleMedium,
                overflow: TextOverflow.ellipsis,
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
  const _FriendRow({required this.friend, this.inGame});

  final Friend friend;

  /// Il titolo della gara aperta a cui sta partecipando, se ce n'e' una.
  final String? inGame;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '@${friend.username}',
                    style: context.texts.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (inGame case final gara?) ...[
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 12,
                          color: context.palette.accent,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            'IN GARA  ·  ${gara.toUpperCase()}',
                            style: context.texts.labelSmall?.copyWith(
                              color: context.palette.accent,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
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
