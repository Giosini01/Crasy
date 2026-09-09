import 'package:video_player/video_player.dart';

/// Sul web un video appena registrato non ha un percorso su disco.
///
/// Il selettore del browser consegna dei byte, non un file: non c'e' niente da
/// aprire, e chi chiama questa funzione lo scopre da qui invece che da un
/// errore. Vedi `local_video_io.dart` per il caso vero.
VideoPlayerController? lettoreDalDisco(String percorso) => null;
