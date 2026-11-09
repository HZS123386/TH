import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { generateLifeReport, unlockLifeReport, generationCopy, lifeReportPollInterval, previewGenerationProgress, reportGenerationProgress, type GenerationProgress } from "./lifeReport";
import { ApiError, api } from "./reading";
import { reportFixture } from "../../tests/fixtures/lifeReport";

describe("confirmed report generation progress", () => {
  it("advances inside a section while no complete paid section has finished", () => {
    const report = reportFixture();
    report.full_state = "generating";
    const sections = (["work", "money", "relationships", "annual", "plan"] as const).map(key => ({ key, percent: key === "work" ? 35 : 0 }));
    report.generation_progress = { percent: 7, sections };
    expect(report.progress.completed).toBe(0);
    expect(reportGenerationProgress(report)).toMatchObject({ percent: 7, sections });
    report.generation_progress = { percent: 14, sections: sections.map(section => ({ ...section, percent: section.key === "work" ? 70 : 0 })) };
    expect(reportGenerationProgress(report).percent).toBe(14);
  });
  it("counts paid content independently from the already generated preview", () => {
    const report = reportFixture();
    report.full_state = "generating";
    expect(reportGenerationProgress(report)).toMatchObject({ percent: 0, completed: 0, total: 100, phase: "full" });
    report.progress.completed = 2;
    expect(reportGenerationProgress(report)).toMatchObject({ percent: 40, completed: 40, total: 100 });
    report.progress.completed = 4;
    expect(reportGenerationProgress(report).percent).toBe(80);
  });

  it("reaches 100 only after the preview and all sections are ready", () => {
    const report = reportFixture(undefined, true);
    report.full_state = "generating";
    expect(reportGenerationProgress(report).percent).toBe(99);
    report.full_state = "ready";
    expect(reportGenerationProgress(report)).toMatchObject({ percent: 100, phase: "ready" });
    report.preview = null; report.preview_state = "generating";
    expect(reportGenerationProgress(report)).toMatchObject({ percent: 99, phase: "preview" });
  });

  it("uses the server's total and rejects impossible counters", () => {
    const report = reportFixture();
    report.progress = { completed: 1, total: 3 };
    expect(reportGenerationProgress(report)).toMatchObject({ percent: 33, completed: 33, total: 100 });
    for (const progress of [{ completed: -1, total: 5 }, { completed: 6, total: 5 }, { completed: 0, total: 0 }, { completed: 1.5, total: 5 }]) {
      expect(() => reportGenerationProgress({ ...report, progress })).toThrow();
    }
  });
});

describe("report polling and rate limits", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    const values = new Map<string, string>();
    const storage = { getItem: (key: string) => values.get(key) ?? null, setItem: (key: string, value: string) => values.set(key, value) };
    vi.stubGlobal("window", { localStorage: storage, sessionStorage: storage, setTimeout, clearTimeout });
  });
  afterEach(() => { vi.useRealTimers(); vi.unstubAllGlobals(); });

  const json = (value: unknown, status = 200, retryAfter?: string) => new Response(JSON.stringify(value), {
    status, headers: { "Content-Type": "application/json", ...(retryAfter ? { "Retry-After": retryAfter } : {}) },
  });
  function generating() {
    const report = reportFixture();
    report.full_state = "generating"; report.access = "full";
    report.progress.completed = 1;
    return report;
  }

  it("returns a cached free preview without requesting any paid content", async () => {
    const report = reportFixture();
    const fetch = vi.fn().mockResolvedValue(json(report));
    vi.stubGlobal("fetch", fetch);
    expect(await generateLifeReport(report.input, new AbortController().signal)).toMatchObject({ access: "preview", full_state: "not_started" });
    await vi.advanceTimersByTimeAsync(60_000);
    expect(fetch).toHaveBeenCalledTimes(1);
    expect(fetch.mock.calls[0][0]).toBe("/api/life-reports?wait=false");
  });

  it("follows in-progress free content and stops at the free preview without unlocking", async () => {
    const report = reportFixture();
    report.preview = null; report.preview_state = "generating";
    const sections = (["preview_summary", "preview_strength", "preview_decisions", "preview_relationships"] as const).map(key => ({ key, percent: key === "preview_summary" ? 12 : 0 }));
    const early = { ...report, preview_generation_progress: { percent: 3, sections } };
    const later = { ...report, preview_generation_progress: { percent: 5, sections: sections.map(section => ({ ...section, percent: section.key === "preview_summary" ? 20 : 0 })) } };
    expect(previewGenerationProgress(early).percent).toBe(3);
    const fetch = vi.fn().mockResolvedValueOnce(json(early)).mockResolvedValueOnce(json(later)).mockResolvedValueOnce(json(reportFixture(report.input)));
    vi.stubGlobal("fetch", fetch);
    const values: number[] = [];
    const waiting = generateLifeReport(report.input, new AbortController().signal, progress => values.push(progress.percent));
    await vi.advanceTimersByTimeAsync(lifeReportPollInterval);
    expect(values).toEqual([3, 5]);
    await vi.advanceTimersByTimeAsync(lifeReportPollInterval);
    expect((await waiting).full_state).toBe("not_started");
    expect(values).toEqual([3, 5, 100]);
    expect(fetch.mock.calls.some(call => String(call[0]).endsWith("/unlock"))).toBe(false);
  });

  it("keeps a long generation within the real API's 30-read minute limit", async () => {
    const report = generating(), reads: number[] = [];
    let ready = false;
    vi.stubGlobal("fetch", vi.fn(async (_url: string, init: RequestInit) => {
      if (init.method === "GET") reads.push(Date.now());
      return json(ready ? reportFixture(report.input, true) : report);
    }));
    const progress = vi.fn();
    const waiting = unlockLifeReport(report, new AbortController().signal, progress);
    await vi.advanceTimersByTimeAsync(60_000);
    expect(reads.length).toBeGreaterThan(0);
    expect(reads.length).toBeLessThan(30);
    expect(progress).toHaveBeenLastCalledWith(expect.objectContaining({ percent: 20, phase: "full" }));
    ready = true;
    await vi.advanceTimersByTimeAsync(lifeReportPollInterval);
    expect((await waiting).full_state).toBe("ready");
    expect(progress).toHaveBeenLastCalledWith(expect.objectContaining({ percent: 100, phase: "ready" }));
  });

  it("honors repeated Retry-After responses without losing progress or stopping generation", async () => {
    const report = generating();
    const fetch = vi.fn().mockResolvedValueOnce(json(report));
    for (let i = 0; i < 4; i++) fetch.mockResolvedValueOnce(json({ detail: "too_many_requests" }, 429, "60"));
    fetch.mockResolvedValueOnce(json(reportFixture(report.input, true)));
    vi.stubGlobal("fetch", fetch);
    const values: GenerationProgress[] = [];
    const waiting = unlockLifeReport(report, new AbortController().signal, progress => values.push(progress));
    await vi.advanceTimersByTimeAsync(lifeReportPollInterval);
    expect(values.at(-1)).toMatchObject({ percent: 20, phase: "waiting" });
    for (let count = 2; count <= 5; count++) {
      await vi.advanceTimersByTimeAsync(59_999);
      expect(fetch).toHaveBeenCalledTimes(count);
      await vi.advanceTimersByTimeAsync(1);
      expect(fetch).toHaveBeenCalledTimes(count + 1);
    }
    expect((await waiting).full_state).toBe("ready");
    expect(values.filter(value => value.phase === "waiting")).toHaveLength(4);
  });

  it("uses a safe wait when a throttled server omits Retry-After and can cancel that wait", async () => {
    const report = generating();
    const fetch = vi.fn().mockResolvedValueOnce(json(report)).mockResolvedValueOnce(json({ detail: "too_many_requests" }, 429));
    vi.stubGlobal("fetch", fetch);
    const controller = new AbortController();
    const waiting = unlockLifeReport(report, controller.signal, vi.fn());
    const stopped = expect(waiting).rejects.toMatchObject({ name: "AbortError" });
    await vi.advanceTimersByTimeAsync(lifeReportPollInterval + 59_999);
    expect(fetch).toHaveBeenCalledTimes(2);
    controller.abort();
    await stopped;
    await vi.advanceTimersByTimeAsync(60_000);
    expect(fetch).toHaveBeenCalledTimes(2);
  });

  it("backs off ordinary connection errors and describes a progress-query failure accurately", async () => {
    const report = generating();
    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(json(report)).mockRejectedValue(new TypeError("offline")));
    const waiting = unlockLifeReport(report, new AbortController().signal, vi.fn());
    const failed = expect(waiting).rejects.toThrow(generationCopy.zh.queryError);
    await vi.advanceTimersByTimeAsync(lifeReportPollInterval * 7);
    await failed;
  });

  it.each(["12", new Date(Date.now() + 12_000).toUTCString()])("retains status and Retry-After metadata from HTTP errors (%s)", async value => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(json({ detail: "limited" }, 429, value)));
    const error = await api("/api/test", "zh", new AbortController().signal).catch(cause => cause);
    expect(error).toBeInstanceOf(ApiError);
    if (!(error instanceof ApiError)) throw error;
    expect(error.status).toBe(429);
    expect(error.retryAfterMs).toBeGreaterThan(10_000);
    expect(error.retryAfterMs).toBeLessThanOrEqual(12_000);
  });
});
