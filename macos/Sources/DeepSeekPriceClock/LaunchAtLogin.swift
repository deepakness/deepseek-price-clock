/* Login item registration. SMAppService keeps the registration tied to the app's
   signature, so it only works for the assembled, signed bundle. */

import Foundation
import ServiceManagement

enum LaunchAtLogin {
  static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

  static func set(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      // Logged, not thrown: a failed registration must not break the panel.
      NSLog("DeepSeek Price Clock: launch at login failed — %@", error.localizedDescription)
    }
  }
}
