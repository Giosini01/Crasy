import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/modal_sheet.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/friends/presentation/widgets/friend_avatar.dart';
import 'package:crasy/features/moderation/presentation/providers/moderation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chi hai bloccato, e come si torna indietro.
///
/// **Serve perche' il blocco sia usabile.** Un blocco senza sblocco e' una
/// decisione definitiva, e le decisioni definitive si evitano: la gente
/// smetterebbe di bloccare e continuerebbe a leggere cose che non vuole
/// leggere. Sapere che si disfa e' quello che rende il comando un gesto normale
/// invece che una sentenza.
Future<void> showBlockedPeople(BuildContext context) {
  return ModalSheet.show<void>(
    context: context,
    builder: (sheetContext) => ModalSheet(
      title: 'PERSONE BLOCCATE',
      confirmLabel: 'Chiudi',
      onConfirm: () => Navigator.of(sheetContext).pop(),
      child: const _BlockedList(),
    ),
  );
}

class _BlockedList extends ConsumerWidget {
  const _BlockedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final bloccati = ref.watch(blockedIdsProvider);

    return bloccati.when(
      loading: () => const SizedBox(height: 40),
      error: (_, _) => Text(
        'Non riusciamo a leggere l\'elenco. Riprova fra poco.',
        style: texts.bodyMedium,
      ),
      data: (elenco) {
        if (elenco.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Non hai bloccato nessuno.',
              style: texts.bodyMedium?.copyWith(color: palette.textSecondary),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [for (final userId in elenco) _BlockedRow(userId: userId)],
        );
      },
    );
  }
}

class _BlockedRow extends ConsumerWidget {
  const _BlockedRow({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    // Il nome si legge dal profilo: nell'elenco dei bloccati c'e' solo
    // l'identificativo, e una riga con dentro `a7Kd92...` non dice a nessuno chi
    // sta sbloccando.
    final nome =
        ref.watch(publicProfileProvider(userId)).valueOrNull?.username ?? '...';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          FriendAvatar(userId: userId, username: nome, size: 32),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '@$nome',
              style: texts.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final fatto = await ref
                  .read(moderationActionsProvider)
                  .unblock(userId);

              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    fatto
                        ? 'Hai sbloccato @$nome.'
                        : 'Non ci siamo riusciti. Riprova.',
                  ),
                ),
              );
            },
            child: Text(
              'SBLOCCA',
              style: texts.labelSmall?.copyWith(color: palette.accent),
            ),
          ),
        ],
      ),
    );
  }
}
