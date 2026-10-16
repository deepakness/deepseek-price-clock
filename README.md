# DeepSeek Price Clock

Chrome extension (Manifest V3) that shows DeepSeek API pricing at a glance. The toolbar icon shows the DeepSeek whale on green during off-peak (half price) and on red during peak, so one look tells you whether to run the job now or queue it for the cheap window.

<!-- Replace these placeholders with real screenshots: open this README on GitHub, click the pencil icon, and drag your images onto these lines. GitHub uploads and rewrites the URLs for you. -->
![Toolbar icon showing green for off-peak and red for peak](https://via.placeholder.com/640x160?text=Drag+screenshot+1+here+-+toolbar+icons)
![Popup with live countdown, price windows, and rates](https://via.placeholder.com/380x560?text=Drag+screenshot+2+here+-+popup)

## What you get

- Green icon = off-peak (half price), red icon = peak. Hover shows when the window flips.
- Popup with a live countdown, 24-hour price timeline, upcoming window schedule, and current Flash/Pro rates.
- Local/UTC toggle. Weekends and Chinese public holidays are off-peak all day.
- Fully offline. No host permissions, no network calls.

## Install in Chrome

1. Download this repo (`Code` → `Download ZIP`) and unzip it, or `git clone` it.
2. Open `chrome://extensions` in Chrome.
3. Turn on **Developer mode** (toggle in the top-right corner).
4. Click **Load unpacked** and select the `deepseek-price-clock` folder.
5. Click the puzzle-piece icon in the toolbar and pin **DeepSeek Price Clock** so the icon stays visible.

To update later, pull the latest code and click the reload icon on the extension card in `chrome://extensions`.

## How it works

- `price.js` holds the peak/off-peak logic (UTC windows, Beijing weekends, CN holidays). It is ported from [deepakness.com/deepseek](https://deepakness.com/deepseek/) — keep the two in sync.
- `background.js` recomputes the window on an alarm tick and swaps the toolbar icon.
- `popup.html` / `popup.css` / `popup.js` render the countdown, timeline, schedule, and rates.

`CN_HOLIDAYS` in `price.js` needs the next year's Chinese public holidays once the State Council announces them (usually November).
