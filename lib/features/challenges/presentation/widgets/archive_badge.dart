import 'package:crasy/core/theme/app_colors.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:flutter/material.dart';

/// Il marchio che dice **"qui si manda roba vecchia"**.
///
/// ## Perche' c'e', e perche' si vede tanto
///
/// In una gara normale la foto e' stata scattata sul momento, e quello e' un
/// fatto che nessuno deve dichiarare: lo garantisce l'app, che la galleria non
/// la apre. E' una **garanzia di autenticita' che non costa niente**, ed e' la
/// cosa che distingue CRASY da qualunque altro posto dove si mettono foto.
///
/// In una gara d'archivio quella garanzia non c'e' piu'. Chi manda puo' aver
/// scaricato un video virale mezz'ora prima, e con dei soldi in palio qualcuno
/// lo fara'. Non si puo' impedire — nessuno sa dire da dove viene un file — ma
/// **si puo' dire a chi vota che deve giudicare anche quello**. Una fiamma data
/// sapendolo e' un'altra cosa da una data credendo di guardare uno che si e'
/// messo in gioco stamattina.
///
/// ## Perche' l'altra non ha nessun marchio
///
/// L'istantanea e' la norma, e **marcare la norma la annacqua**. Se tutte e due
/// portassero un'etichetta, diventerebbero due gusti fra cui scegliere; con una
/// sola etichetta resta quello che e': una gara normale, e un'eccezione
/// dichiarata.
class ArchiveBadge extends StatelessWidget {
  const ArchiveBadge({required this.challenge, this.compact = false, super.key});

  final Challenge challenge;

  /// Nelle schede sta stretto: sparisce la parola lunga e resta il segno.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!challenge.source.isArchive) {
      return const SizedBox.shrink();
    }

    final palette = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.crasyRedTint,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: palette.accent.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 2 : 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: compact ? 11 : 13,
              color: palette.accent,
            ),
            const SizedBox(width: 4),
            Text(
              challenge.source.label,
              style: context.texts.labelSmall?.copyWith(
                color: palette.accent,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 10 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
