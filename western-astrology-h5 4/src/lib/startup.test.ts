import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import { afterEach, beforeEach, expect, it, vi } from "vitest";

const source = readFileSync("web-client/web/browser.js", "utf8");
const recoveryKey = "fate-startup-recovery-at";

function openDocument(storage = new Map<string, string>(), storageBlocked = false, options: {
  url?: string; local?: Map<string, string>; cookie?: { value: string }; cookieBlocked?: boolean;
} = {}) {
  const status = { textContent: "" };
  const button = { hidden: true, addEventListener: vi.fn() };
  const startup = { remove: vi.fn() };
  const nodes = new Map<string, unknown>([
    ["fate-startup-status", status], ["fate-startup-retry", button], ["fate-startup", startup],
  ]);
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
  const document = { documentElement: { lang: "zh" }, getElementById: (id: string) => nodes.get(id), addEventListener: vi.fn() };
  Object.defineProperty(document, "cookie", {
    get: () => options.cookieBlocked ? "" : cookie.value,
    set: (value: string) => { if (!options.cookieBlocked) cookie.value = value.includes("Max-Age=0") ? "" : value.split(";")[0]; },
  });
  runInNewContext(source, {
    window, location, URL, URLSearchParams, Date, Event, setTimeout, clearTimeout, document, history: { replaceState: vi.fn() },
    performance: { mark: vi.fn() },
    sessionStorage: window.sessionStorage,
  });
  return { boot: window.fateBoot, location, status, button, startup, storage, local, cookie };
}

beforeEach(() => { vi.useFakeTimers(); vi.setSystemTime(new Date("2026-11-11T06:00:00Z")); });
afterEach(() => { vi.clearAllTimers(); vi.useRealTimers(); });

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
