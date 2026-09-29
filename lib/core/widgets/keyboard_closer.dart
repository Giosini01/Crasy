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

  @override
  Widget build(BuildContext context) {
    final tastiera = MediaQuery.viewInsetsOf(context).bottom;
    final iPhone = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return GestureDetector(
      // Translucent: il tocco arriva anche ai tasti sotto. Un campo di testo
      // vince comunque la gara del tocco, quindi toccarne un altro sposta la
      // tastiera invece di chiuderla.
      behavior: HitTestBehavior.translucent,
      onTap: chiudi,
      child: Stack(
        children: [
          child,
          if (iPhone && tastiera > 0)
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
        height: 44,
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
