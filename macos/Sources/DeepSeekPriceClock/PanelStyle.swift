/* Colour and type tokens transcribed from popup.css, including its dark-mode
   overrides, so the panel matches the extension in both appearances. */

import AppKit
import PriceClockCore
import SwiftUI

enum PanelStyle {
  static let offSolid = dynamic(light: 0x22c55e, dark: 0x4ade80)
  static let peakSolid = dynamic(light: 0xef4444, dark: 0xf87171)
  static let offText = dynamic(light: 0x1b7d2f, dark: 0xbbf7d0)
  static let peakText = dynamic(light: 0xc62828, dark: 0xffc1c1)
  static let offBackground = dynamic(light: 0xe8f5e9, dark: 0x1b4d2f)
  static let peakBackground = dynamic(light: 0xffebee, dark: 0x5b1d1d)
  static let surface = dynamic(light: 0xffffff, dark: 0x1a2436)
  static let surfaceHover = dynamic(light: 0xecf2ff, dark: 0x243247)
  static let border = dynamic(light: 0xd8e0ed, dark: 0x3d4f6a)
  static let text = dynamic(light: 0x0f172a, dark: 0xeef3f9)
  static let textMuted = dynamic(light: 0x4b5563, dark: 0xc5cedb)
  static let textSoft = dynamic(light: 0x6b7280, dark: 0xaeb9ca)
  static let link = dynamic(light: 0x3364ff, dark: 0xa3c4ff)

  static func solid(_ phase: Phase) -> Color {
    phase == .peak ? peakSolid : offSolid
  }

  static func tint(_ phase: Phase) -> Color {
    phase == .peak ? peakText : offText
  }

  static func background(_ phase: Phase) -> Color {
    phase == .peak ? peakBackground : offBackground
  }

  private static func dynamic(light: UInt32, dark: UInt32) -> Color {
    Color(
      nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return NSColor(hex: isDark ? dark : light)
      })
  }
}

extension NSColor {
  convenience init(hex: UInt32) {
    self.init(
      srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
      green: CGFloat((hex >> 8) & 0xff) / 255,
      blue: CGFloat(hex & 0xff) / 255,
      alpha: 1
    )
  }
}

