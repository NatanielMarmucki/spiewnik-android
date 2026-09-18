import Flutter
import UIKit
import XCTest

@testable import Runner

class LegacyUserDefaultsTests: XCTestCase {
  private var suiteName: String!
  private var defaults: UserDefaults!

  override func setUp() {
    super.setUp()
    suiteName = "LegacyUserDefaultsTests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    super.tearDown()
  }

  private func read(_ key: String = "isSize", method: String = LegacyUserDefaults.readNumberMethod) -> Any? {
    return LegacyUserDefaults.handle(method: method, arguments: ["key": key], defaults: defaults)
  }

  func testReadsRealValueAsDouble() {
    defaults.set(CGFloat(22), forKey: "isSize")

    let value = read() as? NSNumber

    XCTAssertEqual(value?.doubleValue, 22)
    XCTAssertEqual(String(cString: value!.objCType), "d")
  }

  func testReadsIntegerValueAsInteger() {
    defaults.set(24, forKey: "isSize")

    let value = read() as? NSNumber

    XCTAssertEqual(value?.intValue, 24)
    XCTAssertEqual(String(cString: value!.objCType), "q")
  }

  func testReturnsNilWhenTheKeyIsMissing() {
    XCTAssertNil(read())
  }

  func testReturnsNilForBooleansAndText() {
    defaults.set(true, forKey: "isSize")
    XCTAssertNil(read())

    defaults.set("22", forKey: "isSize")
    XCTAssertNil(read())
  }

  func testRejectsKeysThatAreNotMigrated() {
    for key in ["isLineSpacing", "isSearchDynamic", "isSizeImg", "flutter.fontSize"] {
      defaults.set(5, forKey: key)

      XCTAssertTrue(read(key) is FlutterError, "\(key) must not be readable")
    }
  }

  func testRejectsUnknownMethods() {
    defaults.set(22.0, forKey: "isSize")

    XCTAssertTrue(read(method: "readString") as AnyObject === FlutterMethodNotImplemented as AnyObject)
  }
}

/// Channel registration after the UIScene migration.
///
/// The font size migration calls `com.natanielmarmucki.spiewnik/legacy_user_defaults` from Dart
/// before `runApp`. Under the scene lifecycle the channel is registered in
/// `didInitializeImplicitFlutterEngine` instead of `didFinishLaunchingWithOptions`, so these tests
/// check the wiring survives: the delegate conforms to the protocol, and the handler registered by
/// `registerApplicationChannels` actually answers a real encoded call.
class ApplicationChannelsTests: XCTestCase {
  /// Kolejka jest w protokole wymagana, ale nasz kanał jej nie używa.
  private final class NoopTaskQueue: NSObject, FlutterTaskQueue {}

  /// Records handlers instead of talking to an engine, and lets a test call them.
  private final class SpyMessenger: NSObject, FlutterBinaryMessenger {
    private(set) var handlers: [String: FlutterBinaryMessageHandler] = [:]

    func setMessageHandlerOnChannel(
      _ channel: String,
      binaryMessageHandler handler: FlutterBinaryMessageHandler? = nil
    ) -> FlutterBinaryMessengerConnection {
      handlers[channel] = handler
      return FlutterBinaryMessengerConnection(handlers.count)
    }

    func send(onChannel channel: String, message: Data?) {}

    func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply? = nil) {}

    func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}

    func makeBackgroundTaskQueue() -> any FlutterTaskQueue { return NoopTaskQueue() }

    /// Sends an encoded method call to the registered handler and decodes its answer.
    func call(_ channel: String, method: String, arguments: Any?) throws -> Any? {
      let handler = try XCTUnwrap(handlers[channel], "no handler on \(channel)")
      let codec = FlutterStandardMethodCodec.sharedInstance()
      let message = codec.encode(FlutterMethodCall(methodName: method, arguments: arguments))
      var reply: Data?
      var answered = false
      handler(message) { data in
        reply = data
        answered = true
      }
      XCTAssertTrue(answered, "handler did not answer")
      guard let reply else { return nil }
      return codec.decodeEnvelope(reply)
    }
  }

  func testAppDelegateRegistersChannelsOnTheImplicitEngine() {
    // Registration moved to this callback; without the conformance it would never run and the
    // migration would read nothing, silently.
    XCTAssertTrue(AppDelegate() is FlutterImplicitEngineDelegate)
  }

  func testRegisteredChannelAnswers() throws {
    let suiteName = "ApplicationChannelsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.set(24, forKey: "isSize")
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let messenger = SpyMessenger()

    AppDelegate.registerApplicationChannels(with: messenger, defaults: defaults)

    XCTAssertTrue(messenger.handlers.keys.contains(LegacyUserDefaults.channelName))
    let value = try messenger.call(
      LegacyUserDefaults.channelName,
      method: LegacyUserDefaults.readNumberMethod,
      arguments: ["key": "isSize"]
    )
    XCTAssertEqual((value as? NSNumber)?.intValue, 24)
  }

  func testRegisteredChannelAnswersNilWhenTheOldAppNeverSavedTheSize() throws {
    let suiteName = "ApplicationChannelsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let messenger = SpyMessenger()

    AppDelegate.registerApplicationChannels(with: messenger, defaults: defaults)

    // Answering with nil is the normal "no key" case; it must not look like a dead channel.
    let value = try messenger.call(
      LegacyUserDefaults.channelName,
      method: LegacyUserDefaults.readNumberMethod,
      arguments: ["key": "isSize"]
    )
    XCTAssertNil(value)
  }
}
