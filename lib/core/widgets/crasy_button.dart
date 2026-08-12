import 'package:crasy/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// Il comando principale: rosso pieno, a tutta larghezza, etichetta maiuscola.
///
/// Ce n'e' **uno solo per schermata**, e la regola vale anche quando fa comodo
/// romperla: due bottoni rossi nella stessa vista sono due bottoni che si
/// contendono lo stesso significato, e chi guarda deve fermarsi a scegliere.
/// Tutto il resto e' [SecondaryButton] o un semplice testo toccabile.
///
/// Mentre e' [loading] il bottone **tiene la sua altezza e la sua larghezza**:
/// sostituire l'etichetta con una rotellina piu' piccola farebbe saltare il
/// layout proprio nel momento in cui l'utente sta guardando quel punto.
class CrasyButton extends StatelessWidget {
  const CrasyButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.textFaint,
              ),
            )
          : Text(label.toUpperCase()),
    );
  }
}

/// Il comando secondario: solo un filetto attorno, testo nero.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final content = Text(label.toUpperCase());

    return OutlinedButton(
      onPressed: onPressed,
      child: icon == null
          ? content
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 10),
                content,
              ],
            ),
    );
  }
}
