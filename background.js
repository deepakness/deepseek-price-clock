importScripts("price.js");

// A flip older than this when the worker notices it (laptop asleep, Chrome
// closed) is skipped rather than announced late.
const NOTIFY_GRACE_MS = 5 * 60000;

function endLabel(end) {
  return end.toLocaleString(undefined, {
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}

// Shows a desktop notification when the window kind differs from the last
// one seen, if alerts are on and the flip just happened. The first run after
// install only records the current kind.
async function maybeNotify(now, win) {
  const { lastKind, notify } = await chrome.storage.local.get([
    "lastKind",
    "notify",
  ]);
  if (lastKind === win.kind) return;
  await chrome.storage.local.set({ lastKind: win.kind });
  if (!notify || !lastKind) return;
  if (now.getTime() - currentWindowStart(now).getTime() > NOTIFY_GRACE_MS) {
    return;
  }
  if (!(await chrome.permissions.contains({ permissions: ["notifications"] }))) {
    return;
  }
  const peak = win.kind === "peak";
  const time = endLabel(win.end);
  await chrome.notifications.create("flip", {
    type: "basic",
    iconUrl: peak ? "icons/peak128.png" : "icons/off128.png",
    title: peak
      ? "DeepSeek: peak pricing started"
      : "DeepSeek: off-peak started (half price)",
    message: peak ? `Off-peak again ${time}` : `Half price until ${time}`,
  });
}

// Recomputes the current window and paints the toolbar icon: green "D" for
// off-peak, red "D" for peak. Runs on install, on every alarm tick, and
// whenever the browser wakes the worker.
async function update() {
  const now = new Date();
  const win = currentWindow(now);
  const peak = win.kind === "peak";
  const prefix = peak ? "peak" : "off";
  await chrome.action.setIcon({
    path: {
      16: `icons/${prefix}16.png`,
      32: `icons/${prefix}32.png`,
      48: `icons/${prefix}48.png`,
      128: `icons/${prefix}128.png`,
    },
  });
  const time = endLabel(win.end);
  await chrome.action.setTitle({
    title: peak
      ? `DeepSeek: peak pricing until ${time}`
      : `DeepSeek: off-peak (half price) until ${time}`,
  });
  // Align the next tick with the top of the next minute.
  const delay = 61000 - now.getMilliseconds() - now.getSeconds() * 1000;
  chrome.alarms.create("tick", { when: Date.now() + delay });
  // Second alarm at the exact switch instant, so the icon flips on time even
  // if the worker was asleep.
  chrome.alarms.create("switch", { when: win.end.getTime() + 1000 });
  await maybeNotify(now, win);
}

// The tick and switch alarms land on the same second at a flip, so runs are
// queued one after another to keep the lastKind check from racing.
let queue = Promise.resolve();
function refresh() {
  queue = queue.then(update).catch((err) => console.error(err));
  return queue;
}

// The popup can close while Chrome shows the permission prompt, losing its
// callback, so a grant from the alerts toggle turns alerts on here too.
chrome.permissions.onAdded.addListener((perms) => {
  if (perms.permissions && perms.permissions.includes("notifications")) {
    chrome.storage.local.set({ notify: true });
  }
});

chrome.runtime.onInstalled.addListener(refresh);
chrome.runtime.onStartup.addListener(refresh);
chrome.alarms.onAlarm.addListener(refresh);
refresh();
