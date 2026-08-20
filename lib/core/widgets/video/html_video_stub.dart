import 'package:flutter/widgets.dart';

/// Fuori dal web non esiste nessun elemento HTML da mostrare.
///
/// Su telefono il lettore di sistema — AVPlayer su iPhone, ExoPlayer su
/// Android — fa gia' tutto quello che serve, e lo fa meglio: `VideoFrame` usa
/// quello e questa funzione non viene mai chiamata.
Widget? buildHtmlVideo(String url) => null;
