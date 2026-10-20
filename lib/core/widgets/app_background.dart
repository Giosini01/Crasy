import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/seasons/season_skin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fondo pagina a tinta unita.
///
/// Non ci sono gradienti ne' aloni: il colore lo mette solo l'azione primaria.
/// Serve comunque un widget dedicato perche' e' anche il punto in cui si
/// forzano le icone scure sulla barra di stato: l'app resta chiara anche su un
/// dispositivo in tema scuro, e senza questo le icone di sistema resterebbero
/// bianche su bianco.
class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: palette.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      // **L'unico punto da cui la stagione entra in tutte le pagine.**
      //
      // Ventinove schermate passano da qui, e nessuna di loro sa che esiste una
      // stagione: le ragnatele di ottobre e la neve di dicembre si appendono in
      // questa riga, non in ventinove file. Fuori stagione [SeasonSkin.decora]
      // torna il figlio com'e' arrivato, e questo widget e' quello di sempre.
      child: ColoredBox(
        color: palette.background,
        child: context.stagione.decora(context, child),
      ),
    );
  }
}
