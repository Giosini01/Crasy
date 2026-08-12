import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:flutter/material.dart';

/// L'attesa iniziale.
///
/// Il logotipo e la tagline, in mezzo al bianco. Nessuna rotellina: dura il
/// tempo di sapere chi ha aperto l'app, che sono poche centinaia di
/// millisecondi, e un indicatore di caricamento per quel tempo la' serve solo a
/// far sembrare lenta una cosa che non lo e'.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CrasyWordmark(size: 44),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'DO SOMETHING CRAZY.',
                style: context.texts.labelSmall?.copyWith(
                  color: context.palette.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
