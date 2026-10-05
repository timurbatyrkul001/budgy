import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // App Intent köprüsü: Kısayollar/Siri'den gelen "harcama ekle" isteği bu
    // kanaldan Flutter'a akar. Dart tarafı `ready` deyince kuyruk boşalır
    // (soğuk başlatma); bkz. IntentBridge.swift.
    IntentBridge.shared.attach(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }
}
