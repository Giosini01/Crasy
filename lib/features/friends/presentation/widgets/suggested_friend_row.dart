import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/features/friends/domain/entities/suggested_friend.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/friends/presentation/widgets/friend_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Una persona trovata in rubrica: faccia, nome, e il tasto per chiederle
/// l'amicizia senza aprire niente.
///
/// **Il tasto e' rosso e dice cosa fa.** Sta in tre posti diversi — il primo
/// ingresso, il pannello del profilo, la pagina degli amici — e in tutti e tre
/// e' questo stesso pezzo di schermo: tre copie somiglianti avrebbero preso
/// strade diverse alla prima modifica, e sarebbe successo senza che nessuno se
/// ne accorgesse.
class SuggestedFriendRow extends ConsumerStatefulWidget {
  const SuggestedFriendRow({required this.suggested, super.key});

  final SuggestedFriend suggested;

  @override
  ConsumerState<SuggestedFriendRow> createState() => _SuggestedFriendRowState();
}

class _SuggestedFriendRowState extends ConsumerState<SuggestedFriendRow> {
  bool _inviata = false;

  Future<void> _chiedi() async {
    // Il tasto cambia subito: la richiesta parte, e se il server dovesse
    // rifiutarla il posto per dirlo non e' una riga che fra un secondo non
    // c'e' piu'.
    setState(() => _inviata = true);

    await ref.read(friendActionsProvider).send(widget.suggested.userId);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final chi = widget.suggested;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          FriendAvatar(userId: chi.userId, username: chi.username),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.userProfileOf(chi.userId)),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    chi.nome,
                    style: context.texts.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (chi.displayName.isNotEmpty)
                    Text(
                      '@${chi.username}',
                      style: context.texts.bodySmall?.copyWith(
                        color: palette.textFaint,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // **Inviata non torna indietro.** Non e' una svista: disdire una
          // richiesta si fa dal profilo di quella persona, dove si vede tutto
          // il rapporto. Qui, in una riga che sparira', un tasto che annulla
          // sarebbe un modo di sbagliarsi in fretta.
          _inviata
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Text(
                    'INVIATA',
                    style: context.texts.labelSmall?.copyWith(
                      color: palette.textFaint,
                    ),
                  ),
                )
              : FilledButton(
                  onPressed: _chiedi,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('Invia richiesta'),
                ),
        ],
      ),
    );
  }
}
