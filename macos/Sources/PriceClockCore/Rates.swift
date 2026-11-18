/* Model rates, per 1M tokens. popup.html is the source of truth: the test in
   Tests/PriceClockCoreTests compares this table against rates.json, which
   Tools/gen-vectors.mjs extracts from that file. */

import Foundation

public struct Rate: Codable, Sendable, Equatable {
  public let off: String
  public let peak: String

  public init(off: String, peak: String) {
    self.off = off
    self.peak = peak
  }
}

public struct ModelRates: Sendable, Equatable {
  public let name: String
  /// In `RateTable.columns` order: input (cache miss), cached input, output.
  public let rates: [Rate]

  public init(name: String, rates: [Rate]) {
    self.name = name
    self.rates = rates
  }
}

public enum RateTable {
  public static let columns = ["input", "cached", "output"]

  public static let models: [ModelRates] = [
    ModelRates(name: "V4.1 Flash", rates: [
      Rate(off: "$0.15", peak: "$0.30"),
      Rate(off: "$0.003", peak: "$0.006"),
      Rate(off: "$0.60", peak: "$1.20"),
    ]),
    ModelRates(name: "V4 Pro", rates: [
      Rate(off: "$0.66", peak: "$1.32"),
      Rate(off: "$0.022", peak: "$0.044"),
      Rate(off: "$1.98", peak: "$3.96"),
    ]),
  ]

  public static func amount(_ rate: Rate, phase: Phase) -> String {
    phase == .peak ? rate.peak : rate.off
  }
}
