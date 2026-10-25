# Repository Guidelines

## Project Structure

DeepSeek Price Clock is a Manifest V3 extension for Chrome and Firefox with no runtime dependencies and no network access.

- `manifest.json`: shared manifest. The repo root must stay loadable as an unpacked Chrome extension, so keep runtime files at the root.
- `price.js`: peak/off-peak logic (UTC windows, Beijing weekends, `CN_HOLIDAYS`). Ported from deepakness.com/deepseek; keep `SWITCH_MINUTES`, `WEEKEND_RULE_START`, and `CN_HOLIDAYS` in sync with it.
- `background.js`: alarm ticks, toolbar icon and title, flip notifications. Chrome runs it as a service worker (`importScripts("price.js")`); Firefox runs it as a background script with `price.js` loaded first from the manifest.
- `popup.html`, `popup.css`, `popup.js`: popup UI.
- `icons/`: `off*` (green) and `peak*` (red) toolbar icons.
- `platforms/firefox.json`: top-level manifest keys merged over `manifest.json` for Firefox (background scripts, add-on ID, data collection declaration).
- `build.mjs`: writes `dist/chrome/`, `dist/firefox/`, and a zip of each. Update `RUNTIME_FILES` when adding a runtime file.
- `sign-firefox.sh`: signs the Firefox build with Mozilla and attaches the `.xpi` to the GitHub release.
- `.github/workflows/release.yml`: builds both zips and creates the release when a version tag is pushed.

## Firefox Add-on ID

The Firefox ID is `deepseek-clock@deepakness.com`. Never change it: installed copies update in place only under the same ID, and Mozilla never lets an ID be reused. The first choice, `deepseek-price-clock@deepakness.com`, was already registered on Mozilla's side and could not be signed, which is why the ID differs from the repo name.

## Build and Test

There is no `package.json` or test runner. Builds need Node and the system `zip` command.

- `node build.mjs` builds both browsers; `node build.mjs firefox` builds one.
- `npx web-ext lint --source-dir dist/firefox` must report no errors before signing.
- Chrome: **Load unpacked** on the repo root (or `dist/chrome`), then reload after edits.
- Firefox: `about:debugging#/runtime/this-firefox` → **Load Temporary Add-on** → `dist/firefox/manifest.json`.
- Check the icon colour and hover title, the popup countdown and timeline, the Local/UTC toggle, and turning flip notifications on and off in both browsers.

Keep code browser-neutral. `chrome.*` APIs work in both browsers; put browser differences in `platforms/firefox.json` rather than forking files. The notifications permission request in `popup.js` must stay synchronous inside the click handler, before any `await`, or Firefox rejects it.

## Release

1. Bump `version` in `manifest.json` and commit.
2. Push a matching tag: `git tag vX.Y.Z && git push origin vX.Y.Z`. The workflow fails if the tag and manifest version differ.
3. Wait for the Release workflow to create the GitHub release with `deepseek-price-clock-chrome.zip` and `deepseek-price-clock-firefox.zip`.
4. Run `./sign-firefox.sh`. It reads AMO API keys from the macOS Keychain, has Mozilla sign the build as unlisted (self-distributed, not on addons.mozilla.org), and attaches `deepseek-price-clock-firefox.xpi` to the release.
5. Write short release notes with `gh release edit`.

Mozilla signs each version only once. If a signed build needs a fix, bump the version and release again. Asset file names carry no version so the README's `releases/latest/download/...` links keep working.

## Yearly Maintenance

Add the next year's Chinese public holidays to `CN_HOLIDAYS` in `price.js` once the State Council announces them (usually November), mirror the change on deepakness.com/deepseek, and release a new version.

## Coding Style and Commits

JavaScript uses double quotes, semicolons, 2-space indentation, and short comments that explain why. Commit messages are short imperative summaries; release commits end with the version, e.g. `Add optional flip notifications with popup toggle (v1.1.0)`.

## Security

- Never commit API keys, `.env` files, `dist/`, or signed `.xpi` files. Keys live only in the maintainer's Keychain (or, optionally, the `AMO_JWT_ISSUER` and `AMO_JWT_SECRET` repo secrets the workflow can use).
- Keep the extension offline: no host permissions, analytics, remote code, or network calls without an explicit product decision. The Firefox manifest declares that no data is collected.
