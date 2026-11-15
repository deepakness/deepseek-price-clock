/* The one-line explanation under the alerts toggle. Derived from the current
   grant rather than remembered, so text that says "declined" cannot outlive the
   denial — the bug this replaces. */

import Foundation

public enum NotificationStatus: Sendable {
  /// No app bundle, so no notification centre to ask (the raw dev binary).
  case unavailable
  case notDetermined
  case denied
  case authorized
}

public enum NotificationHint {
  public static let prompt = "Desktop alert at each peak / off-peak switch"

  public static func text(for status: NotificationStatus, alertsOn: Bool) -> String {
    switch status {
    case .unavailable: return "Notifications need the built .app, not a raw build"
    case .denied: return "Notification permission was declined"
    case .authorized, .notDetermined: return prompt
    }
  }
}
