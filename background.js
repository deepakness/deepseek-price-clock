importScripts("price.js");

// Recomputes the current window and paints the toolbar icon: green "D" for
// off-peak, red "D" for peak. Runs on install, on every alarm tick, and
// whenever the browser wakes the worker.
async function refresh() {
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
  const time = win.end.toLocaleString(undefined, {
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
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
}

chrome.runtime.onInstalled.addListener(refresh);
chrome.runtime.onStartup.addListener(refresh);
chrome.alarms.onAlarm.addListener(refresh);
refresh();
