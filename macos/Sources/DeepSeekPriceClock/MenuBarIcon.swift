/* The menu bar glyph. The extension's toolbar PNG is a coloured rounded square
   with a white whale inside it, which is far too much visual weight for a menu
   bar. So the whale is lifted out by keeping the near-white pixels as an alpha
   mask and tinting that: shape preserved, colour carries the phase, and it
   adapts to dark mode. */

import AppKit
import PriceClockCore
import SwiftUI

@MainActor
enum MenuBarIcon {
  private static var cache: [Phase: NSImage] = [:]

  static func image(for phase: Phase) -> NSImage {
    if let cached = cache[phase] { return cached }
    let tinted = tinted(
      mask: mask, color: phase == .peak ? PanelStyle.peakSolid : PanelStyle.offSolid)
    cache[phase] = tinted
    return tinted
  }

  /// White whale, transparent everywhere else, at the size the menu bar wants.
  /// The source PNG is decoded into a known RGBA buffer first: NSBitmapImageRep's
  /// colorAt is unreliable for the colour space these files carry.
  private static let mask: NSImage = {
    let empty = NSImage(size: NSSize(width: 18, height: 18))
    guard
      let url = glyphURL,
      let data = try? Data(contentsOf: url),
      let source = NSBitmapImageRep(data: data)?.cgImage
    else { return empty }

    let width = source.width
    let height = source.height
    let space = CGColorSpaceCreateDeviceRGB()
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    guard
      let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else { return empty }
    context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

    // The whale is pure white on the phase-coloured rounded square.
    var masked = [UInt8](repeating: 0, count: width * height * 4)
    for index in stride(from: 0, to: pixels.count, by: 4) {
      let isWhale =
        pixels[index] > 191 && pixels[index + 1] > 191 && pixels[index + 2] > 191
        && pixels[index + 3] > 127
      guard isWhale else { continue }
      masked[index] = 255
      masked[index + 1] = 255
      masked[index + 2] = 255
      masked[index + 3] = 255
    }

    guard
      let maskedContext = CGContext(
        data: &masked,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ),
      let maskImage = maskedContext.makeImage()
    else { return empty }

    let image = NSImage(cgImage: maskImage, size: NSSize(width: 18, height: 18))
    image.isTemplate = true
    return image
  }()

  /// The whale art, found without Bundle.module: that accessor traps when the
  /// SwiftPM resource bundle is missing, and the assembled app must not depend on
  /// a build directory that can be cleaned away. Checked in order: the app's
  /// Resources, the resource bundle beside the executable (sealed inside
  /// Contents/MacOS, or sitting next to the binary in the dev loop).
  private static var glyphURL: URL? {
    let besideExecutable = Bundle.main.bundleURL
      .appendingPathComponent("DeepSeekPriceClock_DeepSeekPriceClock.bundle")
      .appendingPathComponent("Contents/Resources/peak32.png")
    let candidates: [URL] = [
      Bundle.main.url(forResource: "peak32", withExtension: "png"),
      besideExecutable,
    ].compactMap { $0 }
    return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
  }

  private static func tinted(mask: NSImage, color: Color) -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let tint = NSColor(color)
    let image = NSImage(size: size, flipped: false) { rect in
      mask.draw(in: rect)
      tint.set()
      rect.fill(using: .sourceAtop)
      return true
    }
    image.isTemplate = false
    return image
  }
}
