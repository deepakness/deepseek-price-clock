/* The popup, redrawn. Same order as popup.html: header, card (hero, timeline,
   windows), rates, alerts, footer. */

import PriceClockCore
import SwiftUI

struct PanelView: View {
  let model: ClockModel
  @State private var zone: ZoneMode = Settings.zone
  @State private var alerts: Bool = Settings.alerts
  @State private var alertHint = "Desktop alert at each peak / off-peak switch"
  @State private var launchAtLogin = LaunchAtLogin.isEnabled

  init(model: ClockModel) {
    self.model = model
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      header
      if let flip = model.recentFlip {
        flipNotice(flip)
      }
      VStack(alignment: .leading, spacing: 10) {
        HeroCard(model: model)
        TimelineStrip(model: model)
        WindowsTable(model: model)
      }
      .padding(10)
      .background(PanelStyle.surface, in: RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12).strokeBorder(PanelStyle.border.opacity(0.7), lineWidth: 1))

      RatesBlock(model: model)
      alertsRow
      footer
    }
    .padding(12)
    .frame(width: 380)
    .background(PanelStyle.surface)
    .onChange(of: zone) { _, next in
      Settings.zone = next
      model.refreshNow()
    }
    .onAppear {
      // A permission revoked in System Settings must show as off here, not as a
      // switch that silently does nothing.
      alerts = Settings.alerts && Notifier.shared.isAuthorized
      model.setPanelVisible(true)
    }
    .onDisappear { model.setPanelVisible(false) }
  }

  private var header: some View {
    HStack(spacing: 8) {
      Image(nsImage: MenuBarIcon.image(for: model.phase))
        .resizable()
        .frame(width: 22, height: 22)
      VStack(alignment: .leading, spacing: 1) {
        Text("DeepSeek Price Clock")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(PanelStyle.text)
        Text(model.timezoneCaption)
          .font(.system(size: 10))
          .foregroundStyle(PanelStyle.textSoft)
      }
      Spacer(minLength: 4)
      Picker("Timezone", selection: $zone) {
        Text("Local").tag(ZoneMode.local)
        Text("UTC").tag(ZoneMode.utc)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .controlSize(.small)
      .frame(width: 110)
    }
  }

  /// Shown when a flip was just noticed: the panel's own fallback for systems
  /// that will not let a locally signed app post banners.
  private func flipNotice(_ phase: Phase) -> some View {
    HStack(spacing: 6) {
      Image(systemName: phase == .peak ? "arrow.up.right" : "arrow.down.right")
        .font(.system(size: 10, weight: .semibold))
      Text(phase == .peak ? "Peak pricing just started" : "Off-peak just started")
        .font(.system(size: 10, weight: .medium))
      Spacer(minLength: 0)
    }
    .foregroundStyle(PanelStyle.tint(phase))
    .padding(.horizontal, 8)
    .padding(.vertical, 5)
    .background(PanelStyle.background(phase), in: RoundedRectangle(cornerRadius: 6))
  }

  private var alertsRow: some View {
    Toggle(isOn: $alerts) {
      VStack(alignment: .leading, spacing: 1) {
        Text("Notify me when the price flips")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(PanelStyle.text)
        Text(alertHint)
          .font(.system(size: 9))
          .foregroundStyle(PanelStyle.textSoft)
      }
    }
    .toggleStyle(.switch)
    .controlSize(.small)
    .onChange(of: alerts) { _, enabled in
      guard enabled else {
        // Only the user turning it off resets the hint: this handler also runs
        // when the app reverts the switch after a denial, and that explanation
        // has to stay on screen.
        Settings.alerts = false
        return
      }
      guard Notifier.shared.available else {
        alerts = false
        alertHint = "Notifications need the built .app, not a raw build"
        return
      }
      Task {
        let granted = await Notifier.shared.requestAuthorization()
        Settings.alerts = granted
        if !granted {
          alerts = false
          alertHint = "Notification permission was declined"
        }
      }
    }
  }

  private var footer: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 5) {
        legendSwatch(PanelStyle.offSolid, "Green icon = off-peak")
        Text("·").font(.system(size: 9)).foregroundStyle(PanelStyle.textSoft)
        legendSwatch(PanelStyle.peakSolid, "Red icon = peak")
      }
      HStack(spacing: 6) {
        Text("Weekends & CN holidays off-peak")
          .font(.system(size: 9))
          .foregroundStyle(PanelStyle.textSoft)
        Spacer(minLength: 4)
        Link("Full price clock ↗", destination: URL(string: "https://deepakness.com/deepseek/")!)
          .font(.system(size: 9))
          .foregroundStyle(PanelStyle.link)
      }
      HStack(spacing: 8) {
        Toggle("Launch at login", isOn: $launchAtLogin)
          .toggleStyle(.checkbox)
          .font(.system(size: 9))
          .foregroundStyle(PanelStyle.textMuted)
          .onChange(of: launchAtLogin) { _, enabled in
            LaunchAtLogin.set(enabled)
          }
        Spacer(minLength: 4)
        Text(version)
          .font(.system(size: 9))
          .foregroundStyle(PanelStyle.textSoft)
        Button("Quit") { NSApp.terminate(nil) }
          .buttonStyle(.plain)
          .font(.system(size: 9))
          .foregroundStyle(PanelStyle.link)
      }
    }
  }

  private var version: String {
    "v" + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")
  }

  private func legendSwatch(_ color: Color, _ label: String) -> some View {
    HStack(spacing: 3) {
      RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 8, height: 8)
      Text(label).font(.system(size: 9)).foregroundStyle(PanelStyle.textSoft)
    }
  }
}
