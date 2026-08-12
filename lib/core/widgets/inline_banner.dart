import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Un errore, detto in linea.
///
/// Niente riquadro rosso, niente fondo colorato: il rosso e' gia' il colore
/// dell'accento, e un pannello rosso pieno in mezzo a una schermata bianca
/// sarebbe la cosa piu' vistosa dell'app — piu' del premio. Bastano un segno e
/// una riga di testo del colore giusto.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    required this.message,
    this.icon = Icons.error_outline_rounded,
    super.key,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: palette.danger),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            message,
            style: context.texts.bodySmall?.copyWith(color: palette.danger),
          ),
        ),
      ],
    );
  }
}
