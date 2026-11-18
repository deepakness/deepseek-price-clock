/* Whether a phase flip deserves a banner. Ported from background.js'
   maybeNotify: the first run only records the phase, alerts must be on and
   authorized, and a flip noticed late (laptop asleep) is dropped rather than
   announced hours afterwards. */

import Foundation

public enum AnnouncementPolicy {
  /// A flip older than this when the app notices it is skipped.
  public static let graceSeconds: TimeInterval = 300

  public static func shouldAnnounce(
    previous: Phase?,
    current: Phase,
    windowStart: Date,
    now: Date,
    alertsEnabled: Bool,
    authorized: Bool
  ) -> Bool {
    guard previous != nil, previous != current else { return false }
    guard alertsEnabled, authorized else { return false }
    return now.timeIntervalSince(windowStart) <= graceSeconds
  }

  /// The panel's own "price flipped" strip: stays up for the same grace window
  /// and then goes away, so it never becomes permanent furniture.
  public static func noticeVisible(shownAt: Date?, now: Date) -> Bool {
    guard let shownAt else { return false }
    return now.timeIntervalSince(shownAt) <= graceSeconds
  }
}
