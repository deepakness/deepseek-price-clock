/* Menu bar entry point. The panel is a .window-style MenuBarExtra so it behaves
   like the extension popup: click to open, click away to dismiss.

   `--snapshot <path> [--dark]` renders the panel to a PNG and exits; it exists
   so the panel can be inspected without a human watching the screen. */

import AppKit
import PriceClockCore
import SwiftUI

@main
struct DeepSeekPriceClockApp: App {
  @State private var model = ClockModel()

  init() {
    MainActor.assumeIsolated {
      if Snapshot.requested {
        Snapshot.run(model: ClockModel())
        exit(0)
      }
      if CommandLine.arguments.contains("--notify-test") {
        Snapshot.notificationProbe()
      }
    }
  }

  var body: some Scene {
    MenuBarExtra {
      PanelView(model: model)
        .onAppear { model.setPanelVisible(true) }
        .onDisappear { model.setPanelVisible(false) }
    } label: {
      Image(nsImage: MenuBarIcon.image(for: model.phase))
    }
    .menuBarExtraStyle(.window)
  }
}

@MainActor
enum Snapshot {
  static var requested: Bool { CommandLine.arguments.contains("--snapshot") }

  /// `--notify-test`: ask for permission, post one real flip banner, exit. Used
  /// to verify delivery in the signed bundle.
  static func notificationProbe() {
    Task { @MainActor in
      // Let the app finish launching: the notification centre wants a running
      // app bundle, not one still inside App.init.
      try? await Task.sleep(for: .seconds(2))
      Notifier.shared.probeLog("requesting authorization")
      let granted = await Notifier.shared.requestAuthorization()
      Notifier.shared.probeLog("authorized: \(granted)")
      guard granted else { exit(1) }
      try? await Task.sleep(for: .seconds(3))
      Notifier.shared.postFlip(phase: .off, endLabel: "Sun 9:00 AM")
      Notifier.shared.probeLog("posted")
      try? await Task.sleep(for: .seconds(2))
      exit(0)
    }
  }

  static func run(model: ClockModel) {
    let arguments = CommandLine.arguments
    guard
      let index = arguments.firstIndex(of: "--snapshot"), arguments.count > index + 1
    else { return }
    let dark = arguments.contains("--dark")
    // `--zone utc|local` pins the toggle for the snapshot; the previous value is
    // restored so rendering never changes what the app will open with.
    let previousZone = Settings.zone
    if let zoneIndex = arguments.firstIndex(of: "--zone"), arguments.count > zoneIndex + 1,
      let zone = ZoneMode(rawValue: arguments[zoneIndex + 1])
    {
      Settings.zone = zone
    }
    defer { Settings.zone = previousZone }
    let renderer = ImageRenderer(
      content: PanelView(model: model).environment(\.colorScheme, dark ? .dark : .light))
    renderer.scale = 2
    guard
      let image = renderer.nsImage,
      let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [NSBitmapImageRep.PropertyKey: Any]())
    else { return }
    try? png.write(to: URL(fileURLWithPath: arguments[index + 1]))
  }
}
