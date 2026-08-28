import 'package:crasy/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Una foto sola, grande quanto lo schermo.
///
/// **Non e' [FullscreenMedia] con un'immagine dentro.** Quella e' fatta per le
/// partecipazioni a una gara: sfoglia da una foto all'altra, mostra le fiamme,
/// sa chi ha mandato cosa. Qui non c'e' niente di tutto questo da mostrare —
/// c'e' una foto profilo — e portarsi dietro quel meccanismo vorrebbe dire
/// costruire una finta partecipazione per far vedere un'immagine.
///
/// Si chiude toccando ovunque, che e' quello che fa chiunque quando una foto
/// occupa lo schermo, e si allarga con due dita per guardare un dettaglio.
Future<void> showPhotoViewer(
  BuildContext context, {
  required String url,
  String? caption,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      // Il fondo nero deve **coprire** la schermata sotto, non velarla: una
      // foto guardata sopra un'altra interfaccia che traspare non si guarda,
      // si intravede.
      opaque: false,
      barrierColor: Colors.black,
      barrierDismissible: true,
      pageBuilder: (context, animazione, _) => FadeTransition(
        opacity: animazione,
        child: _PhotoViewer(url: url, caption: caption),
      ),
    ),
  );
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.url, this.caption});

  final String url;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final didascalia = caption;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                // Due dita per ingrandire. Il minimo e' uno: una foto che si
                // puo' rimpicciolire piu' della sua misura si perde in mezzo al
                // nero e non si sa piu' come riportarla a posto.
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Padding(
                      padding: EdgeInsets.all(AppSpacing.page),
                      child: Text(
                        'La foto non si carica.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
              if (didascalia != null && didascalia.isNotEmpty)
                Positioned(
                  left: AppSpacing.page,
                  right: AppSpacing.page,
                  bottom: AppSpacing.lg,
                  child: Text(
                    didascalia,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
