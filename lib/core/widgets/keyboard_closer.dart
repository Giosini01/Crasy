import 'package:crasy/core/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// **La tastiera si chiude sempre, da qualunque schermata.**
///
/// Sull'iPhone le tastiere dei numeri — il premio di una missione, il premio
/// di una sfida, il telefono, il codice — non hanno il tasto per andare a
/// capo, quindi nemmeno quello per chiudersi. Una volta aperta restava li',
/// sopra il tasto che serviva premere, e l'unico modo di toglierla era uscire
/// dalla schermata.
///
/// Due modi, validi ovunque perche' stanno sopra tutta l'app:
///
/// - **si tocca fuori** da un campo, e la tastiera scende;
/// - **"Fine" in basso a destra**, su una barra appoggiata alla tastiera,
///   finche' la tastiera e' aperta. Su Android la tastiera ha gia' il suo
///   tasto per chiudersi: la barra c'e' solo sull'iPhone.
class KeyboardCloser extends StatelessWidget {
  const KeyboardCloser({required this.child, super.key});

  final Widget child;

  static void chiudi() => FocusManager.instance.primaryFocus?.unfocus();

  /// Quanto e' alta la barra con "Fine".
  static const double altezzaBarra = 44;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final tastiera = mediaQuery.viewInsets.bottom;
    final iPhone = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final conBarra = iPhone && tastiera > 0;

    return GestureDetector(
      // Translucent: il tocco arriva anche ai tasti sotto. Un campo di testo
      // vince comunque la gara del tocco, quindi toccarne un altro sposta la
      // tastiera invece di chiuderla.
      behavior: HitTestBehavior.translucent,
      onTap: chiudi,
      child: Stack(
        children: [
          // **Per il resto dell'app la tastiera e' alta quanto tastiera piu'
          // barra.** La barra sta sopra tutto, e senza questo copriva proprio
          // la riga dove si scrive: il campo dei commenti, e il fondo di ogni
          // foglio e schermata con un campo in basso, salivano fino alla
          // tastiera e finivano sotto il "Fine".
          //
          // Il `MediaQuery` c'e' sempre, anche a tastiera chiusa: metterlo e
          // toglierlo cambierebbe la forma dell'albero, e tutta l'app si
          // rismonterebbe — campo attivo compreso — nell'istante in cui la
          // tastiera si apre.
          MediaQuery(
            data: conBarra
                ? mediaQuery.copyWith(
                    viewInsets: mediaQuery.viewInsets.copyWith(
                      bottom: tastiera + altezzaBarra,
                    ),
                  )
                : mediaQuery,
            child: child,
          ),
          // **Sotto la tastiera, lo stesso colore della barra.** La tastiera
          // dell'iPhone ha gli angoli arrotondati e non si possono cambiare:
          // negli angoli si vedeva l'app sotto, e barra piu' tastiera
          // sembravano due pezzi staccati. Riempiendo quello spazio, il blocco
          // resta squadrato, ad angolo retto.
          if (conBarra)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: tastiera,
              child: const ColoredBox(color: AppColors.paperMuted),
            ),
          if (conBarra)
            Positioned(
              left: 0,
              right: 0,
              bottom: tastiera,
              child: const _BarraFine(),
            ),
        ],
      ),
    );
  }
}

class _BarraFine extends StatelessWidget {
  const _BarraFine();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paperMuted,
      child: Container(
        height: KeyboardCloser.altezzaBarra,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: KeyboardCloser.chiudi,
          style: TextButton.styleFrom(foregroundColor: AppColors.crasyRed),
          child: const Text(
            'Fine',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
