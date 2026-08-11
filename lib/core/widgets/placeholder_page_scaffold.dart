import 'package:app_incontri/core/theme/app_palette.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/core/widgets/app_background.dart';
import 'package:app_incontri/core/widgets/brand_mark.dart';
import 'package:flutter/material.dart';

/// Impalcatura comune delle sezioni ancora da riempire.
///
/// Tiene insieme occhiello, icona, titolo e azioni con lo stesso ritmo
/// verticale in ogni tab, cosi' le schermate sembrano gia' parte di un
/// prodotto anche quando il contenuto vero non c'e' ancora.
class PlaceholderPageScaffold extends StatelessWidget {
  const PlaceholderPageScaffold({
    required this.eyebrow,
    required this.title,
    required this.description,
    this.icon = Icons.auto_awesome,
    this.actions = const [],
    super.key,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EyebrowLabel(eyebrow),
                    const SizedBox(height: AppSpacing.xl),
                    GlyphTile(icon: icon),
                    const SizedBox(height: AppSpacing.lg),
                    Text(title, style: context.texts.displaySmall),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      description,
                      style: context.texts.bodyLarge?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      ...actions,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
