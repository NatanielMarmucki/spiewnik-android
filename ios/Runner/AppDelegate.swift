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

  /// Plugins and our own channel are registered here, not in didFinishLaunching.
  ///
  /// Under the UIScene lifecycle the engine belongs to the scene and does not exist yet when the
  /// application finishes launching. Flutter calls this once the implicit engine is ready, which is
  /// still before Dart's main() runs — and that ordering is what the font size migration depends
  /// on: it calls com.natanielmarmucki.spiewnik/legacy_user_defaults before runApp.
  func didInitializeImplicitFlutterEngine(_ engineBridge: any FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    LegacyUserDefaults.register(with: engineBridge.applicationRegistrar.messenger())
  }
}

/// Reads settings saved by the old native iOS app. It wrote to UserDefaults without the
/// "flutter." prefix that shared_preferences adds, so Flutter cannot see these keys itself.
enum LegacyUserDefaults {
  static let channelName = "com.natanielmarmucki.spiewnik/legacy_user_defaults"
  static let readNumberMethod = "readNumber"

  /// Only keys that are migrated. isLineSpacing, isSearchDynamic and isSizeImg are not.
  static let readableKeys: Set<String> = ["isSize"]

  static func register(with messenger: FlutterBinaryMessenger, defaults: UserDefaults = .standard) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      result(handle(method: call.method, arguments: call.arguments, defaults: defaults))
    }
  }

  /// Result for a channel call: an NSNumber, nil (NSNull on the Dart side), a FlutterError
  /// or FlutterMethodNotImplemented.
  static func handle(method: String, arguments: Any?, defaults: UserDefaults) -> Any? {
    guard method == readNumberMethod else {
      return FlutterMethodNotImplemented
    }
    guard let key = (arguments as? [String: Any])?["key"] as? String, readableKeys.contains(key) else {
      return FlutterError(code: "unsupported_key", message: "This key cannot be read.", details: nil)
    }
    return number(forKey: key, in: defaults)
  }

  /// The number stored under [key] with its original type (real or integer), or nil when the key
  /// is missing or holds something else. A missing key is normal: the old app saved a setting
  /// only after the user changed it.
  static func number(forKey key: String, in defaults: UserDefaults) -> NSNumber? {
    guard let number = defaults.object(forKey: key) as? NSNumber else {
      return nil
    }
    // Booleans are NSNumbers too, but never a valid font size.
    if CFGetTypeID(number) == CFBooleanGetTypeID() {
      return nil
    }
    return number
  }
}
