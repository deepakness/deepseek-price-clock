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
  private var ticker: Task<Void, Never>?
  private var panelVisible = false

  init(now: Date? = nil) {
    let start = now ?? Settings.fakeNow ?? Date()
    self.now = start
    self.window = PriceClock.currentWindow(at: start)
    self.windowStart = PriceClock.currentWindowStart(at: start)
    observeWake()
    scheduleTicker()
  }

  var phase: Phase { window.phase }

  var displayOffset: Int {
    Settings.zone == .utc ? 0 : TimeZone.current.secondsFromGMT(for: now) / 60
  }

  /// True when the current window ends on a different display day.
  var crossDay: Bool {
    LabelFormat.dayKey(window.end, offsetMinutes: displayOffset)
      != LabelFormat.dayKey(now, offsetMinutes: displayOffset)
  }

  var timezoneCaption: String {
    if Settings.zone == .utc { return "UTC · GMT+0" }
    return "\(TimeZone.current.identifier) · \(LabelFormat.gmtOffset(minutes: displayOffset))"
  }

  /// The toolbar-title sentence, mirroring background.js.
  var title: String {
    let time = endLabel(window.end)
    return phase == .peak
      ? "DeepSeek: peak pricing until \(time)"
      : "DeepSeek: off-peak (half price) until \(time)"
  }

  func endLabel(_ date: Date) -> String {
    date.formatted(
      Date.FormatStyle(locale: .current).weekday(.abbreviated).hour().minute())
  }

  func setPanelVisible(_ visible: Bool) {
    guard visible != panelVisible else { return }
    panelVisible = visible
    scheduleTicker()
    if visible { refreshNow() }
  }

  func refreshNow() {
    now = Settings.fakeNow ?? Date()
    window = PriceClock.currentWindow(at: now)
    windowStart = PriceClock.currentWindowStart(at: now)
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
