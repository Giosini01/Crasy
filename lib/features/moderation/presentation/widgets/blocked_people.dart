import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/flame_waiting.dart';
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
      // **Mentre l'elenco arriva, la fiamma.** Prima c'era uno spazio vuoto
      // alto due dita, e il foglio sembrava aperto per sbaglio.
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(child: FiammaCheGira(misura: 28)),
      ),
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
          // **Ogni riga con la sua chiave.** La riga sbloccata sparisce
          // dall'elenco mentre la sua fiamma gira ancora: senza chiave, quella
          // fiamma passerebbe alla riga che le scivola al posto.
          children: [
            for (final userId in elenco)
              _BlockedRow(key: ValueKey(userId), userId: userId),
          ],
        );
      },
    );
  }
}

class _BlockedRow extends ConsumerStatefulWidget {
  const _BlockedRow({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<_BlockedRow> createState() => _BlockedRowState();
}

class _BlockedRowState extends ConsumerState<_BlockedRow> {
  /// **Mentre sblocca, la fiamma al posto del tasto, su questa riga sola.**
  /// Prima SBLOCCA restava li' uguale finche' non arrivava la risposta: si
  /// ritoccava convinti di non aver premuto, e partivano due sblocchi.
  bool _sbloccando = false;

  Future<void> _sblocca(String nome) async {
    if (_sbloccando) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sbloccando = true);

    final fatto = await ref
        .read(moderationActionsProvider)
        .unblock(widget.userId);

    // Riuscito, la riga se ne va da sola con l'elenco: si spegne la fiamma
    // solo se c'e' ancora qualcosa su cui spegnerla.
    if (mounted) {
      setState(() => _sbloccando = false);
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          fatto ? 'Hai sbloccato @$nome.' : 'Non ci siamo riusciti. Riprova.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    // Il nome si legge dal profilo: nell'elenco dei bloccati c'e' solo
    // l'identificativo, e una riga con dentro `a7Kd92...` non dice a nessuno chi
    // sta sbloccando.
    final nome =
        ref.watch(publicProfileProvider(widget.userId)).valueOrNull?.username ??
        '...';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          FriendAvatar(userId: widget.userId, username: nome, size: 32),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '@$nome',
              style: texts.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _sbloccando ? null : () => _sblocca(nome),
            child: _sbloccando
                ? const FiammaCheGira(misura: 18)
                : Text(
                    'SBLOCCA',
                    style: texts.labelSmall?.copyWith(color: palette.accent),
                  ),
          ),
        ],
      ),
    );
  }
}
