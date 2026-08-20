import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Un video sul web, disegnato da un vero elemento `<video>` del browser.
///
/// **Non usa il lettore di Flutter, ed e' la correzione di un difetto che non
/// dava nessun segnale.** Quel lettore considera un video "pronto" quando il
/// browser dice di poterlo riprodurre; ma iPhone, per non consumare dati, **non
/// scarica niente** finche' qualcuno non tocca play. Quel momento non arrivava
/// mai, quindi il video non risultava ne' pronto ne' rotto: restava un
/// rettangolo grigio, per sempre, senza un errore da nessuna parte.
///
/// Qui l'elemento e' nostro e glielo diciamo noi cosa fare:
///
/// - `preload = 'metadata'` scarica **il minimo per avere il primo fotogramma**
///   e le proporzioni, e non un byte di piu';
/// - `controls` mette i comandi del sistema. Sono quelli che la gente conosce
///   gia', li disegna il browser, e su iPhone sono gli unici che sanno aprire un
///   video a tutto schermo;
/// - `playsinline` lo tiene dentro la pagina invece di lanciarlo a schermo
///   pieno al primo play, che su iPhone e' il comportamento predefinito;
/// - `muted` piu' `autoplay` sono un tentativo, non una pretesa: dove il
///   browser lo lascia partire, parte; dove non lo lascia, resta il primo
///   fotogramma con il play sopra. Che e' esattamente quello che serve.
Widget? buildHtmlVideo(String url) {
  // Il nome della fabbrica porta dentro l'indirizzo: due video diversi sono due
  // fabbriche diverse, e lo stesso video riaperto riusa la sua invece di
  // registrarne una nuova a ogni ricostruzione.
  final viewType = 'crasy-video-${url.hashCode}';

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final element = web.document.createElement('video') as web.HTMLVideoElement
      ..src = url
      ..controls = true
      ..autoplay = true
      ..muted = true
      ..loop = true
      ..preload = 'metadata'
      ..playsInline = true;

    element.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'cover'
      ..backgroundColor = 'transparent';

    return element;
  });

  return HtmlElementView(viewType: viewType);
}
