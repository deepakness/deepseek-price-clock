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

  /// Writes a line to /tmp/deepseek-notify.log so a probe run can be read back
  /// without attaching to the process.
  func probeLog(_ line: String) {
    let path = "/tmp/deepseek-notify.log"
    let entry = "\(Date()) \(line)\n"
    if let handle = FileHandle(forWritingAtPath: path) {
      handle.seekToEndOfFile()
      handle.write(Data(entry.utf8))
      handle.closeFile()
    } else {
      try? entry.write(toFile: path, atomically: true, encoding: .utf8)
    }
  }

  func requestAuthorization() async -> Bool {
    guard available else { return false }
    do {
      let granted = try await UNUserNotificationCenter.current().requestAuthorization(
        options: [.alert, .sound])
      probeLog("requestAuthorization returned \(granted)")
      isAuthorized = granted
      return granted
    } catch {
      probeLog("requestAuthorization threw \(error)")
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
