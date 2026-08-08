import 'package:app_incontri/core/theme/app_colors.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/core/widgets/placeholder_page_scaffold.dart';
import 'package:flutter/material.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPageScaffold(
      eyebrow: 'Splash',
      title: 'Daily',
      description:
          'Verifichiamo la sessione, il profilo e lo stato iniziale prima di '
          'mostrare il flusso corretto.',
      actions: [
        Padding(
          padding: EdgeInsets.only(top: AppSpacing.sm),
          child: LinearProgressIndicator(
            minHeight: 3,
            color: AppColors.accent,
            backgroundColor: AppColors.surfaceMuted,
          ),
        ),
      ],
    );
  }
}
