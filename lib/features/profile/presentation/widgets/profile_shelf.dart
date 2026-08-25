import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:flutter/material.dart';

/// Cosa si sta guardando di un profilo.
///
/// **Non "tutte le foto".** Una raccolta di tutto quello che uno ha mandato da
/// quando esiste racconta la quantita', non la persona: dopo trenta gare sono
/// trenta quadrati in cui le due che contano stanno in fondo.
///
/// Tre sezioni, e sono le tre domande che uno si fa davvero guardando un
/// profilo: **dove sta gareggiando adesso**, **cosa ha vinto**, **cosa ha
/// fatto fare agli altri**.
///
/// L'ultima e' la piu' recente e la meno ovvia. Chi lancia una challenge mette
/// dei soldi e non gareggia, quindi non vincera' mai niente: senza una sezione
/// sua, del gesto piu' impegnativo che si possa fare qui dentro non resterebbe
/// traccia da nessuna parte. E' anche l'unico posto in cui il profilo racconta
/// una cosa che uno ha **ordinato** invece che eseguito.
enum ProfileShelf {
  live('IN GARA'),
  trophies('TROFEI'),
  commissioned('COMANDATE');

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

/// Le partecipazioni in gara adesso.
///
/// **In gara** vuol dire "la challenge e' ancora aperta", non "l'ho mandata di
/// recente": una foto di tre giorni fa in una gara che dura una settimana e'
/// ancora in gioco, e una di stamattina in una gara chiusa non lo e' piu'.
///
/// Le altre due sezioni non passano da qui: **non sono fatte di
/// partecipazioni**. Una partecipazione viene cancellata quarantotto ore dopo
/// la fine della gara — foto compresa — quindi una bacheca costruita su quelle
/// si svuoterebbe da sola due giorni dopo ogni vittoria. I trofei stanno sulla
/// gara, che resta.
List<ChallengeEntry> liveEntries(
  List<ChallengeEntry> entries,
  Set<String> liveChallengeIds,
) {
  return [
    for (final entry in entries)
      if (liveChallengeIds.contains(entry.challengeId)) entry,
  ];
}
