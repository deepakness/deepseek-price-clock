/* Generates the parity fixtures that pin the Swift port to the JavaScript.
   price.js has no exports and its `const`s never reach the context global, so
   the source is evaluated with an appended accessor and read back off the
   context. Run with no arguments to regenerate every fixture. */
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const macos = path.resolve(here, "..");
const repo = path.resolve(macos, "..");
const fixtures = path.join(macos, "Tests/PriceClockCoreTests/Fixtures");

const RANGE_START = 1785542400000; // 2026-08-01T00:00:00Z
const RANGE_END = 1801440000000; // 2027-02-01T00:00:00Z
const DAY = 86400000;

// offsetMinutes -> a zone whose offset is exactly that, so node's local date
// (which price.js uses for displaySegments' day start) matches the offset the
// Swift port is handed.
const OFFSET_ZONES = [
  [0, "UTC"],
  [480, "Asia/Shanghai"],
  [-300, "Etc/GMT+5"],
  [345, "Asia/Kathmandu"],
];

function loadPriceJs() {
  const source = fs.readFileSync(path.join(repo, "price.js"), "utf8");
  const accessor =
    "\nthis.__api = { kindAtInstant, nextSwitches, currentWindowStart, " +
    "windowList, displaySegments, SWITCH_MINUTES, WEEKEND_RULE_START };";
  const context = vm.createContext({ Date, console });
  vm.runInContext(source + accessor, context);
  return context.__api;
}

function writeJson(name, data) {
  fs.mkdirSync(fixtures, { recursive: true });
  fs.writeFileSync(path.join(fixtures, name), JSON.stringify(data));
}

// Every 30 minutes, plus every second within ±3 s of each switch minute, so no
// sub-minute rounding can hide a bug at a boundary.
function sampleInstants(switchMinutes) {
  const seen = new Set();
  for (let t = RANGE_START; t < RANGE_END; t += 30 * 60000) seen.add(t);
  for (let day = 0; RANGE_START + day * DAY < RANGE_END; day++) {
    for (const minute of switchMinutes) {
      const at = RANGE_START + day * DAY + minute * 60000;
      for (const delta of [-3000, -2000, -1000, 0, 1000, 2000, 3000]) {
        seen.add(at + delta);
      }
    }
  }
  return [...seen].sort((a, b) => a - b);
}

function writeValidity() {
  const api = loadPriceJs();
  const cases = sampleInstants(api.SWITCH_MINUTES).map((t) => {
    const now = new Date(t);
    const next = api.nextSwitches(now, 1)[0];
    return {
      t,
      phase: api.kindAtInstant(now),
      next: { t: next.date.getTime(), phase: next.kind },
      start: api.currentWindowStart(now).getTime(),
      windows: api.windowList(now, 4).map((window) => ({
        start: window.start.getTime(),
        end: window.end.getTime(),
        phase: window.kind,
        current: window.current,
      })),
    };
  });
  writeJson("validity.json", {
    switchMinutes: api.SWITCH_MINUTES,
    weekendRuleStartMs: api.WEEKEND_RULE_START,
    cases,
  });
  return cases.length;
}

// Segments are generated one offset per process: price.js derives its day start
// from the machine's local date, so TZ must equal the offset being sampled.
function writeSegments(offset) {
  const api = loadPriceJs();
  const cases = [];
  for (let t = RANGE_START; t < RANGE_END; t += 4 * 3600000) {
    cases.push({
      t,
      offset,
      segments: api.displaySegments(new Date(t), offset).map((segment) => ({
        start: segment.start,
        end: segment.end,
        phase: segment.kind,
      })),
    });
  }
  const file = path.join(fixtures, "segments.json");
  let existing = { cases: [] };
  if (fs.existsSync(file)) existing = JSON.parse(fs.readFileSync(file, "utf8"));
  writeJson("segments.json", { cases: existing.cases.concat(cases) });
  return cases.length;
}

function writeAllSegments() {
  const file = path.join(fixtures, "segments.json");
  fs.rmSync(file, { force: true });
  let total = 0;
  for (const [offset, zone] of OFFSET_ZONES) {
    execFileSync(process.execPath, [fileURLToPath(import.meta.url), "--segments", String(offset)], {
      env: { ...process.env, TZ: zone },
      stdio: "inherit",
    });
    total += 1;
  }
  const data = JSON.parse(fs.readFileSync(file, "utf8"));
  return `${data.cases.length} cases across ${total} offsets`;
}

// popup.html is the single source of truth for prices: the app's rate table is
// asserted against this extraction rather than retyped from the docs.
function writeRates() {
  const html = fs.readFileSync(path.join(repo, "popup.html"), "utf8");
  const start = html.indexOf('<div class="ds-rates-now">');
  const end = html.indexOf('<div class="ds-rates-next">');
  if (start < 0 || end < start) throw new Error("could not find the rates-now block");
  const block = html.slice(start, end);

  const columns = [...block.matchAll(/<span class="ds-rate-kind"[^>]*>([^<]+)<\/span>/g)].map((m) =>
    m[1].trim()
  );
  const names = [...block.matchAll(/<p class="ds-rate-name">([^<]+)<\/p>/g)].map((m) => m[1].trim());
  const amounts = [...block.matchAll(/data-off="([^"]*)" data-peak="([^"]*)"/g)].map((m) => ({
    off: m[1],
    peak: m[2],
  }));
  const perModel = amounts.length / names.length;
  const models = names.map((name, index) => ({
    name,
    rates: amounts.slice(index * perModel, (index + 1) * perModel),
  }));
  writeJson("rates.json", { columns, models });
  return `${models.length} models × ${perModel} columns`;
}

if (process.argv[2] === "--segments") {
  process.stdout.write(String(writeSegments(Number(process.argv[3]))));
} else if (process.argv[2] === "--validity") {
  process.stdout.write(String(writeValidity()));
} else {
  process.stdout.write(`validity ${writeValidity()}\n`);
  process.stdout.write(`segments ${writeAllSegments()}\n`);
  process.stdout.write(`rates ${writeRates()}\n`);
}
