import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import { afterEach, beforeEach, expect, it, vi } from "vitest";

const source = readFileSync("web-client/web/browser.js", "utf8");
const recoveryKey = "fate-startup-recovery-at";

function openDocument(storage = new Map<string, string>(), storageBlocked = false) {
  const status = { textContent: "" };
  const button = { hidden: true, addEventListener: vi.fn() };
  const startup = { remove: vi.fn() };
  const nodes = new Map<string, unknown>([
    ["fate-startup-status", status], ["fate-startup-retry", button], ["fate-startup", startup],
  ]);
  const window = { dispatchEvent: vi.fn(), addEventListener: vi.fn() } as any;
  const location = { search: "?lang=zh&id=retained-report", reload: vi.fn() };
  runInNewContext(source, {
    window, location, URLSearchParams, Date, Event, setTimeout, clearTimeout,
    document: { documentElement: { lang: "zh" }, getElementById: (id: string) => nodes.get(id) },
    performance: { mark: vi.fn() },
    sessionStorage: {
      getItem: (key: string) => storage.get(key) ?? null,
      setItem: (key: string, value: string) => {
        if (storageBlocked) throw Error("Storage unavailable");
        storage.set(key, value);
      },
      removeItem: (key: string) => storage.delete(key),
    },
  });
  return { boot: window.fateBoot, location, status, button, startup, storage };
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
