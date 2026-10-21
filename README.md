# DeepSeek Price Clock

Chrome extension (Manifest V3) that shows DeepSeek API pricing at a glance. The toolbar icon shows the DeepSeek whale on green during off-peak (half price) and on red during peak, so one look tells you whether to run the job now or queue it for the cheap window.

<img width="363" height="134" alt="Toolbar icon: green whale for off-peak, red whale for peak" src="https://github.com/user-attachments/assets/c7245722-88d9-4473-bc2b-82cdc9695522" />

<img width="607" height="754" alt="Popup showing live countdown, 24-hour timeline, price windows, and rates" src="https://github.com/user-attachments/assets/ef7ed554-534c-4308-9b9b-71c63c72b93f" />

## What you get

- Green icon = off-peak (half price), red icon = peak. Hover shows when the window flips.
- Popup with a live countdown, 24-hour price timeline, upcoming window schedule, and current Flash/Pro rates (input, cached input, output).
- Local/UTC toggle. Weekends and Chinese public holidays are off-peak all day.
- Optional desktop notification when the price flips between peak and off-peak. Turn it on with the toggle in the popup; Chrome asks for the notifications permission the first time.
- Fully offline. No host permissions, no network calls.

> [!IMPORTANT]
> **Not seeing flip notifications?** Your OS has to allow Chrome to show them, and Chrome has to be running at the flip.
> - **macOS:** System Settings → Notifications → Google Chrome → turn on **Allow notifications** (often off by default). Focus / Do Not Disturb hides banners.
> - **Windows:** Settings → System → Notifications → turn on **Google Chrome**. Focus / Do Not Disturb hides banners. To get alerts with all Chrome windows closed, enable **Continue running background apps when Google Chrome is closed** in `chrome://settings/system`.
> - **Linux:** depends on your desktop's notification settings; make sure Chrome isn't muted and Do Not Disturb is off.

## Install in Chrome

1. [Download this repo as a ZIP](https://github.com/deepakness/deepseek-price-clock/archive/refs/heads/main.zip) and unzip it, or `git clone https://github.com/deepakness/deepseek-price-clock.git`.
2. Open `chrome://extensions` in Chrome.
3. Turn on **Developer mode** (toggle in the top-right corner).
4. Click **Load unpacked** and select the unzipped folder (`deepseek-price-clock-main` if you used the ZIP).
5. Click the puzzle-piece icon in the toolbar and pin **DeepSeek Price Clock** so the icon stays visible.

To update later, re-download the ZIP (or `git pull`) and click the reload icon on the extension card in `chrome://extensions`.

## How it works

- `price.js` holds the peak/off-peak logic (UTC windows, Beijing weekends, CN holidays). It is ported from [deepakness.com/deepseek](https://deepakness.com/deepseek/) — keep the two in sync.
- `background.js` recomputes the window on an alarm tick, swaps the toolbar icon, and sends the flip notification when alerts are on.
- `popup.html` / `popup.css` / `popup.js` render the countdown, timeline, schedule, and rates.

`CN_HOLIDAYS` in `price.js` needs the next year's Chinese public holidays once the State Council announces them (usually November).
