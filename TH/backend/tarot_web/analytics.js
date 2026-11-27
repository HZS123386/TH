/* Anonymous Tarot H5 page and action measurements. */
(() => {
  'use strict';

  const storageKey = 'fate-tarot-visitor-v1';
  const id = () => Array.from(crypto.getRandomValues(new Uint8Array(16)), byte => byte.toString(16).padStart(2, '0')).join('');
  let visitor;
  try {
    visitor = localStorage.getItem(storageKey);
    if (!/^[a-f0-9]{32}$/.test(visitor ?? '')) {
      visitor = id();
      localStorage.setItem(storageKey, visitor);
    }
  } catch {
    return;
  }

  const pending = new Map();
  let page, overlay, current, startedAt, checkpointTimer, sendTimer;
  let sending = false;
  let suspended = false;
  let retryDelay = 1500;

  function schedule(delay = 400) {
    if (!pending.size || sending || sendTimer) return;
    sendTimer = setTimeout(() => {
      sendTimer = null;
      send();
    }, delay);
  }

  function queue(entry) {
    if (pending.size >= 400 && !pending.has(entry.id)) pending.delete(pending.keys().next().value);
    pending.set(entry.id, entry);
    schedule();
  }

  async function send(leaving = false) {
    if ((!leaving && sending) || !pending.size) return;
    clearTimeout(sendTimer);
    sendTimer = null;
    const observations = [...pending.values()].slice(0, 40);
    if (!leaving) sending = true;
    let retry = false;
    try {
      const response = await fetch('/api/tarot/activity', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Tarot-Visitor': visitor },
        body: JSON.stringify({ observations }),
        keepalive: true,
      });
      retry = response.status >= 500 || response.status === 429;
      if (!retry) {
        for (const item of observations) {
          if (pending.get(item.id) === item) pending.delete(item.id);
        }
      }
    } catch {
      retry = true;
    } finally {
      if (!leaving) sending = false;
      if (!suspended && document.visibilityState === 'visible') schedule(retry ? retryDelay : 400);
      retryDelay = retry ? Math.min(30000, retryDelay * 2) : 1500;
    }
  }

  function checkpoint(stop = false) {
    if (startedAt == null) return;
    const now = performance.now();
    current.visibleMs = Math.min(2147483647, current.visibleMs + now - startedAt);
    queue({ id: current.id, event: current.name, visible_ms: Math.floor(current.visibleMs) });
    startedAt = stop ? null : now;
    if (stop) clearInterval(checkpointTimer);
  }

  function syncView() {
    const next = overlay || page;
    const visible = !suspended && document.visibilityState === 'visible';
    if (next !== current || !visible) checkpoint(true);
    current = next;
    if (!current || !visible || startedAt != null) return;
    if (!current.id) {
      current.id = id();
      queue({ id: current.id, event: current.name, visible_ms: 0 });
    }
    startedAt = performance.now();
    checkpointTimer = setInterval(() => checkpoint(), 15000);
  }

  function leave() {
    checkpoint(true);
    // An in-flight checkpoint may overlap with this last update, so the server keeps the larger total.
    send(true);
  }

  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
      syncView();
      schedule();
    } else {
      leave();
    }
  });
  window.addEventListener('pagehide', () => {
    suspended = true;
    leave();
  });
  window.addEventListener('pageshow', () => {
    suspended = false;
    syncView();
    schedule();
  });
  window.addEventListener('online', () => schedule());

  window.TarotAnalytics = {
    page(name, context) {
      if (page?.name === name && page.context === context) return;
      page = { name, context, visibleMs: 0 };
      syncView();
    },
    overlay(name) {
      if (overlay?.name === name) return;
      overlay = name ? { name, visibleMs: 0 } : null;
      syncView();
    },
    action(event) {
      if (!suspended && document.visibilityState === 'visible') queue({ id: id(), event });
    },
  };
})();
