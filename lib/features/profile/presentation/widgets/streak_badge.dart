import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// **Da quanti giorni di fila gioca. Lo vedono tutti.**
///
/// Non e' un contatore privato: sta sul profilo accanto al nome, e si vede
/// anche aprendo quello di un altro. E' la differenza fra un promemoria — che
/// riguarda solo te e si ignora — e una cosa che gli altri possono guardare,
/// che e' il motivo per cui la gente le serie le tiene.
///
/// **Sotto i due giorni non compare.** "1 giorno di fila" non e' una serie: e'
/// aver giocato oggi, cioe' la cosa normale. Mostrarlo svuoterebbe di senso il
/// distintivo proprio nel punto in cui dovrebbe cominciare a valere — e lo
/// metterebbe addosso a chiunque, compreso chi non ha mai pensato di farne una.
class StreakBadge extends StatelessWidget {
  const StreakBadge({required this.giorni, this.compatto = false, super.key});

  final int giorni;

  /// Nella versione stretta c'e' solo il numero accanto alla fiamma: serve
  /// dove lo spazio e' quello di una riga di elenco.
  final bool compatto;

  @override
  Widget build(BuildContext context) {
    if (giorni < 2) {
      return const SizedBox.shrink();
    }

    final palette = context.palette;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compatto ? 6 : AppSpacing.sm,
        vertical: compatto ? 1 : 3,
      ),
      decoration: BoxDecoration(
        // Contornato e non pieno: pieno di rosso griderebbe quanto il tasto
        // che lancia una missione, e questa e' una cosa che si nota, non una
        // che si fa.
        border: Border.all(color: palette.accent),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: compatto ? 11 : 13,
            color: palette.accent,
          ),
          const SizedBox(width: 3),
          Text(
            compatto ? '$giorni' : '$giorni GIORNI DI FILA',
            style: context.texts.labelSmall?.copyWith(
              fontSize: compatto ? 10 : 11,
              color: palette.accent,
            ),
          ),
        ],
      ),
    );
  }
}
