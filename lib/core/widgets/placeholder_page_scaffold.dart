import 'package:app_incontri/core/theme/app_colors.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

class PlaceholderPageScaffold extends StatelessWidget {
  const PlaceholderPageScaffold({
    required this.eyebrow,
    required this.title,
    required this.description,
    this.actions = const [],
    super.key,
  });

  final String eyebrow;
  final String title;
  final String description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, AppColors.surfaceMuted],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    eyebrow.toUpperCase(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.displayMedium),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        description,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        ...actions,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
