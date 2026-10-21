/* Popup UI: mirrors deepakness.com/deepseek with live countdown, 24h timeline
   bar, upcoming window schedule, Local/UTC toggle, and active model rates. */
"use strict";

const heroEl = document.getElementById("ds-hero");
const brandMarkEl = document.getElementById("ds-brand-mark");
const badgeEl = document.getElementById("ds-badge-text");
const countEl = document.getElementById("ds-count");
const untilTextEl = document.getElementById("ds-until-text");
const progressFillEl = document.getElementById("ds-progress-fill");
const windowsBodyEl = document.getElementById("ds-windows-body");
const windowsZoneEl = document.getElementById("ds-windows-zone");
const ratesEl = document.getElementById("ds-rates");
const rateNowLabelEl = document.getElementById("ds-rates-now-label");
const rateNextLabelEl = document.getElementById("ds-rates-next-label");
const nowAmounts = Array.from(document.querySelectorAll(".ds-rates-now .ds-amt"));
const nextAmounts = Array.from(document.querySelectorAll(".ds-rates-next .ds-amt"));
const trackEl = document.getElementById("ds-track");
const nowEl = document.getElementById("ds-now");
const tzEl = document.getElementById("ds-tz");
const toggleBtns = Array.from(document.querySelectorAll(".ds-toggle-btn"));

let zone = "local";
try {
  const saved = localStorage.getItem("ds-zone");
  if (saved === "local" || saved === "utc") zone = saved;
} catch {}

let timeFmt;
let timeZoneFmt;
let dayFmt;
let dayTimeZoneFmt;
let dateFmt;
let dateTimeZoneFmt;

function buildFormatters() {
  const base =
    zone === "utc"
      ? { hour: "2-digit", minute: "2-digit", timeZone: "UTC" }
      : { hour: "2-digit", minute: "2-digit" };
  timeFmt = new Intl.DateTimeFormat(undefined, base);
  timeZoneFmt = new Intl.DateTimeFormat(undefined, {
    ...base,
    timeZoneName: "short",
  });
  dayFmt = new Intl.DateTimeFormat(undefined, { weekday: "short", ...base });
  dayTimeZoneFmt = new Intl.DateTimeFormat(undefined, {
    weekday: "short",
    ...base,
    timeZoneName: "short",
  });
  const dated = { weekday: "short", month: "short", day: "numeric" };
  dateFmt = new Intl.DateTimeFormat(undefined, { ...dated, ...base });
  dateTimeZoneFmt = new Intl.DateTimeFormat(undefined, {
    ...dated,
    ...base,
    timeZoneName: "short",
  });
}

function dayLabel(date, from, withZone) {
  const far = Math.abs(date.getTime() - from.getTime()) >= 6 * 86400000;
  if (withZone) {
    return (far ? dateTimeZoneFmt : dayTimeZoneFmt).format(date);
  }
  return (far ? dateFmt : dayFmt).format(date);
}

function displayOffset() {
  return zone === "utc" ? 0 : -new Date().getTimezoneOffset();
}

function tzName() {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || "local time";
  } catch {
    return "local time";
  }
}

function offsetLabel() {
  const offsetMinutes = displayOffset();
  const sign = offsetMinutes >= 0 ? "+" : "−";
  const abs = Math.abs(offsetMinutes);
  const hours = Math.floor(abs / 60);
  const minutes = abs % 60;
  return (
    "GMT" +
    sign +
    hours +
    (minutes ? ":" + String(minutes).padStart(2, "0") : "")
  );
}

function renderTzLabel() {
  tzEl.textContent =
    zone === "utc" ? "UTC · GMT+0" : `${tzName()} · ${offsetLabel()}`;
}

function clock(totalSeconds) {
  const sec = Math.max(0, Math.floor(totalSeconds));
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = sec % 60;
  return `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
}

function awayLabel(ms) {
  const mins = Math.max(0, Math.floor(ms / 60000));
  const hours = Math.floor(mins / 60);
  return hours ? `${hours}h ${mins % 60}m` : `${mins}m`;
}

function durationLabel(ms) {
  const mins = Math.max(0, Math.round(ms / 60000));
  const hours = Math.floor(mins / 60);
  const rest = mins % 60;
  if (!hours) return `${rest}m`;
  return rest ? `${hours}h ${rest}m` : `${hours}h`;
}

function displayDayKey(date) {
  const year = zone === "utc" ? date.getUTCFullYear() : date.getFullYear();
  const month = zone === "utc" ? date.getUTCMonth() : date.getMonth();
  const day = zone === "utc" ? date.getUTCDate() : date.getDate();
  return year * 10000 + (month + 1) * 100 + day;
}

function rangeLabel(start, end) {
  if (displayDayKey(start) === displayDayKey(end)) {
    return `${timeFmt.format(start)} – ${timeFmt.format(end)}`;
  }
  return `${dayLabel(start, end, false)} – ${dayLabel(end, start, false)}`;
}

function renderTrack() {
  trackEl.innerHTML = "";
  const segments = displaySegments(new Date(), displayOffset());
  for (const seg of segments) {
    const div = document.createElement("div");
    div.className = `ds-seg ds-seg-${seg.kind}`;
    div.style.width = `${(((seg.end - seg.start) / 1440) * 100).toFixed(4)}%`;
    trackEl.appendChild(div);
  }
}

const windowRows = [];

function buildWindowRows(count) {
  for (let i = 0; i < count; i++) {
    const tr = document.createElement("tr");
    const kind = document.createElement("th");
    kind.setAttribute("scope", "row");
    kind.className = "ds-win-kind";
    const range = document.createElement("td");
    range.className = "ds-win-range";
    const meta = document.createElement("td");
    meta.className = "ds-win-meta";
    tr.append(kind, range, meta);
    windowsBodyEl.appendChild(tr);
    windowRows.push({ tr, kind, range, meta });
  }
}

function renderWindows(now) {
  windowsZoneEl.textContent = zone === "utc" ? "UTC" : "your time";
  const items = windowList(now, windowRows.length);
  items.forEach((item, i) => {
    const row = windowRows[i];
    row.tr.className = `ds-win-${item.kind}${item.current ? " ds-win-current" : ""}`;
    row.kind.textContent = item.kind === "peak" ? "Peak" : "Off-peak";
    row.range.textContent = rangeLabel(item.start, item.end);
    row.meta.textContent = item.current
      ? `${awayLabel(item.end.getTime() - now.getTime())} left`
      : durationLabel(item.end.getTime() - item.start.getTime());
  });
}

function tick() {
  const now = new Date();
  const win = currentWindow(now);
  const peak = win.kind === "peak";

  document.body.classList.toggle("is-peak", peak);
  brandMarkEl.src = peak ? "icons/peak48.png" : "icons/off48.png";
  heroEl.className = `ds-hero ds-hero-${win.kind}`;
  badgeEl.textContent = peak ? "Peak pricing" : "Off-peak · half price";
  countEl.textContent = clock((win.end.getTime() - now.getTime()) / 1000);
  const winStart = currentWindowStart(now).getTime();
  const winFrac = (now.getTime() - winStart) / (win.end.getTime() - winStart);
  progressFillEl.style.width = `${(Math.min(1, Math.max(0, winFrac)) * 100).toFixed(3)}%`;

  const crossDay = displayDayKey(win.end) !== displayDayKey(now);
  untilTextEl.textContent =
    (peak ? "Off-peak starts " : "Peak starts ") +
    (crossDay ? dayLabel(win.end, now, true) : timeZoneFmt.format(win.end));

  renderWindows(now);

  ratesEl.className = `ds-rates ds-rates-${win.kind}`;
  rateNowLabelEl.textContent = `Paying now · ${peak ? "peak" : "off-peak"}`;
  rateNextLabelEl.textContent = `From ${crossDay ? dayLabel(win.end, now, false) : timeFmt.format(win.end)} · ${peak ? "off-peak" : "peak"}`;
  for (const el of nowAmounts) {
    el.textContent = el.getAttribute(peak ? "data-peak" : "data-off");
  }
  for (const el of nextAmounts) {
    el.textContent = el.getAttribute(peak ? "data-off" : "data-peak");
  }
  const displayMinute =
    (win.minuteOfDay + now.getUTCSeconds() / 60 + displayOffset() + 1440) % 1440;
  nowEl.style.left = `${(displayMinute / 1440) * 100}%`;
}

function applyToggleState() {
  for (const btn of toggleBtns) {
    const active = btn.getAttribute("data-zone") === zone;
    btn.classList.toggle("ds-toggle-active", active);
    btn.setAttribute("aria-pressed", active ? "true" : "false");
  }
}

function setZone(nextZone) {
  if (nextZone !== "local" && nextZone !== "utc") return;
  zone = nextZone;
  try {
    localStorage.setItem("ds-zone", zone);
  } catch {}
  buildFormatters();
  renderTzLabel();
  renderTrack();
  applyToggleState();
  tick();
}

for (const btn of toggleBtns) {
  btn.addEventListener("click", () => setZone(btn.getAttribute("data-zone")));
}

// Flip alerts. The notifications permission is optional and requested the
// first time alerts are turned on; background.js sends the notifications.
const alertsToggleEl = document.getElementById("ds-alerts-toggle");
const alertsHintEl = document.getElementById("ds-alerts-hint");
const ALERTS_HINT = alertsHintEl.textContent;

function setAlerts(on) {
  alertsToggleEl.checked = on;
  chrome.storage.local.set({ notify: on });
}

alertsToggleEl.addEventListener("change", () => {
  alertsHintEl.textContent = ALERTS_HINT;
  if (!alertsToggleEl.checked) {
    setAlerts(false);
    return;
  }
  // Must run inside the click gesture, before any await.
  chrome.permissions
    .request({ permissions: ["notifications"] })
    .then((granted) => {
      setAlerts(granted);
      if (!granted) alertsHintEl.textContent = "Notification permission was declined";
    })
    .catch(() => setAlerts(false));
});

Promise.all([
  chrome.storage.local.get("notify"),
  chrome.permissions.contains({ permissions: ["notifications"] }),
]).then(([{ notify }, granted]) => {
  alertsToggleEl.checked = Boolean(notify && granted);
});

buildFormatters();
buildWindowRows(SWITCH_MINUTES.length);
renderTzLabel();
renderTrack();
applyToggleState();
tick();
setInterval(tick, 1000);
