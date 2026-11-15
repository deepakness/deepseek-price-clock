# DeepSeek Price Clock for macOS

A menu-bar app that answers one question: is DeepSeek API pricing peak or off-peak
right now, and how long until it flips? Green whale means off-peak (half price), red
whale means peak. Click the whale for the countdown, the 24-hour timeline, the upcoming
price windows and the current rates.

Same brain as the browser extension in the repo root: `price.js` is the source of truth
and the Swift port is checked against it (see [Parity](#parity)).

## Requirements

- macOS 14 or newer
- Xcode 27 (for Swift 6.3)
- Node, only for regenerating the parity fixtures

## Build and install

```sh
cd macos
./build.sh                     # -> build/DeepSeek Price Clock.app
cp -R "build/DeepSeek Price Clock.app" /Applications/
open "/Applications/DeepSeek Price Clock.app"
```

`build.sh` signs the app so its identity stays the same across rebuilds, which is what
keeps the notification permission (and any future launch-at-login registration)
attached to it. It looks for a code signing identity in this order:

1. `DS_SIGN_IDENTITY` if you set it
2. `DeepSeek Price Clock Dev` — create it once in Keychain Access: **Certificate
   Assistant → Create a Certificate**, name it exactly that, Identity Type *Self Signed
   Root*, Certificate Type *Code Signing*
3. Any `Apple Development:` identity already on the machine

If none exist the script stops and prints the recipe.

The dev loop is `swift build && ./.build/debug/DeepSeekPriceClock`. Two caveats for the
raw binary: macOS gives it no notification permissions (see below) and no login-item
registration. Both need the assembled `.app`.

## Tests

```sh
swift test
```

Fifteen tests, and the interesting ones are parity tests: `Tools/gen-vectors.mjs` runs
the real `../price.js` in a node `vm` and writes the fixtures the Swift tests compare
against.

- `Fixtures/validity.json` — phase, next switch, window start and the four upcoming
  windows, sampled every 30 minutes across 2026-08-01 → 2027-01-31 plus every second
  within ±3 s of each switch minute (13,248 samples).
- `Fixtures/segments.json` — the 24-hour bar at four display offsets (`0`, `+480`,
  `-300`, `+345`), each generated in its own node process with `TZ` pinned, because
  `price.js` derives its day start from the machine's local date.
- `Fixtures/rates.json` — the rate table extracted from `popup.html`, so the app's
  prices cannot drift from the extension's.

Regenerate after any change to `price.js` or `popup.html`:

```sh
node Tools/gen-vectors.mjs
git diff --stat Tests/PriceClockCoreTests/Fixtures   # should be empty if nothing changed
```

## Parity

`Sources/PriceClockCore/PriceClock.swift` is a name-for-name port of `price.js`:
`switchMinutes`, `weekendRuleStart`, `cnHolidays`, `offPeakAllDay`, `phase`,
`isSwitchInstant`, `nextSwitches`, `currentWindow`, `currentWindowStart`, `windows`,
`displaySegments`. Keep them in sync. Beijing arithmetic uses a fixed +8 h shift (China
has no DST), never the machine's timezone, which is what makes the fixtures portable.

## Notifications

The popup's "Notify me when the price flips" toggle asks macOS for permission and posts
one banner per flip, with the same wording as the extension.

On some macOS builds `UNUserNotificationCenter` refuses locally signed apps outright
(`UNErrorDomain` code 1, "Notifications are not allowed for this application") — it was
observed here with both an Apple Development and an ad-hoc signature, after LaunchServices
registration, from `/Applications`. When that happens the toggle explains it instead of
pretending, and the panel shows its own "Peak pricing just started" strip for five
minutes after a flip, so the information still reaches you. If banners do work on your
machine, they arrive only while the app is running (it is a menu-bar app, so it is).

## Manual checks with a fake clock

`DEEPSEEK_FAKE_NOW=<epoch ms>` anchors the clock: the app starts at that instant and runs
forward at real speed, so a flip can be watched without touching the system clock.

```sh
# 2026-09-25 inside Mid-Autumn: expect one solid off-peak bar
DEEPSEEK_FAKE_NOW=1790323200000 "/Applications/DeepSeek Price Clock.app/Contents/MacOS/DeepSeekPriceClock"
```

`--snapshot <path> [--dark] [--zone utc|local]` renders the panel to a PNG and exits,
which is handy for looking at a state without a screen to stare at.

## Yearly maintenance

`CN_HOLIDAYS` lives in `price.js`; add the next year's State Council dates there (usually
announced in November), regenerate the fixtures above, and rebuild. The app's copy in
`PriceClock.swift` is checked by the fixtures, so forgetting it fails `swift test`.
