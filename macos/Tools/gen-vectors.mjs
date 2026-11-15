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

if (process.argv[2] === "--validity") {
  process.stdout.write(String(writeValidity()));
} else {
  process.stdout.write(`validity ${writeValidity()}\n`);
}
