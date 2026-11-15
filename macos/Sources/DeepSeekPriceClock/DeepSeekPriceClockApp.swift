/* Menu bar entry point. The panel is a .window-style MenuBarExtra so it behaves
   like the extension popup: click to open, click away to dismiss. */

import PriceClockCore
import SwiftUI

@main
struct DeepSeekPriceClockApp: App {
  @State private var model = ClockModel()

  var body: some Scene {
    MenuBarExtra {
      VStack(alignment: .leading, spacing: 4) {
        Text(model.title)
        Text(model.phase.rawValue)
      }
      .padding()
      .onAppear { model.setPanelVisible(true) }
      .onDisappear { model.setPanelVisible(false) }
    } label: {
      Image(nsImage: MenuBarIcon.image(for: model.phase))
    }
    .menuBarExtraStyle(.window)
  }
}
