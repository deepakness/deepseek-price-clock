/* Current and next rates, per 1M tokens, straight from the shared rate table. */

import PriceClockCore
import SwiftUI

struct RatesBlock: View {
  let model: ClockModel

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      block(
        title: "Paying now · \(model.phase == .peak ? "peak" : "off-peak")",
        phase: model.phase, showHeader: true)
      block(
        title: "From \(fromLabel) · \(model.phase == .peak ? "off-peak" : "peak")",
        phase: other(than: model.phase), showHeader: false)
    }
  }

  private func block(title: String, phase: Phase, showHeader: Bool) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(spacing: 6) {
        Circle().fill(PanelStyle.solid(phase)).frame(width: 6, height: 6)
        Text(title)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(PanelStyle.textMuted)
        Spacer(minLength: 4)
        Text("per 1M tokens")
          .font(.system(size: 9))
          .foregroundStyle(PanelStyle.textSoft)
      }
      Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 3) {
        if showHeader {
          GridRow {
            Color.clear.frame(width: 62, height: 1)
            ForEach(RateTable.columns, id: \.self) { column in
              Text(column)
                .font(.system(size: 9))
                .foregroundStyle(PanelStyle.textSoft)
                .frame(width: 46, alignment: .trailing)
            }
          }
        }
        ForEach(RateTable.models, id: \.name) { rates in
          GridRow {
            Text(rates.name)
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(PanelStyle.text)
              .frame(width: 62, alignment: .leading)
            ForEach(Array(rates.rates.enumerated()), id: \.offset) { _, rate in
              Text(RateTable.amount(rate, phase: phase))
                .font(.system(size: 10, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(PanelStyle.text)
                .frame(width: 46, alignment: .trailing)
            }
          }
        }
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 9).fill(
        phase == .peak ? PanelStyle.peakBackground.opacity(0.4) : PanelStyle.offBackground.opacity(0.4))
    )
  }

  private var fromLabel: String {
    model.crossDay ? model.dayTimeLabel(model.window.end) : model.timeLabel(model.window.end)
  }

  private func other(than phase: Phase) -> Phase {
    phase == .peak ? .off : .peak
  }
}
