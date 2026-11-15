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
