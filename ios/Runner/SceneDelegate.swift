import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// **La finestra della scena si presta anche all'AppDelegate.**
  ///
  /// E' il motivo per cui il foglio di pagamento restava fermo su "apro il
  /// foglio" per sempre. Il codice nativo di Stripe cerca dove aprirsi in
  /// `UIApplication.shared.delegate?.window`, cioe' nella finestra
  /// dell'AppDelegate — che nelle app a "scene", come CRASY, **e' vuota**: la
  /// finestra ce l'ha la scena. Trovandola vuota, Stripe si presenta sopra un
  /// controller creato al volo e mai mostrato: il foglio non compare, non
  /// fallisce niente, e la risposta a Dart non arriva mai.
  ///
  /// Si copia qui, nel momento in cui UIKit la assegna alla scena, cosi' chi la
  /// cerca nel posto vecchio la trova. Con una sola scena
  /// (`UIApplicationSupportsMultipleScenes` e' `false`) sono la stessa finestra.
  override var window: UIWindow? {
    didSet {
      (UIApplication.shared.delegate as? FlutterAppDelegate)?.window = window
    }
  }
}
