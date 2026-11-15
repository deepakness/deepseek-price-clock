/* Flip banners. UNUserNotificationCenter needs a real app bundle, so every call
   is guarded: running the binary straight out of .build (dev loop) simply has no
   notifications instead of crashing. */

import Foundation
import PriceClockCore
import UserNotifications

@MainActor
final class Notifier {
  static let shared = Notifier()

  private(set) var isAuthorized = false
  /// False when running the raw binary out of .build, where the notification
  /// centre has no bundle to attribute a banner to.
  let available = Bundle.main.bundleIdentifier != nil

  /// Reads the current grant on launch, so a flip is not announced into a void.
  func refreshAuthorization() {
    guard available else { return }
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let granted = settings.authorizationStatus == .authorized
        || settings.authorizationStatus == .provisional
      Task { @MainActor in self.isAuthorized = granted }
    }
  }

  func requestAuthorization() async -> Bool {
    guard available else { return false }
    let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound])) ?? false
    isAuthorized = granted
    return granted
  }

  /// Same titles and messages as background.js; `endLabel` is already the
  /// system-local "Mon 9:00 AM" form.
  func postFlip(phase: Phase, endLabel: String) {
    guard available, isAuthorized else { return }
    let peak = phase == .peak
    let content = UNMutableNotificationContent()
    content.title =
      peak ? "DeepSeek: peak pricing started" : "DeepSeek: off-peak started (half price)"
    content.body = peak ? "Off-peak again \(endLabel)" : "Half price until \(endLabel)"
    content.sound = .default
    let request = UNNotificationRequest(identifier: "flip", content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
  }
}
