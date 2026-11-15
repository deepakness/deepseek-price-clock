/* The 24-hour bar: price segments in display time with a marker at "now". */

import PriceClockCore
import SwiftUI

struct TimelineStrip: View {
  let model: ClockModel

  private var segments: [DaySegment] {
    PriceClock.displaySegments(at: model.now, offsetMinutes: model.displayOffset)
  }

  var body: some View {
    VStack(spacing: 3) {
      GeometryReader { proxy in
        ZStack(alignment: .topLeading) {
          HStack(spacing: 2) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
              Rectangle()
                .fill(PanelStyle.solid(segment.phase).opacity(segment.phase == .peak ? 0.5 : 0.55))
                .frame(
                  width: max(
                    0,
                    (segment.endMinute - segment.startMinute) / 1440 * (proxy.size.width
                      - CGFloat(max(0, segments.count - 1)) * 2)))
            }
          }
          Rectangle()
            .fill(PanelStyle.text)
            .frame(width: 2, height: proxy.size.height + 6)
            .offset(x: markerX(in: proxy.size.width) - 1, y: -3)
        }
      }
      .frame(height: 8)
      .clipShape(RoundedRectangle(cornerRadius: 2))

      HStack(spacing: 0) {
        ForEach(["00", "06", "12", "18", "24"], id: \.self) { tick in
          Text(tick)
            .font(.system(size: 9))
            .foregroundStyle(PanelStyle.textSoft)
          if tick != "24" { Spacer(minLength: 0) }
        }
      }
    }
  }

  private func markerX(in width: CGFloat) -> CGFloat {
    let minute =
      (Double(model.window.minuteOfDay) + model.now.timeIntervalSince1970.truncatingRemainder(
        dividingBy: 60) / 60 + Double(model.displayOffset) + 1440)
      .truncatingRemainder(dividingBy: 1440)
    return width * CGFloat(minute / 1440)
  }
}
