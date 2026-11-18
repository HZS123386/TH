import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import { afterEach, beforeEach, expect, it, vi } from "vitest";

const source = readFileSync("web-client/web/browser.js", "utf8");
const bootstrapSource = readFileSync("web-client/web/flutter_bootstrap.js", "utf8").replace(/\{\{flutter_(?:js|build_config)\}\}/g, "");
const recoveryKey = "fate-startup-recovery-at";

function openDocument(storage = new Map<string, string>(), storageBlocked = false, options: {
  url?: string; local?: Map<string, string>; cookie?: { value: string }; cookieBlocked?: boolean;
  streamingHtml?: boolean; missingBootstrap?: boolean;
} = {}) {
  const status = { textContent: "" };
  const button = { hidden: true };
  const startup = { remove: vi.fn() };
  const nodes = new Map<string, unknown>([
    ["fate-startup-status", status], ["fate-startup-retry", button], ["fate-startup", startup],
  ]);
  const listeners = new Map<string, ((event: any) => void)[]>();
  const window = { dispatchEvent: vi.fn(), addEventListener: vi.fn((type: string, listener: (event: any) => void) => {
    listeners.set(type, [...(listeners.get(type) ?? []), listener]);
  }) } as any;
  const url = new URL(options.url ?? "http://127.0.0.1/thai-landing/?lang=zh&id=retained-report");
  const location = { href: url.href, host: url.host, hostname: url.hostname, pathname: url.pathname, protocol: url.protocol, search: url.search, reload: vi.fn(), replace: vi.fn() };
  const local = options.local ?? new Map<string, string>();
  const cookie = options.cookie ?? { value: "" };
  const makeStorage = (values: Map<string, string>) => ({
    getItem: (key: string) => { if (storageBlocked) throw Error("Storage unavailable"); return values.get(key) ?? null; },
    setItem: (key: string, value: string) => { if (storageBlocked) throw Error("Storage unavailable"); values.set(key, value); },
    removeItem: (key: string) => { if (storageBlocked) throw Error("Storage unavailable"); return values.delete(key); },
  });
  window.localStorage = makeStorage(local);
  window.sessionStorage = makeStorage(storage);
  const document = { readyState: options.streamingHtml ? "loading" : "complete", documentElement: { lang: "zh" }, getElementById: (id: string) => nodes.get(id), addEventListener: vi.fn((_type: string, _callback: (event: any) => void) => {}) };
  Object.defineProperty(document, "cookie", {
    get: () => options.cookieBlocked ? "" : cookie.value,
    set: (value: string) => { if (!options.cookieBlocked) cookie.value = value.includes("Max-Age=0") ? "" : value.split(";")[0]; },
  });
  const context = {
    window, location, URL, URLSearchParams, Date, Event, setTimeout, clearTimeout, document, history: { replaceState: vi.fn() },
    performance: { mark: vi.fn() }, console: { error: vi.fn() },
    sessionStorage: window.sessionStorage,
    _flutter: { buildConfig: { engineRevision: "test-engine" }, loader: { load: vi.fn(async (_options: any) => {}) } },
  };
  window._flutter = options.missingBootstrap ? undefined : context._flutter;
  runInNewContext(source, context);
  const startFlutter = (load = vi.fn(async (_options: any) => {})) => {
    context._flutter.loader.load = load;
    runInNewContext(bootstrapSource, context);
    return load;
  };
  const emit = (type: string, event = {}) => { for (const listener of listeners.get(type) ?? []) listener(event); };
  const clickRetry = () => document.addEventListener.mock.calls.find(([type]) => type === "click")?.[1]({ target: { closest: () => button } });
  return { boot: window.fateBoot, location, status, button, startup, storage, local, cookie, startFlutter, emit, clickRetry };
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
  expect(second.boot.compatibility).toBe(true);
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
  page.boot.fail();
  page.emit("error", { error: Error("late engine error") });
  page.emit("unhandledrejection", { reason: Error("late rejection") });
  vi.advanceTimersByTime(180000);
  expect(page.location.reload).not.toHaveBeenCalled();
  expect(page.startup.remove).toHaveBeenCalledTimes(1);
  expect(page.storage.has(recoveryKey)).toBe(false);
});

it("does not refresh just because loading is slow or storage is unavailable", () => {
  const slow = openDocument();
  vi.advanceTimersByTime(20000);
  expect(slow.status.textContent).toContain("请稍候");
  expect(slow.location.reload).not.toHaveBeenCalled();
  vi.advanceTimersByTime(40000);
  slow.boot.ready();
  vi.advanceTimersByTime(120000);
  expect(slow.location.reload).not.toHaveBeenCalled();
  expect(slow.startup.remove).toHaveBeenCalledOnce();
  const blocked = openDocument(new Map(), true);
  blocked.boot.fail();
  vi.advanceTimersByTime(1000);
  expect(blocked.location.reload).not.toHaveBeenCalled();
  expect(blocked.button.hidden).toBe(false);
  blocked.clickRetry();
  expect(blocked.location.reload).toHaveBeenCalledOnce();
});

it("recovers an incomplete HTML stream before the engine watchdog without a reload loop", () => {
  const first = openDocument(new Map(), false, { streamingHtml: true, missingBootstrap: true });
  vi.advanceTimersByTime(12000);
  expect(first.status.textContent).toContain("请稍候");
  expect(first.location.reload).not.toHaveBeenCalled();
  vi.advanceTimersByTime(8700);
  expect(first.location.reload).toHaveBeenCalledOnce();
  const second = openDocument(first.storage, false, { streamingHtml: true, missingBootstrap: true });
  vi.advanceTimersByTime(180000);
  expect(second.location.reload).not.toHaveBeenCalled();
  expect(second.button.hidden).toBe(false);
  expect(second.status.textContent).toContain("页面加载失败");
});

it("keeps waiting for a slow engine when the streamed HTML already contains its build configuration", () => {
  const page = openDocument(new Map(), false, { streamingHtml: true });
  vi.advanceTimersByTime(60000);
  expect(page.location.reload).not.toHaveBeenCalled();
  page.boot.ready();
  vi.advanceTimersByTime(120000);
  expect(page.location.reload).not.toHaveBeenCalled();
});

it("shows the app when the official JS fallback succeeds after a Wasm import failure", async () => {
  const first = openDocument();
  first.startFlutter(vi.fn(async (_options: any) => { throw Error("Wasm import failed"); }));
  await vi.advanceTimersByTimeAsync(700);
  const second = openDocument(first.storage);
  const runApp = vi.fn(async () => { second.boot.ready(); });
  const initializeEngine = vi.fn(async (_config: any) => ({ runApp }));
  second.startFlutter(vi.fn(async (options: any) => { await options.onEntrypointLoaded({ initializeEngine }); }));
  await vi.advanceTimersByTimeAsync(180000);
  expect(initializeEngine.mock.calls[0][0].renderer).toBe("canvaskit");
  expect(runApp).toHaveBeenCalledOnce();
  expect(second.startup.remove).toHaveBeenCalledOnce();
  expect(second.storage.has(recoveryKey)).toBe(false);
  expect(second.location.reload).not.toHaveBeenCalled();
});

it.each(["entrypoint", "engine", "runApp"])("retries a %s failure once and limits renderer fallback to entrypoint/engine failures", async (failure) => {
  const first = openDocument(new Map(), false, { url: "https://fate.example/thai-landing/report.html?lang=zh&id=retained-report#section" });
  const load = first.startFlutter(vi.fn(async (options: any) => {
    if (failure === "entrypoint") throw Error("Wasm import failed");
    await options.onEntrypointLoaded({ initializeEngine: async () => {
      if (failure === "engine") throw Error("Skwasm failed");
      return { runApp: async () => { throw Error("runApp failed"); } };
    } });
  }));
  expect(load.mock.calls[0][0].config.renderer).toBeUndefined();
  await vi.advanceTimersByTimeAsync(700);
  expect(first.location.reload).toHaveBeenCalledOnce();
  expect(first.location.href).toBe("https://fate.example/thai-landing/report.html?lang=zh&id=retained-report#section");

  const second = openDocument(first.storage, false, { url: first.location.href });
  const initializeEngine = vi.fn(async (_config: any) => { throw Error("JS engine failed too"); });
  const compatibilityLoad = second.startFlutter(vi.fn(async (options: any) => {
    await options.onEntrypointLoaded({ initializeEngine });
  }));
  const renderer = failure === "runApp" ? undefined : "canvaskit";
  expect(compatibilityLoad.mock.calls[0][0].config.renderer).toBe(renderer);
  await vi.advanceTimersByTimeAsync(180000);
  expect(initializeEngine.mock.calls[0][0]).toEqual({ canvasKitBaseUrl: "engine/test-engine/", ...(renderer ? { renderer } : {}) });
  expect(second.location.reload).not.toHaveBeenCalled();
  expect(second.button.hidden).toBe(false);
  expect(second.status.textContent).toContain("页面加载失败");
});

it("retries an app-font failure without forcing CanvasKit, even after the slow hint, and shares the one-retry limit", () => {
  const first = openDocument();
  first.boot.stage("app");
  vi.advanceTimersByTime(12000);
  expect(first.status.textContent).toContain("请稍候");
  first.emit("unhandledrejection", { reason: Error("UI font failed") });
  vi.advanceTimersByTime(700);
  expect(first.location.reload).toHaveBeenCalledOnce();

  const second = openDocument(first.storage);
  const load = second.startFlutter();
  expect(second.boot.compatibility).toBe(false);
  expect(load.mock.calls[0][0].config.renderer).toBeUndefined();
  second.boot.stage("app");
  vi.setSystemTime(new Date(Date.now() + 180000));
  second.emit("unhandledrejection", { reason: Error("UI font failed again") });
  vi.advanceTimersByTime(180000);
  expect(second.location.reload).not.toHaveBeenCalled();
  expect(second.status.textContent).toContain("页面加载失败");
  expect(second.button.hidden).toBe(false);
});

it("recovers an unresolved startup after the watchdog, without a retry loop", () => {
  const first = openDocument();
  first.startFlutter();
  vi.advanceTimersByTime(89999);
  expect(first.location.reload).not.toHaveBeenCalled();
  expect(first.status.textContent).toContain("请稍候");
  vi.advanceTimersByTime(701);
  expect(first.location.reload).toHaveBeenCalledOnce();
  const second = openDocument(first.storage);
  // Even a suspended tab whose watchdog runs after the marker expires has spent its retry.
  vi.setSystemTime(new Date(Date.now() + 180000));
  vi.advanceTimersByTime(180000);
  expect(second.location.reload).not.toHaveBeenCalled();
  expect(second.button.hidden).toBe(false);
  expect(second.status.textContent).toContain("页面加载失败");
});

it.each(["error", "unhandledrejection"])("recovers a pre-ready %s while ignoring ordinary image failures", (type) => {
  const page = openDocument();
  page.emit("error", { target: { tagName: "IMG", src: "portrait.webp" } });
  expect(page.storage.has(recoveryKey)).toBe(false);
  page.emit(type, type === "error" ? { error: Error("engine failed") } : { reason: Error("engine promise failed") });
  vi.advanceTimersByTime(700);
  expect(page.location.reload).toHaveBeenCalledOnce();
});

it("handles callback-mode JavaScript entrypoint fetch errors", () => {
  const page = openDocument();
  page.emit("error", { target: { tagName: "SCRIPT", src: "https://fate.example/thai-landing/main.dart.js" } });
  vi.advanceTimersByTime(700);
  expect(page.location.reload).toHaveBeenCalledOnce();
});

it("recovers inline bootstrap syntax errors and offers retry before DOMContentLoaded", () => {
  const truncated = openDocument();
  truncated.emit("error", { message: "Uncaught SyntaxError: Unexpected end of input" });
  vi.advanceTimersByTime(700);
  expect(truncated.location.reload).toHaveBeenCalledOnce();
  const slowStream = openDocument();
  vi.advanceTimersByTime(12000);
  expect(slowStream.button.hidden).toBe(false);
  slowStream.clickRetry();
  expect(slowStream.location.reload).toHaveBeenCalledOnce();
});

it("still consumes the only compatibility retry if the reload document arrives after its original TTL", () => {
  const first = openDocument();
  first.boot.fail();
  vi.setSystemTime(new Date(Date.now() + 180000));
  const second = openDocument(first.storage);
  expect(second.boot.compatibility).toBe(true);
  vi.advanceTimersByTime(180000);
  expect(second.location.reload).not.toHaveBeenCalled();
  expect(second.status.textContent).toContain("页面加载失败");
});

it("expires compatibility preferences for later visits and keeps them scoped to one pathname", () => {
  const page = openDocument();
  page.boot.fail();
  expect(openDocument(page.storage).boot.compatibility).toBe(true);
  expect(openDocument(page.storage, false, { url: "http://127.0.0.1/other/" }).boot.compatibility).toBe(false);
  vi.setSystemTime(new Date(Date.now() + 120001));
  const later = openDocument(page.storage);
  const load = later.startFlutter();
  expect(later.boot.compatibility).toBe(false);
  expect(load.mock.calls[0][0].config.renderer).toBeUndefined();
});

it("does not start Flutter while the HTTP owner is being migrated", () => {
  const page = openDocument(new Map(), false, { url: "http://129.226.126.212/thai-landing/?lang=zh" });
  const load = page.startFlutter();
  vi.advanceTimersByTime(180000);
  expect(load).not.toHaveBeenCalled();
  expect(page.location.reload).not.toHaveBeenCalled();
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
