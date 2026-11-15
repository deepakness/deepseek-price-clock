/* Drives the menu bar glyph and the panel. One task: keep `now` fresh at the
   cadence the panel needs, and recompute the price window from the ported
   logic. */

import AppKit
import Foundation
import Observation
import PriceClockCore

@MainActor
@Observable
final class ClockModel {
  private(set) var now: Date
  private(set) var window: CurrentWindow
  private(set) var windowStart: Date
  /// Set when a flip was just noticed, so the panel can say so even when the
  /// system refuses our banners.
  private(set) var recentFlip: Phase?
  private var recentFlipAt: Date?
  private var ticker: Task<Void, Never>?
  private var panelVisible = false

  init(now: Date? = nil) {
    let start = now ?? Settings.currentInstant
    self.now = start
    self.window = PriceClock.currentWindow(at: start)
    self.windowStart = PriceClock.currentWindowStart(at: start)
    Notifier.shared.refreshAuthorization()
    observeWake()
    scheduleTicker()
    Settings.lastPhase = window.phase
  }

  var phase: Phase { window.phase }

  var displayOffset: Int {
    // autoupdatingCurrent, not .current: the latter is a snapshot taken at launch
    // and would keep showing the old zone after a travel or region change.
    Settings.zone == .utc ? 0 : TimeZone.autoupdatingCurrent.secondsFromGMT(for: now) / 60
  }

  /// True when the current window ends on a different display day.
  var crossDay: Bool {
    LabelFormat.dayKey(window.end, offsetMinutes: displayOffset)
      != LabelFormat.dayKey(now, offsetMinutes: displayOffset)
  }

  var timezoneCaption: String {
    if Settings.zone == .utc { return "UTC · GMT+0" }
    return "\(TimeZone.autoupdatingCurrent.identifier) · \(LabelFormat.gmtOffset(minutes: displayOffset))"
  }

  /// "06:00" / "2:00 PM" in the panel's timezone (UTC when the toggle says so).
  func timeLabel(_ date: Date) -> String {
    LabelFormat.time(date, offsetMinutes: displayOffset)
  }

  /// "Mon 06:00" in the panel's timezone.
  func dayTimeLabel(_ date: Date) -> String {
    LabelFormat.dayTime(date, offsetMinutes: displayOffset)
  }

  /// The toolbar-title sentence, mirroring background.js, which always speaks in
  /// system-local time.
  var title: String {
    let time = endLabel(window.end)
    return phase == .peak
      ? "DeepSeek: peak pricing until \(time)"
      : "DeepSeek: off-peak (half price) until \(time)"
  }

  func endLabel(_ date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
    var style = Date.FormatStyle(locale: .current).weekday(.abbreviated).hour().minute()
    style.timeZone = timeZone
    return date.formatted(style)
  }

  func setPanelVisible(_ visible: Bool) {
    guard visible != panelVisible else { return }
    panelVisible = visible
    scheduleTicker()
    if visible { refreshNow() }
  }

  func refreshNow() {
    now = Settings.currentInstant
    window = PriceClock.currentWindow(at: now)
    windowStart = PriceClock.currentWindowStart(at: now)
    announceIfFlipped()
  }

  /// Records the phase and, when the flip is fresh, posts one banner and keeps
  /// a short notice for the panel.
  private func announceIfFlipped() {
    // Expire the panel strip first: it has to disappear even when no flip is
    // happening, which is every tick after the first one.
    if !AnnouncementPolicy.noticeVisible(shownAt: recentFlipAt, now: now) {
      recentFlip = nil
      recentFlipAt = nil
    }

    let previous = Settings.lastPhase
    guard previous != window.phase else { return }
    Settings.lastPhase = window.phase
    if previous != nil, Settings.alerts,
      now.timeIntervalSince(windowStart) <= AnnouncementPolicy.graceSeconds
    {
      recentFlip = window.phase
      recentFlipAt = now
    }
    guard
      AnnouncementPolicy.shouldAnnounce(
        previous: previous,
        current: window.phase,
        windowStart: windowStart,
        now: now,
        alertsEnabled: Settings.alerts,
        authorized: Notifier.shared.isAuthorized
      )
    else { return }
    Notifier.shared.postFlip(phase: window.phase, endLabel: endLabel(window.end))
  }

  /// 1 s while the panel is open (the countdown needs it), 20 s otherwise, so a
  /// closed panel does not wake the CPU to reformat text.
  private func scheduleTicker() {
    ticker?.cancel()
    let interval = panelVisible ? Duration.seconds(1) : .seconds(20)
    ticker = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: interval)
        guard !Task.isCancelled, let self else { return }
        self.refreshNow()
      }
    }
  }

  private func observeWake() {
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.refreshNow() }
    }
  }
}
