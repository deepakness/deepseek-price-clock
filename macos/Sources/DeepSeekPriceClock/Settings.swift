/* Small UserDefaults wrapper: the app's equivalent of chrome.storage.local.
   Keys match the extension's names where the meaning is the same. */

import Foundation
import PriceClockCore

enum Settings {
  private static var defaults: UserDefaults { .standard }

  static var zone: ZoneMode {
    get { ZoneMode(rawValue: defaults.string(forKey: "zone") ?? "") ?? .local }
    set { defaults.set(newValue.rawValue, forKey: "zone") }
  }

  static var alerts: Bool {
    get { defaults.bool(forKey: "alerts") }
    set { defaults.set(newValue, forKey: "alerts") }
  }

  static var lastPhase: Phase? {
    get { defaults.string(forKey: "lastPhase").flatMap(Phase.init(rawValue:)) }
    set { defaults.set(newValue?.rawValue, forKey: "lastPhase") }
  }

  /// A day the fake clock was pinned to, so the holiday/weekend paths can be
  /// inspected without touching the system clock. Nil when unset.
  static var fakeNow: Date? {
    guard let raw = ProcessInfo.processInfo.environment["DEEPSEEK_FAKE_NOW"],
      let ms = Double(raw)
    else { return nil }
    return Date(timeIntervalSince1970: ms / 1000)
  }
}
