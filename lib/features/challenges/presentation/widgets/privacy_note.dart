import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// **"Resta fra voi", detto dove serve.**
///
/// Le sfide uno contro uno sono il posto delle foto piu' personali, e chi ne
/// manda una deve saperlo prima di toccare il tasto: non finisce in home, fra
/// i vincitori o sul profilo di nessuno. Un lucchetto e una riga, nello stesso
/// punto in cui uno si chiede "chi la vedra'?".
class PrivacyNote extends StatelessWidget {
  const PrivacyNote({required this.text, super.key});

  final String text;

  /// La frase standard per le sfide uno contro uno.
  static const String sfida =
      'Privata: la sfida e la foto le vedete solo voi due. Nessun altro, '
      'nemmeno i vostri amici: non va in home, fra i vincitori o sui profili.';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_rounded, size: 16, color: palette.accent),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: context.texts.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
