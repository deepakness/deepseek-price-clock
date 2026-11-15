# DeepSeek Price Clock for macOS

A menu-bar app that answers one question: is DeepSeek API pricing peak or off-peak
right now, and how long until it flips? Green whale means off-peak (half price), red
whale means peak. Click the whale for the countdown, the 24-hour timeline, the upcoming
price windows and the current rates.

Same brain as the browser extension in the repo root: `price.js` is the source of truth
and the Swift port is checked against it (see [Parity](#parity)).

> [!IMPORTANT]
> **This app is unsigned.** It is ad-hoc signed, not notarized by Apple, so Gatekeeper
> has no idea who made it. Built on the machine that runs it, that is fine. Copied from
> another machine, downloaded as a zip, or sent through AirDrop, macOS will refuse to
> open it ("can't be opened because Apple cannot check it for malicious software" or
> "is damaged and can't be opened") until you clear the quarantine flag:
>
> ```sh
> xattr -dr com.apple.quarantine "/Applications/DeepSeek Price Clock.app"
> ```
>
> Or: System Settings → Privacy & Security → scroll down → **Open Anyway**. Neither
> action makes the app trusted, they just let it run once; a rebuilt app may ask again.
> If you want the warning gone for good you need your own Developer ID certificate and
> a notarization round trip, which this repo deliberately does not do.

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

`build.sh` ad-hoc signs the app (`codesign -s -`): no certificate, no identity, and it
runs fine from `/Applications` on the Mac that built it. The catch is that an ad-hoc
signature changes on every rebuild, so macOS treats each build as a different app and the
notification permission (and the login-item registration) resets.

If you want a stable identity instead — the app keeps its permissions across rebuilds —
create one once in Keychain Access (**Certificate Assistant → Create a Certificate**, name
it whatever you like, Identity Type *Self Signed Root*, Certificate Type *Code Signing*)
and pass it to the script:

```sh
DS_SIGN_IDENTITY="DeepSeek Price Clock Dev" ./build.sh
```

An `Apple Development:` identity works too, if you have one. Nothing in the repo assumes
either, and no certificate or team identifier is baked into the build.

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

Two things can stop a banner:

1. **Gatekeeper-adjacent refusal.** On some macOS builds `UNUserNotificationCenter`
   rejects unsigned apps outright (`UNErrorDomain` code 1, "Notifications are not allowed
   for this application"). It reproduces with ad-hoc and with developer signatures, after
   LaunchServices registration, from `/Applications`.
2. **The ad-hoc rebuild trap.** An ad-hoc signature changes every build, so even where
   banners do work, a rebuild can leave you with a permission granted to a binary that no
   longer exists. A stable identity (`DS_SIGN_IDENTITY`) avoids this one.

When permission is unavailable the toggle says so instead of pretending, and the panel
shows its own "Peak pricing just started" strip for five minutes after a flip, so the
information still reaches you. Banners, where they work, arrive only while the app is
running — it is a menu-bar app, so it is.

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
