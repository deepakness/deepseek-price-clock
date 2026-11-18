/* Upcoming price windows: kind, range and how long is left. */

import PriceClockCore
import SwiftUI

struct WindowsTable: View {
  let model: ClockModel
  var count: Int = 4

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text("Price windows · \(Settings.zone == .utc ? "UTC" : "your time")")
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(PanelStyle.textSoft)

      ForEach(Array(windows.enumerated()), id: \.offset) { _, window in
        HStack(spacing: 8) {
          Text(window.phase == .peak ? "Peak" : "Off-peak")
            .font(.system(size: 11, weight: window.isCurrent ? .semibold : .regular))
            .foregroundStyle(PanelStyle.tint(window.phase))
            .frame(width: 54, alignment: .leading)
          Text(rangeLabel(window))
            .font(.system(size: 11, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(PanelStyle.text)
          Spacer(minLength: 4)
          Text(metaLabel(window))
            .font(.system(size: 10))
            .foregroundStyle(PanelStyle.textSoft)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 5)
        .background(
          window.isCurrent ? PanelStyle.background(window.phase).opacity(0.55) : .clear,
          in: RoundedRectangle(cornerRadius: 4))
      }
    }
  }

  private var windows: [PriceWindow] {
    PriceClock.windows(at: model.now, count: count)
  }

  private func rangeLabel(_ window: PriceWindow) -> String {
    if LabelFormat.dayKey(window.start, offsetMinutes: model.displayOffset)
      == LabelFormat.dayKey(window.end, offsetMinutes: model.displayOffset)
    {
      return "\(model.timeLabel(window.start)) – \(model.timeLabel(window.end))"
    }
    return "\(model.dayTimeLabel(window.start)) – \(model.dayTimeLabel(window.end))"
  }

  private func metaLabel(_ window: PriceWindow) -> String {
    if window.isCurrent {
      return LabelFormat.away(ms: window.end.timeIntervalSince(model.now) * 1000) + " left"
    }
    return LabelFormat.duration(ms: window.end.timeIntervalSince(window.start) * 1000)
  }
}
