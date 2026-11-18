/* Flip banners. UNUserNotificationCenter needs a real app bundle, so every call
   is guarded: running the binary straight out of .build (dev loop) simply has no
   notifications instead of crashing. */

import Foundation
import PriceClockCore
import UserNotifications

@Observable
@MainActor
final class Notifier {
  static let shared = Notifier()

  /// Live grant state. The panel's hint is derived from this, so text can never
  /// outlive the permission it describes.
  private(set) var status: NotificationStatus

  var isAuthorized: Bool { status == .authorized }

  /// False when running the raw binary out of .build, where the notification
  /// centre has no bundle to attribute a banner to.
  var available: Bool { status != .unavailable }

  init() {
    status = Bundle.main.bundleIdentifier == nil ? .unavailable : .notDetermined
  }

  /// Re-reads the grant. Called on launch, whenever the app becomes active (the
  /// user may have flipped it in System Settings), and before the panel opens.
  func refreshStatus() {
    guard available else { return }
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let next: NotificationStatus
      switch settings.authorizationStatus {
      case .authorized, .provisional, .ephemeral: next = .authorized
      case .denied: next = .denied
      default: next = .notDetermined
      }
      Task { @MainActor in self.status = next }
    }
  }

  /// Logs to the unified system log (Console.app, filter "DeepSeek Price Clock")
  /// instead of writing files.
  func probeLog(_ line: String) {
    NSLog("DeepSeek Price Clock: %@", line)
  }

  func requestAuthorization() async -> Bool {
    guard available else { return false }
    do {
      let granted = try await UNUserNotificationCenter.current().requestAuthorization(
        options: [.alert, .sound])
      probeLog("requestAuthorization returned \(granted)")
      status = granted ? .authorized : .denied
      return granted
    } catch {
      probeLog("requestAuthorization threw \(error)")
      // macOS can refuse outright without showing a prompt; report that as a
      // denial so the panel can explain itself instead of looking broken.
      status = .denied
      return false
    }
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
