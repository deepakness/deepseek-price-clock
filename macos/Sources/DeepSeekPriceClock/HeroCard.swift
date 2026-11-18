/* The top card of the popup: phase badge, countdown, elapsed-window bar and the
   next switch. Colours come from the phase, as in popup.css. */

import PriceClockCore
import SwiftUI

struct HeroCard: View {
  let model: ClockModel

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Circle()
          .fill(PanelStyle.solid(phase))
          .frame(width: 7, height: 7)
        Text(phase == .peak ? "Peak pricing" : "Off-peak · half price")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(PanelStyle.tint(phase))
      }

      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(LabelFormat.countdown(secondsRemaining: model.window.end.timeIntervalSince(model.now)))
          .font(.system(size: 34, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(PanelStyle.text)
        Text("left")
          .font(.system(size: 11))
          .foregroundStyle(PanelStyle.textSoft)
      }

      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(PanelStyle.solid(phase).opacity(0.18))
          Capsule()
            .fill(PanelStyle.solid(phase))
            .frame(width: max(0, min(1, progress)) * proxy.size.width)
        }
      }
      .frame(height: 5)

      HStack(spacing: 4) {
        Text("→").font(.system(size: 11))
        Text(untilText).font(.system(size: 11))
      }
      .foregroundStyle(PanelStyle.textMuted)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(PanelStyle.background(phase), in: RoundedRectangle(cornerRadius: 10))
  }

  private var phase: Phase { model.phase }

  private var progress: Double {
    let total = model.window.end.timeIntervalSince(model.windowStart)
    guard total > 0 else { return 0 }
    return model.now.timeIntervalSince(model.windowStart) / total
  }

  private var untilText: String {
    let prefix = phase == .peak ? "Off-peak starts " : "Peak starts "
    return prefix + whenLabel(model.window.end)
  }

  /// "9:00 AM", or day-qualified when the switch is on another display day.
  private func whenLabel(_ date: Date) -> String {
    model.crossDay ? model.dayTimeLabel(date) : model.timeLabel(date)
  }
}
