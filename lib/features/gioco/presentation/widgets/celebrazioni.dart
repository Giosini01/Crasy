import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/features/gioco/domain/entities/stato_del_gioco.dart';
import 'package:flutter/material.dart';

/// **Un premio appena arrivato**, in basso, ovunque si sia nell'app.
///
/// Gli XP saltano dentro, si legge cosa li ha dati, e se ne va da solo: chi
/// stava guardando una foto non deve chiudere niente. Piu' premi insieme — la
/// sfida del giorno e il traguardo con la stessa foto — escono uno dopo
/// l'altro.
SnackBar premioArrivato(PremioXp premio) {
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 3),
    padding: EdgeInsets.zero,
    content: _PremioArrivato(premio: premio),
  );
}

class _PremioArrivato extends StatelessWidget {
  const _PremioArrivato({required this.premio});

  final PremioXp premio;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.elasticOut,
            builder: (context, scala, figlio) =>
                Transform.scale(scale: scala, child: figlio),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '+${premio.xp} XP',
                style: texts.labelLarge?.copyWith(color: palette.onAccent),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  premio.permanente
                      ? 'TRAGUARDO RAGGIUNTO'
                      : 'SFIDA DEL GIORNO FATTA',
                  style: texts.labelSmall?.copyWith(
                    color: palette.background.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  premio.titolo,
                  style: texts.titleMedium?.copyWith(color: palette.background),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// **Il livello nuovo**: la seconda festa, piu' grande, solo quando si sale.
///
/// Il numero arriva da piccolo e cresce, il nome sotto. Si chiude con un
/// tocco ovunque, o andando a vedere le sfide.
Future<void> mostraNuovoLivello(
  BuildContext context, {
  required int numero,
  required String nome,
  required VoidCallback apriLeSfide,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Chiudi',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (contesto, _, _) => _NuovoLivello(
      numero: numero,
      nome: nome,
      apriLeSfide: () {
        Navigator.of(contesto).pop();
        apriLeSfide();
      },
    ),
    transitionBuilder: (contesto, animazione, _, figlio) {
      final curva = CurvedAnimation(
        parent: animazione,
        curve: Curves.elasticOut,
        reverseCurve: Curves.easeIn,
      );

      return FadeTransition(
        opacity: animazione,
        child: ScaleTransition(scale: curva, child: figlio),
      );
    },
  );
}

class _NuovoLivello extends StatelessWidget {
  const _NuovoLivello({
    required this.numero,
    required this.nome,
    required this.apriLeSfide,
  });

  final int numero;
  final String nome;
  final VoidCallback apriLeSfide;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Center(
      child: Material(
        color: palette.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LIVELLO NUOVO',
                style: texts.labelSmall?.copyWith(color: palette.accent),
              ),
              const SizedBox(height: AppSpacing.md),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutBack,
                builder: (context, t, figlio) => Transform.rotate(
                  angle: (1 - t) * -0.6,
                  child: Transform.scale(scale: 0.6 + 0.4 * t, child: figlio),
                ),
                child: Container(
                  width: 108,
                  height: 108,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$numero',
                    style: texts.displayMedium?.copyWith(
                      color: palette.onAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(nome.toUpperCase(), style: texts.displaySmall),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Sei salito di livello.',
                style: texts.bodyMedium?.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: apriLeSfide,
                child: Text(
                  'VEDI LE SFIDE',
                  style: texts.labelLarge?.copyWith(color: palette.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
