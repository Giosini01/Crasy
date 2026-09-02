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

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// **Il numero sull'icona si azzera entrando.**
  ///
  /// Quel pallino rosso vuol dire "c'e' qualcosa che non hai letto": una volta
  /// che l'app e' aperta non e' piu' vero, e lasciarlo li' lo trasforma in una
  /// decorazione permanente che nessuno guarda piu'. E il giorno in cui
  /// significa davvero qualcosa, non se ne accorge nessuno.
  ///
  /// Si azzera a ogni ritorno in primo piano, non solo al primo avvio: le
  /// notifiche arrivano anche mentre l'app sta in secondo piano.
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)

    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0)
    } else {
      application.applicationIconBadgeNumber = 0
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
