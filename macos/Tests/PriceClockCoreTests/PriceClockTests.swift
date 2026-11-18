import Foundation
import Testing
@testable import PriceClockCore

struct ValidityFixture: Decodable {
  struct Next: Decodable {
    let t: Int
    let phase: Phase
  }
  struct Window: Decodable {
    let start: Int
    let end: Int
    let phase: Phase
    let current: Bool
  }
  struct Case: Decodable {
    let t: Int
    let phase: Phase
    let next: Next
    let start: Int
    let windows: [Window]
  }
  let switchMinutes: [Int]
  let weekendRuleStartMs: Int
  let cases: [Case]
}

func loadValidity() throws -> ValidityFixture {
  let url = try #require(
    Bundle.module.url(forResource: "validity", withExtension: "json", subdirectory: "Fixtures")
  )
  return try JSONDecoder().decode(ValidityFixture.self, from: Data(contentsOf: url))
}

func date(_ ms: Int) -> Date { Date(timeIntervalSince1970: Double(ms) / 1000) }

@Test func constantsMatchTheExtension() throws {
  let fixture = try loadValidity()
  #expect(PriceClock.switchMinutes == fixture.switchMinutes)
  #expect(
    PriceClock.weekendRuleStart.timeIntervalSince1970 * 1000
      == Double(fixture.weekendRuleStartMs)
  )
}

@Test func phaseMatchesPriceJsOnEverySample() throws {
  for testCase in try loadValidity().cases {
    #expect(PriceClock.phase(at: date(testCase.t)) == testCase.phase, "t=\(testCase.t)")
  }
}

@Test func nextSwitchMatchesPriceJs() throws {
  for testCase in try loadValidity().cases {
    let next = try #require(PriceClock.nextSwitches(after: date(testCase.t), count: 1).first)
    #expect(next.date == date(testCase.next.t), "t=\(testCase.t)")
    #expect(next.phase == testCase.next.phase, "t=\(testCase.t)")
  }
}

@Test func currentWindowStartMatchesPriceJs() throws {
  for testCase in try loadValidity().cases {
    #expect(
      PriceClock.currentWindowStart(at: date(testCase.t)) == date(testCase.start),
      "t=\(testCase.t)")
  }
}

@Test func windowsMatchPriceJs() throws {
  for testCase in try loadValidity().cases {
    let windows = PriceClock.windows(at: date(testCase.t), count: 4)
    #expect(windows.count == testCase.windows.count, "t=\(testCase.t)")
    for (window, expected) in zip(windows, testCase.windows) {
      #expect(window.start == date(expected.start), "t=\(testCase.t)")
      #expect(window.end == date(expected.end), "t=\(testCase.t)")
      #expect(window.phase == expected.phase, "t=\(testCase.t)")
      #expect(window.isCurrent == expected.current, "t=\(testCase.t)")
    }
  }
}

struct SegmentsFixture: Decodable {
  struct Segment: Decodable {
    let start: Double
    let end: Double
    let phase: Phase
  }
  struct Case: Decodable {
    let t: Int
    let offset: Int
    let segments: [Segment]
  }
  let cases: [Case]
}

@Test func displaySegmentsMatchPriceJsAtFourOffsets() throws {
  let url = try #require(
    Bundle.module.url(forResource: "segments", withExtension: "json", subdirectory: "Fixtures"))
  let fixture = try JSONDecoder().decode(SegmentsFixture.self, from: Data(contentsOf: url))
  #expect(Set(fixture.cases.map(\.offset)) == [0, 480, -300, 345])
  for testCase in fixture.cases {
    let segments = PriceClock.displaySegments(at: date(testCase.t), offsetMinutes: testCase.offset)
    #expect(
      segments.count == testCase.segments.count,
      "t=\(testCase.t) offset=\(testCase.offset)")
    for (segment, expected) in zip(segments, testCase.segments) {
      #expect(segment.startMinute == expected.start, "t=\(testCase.t)")
      #expect(segment.endMinute == expected.end, "t=\(testCase.t)")
      #expect(segment.phase == expected.phase, "t=\(testCase.t)")
    }
  }
}

@Test func holidayRendersAsOneBar() {
  // 2026-11-15T09:55Z is a Beijing Sunday: off-peak all day, one full-width segment.
  let segments = PriceClock.displaySegments(at: date(1_794_736_500_000), offsetMinutes: 0)
  #expect(segments == [DaySegment(startMinute: 0, endMinute: 1440, phase: .off)])
}

struct RatesFixture: Decodable {
  struct Model: Decodable {
    let name: String
    let rates: [Rate]
  }
  let columns: [String]
  let models: [Model]
}

@Test func rateTableMatchesPopupHtml() throws {
  let url = try #require(
    Bundle.module.url(forResource: "rates", withExtension: "json", subdirectory: "Fixtures"))
  let fixture = try JSONDecoder().decode(RatesFixture.self, from: Data(contentsOf: url))
  #expect(RateTable.columns == fixture.columns)
  #expect(RateTable.models.map(\.name) == fixture.models.map(\.name))
  #expect(RateTable.models.flatMap(\.rates) == fixture.models.flatMap(\.rates))
}

@Test func peakRatesAreDoubleOffPeak() {
  #expect(RateTable.amount(RateTable.models[0].rates[0], phase: .off) == "$0.15")
  #expect(RateTable.amount(RateTable.models[0].rates[0], phase: .peak) == "$0.30")
}

@Test func countdownMatchesPopupFormat() {
  #expect(LabelFormat.countdown(secondsRemaining: 599) == "0:09:59")
  #expect(LabelFormat.countdown(secondsRemaining: 43_201) == "12:00:01")
  #expect(LabelFormat.countdown(secondsRemaining: -5) == "0:00:00")
}

@Test func awayAndDurationLabelsMatchPopup() {
  #expect(LabelFormat.away(ms: 135 * 60_000) == "2h 15m")
  #expect(LabelFormat.away(ms: 45 * 60_000) == "45m")
  #expect(LabelFormat.away(ms: 30_000) == "0m")
  #expect(LabelFormat.duration(ms: 90 * 60_000) == "1h 30m")
  #expect(LabelFormat.duration(ms: 3_600_000) == "1h")
  #expect(LabelFormat.duration(ms: 45 * 60_000) == "45m")
}

@Test func gmtOffsetUsesTypographicMinus() {
  #expect(LabelFormat.gmtOffset(minutes: 0) == "GMT+0")
  #expect(LabelFormat.gmtOffset(minutes: 480) == "GMT+8")
  #expect(LabelFormat.gmtOffset(minutes: -300) == "GMT−5")
  #expect(LabelFormat.gmtOffset(minutes: 345) == "GMT+5:45")
}

@Test func dayKeyFollowsDisplayOffset() {
  // 1794785400000 = 2026-11-15T23:30Z: 2026-11-16 in Shanghai (offset 480), 2026-11-15 in UTC.
  #expect(LabelFormat.dayKey(date(1_794_785_400_000), offsetMinutes: 0) == 20_261_115)
  #expect(LabelFormat.dayKey(date(1_794_785_400_000), offsetMinutes: 480) == 20_261_116)
}

@Test func timeLabelsFollowTheDisplayOffset() {
  let instant = date(1_794_808_800_000)  // 2026-11-16T06:00:00Z
  let utc = Locale(identifier: "en_GB")
  #expect(LabelFormat.time(instant, offsetMinutes: 0, locale: utc) == "06:00")
  #expect(LabelFormat.time(instant, offsetMinutes: 480, locale: utc) == "14:00")
  #expect(
    LabelFormat.dayTime(date(1_794_700_800_000), offsetMinutes: 0, locale: utc) == "Sun 00:00")
  #expect(
    LabelFormat.dayTime(date(1_794_700_800_000), offsetMinutes: 480, locale: utc) == "Sun 08:00")
}

@Test func announcementPolicyMirrorsBackgroundJs() {
  let now = date(1_794_736_500_000)
  let start = now.addingTimeInterval(-60)
  // First run only records the phase.
  #expect(
    !AnnouncementPolicy.shouldAnnounce(
      previous: nil, current: .peak, windowStart: start, now: now, alertsEnabled: true,
      authorized: true))
  // A fresh flip with alerts on and permission granted announces.
  #expect(
    AnnouncementPolicy.shouldAnnounce(
      previous: .off, current: .peak, windowStart: start, now: now, alertsEnabled: true,
      authorized: true))
  // Alerts off, permission missing, or a stale flip (older than 300 s) do not.
  #expect(
    !AnnouncementPolicy.shouldAnnounce(
      previous: .off, current: .peak, windowStart: start, now: now, alertsEnabled: false,
      authorized: true))
  #expect(
    !AnnouncementPolicy.shouldAnnounce(
      previous: .off, current: .peak, windowStart: start, now: now, alertsEnabled: true,
      authorized: false))
  #expect(
    !AnnouncementPolicy.shouldAnnounce(
      previous: .off, current: .peak, windowStart: now.addingTimeInterval(-400), now: now,
      alertsEnabled: true, authorized: true))
  // Same phase never announces.
  #expect(
    !AnnouncementPolicy.shouldAnnounce(
      previous: .peak, current: .peak, windowStart: start, now: now, alertsEnabled: true,
      authorized: true))
}

@Test func flipNoticeExpiresAfterTheGraceWindow() {
  let shown = date(1_794_736_500_000)
  #expect(AnnouncementPolicy.noticeVisible(shownAt: shown, now: shown.addingTimeInterval(1)))
  #expect(
    AnnouncementPolicy.noticeVisible(shownAt: shown, now: shown.addingTimeInterval(300)))
  #expect(
    !AnnouncementPolicy.noticeVisible(shownAt: shown, now: shown.addingTimeInterval(301)))
  #expect(!AnnouncementPolicy.noticeVisible(shownAt: nil, now: shown))
}

@Test func notificationHintFollowsTheCurrentGrant() {
  let prompt = "Desktop alert at each peak / off-peak switch"
  // The bug: a grant after a denial must clear the denial text.
  #expect(
    NotificationHint.text(for: .denied, alertsOn: false)
      == "Notification permission was declined")
  #expect(NotificationHint.text(for: .authorized, alertsOn: true) == prompt)
  #expect(NotificationHint.text(for: .authorized, alertsOn: false) == prompt)
  #expect(NotificationHint.text(for: .notDetermined, alertsOn: false) == prompt)
  #expect(
    NotificationHint.text(for: .unavailable, alertsOn: false)
      == "Notifications need the built .app, not a raw build")
}
