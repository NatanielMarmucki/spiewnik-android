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
