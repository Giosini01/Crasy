import 'package:crasy/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// Il pallino rosso con un numero dentro.
///
/// **E' sempre lo stesso pallino, in tutta l'app.** Prima ce n'erano due
/// scritti in due posti diversi — uno sulla campanella, uno sul conto degli
/// amici — e si vedeva: quello degli amici era una pastiglia schiacciata,
/// perche' nasceva da un po' di riempimento ai lati di un testo, e la sua forma
/// dipendeva da quante cifre c'erano dentro. Due segni rossi che vogliono dire
/// la stessa cosa e non si assomigliano si leggono come due cose diverse.
///
/// Qui la misura e' fissa: **alto quanto largo**, quindi con una cifra e' un
/// cerchio esatto. Con due diventa una pastiglia, ma solo allora — ed e' l'unico
/// modo di stare tondo senza tagliare i numeri.
///
/// Il bordo del colore del fondo serve appoggiato sopra un'icona: senza, il
/// rosso tocca il nero del disegno e i due si impastano.
class CountDot extends StatelessWidget {
  const CountDot({required this.count, this.withBorder = true, super.key});

  /// Quanto c'e' da leggere. Sopra nove si scrive `9+`.
  ///
  /// **Nove e' il tetto perche' oltre il numero preciso non serve a decidere
  /// niente**: fra dodici e diciassette notifiche si fa la stessa cosa. E un
  /// pallino largo mezza icona da' fastidio senza dire nulla di piu'.
  final int count;

  /// Se il pallino sta sopra qualcosa e ha bisogno di staccarsene.
  final bool withBorder;

  /// La misura, che vale anche come spazio da tenere libero attorno.
  static const double size = 17;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      constraints: const BoxConstraints(minWidth: size),
      height: size,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(size / 2),
        border: withBorder
            ? Border.all(color: palette.background, width: 1.5)
            : null,
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: context.texts.labelSmall?.copyWith(
          color: palette.background,
          fontSize: 10,
          // Uno perche' il numero stia in mezzo: con l'interlinea normale il
          // testo si appoggia in basso e il cerchio sembra storto.
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
