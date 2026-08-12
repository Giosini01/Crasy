import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/controllers/vote_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/fire_tap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Una partecipazione nel feed: la foto, chi l'ha mandata, il voto.
///
/// La foto occupa tutta la larghezza e tutto il resto sta su una riga sola
/// sotto di essa. Il contenuto e' la cosa folle; l'interfaccia attorno deve
/// essere cosi' silenziosa da non farsi notare.
class EntryTile extends ConsumerWidget {
  const EntryTile({required this.entry, this.showChallenge = true, super.key});

  final ChallengeEntry entry;

  /// Il titolo della challenge si mostra nel feed, dove le foto arrivano da
  /// challenge diverse. Dentro una challenge sola sarebbe la stessa riga
  /// ripetuta sotto ogni foto.
  final bool showChallenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final createdAt = entry.createdAt;
    final voted =
        ref.watch(votedEntryIdsProvider).valueOrNull?.contains(entry.id) ??
        false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FireTap(
          voted: voted,
          onFire: () =>
              ref.read(voteControllerProvider).toggle(entry, voted: true),
          child: MediaFrame(url: entry.mediaUrl, caption: entry.authorName),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '@${entry.authorName}',
                          style: texts.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.isWinner) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'VINCITORE',
                          style: texts.labelSmall?.copyWith(
                            color: palette.accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (showChallenge && entry.challengeTitle.isNotEmpty)
                    Text(
                      entry.challengeTitle.toUpperCase() +
                          (createdAt == null
                              ? ''
                              : '  ·  ${AppDateUtils.shortTimeAgo(createdAt)}'),
                      style: texts.labelMedium?.copyWith(
                        color: palette.textFaint,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            VoteButton(entry: entry),
          ],
        ),
      ],
    );
  }
}

/// Il voto: una fiamma e un numero.
///
/// Non e' un cuore e non e' un pollice. Un cuore su una foto di una persona
/// vuol dire una cosa sola, ed e' esattamente la cosa che CRASY non e'; un
/// pollice in su e' il gesto di un sondaggio. La fiamma dice quello che va
/// detto — **questa e' fuori di testa** — ed e' lo stesso segno che il marchio
/// porta addosso.
///
/// La foto con piu' fiamme allo scadere del tempo si prende il premio, quindi
/// questo e' letteralmente il bottone che decide chi vince.
class VoteButton extends ConsumerWidget {
  const VoteButton({required this.entry, super.key});

  final ChallengeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final voted =
        ref.watch(votedEntryIdsProvider).valueOrNull?.contains(entry.id) ??
        false;

    return Semantics(
      button: true,
      label: voted ? 'Togli la fiamma' : 'Dai la fiamma',
      child: InkWell(
        onTap: () =>
            ref.read(voteControllerProvider).toggle(entry, voted: !voted),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                voted
                    ? Icons.local_fire_department
                    : Icons.local_fire_department_outlined,
                size: 20,
                color: voted ? palette.accent : palette.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${entry.votes}',
                style: context.texts.titleMedium?.copyWith(
                  color: voted ? palette.accent : palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
