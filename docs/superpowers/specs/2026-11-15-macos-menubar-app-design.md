# DeepSeek Price Clock for macOS — design

2026-11-15 · Status: awaiting approval

## Intent and why

The Chrome/Firefox extension answers one question: *is DeepSeek API pricing peak or
off-peak right now, and how long until it flips?* It lives inside a browser, so it is
only visible when the browser is open. A Mac menu-bar app answers the same question
from the menu bar, always on screen, no browser involved.

For one person (the repo owner). Solo means we skip distribution work: no Developer ID,
no notarization, no DMG, no auto-update. The app is built locally and dragged to
`/Applications`.

## Goals

- Menu-bar glyph: the DeepSeek whale, tinted green for off-peak and red for peak, with a
  hover tooltip naming the current window and when it ends.
- Click the glyph: a panel with parity to `popup.html` — live countdown, progress bar,
  24-hour timeline with a "now" marker, upcoming price-window table, current and next
  rates for V4.1 Flash and V4 Pro, Local/UTC toggle, flip-alert toggle.
- Optional desktop notification when the price flips, same wording as the extension.
- Fully offline, zero runtime dependencies, no network calls.
- Logic parity with `price.js`, proven by tests generated from the JavaScript itself.

## Non-goals

- Distribution to other people: signing, notarization, App Store, Sparkle, DMG.
- Countdown text in the menu bar. Colour is the glance signal, as in the toolbar icon.
  Cheap to add later, not now.
- Any new pricing behaviour, network fetch, model list, or cost calculator.
- Replacing the extension. The repo keeps both; the extension stays the primary artefact
  and keeps its flat root layout.

## Anti-goals

These would mean the work failed even if the app runs:

- Two price clocks that disagree. The Swift port must be provably the same function as
  `price.js`, not a reimplementation from the README.
- A menu bar icon redrawn every second, or a 1-second timer that wakes the CPU to do
  nothing but format text.
- A permission prompt on first launch. Notifications are asked for only when the toggle
  is turned on.
- Breaking the extension build. Everything new lives under `macos/`; `RUNTIME_FILES`,
  `manifest.json`, and `node build.mjs` output stay byte-identical.

## Constraints

- Target macOS 14+, Swift 6.3, Xcode 27 (present on this machine). `MenuBarExtra`
  needs 13+, `SMAppService` needs 13+.
- Repo root must remain loadable as an unpacked Chrome extension → no runtime files move;
  the app is a self-contained subtree at `macos/`.
- No `.xcodeproj` in git (unmergeable, GUI-bound). SwiftPM package plus a bundle-assembly
  script, mirroring the repo's `node build.mjs` habit.
- Code signing uses a **self-signed "Code Signing" certificate** created once in Keychain
  Access (Certificate Assistant), so the app's identity is stable across rebuilds and
  Notification Center keeps its authorization. Stable bundle identifier
  `com.deepakness.deepseek-price-clock`. *Superseded during implementation:* the shipped
  build ad-hoc signs by default so no identity is attached to a build, and accepts
  `DS_SIGN_IDENTITY` for a stable identity; see `macos/README.md`.
- China has no DST, which is why `price.js` does its Beijing arithmetic as a fixed +8
  shift on UTC. The Swift port keeps that exact approach so test vectors stay comparable
  and Beijing weekends/holidays are unambiguous. `Calendar`/`TimeZone` is used only for
  *display* formatting.

## Approaches considered

1. **Native SwiftUI `MenuBarExtra` + SwiftPM** — chosen. One small package, no webview,
   no dependencies, ~700 lines. `price.js` ports mechanically because it is pure integer
   date math.
2. **Tauri** — reuses `popup.html/css/js` nearly verbatim behind a Rust shell. Rejected:
   a Rust toolchain and a ~5 MB webview app to draw one small panel, and the timer/notify
   layer would be rewritten in Rust anyway.
3. **Electron tray window** — reuses all web code, ~150 MB resident. Rejected: wrong
   weight for a clock that sits in the menu bar forever.

Build-system alternatives inside approach 1: hand-written `.xcodeproj` (rejected,
unmergeable), XcodeGen (rejected, new dependency), **SwiftPM + `build.sh` assembling the
`.app`** (chosen: reproducible, diffable, one command).

## How it gets built

### Layout

```
macos/
  Package.swift                     executable + library + test targets, macOS 14
  Sources/PriceClockCore/
    PriceClock.swift                port of price.js — pure, no AppKit
    Rates.swift                     model rate table (single source of truth)
  Sources/DeepSeekPriceClock/
    DeepSeekPriceClockApp.swift     @main, MenuBarExtra, NSAppDelegate bits
    ClockModel.swift                @MainActor observable: ticker, phase, strings
    MenuBarIcon.swift               template PNG → tinted NSImage
    PanelView.swift                 popup parity UI
    PanelStyle.swift                colour/typography tokens from popup.css
    Notifier.swift                  UNUserNotificationCenter
    Settings.swift                  UserDefaults: zone, alerts, lastPhase, launchAtLogin
  Tests/PriceClockCoreTests/
    PriceClockTests.swift           golden-vector parity tests
    Fixtures/vectors.json           generated from ../price.js (committed)
  Tools/gen-vectors.mjs             node script that emits vectors.json
  Resources/Info.plist              LSUIElement=1, bundle id, min system version
  build.sh                          swift build -c release → .app → ad-hoc codesign
  README.md                         build, run, notification caveat, parity workflow
```

### Core API (port of `price.js`)

Faithful, name-for-name so the two files can be read side by side:

```swift
public enum Phase: String { case peak, off }

public struct PriceWindow { public let start, end: Date; public let phase: Phase
                            public let isCurrent: Bool }
public struct DaySegment { public let startMinute, endMinute: Double
                           public let phase: Phase }

public enum PriceClock {
  public static let switchMinutes = [60, 240, 360, 600]        // UTC minutes
  public static let weekendRuleStart: Date                     // Sun 2026-08-23 00:00 +08
  public static let cnHolidays: [(from: String, to: String)]   // Beijing date keys
  public static func offPeakAllDay(_ date: Date) -> Bool
  public static func phase(at date: Date) -> Phase
  public static func isSwitchInstant(_ date: Date) -> Bool
  public static func nextSwitches(after: Date, count: Int) -> [(date: Date, phase: Phase)]
  public static func currentWindow(at: Date) -> CurrentWindow  // phase, nextPhase, end, minuteOfDay
  public static func currentWindowStart(at: Date) -> Date
  public static func windows(at: Date, count: Int) -> [PriceWindow]
  public static func displaySegments(at: Date, offsetMinutes: Int) -> [DaySegment]
}
```

Beijing date key (`yyyy-MM-dd`) is produced from `date + 8h` with a UTC-fixed formatter,
matching `beijingDateKey()`; Beijing weekday likewise from the shifted instant.

`displaySegments` needs care. `price.js` derives its day start from the *host machine's*
local date (`new Date(now).getFullYear()` …), so the JS output silently depends on where
it runs. Algebraically it is just "midnight of the display day": with
`shifted = now + offsetMinutes * 60000`,
`dayStart = floorToUTCDay(shifted) - offsetMinutes * 60000`. The Swift port uses that
closed form (pure, no `TimeZone.current`), and `gen-vectors.mjs` runs node once per
fixture offset with `TZ` pinned to a zone at that offset, so the JS and Swift inputs agree
and the committed fixtures are machine-independent. The 16:00 UTC boundary (`960`) that
`displaySegments` adds is not a switch minute — it is kept verbatim; parity tests would
catch its removal.

### UI mapping (popup → SwiftUI)

| popup.html | SwiftUI |
|---|---|
| `.ds-hero` gradient card, `H:MM:SS` countdown | hero VStack, `Text` with `.monospacedDigit()` |
| `.ds-progress-fill` window-elapsed bar | `GeometryReader` + rounded rect at `elapsed/total` |
| `.ds-track` 24h segments + `.ds-now` line | `HStack(spacing: 0)` of flex segments; overlay 1.5 pt rule at `displayMinute/1440` |
| 4-row window table (kind / range / meta) | `Grid` with a kind pill, range, "2h 15m left" |
| rates: now block + next block, 2 models × 3 columns | `Grid` reusing the same shape |
| Local/UTC segmented toggle | `Picker(.segmented)`, persisted in UserDefaults |
| alerts toggle + hint | `Toggle(.switch)` + caption, requests authorization on enable |
| footer legend + link | legend swatches + `Link("Full price clock ↗")` |
| — (new) | footer row: launch-at-login toggle, Quit button, version |

Panel ~380 pt wide, self-sizing height, `.menuBarExtraStyle(.window)` so it behaves like
the popup: click to open, click elsewhere to dismiss.

Time labels use `Date.FormatStyle` with `Locale.current`, mirroring today's
`Intl.DateTimeFormat(undefined, …)`: on a 12-hour en-US system the tooltip and
notification read "Thu, 9:00 AM", not the "Thu 09:00" sketch above. Notification text
always uses system-local time, exactly as `background.js` does, regardless of the panel's
Local/UTC toggle.

Colours come from the CSS custom properties already in `popup.css` (light and dark sets:
`--ds-off-solid #22c55e`, `--ds-peak-solid #ef4444`, surfaces, borders, text). Swift maps
them through a small `Color(light:dark:)` helper built on `NSColor(name:dynamicProvider:)`
so the panel follows system appearance exactly like `prefers-color-scheme` does today.

### Menu bar item

`MenuBarExtra { PanelView() } label: { Image(nsImage: icon(for: model.phase)) }` with the
tinted image rebuilt only when the phase changes, plus `.help(...)` carrying the same
sentence the extension puts in its toolbar title ("DeepSeek: off-peak (half price) until
Thu 09:00").

Icon derivation: `icons/peak16.png` (and `@2x` 32) is loaded with
`isTemplate = true`, then drawn through a tint of the phase colour at 18 pt, producing a
coloured, dark-mode-adapting glyph. The pre-coloured green/red files stay extension-only.

### Ticking

One 1-second `Timer` in `ClockModel` publishes the countdown while the panel is open; when
the panel is closed the timer drops to a 20-second cadence that only asks "did the phase
change?". Phase changes also trigger a wake re-check via
`NSWorkspace.shared.notificationCenter` (`didWakeNotification`), so a laptop that slept
through a switch repaints immediately. No alarms, no background service — a menu-bar app
is already always running.

### Notifications

- Toggle on → `UNUserNotificationCenter.requestAuthorization([.alert, .sound])`; denied or
  granted is stored, and the toggle reverts if denied (hint text like the extension's).
- On each phase recompute: if `lastPhase != current` and `lastPhase` existed and
  `now - currentWindowStart(now) <= 5 min` and alerts are on and authorized → post one
  notification with the extension's exact strings:
  "DeepSeek: peak pricing started"/"Off-peak again <time>" and
  "DeepSeek: off-peak started (half price)"/"Half price until <time>".
- First run records the phase without notifying (parity with `background.js`).

### Build and run

`cd macos && ./build.sh` → `build/DeepSeek Price Clock.app`, then `open` it or drag it to
`/Applications`. The script runs `swift build -c release`, lays out `Contents/MacOS`,
`Contents/Resources` (Info.plist, `AppIcon.icns`, whale PNGs), and ad-hoc signs with the
stable identifier `com.deepakness.deepseek-price-clock`. `swift build && ./build.sh` is the
dev loop; opening `Package.swift` in Xcode works for breakpoints (notifications need the
assembled bundle, so verify those from the `.app`).

### Testing

1. **Parity vectors** (the important one): `node macos/Tools/gen-vectors.mjs` runs
   `price.js` in a `vm` context and writes two committed fixtures:
   - `validity.json` — for each day 2026-08-01 → 2027-01-31 (the August weekend-rule
     start plus the Mid-Autumn and National Day holidays): every 30 minutes, plus every
     second in a ±3 s window around each switch minute. Records `phase`, `nextSwitch`,
     `currentWindowStart`, and `windows(now, 4)`. Roughly 14k samples, ~2 MB, no
     sub-minute rounding can hide a bug.
   - `segments.json` — `displaySegments` sampled at the top of every 4th hour across the
     same range at display offsets `0` (UTC), `+480` (Shanghai), `-300` (US Eastern
     daylight), `+345` (Kathmandu), each generated in its own node run with a pinned `TZ`
     (`UTC`, `Asia/Shanghai`, `Etc/GMT+5`, `Asia/Kathmandu`) so the JS local date and the
     Swift offset agree. A thin grid here is enough: the offsets only
     shift where boundaries land.

   `rates.json` is also generated, extracted from `popup.html`'s `data-off`/`data-peak`
   attributes plus model and column labels, and asserted against `Rates.swift`. That makes
   `popup.html` the single source of truth for prices, so the "two clocks that disagree"
   anti-goal covers the numbers and not just the windows.

   `swift test` compares Swift against all three. Regenerating is the one-line check after
   any pricing change, alongside the yearly `CN_HOLIDAYS` edit.
2. **Manual**: app and extension side by side across a switch minute; Local/UTC toggle;
   a date inside a CN holiday (temporary `DEEPSEEK_FAKE_NOW` env override in the model,
   compiled in but inert unless set); toggle alerts on, get the permission prompt, see a
   flip notification at the next switch.
3. **Regression**: `node build.mjs` still produces the same extension zips (nothing under
   `macos/` is in `RUNTIME_FILES`).

## Risks

1. **Notifications from a locally signed bundle** may still be ignored by Notification
   Center. Mitigation: a stable self-signed identity (see Constraints), stable bundle ID,
   app installed in `/Applications`, a `UNUserNotificationCenter` delegate that logs
   errors; fallback is a README caveat, with an in-panel banner as a follow-up change if
   banners turn out broken.
2. **Menu bar tinting**: PNGs are pre-coloured toolbar art, not template glyphs. Mitigation
   is the template-and-tint path above; if the alpha looks wrong at 18 pt, redraw a
   monochrome whale from `peak32.png`'s alpha with the mask cleaned.
3. **Drift from the extension** when pricing changes. Mitigation: parity fixtures, and the
   yearly `CN_HOLIDAYS` update now touches two files instead of one.

## Left to the builder

- Exact paddings, radii, font sizes, and gradient stops transcribed from `popup.css`.
- Whether launch-at-login ships now or later (footer toggle, default off, `SMAppService`).
- Timer coalescing numbers and whether the idle cadence is 20 s or 60 s.
- App icon (`AppIcon.icns`) derivation from `icons/off128.png`.
- Where the built `.app` is kept locally (`/Applications` recommended in the README).

## Calls made in this document (check these first)

- Build system: SwiftPM + `build.sh`, no `.xcodeproj`.
- Menu bar shows colour only, no countdown text.
- Panel style: `.window` (popover-like), not a drop-down menu.
- Launch-at-login: included as a footer toggle, off by default.
- Notification wording copied verbatim from `background.js`.
- Everything lives in `macos/`; the extension root is untouched.
- Price table single-sourced from `popup.html` and asserted in tests.
- Fixture grid thinned to 30-minute + switch-second sampling; segments sampled separately
  with `TZ` pinned per offset.
- Time labels follow the system locale, like the extension.

## Open question

None. Signing identity decided: a one-time self-signed Code Signing certificate, not
ad-hoc, so each rebuild keeps the same app identity and notification authorization.
