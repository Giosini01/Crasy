import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Foglio modale con l'intestazione di iOS: annulla a sinistra, titolo al
/// centro, conferma a destra.
///
/// Su iOS le scelte e le modifiche brevi si fanno in un foglio che sale dal
/// basso, non in una finestra al centro dello schermo. Tenere qui la struttura
/// evita che ogni schermata se la reinventi.
class ModalSheet extends StatelessWidget {
  const ModalSheet({
    required this.title,
    required this.child,
    required this.onConfirm,
    this.confirmLabel = 'Fatto',
    super.key,
  });

  final String title;
  final Widget child;

  /// Chiamata al tocco su conferma: sta a chi la fornisce chiudere il foglio
  /// restituendo il valore scelto.
  final VoidCallback onConfirm;

  final String confirmLabel;

  /// Apre il foglio e restituisce il valore con cui e' stato chiuso.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SafeArea(
      top: false,
      child: Padding(
        // Lascia salire il foglio sopra la tastiera quando si scrive.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xxs,
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annulla'),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: context.texts.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: onConfirm,
                      child: Text(
                        confirmLabel,
                        style: context.texts.labelLarge?.copyWith(
                          color: palette.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: palette.line, height: 0.5, thickness: 0.5),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
