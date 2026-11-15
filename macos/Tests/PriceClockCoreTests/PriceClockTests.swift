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
