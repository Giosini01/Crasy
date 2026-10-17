import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/flame_waiting.dart';
import 'package:crasy/features/challenges/domain/entities/invio_in_attesa.dart';
import 'package:crasy/features/challenges/presentation/controllers/coda_invio_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **Gli scatti che stanno partendo, visti da tutta l'app.**
///
/// Con poca rete la pagina da cui si manda si chiude prima che lo scatto sia
/// arrivato, e si torna a usare l'app: senza un segno da qualche parte, non si
/// saprebbe se sta salendo, se e' fermo, o se e' andato perso. Qui c'e' la
/// fiamma che gira, quanto e' salito, e — se la rete non c'e' — un tocco per
/// riprovare subito invece di aspettare.
class InviiInCorso extends ConsumerWidget {
  const InviiInCorso({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final io = ref.watch(currentUserIdProvider);
    final invii = [
      for (final invio in ref.watch(codaInvioProvider))
        if (invio.userId == io) invio,
    ];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: invii.isEmpty
          ? const SizedBox.shrink()
          : _Pillola(
              key: const ValueKey('invii'),
              invii: invii,
              onRiprova: () => ref.read(codaInvioProvider.notifier).riprova(),
            ),
    );
  }
}

class _Pillola extends StatelessWidget {
  const _Pillola({required this.invii, required this.onRiprova, super.key});

  final List<InvioInAttesa> invii;
  final VoidCallback onRiprova;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final primo = invii.first;
    final fermo = invii.every((invio) => invio.stato == StatoInvio.inPausa);
    final cosa = invii.length > 1
        ? '${invii.length} scatti stanno partendo'
        : primo.isVideo
        ? 'Il tuo video sta partendo'
        : 'La tua foto sta partendo';
    final quanto = !fermo && primo.avanzamento > 0
        ? ' · ${(primo.avanzamento * 100).round()}%'
        : '';

    return Material(
      color: palette.background,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        // Il tocco serve quando e' fermo: la rete e' tornata e non si vuole
        // aspettare la prossima prova.
        onTap: fermo ? onRiprova : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FiammaCheGira(misura: 26),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  fermo
                      ? '$cosa appena torna la rete · Riprova'
                      : '$cosa$quanto',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: texts.labelMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
