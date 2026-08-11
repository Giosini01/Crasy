import 'package:app_incontri/core/theme/app_palette.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/core/widgets/app_background.dart';
import 'package:app_incontri/core/widgets/brand_mark.dart';
import 'package:flutter/material.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                const Spacer(),
                const BrandWordmark(height: 56),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Una foto al giorno, e chi c\'e\' oggi.',
                  textAlign: TextAlign.center,
                  style: context.texts.bodyLarge?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const Spacer(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: const SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
