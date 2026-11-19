import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import { webcrypto } from "node:crypto";
import { afterEach, beforeEach, expect, it, vi } from "vitest";

const source = readFileSync("web-client/web/browser.js", "utf8");
const recoveryKey = "fate-startup-recovery-at";

function openDocument(storage = new Map<string, string>(), storageBlocked = false, options: {
  url?: string; language?: string; local?: Map<string, string>; cookie?: { value: string }; cookieBlocked?: boolean; fetch?: ReturnType<typeof vi.fn>;
  portrait?: EventTarget; welcome?: boolean; privateBrowsing?: boolean;
  navigationType?: "navigate" | "reload" | "back_forward";
  historyEntry?: { state: Record<string, unknown> | null };
} = {}) {
  const status = { textContent: "" };
  const button = { hidden: true, addEventListener: vi.fn() };
  const startup = { remove: vi.fn(), dataset: {} as Record<string, string> };
  const start = { setAttribute: vi.fn(), addEventListener: vi.fn() };
  const nodes = new Map<string, unknown>([
    ["fate-startup-status", status], ["fate-startup-retry", button], ["fate-startup", startup],
    ["fate-welcome-start", start], ["fate-welcome-portrait", options.portrait],
  ]);
  if (options.welcome) nodes.set("fate-welcome", { querySelector: vi.fn(), addEventListener: vi.fn() });
  const window = { dispatchEvent: vi.fn(), addEventListener: vi.fn() } as any;
  const url = new URL(options.url ?? "http://127.0.0.1/thai-landing/?lang=zh&id=retained-report");
  const location = { href: url.href, host: url.host, hostname: url.hostname, pathname: url.pathname, protocol: url.protocol, search: url.search, reload: vi.fn(), replace: vi.fn() };
  const local = options.local ?? new Map<string, string>();
  const cookie = options.cookie ?? { value: "" };
  const makeStorage = (values: Map<string, string>) => ({
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => { if (storageBlocked) throw Error("Storage unavailable"); values.set(key, value); },
    removeItem: (key: string) => values.delete(key),
  });
  window.localStorage = makeStorage(local);
  window.sessionStorage = makeStorage(storage);
  const document = { visibilityState: "visible", documentElement: { lang: options.language ?? "zh", dataset: { welcome: String(!/(report|privacy|support)\.html$/.test(url.pathname)) } }, getElementById: (id: string) => nodes.get(id), addEventListener: vi.fn(), removeEventListener: vi.fn() };
  const fetch = options.fetch ?? vi.fn().mockImplementation(async (_url, options) => ({
    ok: true, json: async () => ({ ok: true, accepted_sequences: JSON.parse(options.body).events.map((event: any) => event.sequence) }),
  }));
  window.navigator = { doNotTrack: "0", globalPrivacyControl: options.privateBrowsing ?? false };
  const historyEntry = options.historyEntry ?? { state: null };
  const history = {
    get state() { return historyEntry.state; },
    replaceState: vi.fn((state: Record<string, unknown> | null) => { historyEntry.state = state; }),
  };
  Object.defineProperty(document, "cookie", {
    get: () => options.cookieBlocked ? "" : cookie.value,
    set: (value: string) => { if (!options.cookieBlocked) cookie.value = value.includes("Max-Age=0") ? "" : value.split(";")[0]; },
  });
  runInNewContext(source, {
    window, location, URL, URLSearchParams, Date, Event, setTimeout, clearTimeout, document, history,
    performance: { mark: vi.fn(), now: () => Date.now(), getEntriesByType: () => [{ type: options.navigationType ?? "navigate" }] },
    crypto: webcrypto, AbortController,
    sessionStorage: window.sessionStorage, fetch,
  });
  return { boot: window.fateBoot, h5: window.fateH5, window, document, fetch, location, status, button, start, startup, storage, local, cookie };
}

beforeEach(() => { vi.useFakeTimers(); vi.setSystemTime(new Date("2026-11-11T06:00:00Z")); });
afterEach(() => { vi.clearAllTimers(); vi.useRealTimers(); });

it.each(["zh", "th"])("records the %s welcome before Flutter and shares its identity", async (language) => {
  const page = openDocument(new Map(), false, { language, welcome: true });
  const visit = JSON.parse(page.h5.visitContext());
  const owner = page.h5.ownerKey();
  expect(page.fetch).toHaveBeenCalledTimes(1);
  const [url, request] = page.fetch.mock.calls[0];
  expect(url).toBe("/api/landing/visits");
  expect(request.headers["X-Report-Key"]).toBe(owner);
  expect(request.headers["X-Visit-Id"]).toBe(visit.id);
  expect(JSON.parse(request.body)).toMatchObject({
    id: visit.id, events: [{ page: "welcome", action: "view", state: "visible" }],
  });
  page.h5.trackActivity(JSON.stringify({ ...visit, activity: { page: "welcome", action: "view" } }),
    owner, "/api/landing/visits");
  await vi.advanceTimersByTimeAsync(300);
  expect(page.fetch).toHaveBeenCalledTimes(1);
});

it("does not record the HTML welcome when tracking is disabled", () => {
  const page = openDocument(new Map(), false, { welcome: true, privateBrowsing: true });
  expect(page.fetch).not.toHaveBeenCalled();
  expect(page.h5.visitContext()).toBe("{}");
  expect(page.local.has("astro-life-report-key")).toBe(false);
});

it("uses fresh tags on re-entry and keeps the corresponding visit through reload and history", () => {
  const storage = new Map<string, string>();
  const local = new Map<string, string>();
  const entry = { state: { router: 1 } as Record<string, unknown> | null };
  const url = "http://127.0.0.1/thai-landing/?utm_source=facebook&utm_campaign=story&utm_region=th";
  const original = openDocument(storage, false, { local, url, historyEntry: entry });
  const first = JSON.parse(original.h5.visitContext());
  expect(first).toMatchObject({ source: "facebook", campaign: "story", region: "TH" });
  expect(entry.state?.router).toBe(1);
  entry.state = { router: 2 };
  original.window.addEventListener.mock.calls.find(([name]: string[]) => name === "pagehide")![1]();
  expect(entry.state?.router).toBe(2);
  const direct = openDocument(storage, false, { local });
  const next = JSON.parse(direct.h5.visitContext());
  expect(next.id).not.toBe(first.id);
  expect(next).toMatchObject({ source: "", campaign: "" });
  expect(direct.h5.ownerKey()).toBe(original.h5.ownerKey());
  const reload = openDocument(storage, false, { local, navigationType: "reload" });
  expect(JSON.parse(reload.h5.visitContext())).toEqual(next);
  const back = openDocument(storage, false, { local, url, historyEntry: entry, navigationType: "back_forward" });
  expect(JSON.parse(back.h5.visitContext())).toEqual(first);
});

it("retains the last page through hiding, leaving and restoring without losing ownership", async () => {
  const page = openDocument();
  const payload = { id: "visit-test", source: "facebook", activity: { page: "payment", action: "open_cashier" } };
  page.h5.trackActivity(JSON.stringify(payload), "synthetic-owner", "/api/landing/visits");
  await vi.advanceTimersByTimeAsync(250);
  const visibility = page.document.addEventListener.mock.calls.find(([name]) => name === "visibilitychange")![1];
  const hide = page.window.addEventListener.mock.calls.find(([name]: string[]) => name === "pagehide")![1];
  const show = page.window.addEventListener.mock.calls.find(([name]: string[]) => name === "pageshow")![1];
  page.document.visibilityState = "hidden";
  visibility();
  await vi.advanceTimersByTimeAsync(0);
  hide();
  await vi.advanceTimersByTimeAsync(0);
  page.document.visibilityState = "visible";
  show({ persisted: true });
  await vi.advanceTimersByTimeAsync(250);
  const bodies = page.fetch.mock.calls.map(([, options]) => JSON.parse(options.body));
  const events = bodies.flatMap(body => body.events);
  expect(events.map(event => event.state)).toEqual(["visible", "hidden", "pagehide", "visible"]);
  expect(events.every(event => event.page === "payment" && event.action === "open_cashier")).toBe(true);
  expect(events[3].sequence).toBeGreaterThan(events[2].sequence);
  expect(page.fetch.mock.calls[2][1]).toMatchObject({ keepalive: true, headers: { "X-Report-Key": "synthetic-owner" } });
  expect(page.fetch.mock.calls[2][1].body).not.toContain("synthetic-owner");
  const reloaded = openDocument(page.storage);
  reloaded.h5.trackActivity(JSON.stringify(payload), "synthetic-owner", "/api/landing/visits");
  await vi.advanceTimersByTimeAsync(250);
  expect(JSON.parse(reloaded.fetch.mock.calls[0][1].body).events[0].sequence).toBeGreaterThan(events[3].sequence);
});

it("honors privacy changes and tolerates a failed activity upload", async () => {
  const page = openDocument();
  const payload = JSON.stringify({ id: "visit-test", activity: { page: "birth_form", action: "view" } });
  page.window.navigator.doNotTrack = "1";
  page.h5.trackActivity(payload, "synthetic-owner", "/api/landing/visits");
  expect(page.fetch).not.toHaveBeenCalled();
  page.window.navigator.doNotTrack = "0";
  page.window.navigator.globalPrivacyControl = true;
  page.h5.trackActivity(payload, "synthetic-owner", "/api/landing/visits");
  expect(page.fetch).not.toHaveBeenCalled();
  page.window.navigator.globalPrivacyControl = false;
  page.fetch.mockRejectedValue(new Error("offline"));
  expect(() => page.h5.trackActivity(payload, "synthetic-owner", "/api/landing/visits")).not.toThrow();
  await vi.advanceTimersByTimeAsync(250);
  expect(JSON.parse(page.storage.get('fate-activity-pending')!).items).toHaveLength(1);
});

it("keeps rejected HTTP uploads until Retry-After and acknowledges the same sequences", async () => {
  const page = openDocument();
  page.fetch.mockImplementationOnce(async () => ({ ok: false, headers: { get: () => '60' } }));
  page.h5.trackActivity(JSON.stringify({ id: 'visit-test', activity: { page: 'payment', action: 'open_payment' } }), 'synthetic-owner', '/api/landing/visits');
  await vi.advanceTimersByTimeAsync(250);
  const first = JSON.parse(page.fetch.mock.calls[0][1].body).events[0];
  await vi.advanceTimersByTimeAsync(59000);
  expect(page.fetch).toHaveBeenCalledTimes(1);
  await vi.advanceTimersByTimeAsync(1000);
  expect(page.fetch).toHaveBeenCalledTimes(2);
  expect(JSON.parse(page.fetch.mock.calls[1][1].body).events[0]).toEqual(first);
  expect(JSON.parse(page.storage.get('fate-activity-pending')!).items).toHaveLength(0);
});

it("replays unacknowledged events after refresh without including credentials in the body", async () => {
  const first = openDocument(new Map(), false, { fetch: vi.fn().mockRejectedValue(Error('offline')) });
  const payload = JSON.stringify({ id: 'visit-test', activity: { page: 'birth_form', action: 'view' } });
  first.h5.trackActivity(payload, 'synthetic-owner', '/api/landing/visits');
  await vi.advanceTimersByTimeAsync(250);
  const old = JSON.parse(first.fetch.mock.calls[0][1].body).events[0];
  vi.clearAllTimers();
  const reloaded = openDocument(first.storage);
  reloaded.h5.trackActivity(payload, 'synthetic-owner', '/api/landing/visits');
  await vi.advanceTimersByTimeAsync(250);
  const body = JSON.parse(reloaded.fetch.mock.calls[0][1].body);
  expect(body.events[0]).toEqual(old);
  expect(body.events[1].sequence).toBeGreaterThan(old.sequence);
  expect(JSON.stringify(body)).not.toContain('synthetic-owner');
  expect(JSON.parse(reloaded.storage.get('fate-activity-pending')!).items).toHaveLength(0);
});

it("counts only visible time and keeps separate page entries", async () => {
  const page = openDocument();
  const track = (name: string) => page.h5.trackActivity(JSON.stringify({ id: 'visit-test', activity: { page: name, action: 'view' } }), 'synthetic-owner', '/api/landing/visits');
  const visibility = page.document.addEventListener.mock.calls.find(([name]) => name === 'visibilitychange')![1];
  track('birth_form');
  await vi.advanceTimersByTimeAsync(10000);
  page.document.visibilityState = 'hidden'; visibility();
  await vi.advanceTimersByTimeAsync(120000);
  page.document.visibilityState = 'visible'; visibility();
  await vi.advanceTimersByTimeAsync(5000);
  track('payment');
  await vi.advanceTimersByTimeAsync(250);
  const events = page.fetch.mock.calls.flatMap(([, options]) => JSON.parse(options.body).events);
  expect(events.find(event => event.action === 'leave_page')).toMatchObject({ page: 'birth_form', visible_ms: 15000 });
  const payment = events.find(event => event.page === 'payment');
  expect(payment.visible_ms).toBe(0);
  expect(payment.page_view_id).not.toBe(events[0].page_view_id);
});

it("flushes the latest exit while an older request is still in flight", async () => {
  const page = openDocument();
  page.fetch.mockImplementationOnce(() => new Promise(() => {}));
  page.h5.trackActivity(JSON.stringify({ id: 'visit-test', activity: { page: 'payment', action: 'open_cashier' } }), 'synthetic-owner', '/api/landing/visits');
  await vi.advanceTimersByTimeAsync(250);
  page.window.addEventListener.mock.calls.find(([name]: string[]) => name === 'pagehide')![1]();
  await vi.advanceTimersByTimeAsync(0);
  expect(page.fetch).toHaveBeenCalledTimes(2);
  expect(JSON.parse(page.fetch.mock.calls[1][1].body).events.at(-1).state).toBe('pagehide');
});

const pendingKey = 'fate-activity-pending';
const pendingItems = (storage: Map<string, string>) => JSON.parse(storage.get(pendingKey)!).items as any[];
const eventKey = (item: any) => `${item.visit.id}:${item.event.sequence}`;
const trackVisit = (page: ReturnType<typeof openDocument>, name: string) =>
  page.h5.trackActivity(JSON.stringify({ id: 'visit-test', activity: { page: name, action: 'view' } }), 'synthetic-owner', '/api/landing/visits');
const restorePage = (page: ReturnType<typeof openDocument>) => {
  page.document.visibilityState = 'visible';
  page.window.addEventListener.mock.calls.find(([name]: string[]) => name === 'pageshow')![1]({ persisted: true });
};
const suspendDocumentTimers = () => {
  const now = Date.now();
  vi.clearAllTimers();
  vi.setSystemTime(now);
};
const hidePage = async (page: ReturnType<typeof openDocument>) => {
  page.document.visibilityState = 'hidden';
  page.window.addEventListener.mock.calls.find(([name]: string[]) => name === 'pagehide')![1]();
  await vi.advanceTimersByTimeAsync(0);
  suspendDocumentTimers(); // Cached documents pause timers without rewinding the wall clock.
};

it('keeps every offline page through cached back and forward navigation, then drains without resurrection', async () => {
  const storage = new Map<string, string>();
  const fetch = vi.fn().mockRejectedValue(Error('offline'));
  const a = openDocument(storage, false, { fetch });
  trackVisit(a, 'birth_form');
  await hidePage(a);
  const b = openDocument(storage, false, { fetch });
  trackVisit(b, 'payment');
  await hidePage(b);
  const original = pendingItems(storage);
  restorePage(a);
  const afterBack = new Set(pendingItems(storage).map(eventKey));
  expect(original.every(item => afterBack.has(eventKey(item)))).toBe(true);
  await hidePage(a);
  restorePage(b);
  const beforeUpload = pendingItems(storage);
  expect(new Set(beforeUpload.map(eventKey)).size).toBe(beforeUpload.length);
  expect(beforeUpload.some(item => item.event.page === 'birth_form')).toBe(true);
  expect(beforeUpload.some(item => item.event.page === 'payment')).toBe(true);
  const uploaded = new Set<string>();
  fetch.mockImplementation(async (_url, options) => {
    const body = JSON.parse(options.body);
    body.events.forEach((event: any) => uploaded.add(`${body.id}:${event.sequence}`));
    return { ok: true, json: async () => ({ ok: true, accepted_sequences: body.events.map((event: any) => event.sequence) }) };
  });
  await vi.advanceTimersByTimeAsync(10000);
  expect(beforeUpload.every(item => uploaded.has(eventKey(item)))).toBe(true);
  expect(pendingItems(storage)).toHaveLength(0);
  suspendDocumentTimers();
  const acknowledgedBeforeRestore = new Set(uploaded);
  restorePage(a);
  expect(pendingItems(storage).some(item => acknowledgedBeforeRestore.has(eventKey(item)))).toBe(false);
  await vi.advanceTimersByTimeAsync(250);
  expect(pendingItems(storage)).toHaveLength(0);
});

it('applies a late acknowledgement to the latest shared queue and refreshes stale upload batches', async () => {
  const storage = new Map<string, string>();
  let acknowledge!: (response: unknown) => void;
  const a = openDocument(storage, false, { fetch: vi.fn(() => new Promise(resolve => { acknowledge = resolve; })) });
  trackVisit(a, 'birth_form');
  await vi.advanceTimersByTimeAsync(250);
  const firstSequence = pendingItems(storage)[0].event.sequence;
  a.document.visibilityState = 'hidden';
  suspendDocumentTimers();
  const b = openDocument(storage);
  trackVisit(b, 'payment');
  const second = pendingItems(storage).find(item => item.event.page === 'payment');
  acknowledge({ ok: true, json: async () => ({ ok: true, accepted_sequences: [firstSequence] }) });
  await vi.advanceTimersByTimeAsync(0);
  expect(pendingItems(storage).map(eventKey)).toEqual([eventKey(second)]);
  await vi.advanceTimersByTimeAsync(250);
  expect(pendingItems(storage)).toHaveLength(0);
  expect(a.fetch).toHaveBeenCalledTimes(1);
  expect(JSON.parse(b.fetch.mock.calls[0][1].body).events).toHaveLength(1);
});

it('retains locally unsaved events when session storage becomes writable again', async () => {
  const page = openDocument();
  const write = page.window.sessionStorage.setItem;
  page.window.sessionStorage.setItem = (key: string, value: string) => {
    if (key === pendingKey) throw Error('Quota exceeded');
    write(key, value);
  };
  page.fetch.mockRejectedValue(Error('offline'));
  trackVisit(page, 'birth_form');
  trackVisit(page, 'payment');
  await vi.advanceTimersByTimeAsync(250);
  const attempts = JSON.parse(page.fetch.mock.calls[0][1].body).events;
  expect(attempts.map((event: any) => event.page)).toEqual(['birth_form', 'birth_form', 'payment']);
  page.window.sessionStorage.setItem = write;
  restorePage(page);
  const retained = new Set(pendingItems(page.storage).map(item => item.event.sequence));
  expect(attempts.every((event: any) => retained.has(event.sequence))).toBe(true);
});

it('acknowledges in-memory events while storage reads are blocked and does not replay them after recovery', async () => {
  const page = openDocument();
  const read = page.window.sessionStorage.getItem;
  page.window.sessionStorage.getItem = (key: string) => {
    if (key === pendingKey) throw Error('Storage unavailable');
    return read(key);
  };
  trackVisit(page, 'payment');
  await vi.advanceTimersByTimeAsync(250);
  const delivered = JSON.parse(page.fetch.mock.calls[0][1].body).events[0];
  await vi.advanceTimersByTimeAsync(1000);
  expect(page.fetch).toHaveBeenCalledTimes(1);
  page.window.sessionStorage.getItem = read;
  restorePage(page);
  expect(pendingItems(page.storage).some(item => item.event.sequence === delivered.sequence)).toBe(false);
  await vi.advanceTimersByTimeAsync(250);
  expect(pendingItems(page.storage)).toHaveLength(0);
});

it('preserves the shared queue limit and overflow count when an older page returns', () => {
  const sequence = Date.now();
  const items = Array.from({ length: 500 }, (_, index) => ({ visit: { id: 'visit-test' }, event: {
    page: 'birth_form', action: 'view', state: 'visible', kind: 'action', sequence: sequence + index + 1,
    occurred_at: Date.now() / 1000, page_view_id: 'synthetic-page', visible_ms: index,
  } }));
  const storage = new Map([
    [pendingKey, JSON.stringify({ owner: 'synthetic-owner', items, dropped: { 'visit-test': 3 } })],
    ['fate-activity-sequence', String(sequence + 500)],
  ]);
  const fetch = vi.fn().mockRejectedValue(Error('offline'));
  const a = openDocument(storage, false, { fetch });
  trackVisit(a, 'birth_form');
  const b = openDocument(storage, false, { fetch });
  trackVisit(b, 'payment');
  restorePage(a);
  const saved = JSON.parse(storage.get(pendingKey)!);
  expect(saved.items).toHaveLength(500);
  expect(saved.items[0].event.sequence).toBe(sequence + 4);
  expect(saved.items.at(-1).event.sequence).toBe(sequence + 503);
  expect(saved.dropped['visit-test']).toBe(6);
});

it('does not let a cached former owner overwrite the current owner queue', async () => {
  const storage = new Map<string, string>();
  const a = openDocument(storage, false, { fetch: vi.fn().mockRejectedValue(Error('offline')) });
  trackVisit(a, 'birth_form');
  await hidePage(a);
  const b = openDocument(storage);
  b.h5.trackActivity(JSON.stringify({ id: 'other-visit', activity: { page: 'payment', action: 'view' } }), 'other-synthetic-owner', '/api/landing/visits');
  const current = storage.get(pendingKey);
  restorePage(a);
  expect(storage.get(pendingKey)).toBe(current);
  expect(pendingItems(storage).every(item => item.visit.id === 'other-visit')).toBe(true);
});

it.each(["zh", "th"])("keeps an early %s welcome click until Flutter is ready and enters only once", (language) => {
  const page = openDocument(new Map(), false, { language });
  const enter = vi.fn();
  const click = page.start.addEventListener.mock.calls.find(([name]) => name === "click")![1];
  click();
  click();
  page.boot.stage("engine");
  page.boot.connectWelcome(enter);
  expect(enter).not.toHaveBeenCalled();
  expect(page.startup.dataset.state).toBe("waiting");
  expect(page.start.setAttribute).toHaveBeenCalledWith("aria-busy", "true");
  page.boot.ready();
  page.boot.ready();
  expect(enter).toHaveBeenCalledTimes(1);
});

it.each(["click", "error", "timeout"])("releases Flutter startup on a welcome portrait %s", async (reason) => {
  const portrait = new EventTarget();
  const page = openDocument(new Map(), false, { portrait });
  const released = vi.fn();
  page.boot.welcomePaint.then(released);
  await vi.advanceTimersByTimeAsync(0);
  expect(released).not.toHaveBeenCalled();
  if (reason === "click") page.boot.enterWelcome();
  if (reason === "error") portrait.dispatchEvent(new Event("error"));
  await vi.advanceTimersByTimeAsync(reason === "timeout" ? 800 : 0);
  expect(released).toHaveBeenCalledOnce();
});

it("keeps the welcome open without a click and leaves deep links on their original route", () => {
  for (const route of ["", "report.html?id=retained-report", "privacy.html", "support.html"]) {
    const page = openDocument(new Map(), false, { url: `http://127.0.0.1/thai-landing/${route}` });
    const enter = vi.fn();
    page.boot.connectWelcome(enter);
    if (route) page.boot.enterWelcome();
    page.boot.ready();
    expect(enter).not.toHaveBeenCalled();
    expect(page.location.replace).not.toHaveBeenCalled();
  }
});

it("recovers a failed startup once and leaves persistent failures retryable", () => {
  const first = openDocument();
  first.boot.fail();
  first.boot.fail();
  expect(first.status.textContent).toContain("正在重新加载");
  vi.advanceTimersByTime(700);
  expect(first.location.reload).toHaveBeenCalledTimes(1);
  expect(first.location.search).toBe("?lang=zh&id=retained-report");
  const second = openDocument(first.storage);
  second.boot.fail();
  vi.advanceTimersByTime(30000);
  expect(second.location.reload).not.toHaveBeenCalled();
  expect(second.status.textContent).toContain("页面加载失败");
  expect(second.button.hidden).toBe(false);
});

it("cancels recovery when the app becomes visible and clears the failure marker", () => {
  const page = openDocument();
  page.boot.fail();
  page.boot.ready();
  vi.advanceTimersByTime(30000);
  expect(page.location.reload).not.toHaveBeenCalled();
  expect(page.startup.remove).toHaveBeenCalledTimes(1);
  expect(page.storage.has(recoveryKey)).toBe(false);
});

it("does not refresh just because loading is slow or storage is unavailable", () => {
  const slow = openDocument();
  vi.advanceTimersByTime(20000);
  expect(slow.status.textContent).toContain("请稍候");
  expect(slow.location.reload).not.toHaveBeenCalled();
  const blocked = openDocument(new Map(), true);
  blocked.boot.fail();
  vi.advanceTimersByTime(1000);
  expect(blocked.location.reload).not.toHaveBeenCalled();
  expect(blocked.button.hidden).toBe(false);
});

const ownerName = "astro-life-report-key";
const owner = "valid-legacy_owner_" + "a".repeat(32);
const oldUrl = "http://129.226.126.212/thai-landing/report.html?id=saved-report&lang=zh#section";

it("upgrades the production URL and transfers the existing owner before Flutter starts", () => {
  const oldLocal = new Map([[ownerName, owner]]);
  const http = openDocument(new Map(), false, { url: oldUrl, local: oldLocal });
  expect(http.boot.upgrading).toBe(true);
  expect(http.location.replace.mock.calls[0][0]).toBe("https://129.226.126.212/thai-landing/report.html?id=saved-report&lang=zh&_fate_https=1#section");
  expect(http.location.replace.mock.calls[0][0]).not.toContain(owner);
  expect(oldLocal.get(ownerName)).toBe(owner);
  const https = openDocument(new Map(), false, { url: http.location.replace.mock.calls[0][0], cookie: http.cookie });
  expect(https.boot.upgrading).toBe(false);
  expect(https.local.get(ownerName)).toBe(owner);
  expect(https.storage.get(ownerName)).toBe(owner);
  expect(https.cookie.value).toBe("");
});

it("keeps HTTP reports usable when cookies or HTTPS persistence are unavailable", () => {
  const local = new Map([[ownerName, owner]]);
  const http = openDocument(new Map(), false, { url: oldUrl, local, cookieBlocked: true });
  expect(http.boot.upgrading).toBe(false);
  expect(http.location.replace).not.toHaveBeenCalled();
  const https = openDocument(new Map(), true, { url: oldUrl.replace("http:", "https:"), cookie: { value: "fate-https-owner=" + owner } });
  expect(https.boot.upgrading).toBe(true);
  expect(https.location.replace.mock.calls[0][0]).toContain("legacy_http=1");
  expect(local.get(ownerName)).toBe(owner);
});

it("retains conflicting HTTPS owners and keeps the incoming owner recoverable", () => {
  const current = "b".repeat(48);
  const local = new Map([[ownerName, current]]);
  const https = openDocument(new Map(), false, { url: oldUrl.replace("http:", "https:"), local, cookie: { value: "fate-https-owner=" + owner } });
  expect(local.get(ownerName)).toBe(current);
  expect(local.get(ownerName + "-http")).toBe(owner);
  expect(https.boot.upgrading).toBe(true);
  const fallback = openDocument(new Map(), false, { url: https.location.replace.mock.calls[0][0], local: new Map([[ownerName, owner]]) });
  expect(fallback.boot.upgrading).toBe(false);
  expect(fallback.location.replace).not.toHaveBeenCalled();
});

it("does not upgrade local previews or accept malformed migration credentials", () => {
  const preview = openDocument();
  expect(preview.location.replace).not.toHaveBeenCalled();
  const otherPort = openDocument(new Map(), false, { url: "http://129.226.126.212:8765/thai-landing/" });
  expect(otherPort.location.replace).not.toHaveBeenCalled();
  const page = openDocument(new Map(), false, { url: "https://129.226.126.212/thai-landing/", cookie: { value: "fate-https-owner=invalid" } });
  expect(page.local.has(ownerName)).toBe(false);
  expect(page.boot.upgrading).toBe(false);
});

it("returns to the original HTTP owner if a migration cookie expires before HTTPS loads", () => {
  const http = openDocument(new Map(), false, { url: oldUrl, local: new Map([[ownerName, owner]]) });
  const https = openDocument(new Map(), false, { url: http.location.replace.mock.calls[0][0] });
  expect(https.boot.upgrading).toBe(true);
  expect(https.local.has(ownerName)).toBe(false);
  expect(https.location.replace.mock.calls[0][0]).toBe("http://129.226.126.212/thai-landing/report.html?id=saved-report&lang=zh&legacy_http=1#section");
});
