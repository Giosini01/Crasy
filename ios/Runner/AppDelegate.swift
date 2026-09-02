import Flutter
import UIKit

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

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
