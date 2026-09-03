import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // **Si chiede ad Apple di registrare l'app, esplicitamente.**
    //
    // In teoria non servirebbe: la libreria delle notifiche lo fa da se' quando
    // si chiede il permesso all'utente. In pratica, con il modello nuovo di
    // AppDelegate di Flutter — quello che registra i plugin dopo l'avvio — la
    // chiamata puo' non partire mai, e il risultato e' quello che abbiamo visto
    // per un pomeriggio: permesso concesso, firma corretta, e Apple che non
    // consegna nessun recapito perche' **nessuno gliel'ha chiesto**.
    //
    // Chiamarla qui non ha controindicazioni. Non mostra niente a schermo e non
    // chiede niente a nessuno: dice solo al sistema "questa app usa le
    // notifiche". Se poi l'utente il permesso non lo da', non succede nulla.
    application.registerForRemoteNotifications()

    ascoltaIRitorniInPrimoPiano()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Si mette in ascolto di ogni ritorno dell'app in primo piano.
  ///
  /// **Perche' non basta `applicationDidBecomeActive`.** C'era, ed era scritta
  /// bene, e non veniva chiamata mai: quel metodo lo chiama UIKit solo nelle app
  /// che non usano le "scene". CRASY le usa — c'e' un `SceneDelegate`, e
  /// `Info.plist` dichiara `UIApplicationSceneManifest` — e in quel caso il
  /// sistema avvisa **la scena**, non l'app. Il codice che azzerava il pallino
  /// rosso era corretto, presente e irraggiungibile: il tipo di difetto che non
  /// lascia nessuna traccia, perche' non fallisce niente — semplicemente non
  /// succede.
  ///
  /// Invece di rincorrere quale dei due avvisi arrivi su quale versione di iOS,
  /// **si ascoltano tutti e due**. Azzerare un numero che e' gia' zero non
  /// costa niente, mentre non azzerarlo lascia sull'icona un pallino che non se
  /// ne va piu'.
  private func ascoltaIRitorniInPrimoPiano() {
    let centro = NotificationCenter.default

    centro.addObserver(
      self,
      selector: #selector(azzeraIlPallino),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )

    centro.addObserver(
      self,
      selector: #selector(azzeraIlPallino),
      name: UIScene.didActivateNotification,
      object: nil
    )
  }

  /// **Il numero sull'icona si azzera entrando.**
  ///
  /// Quel pallino rosso vuol dire "c'e' qualcosa che non hai letto": una volta
  /// che l'app e' aperta non e' piu' vero, e lasciarlo li' lo trasforma in una
  /// decorazione permanente che nessuno guarda piu'. E il giorno in cui
  /// significa davvero qualcosa, non se ne accorge nessuno.
  ///
  /// Si azzera a **ogni** ritorno in primo piano e non solo al primo avvio: le
  /// notifiche arrivano anche mentre l'app sta in secondo piano, ed e' proprio
  /// allora che il pallino compare.
  @objc private func azzeraIlPallino() {
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0)
    } else {
      UIApplication.shared.applicationIconBadgeNumber = 0
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    apriIlFiloConDart(engineBridge)
  }

  /// Un filo diretto perche' anche Dart possa azzerare il pallino.
  ///
  /// **Serve per le notifiche che arrivano ad app aperta.** Quelle non fanno
  /// tornare l'app in primo piano — c'e' gia' — quindi nessuno degli avvisi di
  /// sopra scatta, ma iOS il pallino lo mette lo stesso, perche' glielo dice il
  /// messaggio. Risultato: il numero compare mentre uno sta guardando l'app,
  /// non se ne va all'uscita, e resta li' fisso. E' l'altra meta' del difetto,
  /// e da Swift non si vede: l'unico che sa che e' arrivato un messaggio in
  /// quel momento e' il codice Dart.
  private func apriIlFiloConDart(_ engineBridge: FlutterImplicitEngineBridge) {
    guard
      let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CrasyPallino")
    else {
      return
    }

    let filo = FlutterMethodChannel(
      name: "crasy/pallino",
      binaryMessenger: registrar.messenger()
    )

    filo.setMethodCallHandler { [weak self] chiamata, rispondi in
      if chiamata.method == "azzera" {
        self?.azzeraIlPallino()
        rispondi(nil)
      } else {
        rispondi(FlutterMethodNotImplemented)
      }
    }
  }
}
