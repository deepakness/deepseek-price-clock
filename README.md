# DeepSeek Price Clock

Chrome and Firefox extension (Manifest V3) that shows DeepSeek API pricing at a glance. The toolbar icon shows the DeepSeek whale on green during off-peak (half price) and on red during peak, so one look tells you whether to run the job now or queue it for the cheap window.

<img width="363" height="134" alt="Toolbar icon: green whale for off-peak, red whale for peak" src="https://github.com/user-attachments/assets/c7245722-88d9-4473-bc2b-82cdc9695522" />

<img width="607" height="754" alt="Popup showing live countdown, 24-hour timeline, price windows, and rates" src="https://github.com/user-attachments/assets/ef7ed554-534c-4308-9b9b-71c63c72b93f" />

## What you get

- Green icon = off-peak (half price), red icon = peak. Hover shows when the window flips.
- Popup with a live countdown, 24-hour price timeline, upcoming window schedule, and current Flash/Pro rates (input, cached input, output).
- Local/UTC toggle. Weekends and Chinese public holidays are off-peak all day.
- Optional desktop notification when the price flips between peak and off-peak. Turn it on with the toggle in the popup; the browser asks for the notifications permission the first time.
- Fully offline. No host permissions, no network calls.

> [!IMPORTANT]
> **Not seeing flip notifications?** Your OS has to allow your browser to show them, and the browser has to be running at the flip.
> - **macOS:** System Settings → Notifications → Google Chrome (or Firefox) → turn on **Allow notifications** (often off by default). Focus / Do Not Disturb hides banners.
> - **Windows:** Settings → System → Notifications → turn on **Google Chrome** (or **Firefox**). Focus / Do Not Disturb hides banners. To get alerts with all Chrome windows closed, enable **Continue running background apps when Google Chrome is closed** in `chrome://settings/system`.
> - **Linux:** depends on your desktop's notification settings; make sure the browser isn't muted and Do Not Disturb is off.

## Install in Chrome

1. Download [`deepseek-price-clock-chrome.zip`](https://github.com/deepakness/deepseek-price-clock/releases/latest/download/deepseek-price-clock-chrome.zip) from the latest release and unzip it. You get a folder named `deepseek-price-clock`.
2. Move that folder somewhere it can stay, such as `Documents`. Chrome loads the extension from it, so moving or deleting it breaks the extension.
3. Open `chrome://extensions` in Chrome and turn on **Developer mode** (toggle in the top-right corner).
4. Click **Load unpacked** and select the `deepseek-price-clock` folder.
5. Click the puzzle-piece icon in the toolbar and pin **DeepSeek Price Clock** so the icon stays visible.

To update, download the newer zip from [Releases](https://github.com/deepakness/deepseek-price-clock/releases), replace the old `deepseek-price-clock` folder with the new one in the same place, and click the reload icon on the extension card in `chrome://extensions`. Keeping the same location keeps your settings, because Chrome identifies an unpacked extension by its folder path.

To run the latest unreleased code instead, `git clone https://github.com/deepakness/deepseek-price-clock.git`, load the cloned folder the same way, and `git pull` to update.

## Install in Firefox

1. Download [`deepseek-price-clock-firefox.xpi`](https://github.com/deepakness/deepseek-price-clock/releases/latest/download/deepseek-price-clock-firefox.xpi) from the latest release.
2. Open the file in Firefox (drag it into a window, or use **File → Open File**) and click **Add**.
3. Pin **DeepSeek Price Clock** from the extensions (puzzle-piece) menu in the toolbar.

The `.xpi` is signed by Mozilla for self-distribution, so it stays installed across restarts. It is not listed on addons.mozilla.org and does not update itself. To update, download the newer `.xpi` from [Releases](https://github.com/deepakness/deepseek-price-clock/releases) and open it again. Needs Firefox 140 or newer.

If a release has no `.xpi` yet, unzip `deepseek-price-clock-firefox.zip` from it, open `about:debugging#/runtime/this-firefox`, click **Load Temporary Add-on**, and pick `manifest.json`. Firefox removes temporary add-ons when it restarts.

## How it works

- `price.js` holds the peak/off-peak logic (UTC windows, Beijing weekends, CN holidays). It is ported from [deepakness.com/deepseek](https://deepakness.com/deepseek/) — keep the two in sync.
- `background.js` recomputes the window on an alarm tick, swaps the toolbar icon, and sends the flip notification when alerts are on.
- `popup.html` / `popup.css` / `popup.js` render the countdown, timeline, schedule, and rates.
- The repo root loads as-is in Chrome. `node build.mjs` writes `dist/chrome/` and `dist/firefox/` plus a zip for each; `platforms/firefox.json` holds the Firefox-only manifest keys (background scripts instead of a service worker, and the add-on ID `deepseek-clock@deepakness.com`, which must never change).

`CN_HOLIDAYS` in `price.js` needs the next year's Chinese public holidays once the State Council announces them (usually November).

## Release

1. Bump `version` in `manifest.json`, commit, and push.
2. Tag and push: `git tag v1.3.1 && git push origin v1.3.1` (the tag must match the version).
3. The [Release workflow](.github/workflows/release.yml) builds both browsers and attaches `deepseek-price-clock-chrome.zip` and `deepseek-price-clock-firefox.zip` to a new GitHub release.
4. Run `./sign-firefox.sh` locally. It has Mozilla sign the Firefox build as an unlisted add-on and attaches `deepseek-price-clock-firefox.xpi` to the same release. It reads [AMO API keys](https://addons.mozilla.org/developers/addon/api/key/) from the macOS Keychain; the top of the script shows how to store them. Mozilla signs each version only once.

## License

[MIT](LICENSE)
