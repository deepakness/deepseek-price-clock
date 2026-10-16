/* DeepSeek peak/off-peak price logic. Ported from deepakness.com/deepseek —
   keep the two in sync (SWITCH_MINUTES, WEEKEND_RULE_START, CN_HOLIDAYS). */

// Peak window switch instants in UTC minutes-of-day: 01:00 and 06:00 open
// a peak window, 04:00 and 10:00 close one. Everything else is off-peak.
const SWITCH_MINUTES = [60, 240, 360, 600];

// Since 00:00 Beijing time on Sunday August 23, 2026 (16:00 UTC Saturday
// August 22) the split only applies Monday to Friday Beijing time.
const WEEKEND_RULE_START = Date.UTC(2026, 7, 22, 16);

// Chinese public holidays from the State Council's yearly arrangement, as
// Beijing dates. DeepSeek bills them off-peak all day. Add the next year's
// dates once announced (usually November).
const CN_HOLIDAYS = [
  ["2026-09-25", "2026-09-27"], // Mid-Autumn
  ["2026-10-01", "2026-10-07"], // National Day
];

function isBeijingWeekend(date) {
  const beijing = new Date(date.getTime() + 8 * 3600000);
  return beijing.getUTCDay() === 0 || beijing.getUTCDay() === 6;
}

function beijingDateKey(date) {
  return new Date(date.getTime() + 8 * 3600000).toISOString().slice(0, 10);
}

function isBeijingHoliday(date) {
  const key = beijingDateKey(date);
  for (const [from, to] of CN_HOLIDAYS) {
    if (key >= from && key <= to) return true;
  }
  return false;
}

// A Saturday, Sunday or public holiday under the new rules is
// off-peak all day.
function offPeakAllDay(date) {
  return (
    date.getTime() >= WEEKEND_RULE_START &&
    (isBeijingWeekend(date) || isBeijingHoliday(date))
  );
}

// Which half of the pricing an instant falls in.
function kindAtInstant(date) {
  if (offPeakAllDay(date)) return "off";
  const minuteOfDay = date.getUTCHours() * 60 + date.getUTCMinutes();
  return (minuteOfDay >= 60 && minuteOfDay < 240) ||
    (minuteOfDay >= 360 && minuteOfDay < 600)
    ? "peak"
    : "off";
}

// A switch minute is a real price change only outside gated weekends/holidays.
function isSwitchInstant(date) {
  const minuteOfDay = date.getUTCHours() * 60 + date.getUTCMinutes();
  for (const m of SWITCH_MINUTES) {
    if (minuteOfDay === m) return !offPeakAllDay(date);
  }
  return false;
}

// The next N price changes as absolute instants.
function nextSwitches(now, count) {
  const dayStart = Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate()
  );
  const out = [];
  let day = 0;
  let index = 0;
  while (out.length < count) {
    const instant = dayStart + day * 86400000 + SWITCH_MINUTES[index] * 60000;
    const candidate = new Date(instant);
    if (instant > now.getTime() && isSwitchInstant(candidate)) {
      out.push({ date: candidate, kind: kindAtInstant(candidate) });
    }
    index++;
    if (index >= SWITCH_MINUTES.length) {
      index = 0;
      day++;
    }
  }
  return out;
}

function nextSwitch(now) {
  return nextSwitches(now, 1)[0];
}

// Current window plus the instant it ends.
function currentWindow(now) {
  const next = nextSwitch(now);
  return {
    kind: kindAtInstant(now),
    nextKind: next.kind,
    end: next.date,
    minuteOfDay: now.getUTCHours() * 60 + now.getUTCMinutes(),
  };
}

// The instant the window you're in began. Walks back up to 21 days to cross
// any weekend + holiday off-peak stretch.
function currentWindowStart(now) {
  const dayStart = Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate()
  );
  let best = null;
  for (let day = -21; day <= 0; day++) {
    for (let i = 0; i < SWITCH_MINUTES.length; i++) {
      const instant = dayStart + day * 86400000 + SWITCH_MINUTES[i] * 60000;
      const candidate = new Date(instant);
      if (
        instant <= now.getTime() &&
        isSwitchInstant(candidate) &&
        (best === null || instant > best.getTime())
      ) {
        best = candidate;
      }
    }
  }
  return best || new Date(now.getTime() - 86400000);
}

// A list of windows as start/end pairs, opening with the active window.
function windowList(now, count) {
  const upcoming = nextSwitches(now, count);
  let start = currentWindowStart(now);
  let kind = kindAtInstant(now);
  const out = [];
  for (let i = 0; i < count; i++) {
    out.push({
      start,
      end: upcoming[i].date,
      kind,
      current: i === 0,
    });
    start = upcoming[i].date;
    kind = upcoming[i].kind;
  }
  return out;
}

// Rebuild the 24-hour day bar in display time (offsetMinutes ahead of UTC).
function displaySegments(now, offsetMinutes) {
  const dayStart =
    offsetMinutes === 0
      ? Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())
      : Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()) -
        offsetMinutes * 60000;

  const boundaries = [0, 1440];
  for (const m of SWITCH_MINUTES) {
    boundaries.push(((m + offsetMinutes) % 1440 + 1440) % 1440);
  }
  boundaries.push(((960 + offsetMinutes) % 1440 + 1440) % 1440);
  boundaries.sort((a, b) => a - b);

  const raw = [];
  for (let i = 0; i < boundaries.length - 1; i++) {
    const start = boundaries[i];
    const end = boundaries[i + 1];
    if (end <= start) continue;
    const sample = new Date(dayStart + (start + 0.5) * 60000);
    raw.push({ start, end, kind: kindAtInstant(sample) });
  }

  const merged = [];
  for (const segment of raw) {
    const last = merged[merged.length - 1];
    if (last && last.kind === segment.kind) {
      last.end = segment.end;
    } else {
      merged.push({ ...segment });
    }
  }
  return merged;
}
