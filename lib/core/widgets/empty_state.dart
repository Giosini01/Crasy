import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Cosa si vede dove non c'e' ancora niente.
///
/// Un titolo grande e una riga di spiegazione, allineati a sinistra come tutto
/// il resto. Non c'e' l'illustrazione al centro dello schermo: un disegno
/// grande in una sezione vuota e' un elemento decorativo che occupa lo spazio
/// del contenuto che manca, e lo fa sembrare piu' vuoto, non meno.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // Solo padding verticale: il margine laterale lo mette la schermata, che e'
    // l'unica a sapere se sta gia' dentro una lista rientrata.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title.toUpperCase(), style: context.texts.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: context.texts.bodyMedium?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}
