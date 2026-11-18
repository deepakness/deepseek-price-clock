/* String helpers ported from popup.js. Keep in sync with `clock`, `awayLabel`,
   `durationLabel`, `offsetLabel` and `displayDayKey`. */

import Foundation

public enum LabelFormat {
  /// `H:MM:SS` with no zero-padded hours, floored and clamped at zero.
  public static func countdown(secondsRemaining: TimeInterval) -> String {
    let seconds = max(0, Int(secondsRemaining.rounded(.down)))
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let rest = seconds % 60
    return "\(hours):\(pad(minutes)):\(pad(rest))"
  }

  /// "2h 15m" or "45m", floored to the minute.
  public static func away(ms: TimeInterval) -> String {
    let minutes = max(0, Int((ms / 60_000).rounded(.down)))
    let hours = minutes / 60
    return hours > 0 ? "\(hours)h \(minutes % 60)m" : "\(minutes)m"
  }

  /// "1h", "1h 30m" or "45m", rounded to the nearest minute.
  public static func duration(ms: TimeInterval) -> String {
    let minutes = max(0, Int((ms / 60_000).rounded()))
    let hours = minutes / 60
    let rest = minutes % 60
    if hours == 0 { return "\(rest)m" }
    return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
  }

  /// "GMT+8", "GMT−5", "GMT+5:45" — U+2212 for negatives, like the popup.
  public static func gmtOffset(minutes: Int) -> String {
    let sign = minutes >= 0 ? "+" : "−"
    let absolute = abs(minutes)
    let hours = absolute / 60
    let rest = absolute % 60
    return "GMT" + sign + String(hours) + (rest == 0 ? "" : ":\(pad(rest))")
  }

  /// "06:00" / "2:00 PM" in the display timezone, like the popup's `timeFmt`.
  public static func time(_ date: Date, offsetMinutes: Int, locale: Locale = .current) -> String {
    var style = Date.FormatStyle(locale: locale).hour().minute()
    style.timeZone = zone(offsetMinutes)
    return date.formatted(style)
  }

  /// "Mon 06:00" in the display timezone, like the popup's `dayFmt`.
  public static func dayTime(
    _ date: Date, offsetMinutes: Int, locale: Locale = .current
  ) -> String {
    var style = Date.FormatStyle(locale: locale).weekday(.abbreviated).hour().minute()
    style.timeZone = zone(offsetMinutes)
    return date.formatted(style)
  }

  static func zone(_ offsetMinutes: Int) -> TimeZone {
    TimeZone(secondsFromGMT: offsetMinutes * 60) ?? .gmt
  }

  /// `yyyyMMdd` in the display timezone, matching `displayDayKey`.
  public static func dayKey(_ date: Date, offsetMinutes: Int) -> Int {
    let shifted = Date(timeIntervalSince1970: date.timeIntervalSince1970 + Double(offsetMinutes) * 60)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let parts = calendar.dateComponents([.year, .month, .day], from: shifted)
    return parts.year! * 10000 + parts.month! * 100 + parts.day!
  }

  static func pad(_ value: Int) -> String {
    value < 10 ? "0\(value)" : String(value)
  }
}
