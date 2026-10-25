// Builds one folder and zip per browser into dist/.
// Usage: node build.mjs [chrome] [firefox]  (no args builds both)
//
// The repo root stays loadable as an unpacked Chrome extension. The build
// copies the runtime files and merges platforms/<browser>.json over the
// top-level keys of manifest.json.
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";

const ALL_TARGETS = ["chrome", "firefox"];
const RUNTIME_FILES = ["background.js", "price.js", "popup.html", "popup.css", "popup.js", "icons"];
const NAME = "deepseek-price-clock";

const targets = process.argv.length > 2 ? process.argv.slice(2) : ALL_TARGETS;
const base = JSON.parse(readFileSync("manifest.json", "utf8"));

for (const browser of targets) {
  if (!ALL_TARGETS.includes(browser)) {
    throw new Error(`Unknown target "${browser}". Use one of: ${ALL_TARGETS.join(", ")}`);
  }

  const out = `dist/${browser}`;
  rmSync(out, { recursive: true, force: true });
  mkdirSync(out, { recursive: true });
  for (const file of RUNTIME_FILES) {
    cpSync(file, `${out}/${file}`, { recursive: true });
  }

  const overridePath = `platforms/${browser}.json`;
  const override = existsSync(overridePath) ? JSON.parse(readFileSync(overridePath, "utf8")) : {};
  writeFileSync(`${out}/manifest.json`, `${JSON.stringify({ ...base, ...override }, null, 2)}\n`);

  // No version in the file name, so releases/latest/download/<file> links stay stable.
  const zip = `${NAME}-${browser}.zip`;
  rmSync(`dist/${zip}`, { force: true });
  if (browser === "chrome") {
    // Chrome users unzip and load the folder, so wrap the files in one
    // named folder. Firefox must stay flat: AMO signs a zip with
    // manifest.json at its root.
    const stage = "dist/.stage";
    rmSync(stage, { recursive: true, force: true });
    cpSync(out, `${stage}/${NAME}`, { recursive: true });
    execFileSync("zip", ["-qrX", `../${zip}`, NAME, "-x", "*.DS_Store"], { cwd: stage });
    rmSync(stage, { recursive: true, force: true });
  } else {
    execFileSync("zip", ["-qrX", `../${zip}`, ".", "-x", ".DS_Store", "*/.DS_Store"], { cwd: out });
  }
  console.log(`built dist/${zip} (v${base.version})`);
}
