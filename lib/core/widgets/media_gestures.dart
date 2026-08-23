import 'package:flutter/widgets.dart';

/// I gesti che valgono sul contenuto, passati a chi sta sotto.
///
/// Serve a un caso solo, ma e' un caso che non si puo' risolvere altrimenti:
/// **sul web un video e' un elemento del browser, e i gesti di Flutter sopra di
/// lui non arrivano.** Il `<video>` si prende tocchi e doppi tocchi, e finche'
/// se li teneva sui video non si poteva ne' aprire lo schermo intero ne' dare
/// la fiamma — due cose che su ogni foto funzionavano da sempre.
///
/// La soluzione naturale — passare le funzioni di mano in mano da chi disegna
/// la griglia fino al video — vorrebbe due parametri nuovi in ogni schermata
/// che mostra una partecipazione, ripetuti uguali, per una faccenda che
/// riguarda una piattaforma sola. Cosi' invece chi gia' gestisce i gesti li
/// **lascia detti sull'albero**, e il video li raccoglie se e quando gli
/// servono.
class MediaGestures extends InheritedWidget {
  const MediaGestures({
    required super.child,
    this.onTap,
    this.onDoubleTap,
    super.key,
  });

  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  static MediaGestures? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MediaGestures>();

  @override
  bool updateShouldNotify(MediaGestures oldWidget) =>
      onTap != oldWidget.onTap || onDoubleTap != oldWidget.onDoubleTap;
}

/// Un tocco sul contenuto, che vale anche per i video.
///
/// E' il `GestureDetector` di sempre piu' la dichiarazione di [MediaGestures]:
/// dove non c'e' la fiamma — la griglia di un profilo, la foto del vincitore —
/// e' questo che rende un video toccabile quanto una foto.
class MediaTap extends StatelessWidget {
  const MediaTap({required this.child, this.onTap, super.key});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MediaGestures(onTap: onTap, child: child),
    );
  }
}
