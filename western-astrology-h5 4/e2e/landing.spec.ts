import { test, expect, type Page } from "@playwright/test";
import { readFile, writeFile } from "node:fs/promises";
import { ui, type Language } from "../src/lib/reading";
import { generationCopy, lifeCopy, type LifeInput, type LifeReport } from "../src/lib/lifeReport";
import { bangkokProvince, place, readyPreviewFixture, reportFixture } from "../tests/fixtures/lifeReport";

// Synthetic fixtures test presentation and transport without consuming paid generation.


async function start(page: Page, language: Language = "zh") {
  await page.goto(`?lang=${language}`, { waitUntil: "domcontentloaded" });
  await page.locator("#birth-date").fill("1995-08-17");
  await page.locator("#birth-time").fill("09:30");
  await page.locator("#birth-country").fill("Thailand");
  await page.locator("#birth-province").fill("Bangkok");
  await page.locator("#birth-city").fill("Bangkok");
  await page.locator(`[data-place-id="${place.id}"]`).click();
}
async function generate(page: Page, language: Language = "zh") {
  await page.getByRole("button", { name: lifeCopy[language].generate, exact: true }).click();
  await expect(page).toHaveURL(/\/report\.html\?id=/);
  await expect(page.getByTestId("life-report")).toBeVisible();
}
for (const language of ["zh", "th"] as const) {
  test(`life report three free sections five paid sections direct unlock and exports in ${language}`, async ({ page }, info) => {
    const errors: string[] = [];
    page.on("pageerror", error => errors.push(error.message));
    const api = await routes(page);
    const c = lifeCopy[language];
    await start(page, language); await generate(page, language);
    await expect(page.getByRole("heading", { name: c.title, exact: true })).toBeVisible();
    await expect(page.getByTestId("life-free-traits").locator("article")).toHaveCount(3);
    await expect(page.getByTestId("life-catalog").locator("button")).toHaveCount(8);
    await expect(page.getByTestId("life-report")).not.toContainText("付费专属分析正文");
    await expect(page.getByTestId("life-unlock-offer")).toContainText("¥300");
    await expect(page.getByTestId("life-unlock-offer")).toContainText(c.direct);
    expect(api.received[0].profile.location_id).toBe(place.id);
    expect(api.received[0].profile.language).toBe(language);
    expect((api.received[0] as LifeInput & { reading?: string }).reading).toBeUndefined();
    await page.getByRole("button", { name: c.feedbackOptions[1], exact: true }).click();
    await expect(page.getByRole("button", { name: c.feedbackOptions[1], exact: true })).toHaveAttribute("aria-pressed", "true");
    const previewPromise = page.waitForEvent("download");
    await page.getByRole("button", { name: c.savePreview, exact: true }).click();
    const preview = await previewPromise;
    expect(await readFile((await preview.path())!, "utf8")).not.toContain("付费专属分析正文");
    await page.locator(".life-report-cover").screenshot({ path: `test-results/life-cover-${language}-${info.project.name}.png` });
    await page.getByTestId("life-unlock-offer").screenshot({ path: `test-results/life-offer-${language}-${info.project.name}.png` });
    await page.getByTestId("life-unlock-button").click();
    await expect(page.getByTestId("life-full-report")).toBeVisible();
    await expect(page.locator('[data-testid^="life-section-"]')).toHaveCount(4);
    await expect(page.getByTestId("life-action-plan")).toBeVisible();
    await expect(page.getByTestId("life-unlock-button")).toHaveCount(0);
    await expect(page.locator(".report-unlock-bar")).toHaveCount(0);
    const fullPromise = page.waitForEvent("download");
    await page.getByRole("button", { name: c.save, exact: true }).first().click();
    const full = await fullPromise;
    const text = await readFile((await full.path())!, "utf8");
    expect(text).toContain(c.plan);
    if (language === "zh") expect(text).toContain("付费专属分析正文");
    await page.getByTestId("life-section-work").screenshot({ path: `test-results/life-work-${language}-${info.project.name}.png` });
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    await expect(page.locator(".reading-section, #reading-dialog, [data-card]")).toHaveCount(0);
    expect(errors).toEqual([]);
  });
}

test("new reports default to the current year without a year field and retain birth input across languages", async ({ page }) => {
  const api = await routes(page);
  await start(page);
  const currentYear = await page.evaluate(() => new Date().getFullYear());
  await expect(page.locator("#reading-year")).toHaveCount(0);
  await expect(page.locator("#birth-form")).not.toContainText("要查看的年份");
  await expect(page.locator("#birth-form")).not.toContainText("所选公历年份");
  await page.locator("#unknown-time").check();
  await expect(page.getByRole("button", { name: lifeCopy.zh.generate, exact: true })).toBeEnabled();
  await expect(page.locator("#time-note")).toContainText("部分解读可能存在偏差");
  await page.locator("#unknown-time").uncheck();
  await page.locator('[data-lang="th"]').click();
  await expect(page.getByTestId("life-report")).toHaveCount(0);
  await expect(page.locator("#birth-date")).toHaveValue("1995-08-17");
  await expect(page.locator("#reading-year")).toHaveCount(0);
  await generate(page, "th");
  expect(api.received[0].profile.language).toBe("th");
  expect(api.received[0].year).toBe(currentYear);
});

test("cancelled and superseded requests cannot display an outdated report", async ({ page }) => {
  await routes(page);
  let release!: () => void;
  const waiting = new Promise<void>(resolve => { release = resolve; });
  let started!: () => void;
  const sent = new Promise<void>(resolve => { started = resolve; });
  await page.route(/\/api\/life-reports(?:\?.*)?$/, async route => {
    const input = route.request().postDataJSON();
    started(); await waiting;
    await route.fulfill({ json: reportFixture(input) }).catch(() => {});
  });
  await start(page);
  await page.getByRole("button", { name: lifeCopy.zh.generate, exact: true }).click();
  await sent;
  await page.getByRole("button", { name: generationCopy.zh.cancel, exact: true }).click();
  await page.locator("#birth-time").fill("10:15"); release();
  await expect(page.getByTestId("report-generation")).toHaveCount(0);
  await expect(page).not.toHaveURL(/report\.html/);
  await expect(page.getByTestId("life-report")).toHaveCount(0);
});

for (const language of ["zh", "th"] as const) {
  test(`unknown birth time can generate unlock export and reopen with its estimate warning in ${language}`, async ({ page }) => {
    const api = await routes(page);
    await start(page, language);
    await page.locator("#birth-time").fill("");
    await page.locator("#unknown-time").check();
    await expect(page.locator("#birth-time")).toBeDisabled();
    await expect(page.locator("#time-note")).toHaveText(ui[language].timeNote);
    await generate(page, language);
    expect(api.received[0].profile.birth_time).toBeNull();
    await expect(page.getByTestId("report-time-note")).toHaveText(ui[language].timeNote);
    await expect(page.locator(".life-report-cover")).toContainText(lifeCopy[language].timeUnknown);
    await page.getByTestId("life-unlock-button").click();
    await expect(page.getByTestId("life-action-plan")).toBeVisible();
    const download = page.waitForEvent("download");
    await page.getByRole("button", { name: lifeCopy[language].save, exact: true }).first().click();
    const html = await readFile((await (await download).path())!, "utf8");
    expect(html).toContain(ui[language].timeNote);
    expect(html).toContain(lifeCopy[language].timeUnknown);
    await page.reload();
    await expect(page.getByTestId("report-time-note")).toHaveText(ui[language].timeNote);
    await page.getByRole("link", { name: generationCopy[language].back, exact: true }).click();
    await page.getByRole("button", { name: lifeCopy[language].history, exact: true }).click();
    await page.getByRole("dialog").getByRole("button").filter({ hasText: lifeCopy[language].open }).click();
    await expect(page).toHaveURL(/report\.html/);
    await expect(page.getByTestId("report-time-note")).toHaveText(ui[language].timeNote);
  });
}

test("a failed preview stays in its animation with its actual error and can retry", async ({ page }) => {
  const api = await routes(page);
  let attempts = 0;
  await page.route(/\/api\/life-reports(?:\?.*)?$/, route => {
    const report = readyPreviewFixture(route.request().postDataJSON());
    if (++attempts === 1) { report.preview = null; report.preview_state = "unavailable"; }
    api.replaceReport(report);
    return route.fulfill({ json: report });
  });
  await start(page);
  await page.getByRole("button", { name: lifeCopy.zh.generate, exact: true }).click();
  await expect(page.locator("#form-error")).toContainText(lifeCopy.zh.previewStates.unavailable);
  await expect(page.getByTestId("report-generation")).toContainText(lifeCopy.zh.previewStates.unavailable);
  await expect(page).not.toHaveURL(/report\.html/);
  await expect(page.getByTestId("life-free-traits")).toHaveCount(0);
  await expect(page.getByTestId("life-unlock-button")).toHaveCount(0);
  await expect(page.locator("#birth-date")).toHaveValue("1995-08-17");
  await expect(page.locator("#birth-time")).toHaveValue("09:30");
  await page.getByRole("button", { name: lifeCopy.zh.retry, exact: true }).click();
  await expect(page.getByTestId("life-free-traits").locator("article")).toHaveCount(3);
  expect(attempts).toBe(2);
});

test("form and report share the dark purple palette at a narrow width", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 760 });
  await routes(page); await start(page);
  const themes = page.getByTestId("life-themes");
  await expect(themes.locator("article")).toHaveCount(6);
  const buttonBox = await page.getByRole("button", { name: lifeCopy.zh.generate, exact: true }).boundingBox();
  const themesBox = await themes.boundingBox();
  expect(buttonBox!.y + buttonBox!.height).toBeLessThan(themesBox!.y);
  for (const language of ["zh", "th"] as const) {
    await page.locator(`[data-lang="${language}"]`).click();
    await page.evaluate(() => document.fonts.ready);
    const cards = await themes.locator("article").evaluateAll(nodes => nodes.map(node => {
      const style = getComputedStyle(node), box = node.getBoundingClientRect();
      return { background: style.background, border: style.borderColor, shadow: style.boxShadow, width: box.width, height: box.height, fits: node.scrollHeight <= node.clientHeight + 1 };
    }));
    expect(new Set(cards.map(card => `${card.background}|${card.border}|${card.shadow}`)).size).toBe(1);
    expect(cards.every(card => Math.abs(card.height - card.width) < 1 && card.fits)).toBe(true);
  }
  await page.locator('[data-lang="zh"]').click();
  const colors = await page.locator("#birth-date,#birth-time,#birth-country,#birth-province,#birth-city").evaluateAll(nodes => nodes.map(node => ({ background: getComputedStyle(node).backgroundColor, color: getComputedStyle(node).color, scheme: getComputedStyle(node).colorScheme })));
  expect(colors.every(value => value.background === "rgb(19, 12, 36)" && value.color === "rgb(255, 245, 223)" && value.scheme === "dark")).toBe(true);
  expect(await page.locator(".form-section").evaluate(node => getComputedStyle(node).color)).toBe("rgb(255, 245, 223)");
  await generate(page);
  await page.getByTestId("life-unlock-button").click();
  await expect(page.getByTestId("life-action-plan")).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});

async function routes(page: Page) {
  let report: LifeReport | undefined;
  const received: LifeInput[] = [];
  await page.route("**/api/thai-locations?*", route => route.fulfill({ json: { items: new URL(route.request().url()).searchParams.get("level") === "province" ? [bangkokProvince] : [place], total: 1 } }));
  await page.route("**/api/life-reports**", async route => {
    const request = route.request();
    const path = new URL(request.url()).pathname;
    if (path.endsWith("/feedback")) {
      const rating = request.postDataJSON().rating;
      if (report) report.feedback = rating;
      return route.fulfill({ json: { rating } });
    }
    if (path.endsWith("/unlock")) {
      report = reportFixture(report!.input, true);
      return route.fulfill({ json: report });
    }
    if (request.method() === "POST") {
      const input = request.postDataJSON() as LifeInput;
      received.push(input);
      expect(request.headers()["x-report-key"]).toMatch(/^[A-Za-z0-9_-]{32,128}$/);
      report = reportFixture(input);
      return route.fulfill({ json: report });
    }
    return route.fulfill({ json: path === "/api/life-reports" ? { items: report ? [report] : [] } : report });
  });
  return { received, replaceReport(value: LifeReport) { report = value; } };
}
test("saved reports retain their original year and new reports default to the current year", async ({ page }) => {
  const api = await routes(page);
  await start(page); await generate(page);
  await page.getByTestId("life-unlock-button").click();
  await expect(page.getByTestId("life-action-plan")).toBeVisible();
  const currentYear = api.received[0].year;
  const saved = reportFixture({ ...api.received[0], year: currentYear - 1 }, true);
  api.replaceReport(saved);
  const key = await page.evaluate(() => localStorage.getItem("astro-life-report-key"));
  await page.getByRole("link", { name: generationCopy.zh.back, exact: true }).click();
  await page.getByRole("button", { name: lifeCopy.zh.history, exact: true }).click();
  await page.getByRole("dialog").getByRole("button").filter({ hasText: lifeCopy.zh.open }).click();
  await expect(page.getByTestId("life-action-plan")).toBeVisible();
  await expect(page.locator(".life-report-cover")).toContainText(String(saved.input.year));
  expect(await page.evaluate(() => localStorage.getItem("astro-life-report-key"))).toBe(key);
  await start(page);
  await generate(page);
  expect(api.received[1].year).toBe(currentYear);
});

test("reopening the displayed report applies a newer snapshot from history", async ({ page }) => {
  const api = await routes(page);
  await start(page); await generate(page);
  api.replaceReport(reportFixture(api.received[0], true));
  await page.getByRole("link", { name: generationCopy.zh.back, exact: true }).click();
  await page.getByRole("button", { name: lifeCopy.zh.history, exact: true }).click();
  await page.getByRole("dialog").getByRole("button").filter({ hasText: lifeCopy.zh.open }).click();
  await expect(page.getByTestId("life-action-plan")).toBeVisible();
  await expect(page.getByTestId("life-unlock-button")).toHaveCount(0);
});

test("progressive generation retains finished chapters and can resume after interruption", async ({ page }) => {
  const api = await routes(page);
  await start(page); await generate(page);
  let unlocks = 0;
  await page.route("**/api/life-reports/*/unlock", route => {
    const report = reportFixture(api.received[0], true);
    if (++unlocks === 1) {
      report.full_state = "generating"; report.chapters = report.chapters.slice(0, 1);
      report.plan = null; report.progress.completed = 1;
    }
    return route.fulfill({ json: report });
  });
  await page.route("**/api/life-reports/11112222333344445555666677778888", route => {
    const report = reportFixture(api.received[0], true);
    report.full_state = "unavailable"; report.chapters = report.chapters.slice(0, 2);
    report.plan = null; report.progress.completed = 2;
    return route.fulfill({ json: report });
  });
  await page.getByTestId("life-unlock-button").click();
  await expect(page.getByTestId("report-generation")).toContainText(lifeCopy.zh.states.unavailable);
  await expect(page.getByRole("progressbar")).toHaveAttribute("aria-valuenow", "40");
  await page.getByRole("button", { name: lifeCopy.zh.retry, exact: true }).click();
  await expect(page.getByTestId("life-action-plan")).toBeVisible();
  await expect(page.locator('[data-testid^="life-section-"]')).toHaveCount(4);
});

for (const language of ["zh", "th"] as const) {
  test(`PDF download exports free and unlocked contents in ${language}`, async ({ page, context }, info) => {
    test.setTimeout(90_000);
    await context.addInitScript(() => Object.defineProperty(window, "showSaveFilePicker", { value: undefined, configurable: true }));
    const errors: string[] = [];
    page.on("pageerror", error => errors.push(error.message));
    const api = await routes(page);
    // Even a stale over-shared snapshot must not put paid content into a free PDF.
    await page.route(/\/api\/life-reports(?:\?.*)?$/, route => {
      if (route.request().method() !== "POST") return route.fallback();
      const input = route.request().postDataJSON() as LifeInput;
      api.received.push(input);
      const report = { ...reportFixture(input, true), access: "preview" as const };
      api.replaceReport(report);
      return route.fulfill({ json: report });
    });
    await start(page, language); await generate(page, language);
    for (const version of ["preview", "full"] as const) {
      if (version === "full") {
        await page.getByTestId("life-unlock-button").click();
        await expect(page.getByTestId("life-action-plan")).toBeVisible();
      }
      const pending = page.waitForEvent("download", { timeout: 60_000 });
      await page.getByTestId("life-pdf-button").click();
      const download = await pending;
      expect(download.suggestedFilename()).toBe(`Life-Report-11112222333344445555666677778888-${version}.pdf`);
      const path = info.outputPath(`${version}-${language}.pdf`);
      await download.saveAs(path);
      const bytes = await readFile(path);
      expect(bytes.subarray(0, 5).toString()).toBe("%PDF-");
      expect(bytes.length).toBeGreaterThan(10_000);
      await expect(page.getByTestId("life-report")).toContainText(lifeCopy[language].pdfDownloaded);
    }
    expect(api.received).toHaveLength(1);
    expect(errors).toEqual([]);
  });
}

test("PDF native picker chooses the file before generation and closes the saved file", async ({ page, context }, info) => {
  test.setTimeout(60_000);
  await context.addInitScript(() => {
    const state = { filename: "", active: false, closed: false, base64: "" };
    Object.assign(window, { pdfSaveTest: state });
    Object.defineProperty(window, "showSaveFilePicker", { configurable: true, value: async (options: { suggestedName: string }) => {
      state.filename = options.suggestedName;
      state.active = navigator.userActivation.isActive;
      return { createWritable: async () => ({
        write: async (blob: Blob) => { state.base64 = await new Promise<string>((resolve, reject) => { const reader = new FileReader(); reader.onload = () => resolve(String(reader.result).split(",")[1]); reader.onerror = reject; reader.readAsDataURL(blob); }); },
        close: async () => { state.closed = true; }, abort: async () => undefined,
      }) };
    } });
  });
  await routes(page); await start(page); await generate(page);
  await page.getByTestId("life-pdf-button").click();
  await expect(page.getByTestId("life-report")).toContainText(lifeCopy.zh.pdfSaved, { timeout: 45_000 });
  const saved = await page.evaluate(() => (window as Window & { pdfSaveTest: { filename: string; active: boolean; closed: boolean; base64: string } }).pdfSaveTest);
  expect(saved.active && saved.closed).toBe(true);
  expect(saved.filename).toMatch(/-preview\.pdf$/);
  const bytes = Buffer.from(saved.base64, "base64");
  expect(bytes.subarray(0, 5).toString()).toBe("%PDF-");
  await writeFile(info.outputPath("native-preview.pdf"), bytes);
});

test("cancelling the PDF location picker does not generate or download a file", async ({ page, context }) => {
  await context.addInitScript(() => Object.defineProperty(window, "showSaveFilePicker", { value: async () => { throw new DOMException("Cancelled", "AbortError"); }, configurable: true }));
  let fonts = 0;
  let downloads = 0;
  page.on("request", request => { if (request.url().includes("/fonts/pdf/")) fonts++; });
  page.on("download", () => downloads++);
  await routes(page); await start(page); await generate(page);
  await page.getByTestId("life-pdf-button").click();
  await expect(page.getByTestId("life-pdf-button")).toBeEnabled();
  await expect(page.getByRole("alert")).toHaveCount(0);
  expect(fonts).toBe(0);
  expect(downloads).toBe(0);
});

test("free reports do not poll or start paid generation before the user unlocks", async ({ page }) => {
  const api = await routes(page);
  let reads = 0;
  page.on("request", request => { if (request.method() === "GET" && /api\/life-reports\/[a-f0-9]+$/.test(request.url())) reads++; });
  await start(page); await generate(page);
  await expect(page.getByTestId("life-background-status")).toHaveText(lifeCopy.zh.backgroundRetry);
  await page.clock.install(); await page.clock.fastForward(60_000);
  expect(reads).toBe(1);
  await expect(page.getByTestId("report-generation")).toHaveCount(0);
  await expect(page.getByTestId("life-full-report")).toHaveCount(0);
  await page.getByTestId("life-unlock-button").click();
  await expect(page.getByTestId("life-action-plan")).toBeVisible();
  expect(api.received).toHaveLength(1);
});
