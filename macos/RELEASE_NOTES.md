The DeepSeek Price Clock as a native Mac menu-bar app. A green whale in the menu bar means off-peak (half price), a red whale means peak. Click it for the live countdown, the 24-hour timeline, the upcoming price windows and the current Flash/Pro rates.

> [!WARNING]
> **Experimental.** This is the first release of the Mac app, contributed by the community. It has automated tests against the extension's pricing logic, but it has not been tried on many Macs yet, so you may run into issues. If something looks wrong, please [open an issue](https://github.com/deepakness/deepseek-price-clock/issues/new) with your macOS version and what you saw.

**Requires** macOS 14 (Sonoma) or newer on an Apple Silicon Mac (M1 or later).

### Install

1. Download `DeepSeek-Price-Clock-macOS.zip` below and double-click it to unzip.
2. Drag **DeepSeek Price Clock.app** into your **Applications** folder.
3. Open it. macOS blocks it the first time because the app is not notarized by Apple. Go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**. Or run once in Terminal:
   ```sh
   xattr -dr com.apple.quarantine "/Applications/DeepSeek Price Clock.app"
   ```
4. Look for the whale in the menu bar at the top right. The app has no Dock icon.

### Features

- Green/red menu-bar whale for off-peak and peak
- Countdown, 24-hour timeline, upcoming windows and rates, in local time or UTC
- Optional notification when the price flips (macOS asks for permission the first time)
- Launch at login
- Fully offline, with no network calls

To uninstall, untick **Launch at login**, click **Quit** in the panel, and move the app to the Trash.

The browser extension for Chrome and Firefox is in the [latest extension release](https://github.com/deepakness/deepseek-price-clock/releases/latest).
