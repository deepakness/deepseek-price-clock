#!/usr/bin/env bash
# Builds the Firefox package, has Mozilla sign it as an unlisted
# (self-distributed) add-on, and attaches the signed .xpi to the GitHub
# release for the current manifest version.
#
# AMO API keys are read from the macOS Keychain. Store them once with:
#   security add-generic-password -a "$USER" -s amo-jwt-issuer -w
#   security add-generic-password -a "$USER" -s amo-jwt-secret -w
# (each command prompts for the value, so it never lands in shell history)
set -euo pipefail
cd "$(dirname "$0")"

version=$(node -p "require('./manifest.json').version")
tag="v$version"
xpi="dist/deepseek-price-clock-firefox.xpi"

if ! gh release view "$tag" > /dev/null 2>&1; then
  echo "No GitHub release $tag yet. Push the tag first: git tag $tag && git push origin $tag"
  exit 1
fi

WEB_EXT_API_KEY=$(security find-generic-password -a "$USER" -s amo-jwt-issuer -w) || {
  echo "AMO key not found in Keychain (service amo-jwt-issuer). See the top of this script."
  exit 1
}
WEB_EXT_API_SECRET=$(security find-generic-password -a "$USER" -s amo-jwt-secret -w) || {
  echo "AMO secret not found in Keychain (service amo-jwt-secret). See the top of this script."
  exit 1
}
export WEB_EXT_API_KEY WEB_EXT_API_SECRET

node build.mjs firefox
npx --yes web-ext@8 lint --source-dir dist/firefox
rm -rf dist/signed
npx --yes web-ext@8 sign --channel unlisted --source-dir dist/firefox --artifacts-dir dist/signed
mv dist/signed/*.xpi "$xpi"

gh release upload "$tag" "$xpi" --clobber
echo "Signed $xpi and attached it to release $tag"
