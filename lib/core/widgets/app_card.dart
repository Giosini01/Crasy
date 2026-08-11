import 'package:app_incontri/core/theme/app_palette.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Riquadro di contenuto: bordo da un pixel, niente ombra.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.lg,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final borderRadius = BorderRadius.circular(radius);
    final content = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: borderRadius,
        border: Border.all(color: palette.border),
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: borderRadius,
                child: content,
              ),
            ),
    );
  }
}
