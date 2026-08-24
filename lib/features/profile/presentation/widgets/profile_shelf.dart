import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:flutter/material.dart';

/// Cosa si sta guardando di un profilo.
///
/// **Non "tutte le foto".** Una raccolta di tutto quello che uno ha mandato da
/// quando esiste racconta la quantita', non la persona: dopo trenta gare sono
/// trenta quadrati in cui le due che contano stanno in fondo. Due sezioni
/// rispondono invece alle due domande che uno si fa davvero guardando un
/// profilo — **dove sta gareggiando adesso** e **cosa ha vinto**.
enum ProfileShelf {
  live('IN GARA'),
  won('VINTE');

  const ProfileShelf(this.label);

  final String label;
}

/// Le due parole in cima alla griglia, come i filtri della ricerca.
class ProfileShelfTabs extends StatelessWidget {
  const ProfileShelfTabs({
    required this.selected,
    required this.onPick,
    super.key,
  });

  final ProfileShelf selected;
  final void Function(ProfileShelf shelf) onPick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          for (final shelf in ProfileShelf.values)
            GestureDetector(
              onTap: () => onPick(shelf),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Text(
                  shelf.label,
                  style: context.texts.labelSmall?.copyWith(
                    color: shelf == selected
                        ? palette.accent
                        : palette.textFaint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Le partecipazioni da mostrare in una delle due sezioni.
///
/// **In gara** vuol dire "la challenge e' ancora aperta", non "l'ho mandata di
/// recente": una foto di tre giorni fa in una gara che dura una settimana e'
/// ancora in gioco, e una di stamattina in una gara chiusa non lo e' piu'.
List<ChallengeEntry> shelfEntries(
  ProfileShelf shelf,
  List<ChallengeEntry> entries,
  Set<String> liveChallengeIds,
) {
  return switch (shelf) {
    ProfileShelf.live => [
      for (final entry in entries)
        if (liveChallengeIds.contains(entry.challengeId)) entry,
    ],
    ProfileShelf.won => [
      for (final entry in entries)
        if (entry.isWinner) entry,
    ],
  };
}
