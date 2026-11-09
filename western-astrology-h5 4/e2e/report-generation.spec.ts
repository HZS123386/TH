import { expect, test, type Page } from "@playwright/test";
import { generationCopy, lifeCopy, type LifeInput } from "../src/lib/lifeReport";
import { bangkokProvince, inputFor, place, reportFixture } from "../tests/fixtures/lifeReport";

async function fillBirth(page: Page) {
  await page.route("**/api/thai-locations?*", route => route.fulfill({ json: {
    items: new URL(route.request().url()).searchParams.get("level") === "province" ? [bangkokProvince] : [place], total: 1,
  } }));
  await page.goto("?lang=zh", { waitUntil: "domcontentloaded" });
  await page.locator("#birth-date").fill("1995-08-17");
  await page.locator("#birth-time").fill("09:30");
  await page.locator("#birth-country").fill("Thailand");
  await page.locator("#birth-province").fill("Bangkok");
  await page.locator("#birth-city").fill("Bangkok");
  await page.locator(`[data-place-id="${place.id}"]`).click();
}

async function showFreeReport(page: Page) {
  await fillBirth(page);
  await page.getByRole("button", { name: lifeCopy.zh.generate, exact: true }).click({ force: true });
  await expect(page).toHaveURL(/report\.html/);
  await expect(page.getByTestId("life-free-traits").locator("article")).toHaveCount(3);
  await expect(page.getByTestId("report-generation")).toHaveCount(0);
}
function partial(input: LifeInput, percent: number) {
  const report = { ...reportFixture(input), access: "full" as const, full_state: "generating" as const };
  report.generation_progress = { percent, sections: [
    {key: "work", percent: Math.min(100, percent * 5)}, {key: "money", percent: Math.max(0, Math.min(100, percent * 5 - 100))},
    {key: "relationships", percent: Math.max(0, Math.min(100, percent * 5 - 200))},
    {key: "annual", percent: Math.max(0, Math.min(100, percent * 5 - 300))}, {key: "plan", percent: Math.max(0, percent * 5 - 400)},
  ] };
  return report;
}

test("unlock starts paid generation and detailed progress independently of the free preview", async ({ page }, info) => {
  test.setTimeout(45_000);
  await page.emulateMedia({ reducedMotion: "no-preference" });
  let input = inputFor(), unlocked = false, percent = 0, ready = false, creates = 0, unlocks = 0;
  await page.route("**/api/life-reports**", route => {
    if (route.request().method() === "POST") {
      if (route.request().url().endsWith("/unlock")) { unlocked = true; unlocks++; }
      else { input = route.request().postDataJSON(); creates++; }
    }
    return route.fulfill({ json: !unlocked ? reportFixture(input) : ready ? reportFixture(input, true) : partial(input, percent) });
  });
  await showFreeReport(page);
  expect(creates).toBe(1); expect(unlocks).toBe(0);
  await expect(page.getByTestId("life-background-status")).toHaveText(lifeCopy.zh.backgroundRetry);
  await page.getByTestId("life-unlock-button").click();
  const dialog = page.getByTestId("report-generation"), progress = page.getByRole("progressbar"), video = dialog.locator("video");
  await expect.poll(() => video.evaluate((node: HTMLVideoElement) => !node.paused && node.currentTime > .2)).toBe(true);
  await expect(progress).toHaveAttribute("aria-valuenow", "0");
  percent = 7;
  await expect(progress).toHaveAttribute("aria-valuenow", "7");
  await expect(dialog.getByTestId("generation-sections")).toContainText("35%");
  percent = 14;
  await expect(progress).toHaveAttribute("aria-valuenow", "14");
  await dialog.screenshot({ path: info.outputPath("unlock-detailed-progress.png") });
  await expect(page.getByTestId("life-action-plan")).toHaveCount(0);
  percent = 31;
  await expect(progress).toHaveAttribute("aria-valuenow", "31");
  percent = 99;
  await expect(progress).toHaveAttribute("aria-valuenow", "99");
  await expect(dialog).toBeVisible();
  ready = true;
  await expect(page.getByTestId("life-action-plan")).toBeVisible({ timeout: 8_000 });
  await expect(dialog).toHaveCount(0);
  await expect(page.getByTestId("life-full-report").getByText(lifeCopy.zh.full, { exact: true })).toBeInViewport();
  expect(creates).toBe(1); expect(unlocks).toBe(1);
  await page.reload();
  await expect(page.getByTestId("life-action-plan")).toBeVisible();
});

test("failed full generation retries without creating the free report again", async ({ page }) => {
  let input = inputFor(), unlocks = 0, creates = 0;
  await page.route("**/api/life-reports**", route => {
    if (route.request().method() === "POST") {
      if (route.request().url().endsWith("/unlock")) unlocks++;
      else { input = route.request().postDataJSON(); creates++; }
    }
    const report = partial(input, 23);
    if (!unlocks) return route.fulfill({ json: reportFixture(input) });
    if (unlocks === 1) return route.fulfill({ json: { ...report, full_state: "unavailable" } });
    return route.fulfill({ json: reportFixture(input, true) });
  });
  await showFreeReport(page);
  await page.getByTestId("life-unlock-button").click();
  await expect(page.getByTestId("report-generation")).toContainText(lifeCopy.zh.states.unavailable);
  await expect(page.getByRole("progressbar")).toHaveAttribute("aria-valuenow", "23");
  await page.getByRole("button", { name: lifeCopy.zh.retry, exact: true }).click();
  await expect(page.getByTestId("life-action-plan")).toBeVisible();
  expect(creates).toBe(1); expect(unlocks).toBe(2);
});

test("cancelling the unlock animation preserves the preview and prevents late full display", async ({ page }) => {
  let input = inputFor(), unlocked = false, release!: () => void, started!: () => void;
  const pending = new Promise<void>(resolve => { release = resolve; });
  const polling = new Promise<void>(resolve => { started = resolve; });
  await page.route("**/api/life-reports**", async route => {
    if (route.request().method() === "POST") {
      if (route.request().url().endsWith("/unlock")) unlocked = true;
      else input = route.request().postDataJSON();
    } else if (unlocked) { started(); await pending; }
    await route.fulfill({ json: !unlocked ? reportFixture(input) : route.request().method() === "POST" ? partial(input, 7) : reportFixture(input, true) }).catch(() => {});
  });
  await showFreeReport(page);
  await page.getByTestId("life-unlock-button").click();
  await expect(page.getByRole("progressbar")).toHaveAttribute("aria-valuenow", "7");
  await expect(page.locator(".report-generation-static")).toBeVisible();
  await polling;
  await page.keyboard.press("Escape"); release();
  await expect(page.getByTestId("report-generation")).toHaveCount(0);
  await expect(page.getByTestId("life-free-traits")).toBeVisible();
  await expect(page.getByTestId("life-action-plan")).toHaveCount(0);
});

test("rate-limited unlock progress waits automatically and displays the full report after 100", async ({ page }) => {
  let input = inputFor(), unlocked = false, polls = 0;
  await page.route("**/api/life-reports**", route => {
    if (route.request().method() === "POST") {
      if (route.request().url().endsWith("/unlock")) unlocked = true;
      else input = route.request().postDataJSON();
    } else if (unlocked && ++polls === 1) return route.fulfill({ status: 429, headers: {"Retry-After": "60"}, json: {detail: "too_many_requests"} });
    return route.fulfill({ json: !unlocked ? reportFixture(input) : polls < 2 ? partial(input, 7) : reportFixture(input, true) });
  });
  await showFreeReport(page);
  await page.clock.install({ time: new Date("2026-11-09T08:00:00Z") });
  await page.clock.pauseAt(new Date("2026-11-09T08:00:01Z"));
  await page.getByTestId("life-unlock-button").click();
  await expect(page.getByTestId("report-generation")).toContainText(generationCopy.zh.full);
  await page.clock.runFor(20);
  await expect(page.getByRole("progressbar")).toHaveAttribute("aria-valuenow", "1");
  await page.clock.runFor(20);
  await expect(page.getByRole("progressbar")).toHaveAttribute("aria-valuenow", "2");
  await page.clock.runFor(2960);
  await expect(page.getByTestId("report-generation")).toContainText(generationCopy.zh.waiting);
  await expect(page.getByRole("progressbar")).toHaveAttribute("aria-valuenow", "7");
  await page.clock.runFor(59_999); expect(polls).toBe(1);
  await page.clock.runFor(1);
  await expect(page.getByTestId("report-generation")).toContainText(generationCopy.zh.ready);
  await page.clock.runFor(1860);
  await expect(page.getByRole("progressbar")).toHaveAttribute("aria-valuenow", "100");
  await page.clock.runFor(150);
  await expect(page.getByTestId("life-action-plan")).toBeVisible();
  expect(polls).toBe(2);
});

test("session storage retains access across the separate free report page", async ({ page, context }) => {
  await context.addInitScript(() => Object.defineProperty(window, "localStorage", { get() { throw new DOMException("Blocked", "SecurityError"); } }));
  let input = inputFor(); const keys: string[] = [];
  await page.route("**/api/life-reports**", route => {
    keys.push(route.request().headers()["x-report-key"]);
    if (route.request().method() === "POST") input = route.request().postDataJSON();
    return route.fulfill({ json: reportFixture(input) });
  });
  await showFreeReport(page); await page.reload();
  await expect(page.getByTestId("life-free-traits")).toBeVisible();
  expect(new Set(keys).size).toBe(1);
});

test("missing report IDs show a recoverable separate-page error", async ({ page }) => {
  await page.goto("report.html?lang=zh");
  await expect(page.getByRole("alert")).toHaveText(generationCopy.zh.missing);
  await page.getByRole("link", {name: generationCopy.zh.back, exact: true}).click();
  await expect(page.locator("#birth-form")).toBeVisible();
});

function freeDraft(input: LifeInput, percent: number) {
  const report = reportFixture(input);
  report.preview = null; report.preview_state = "generating";
  report.preview_generation_progress = { percent, sections: (["preview_summary", "preview_strength", "preview_decisions", "preview_relationships"] as const).map((key, index) => ({ key, percent: Math.min(99, Math.max(0, percent * 4 - index * 99)) })) };
  return report;
}

test("free generation plays the video and advances by content before its first paragraph is complete", async ({ page }, info) => {
  test.setTimeout(40_000);
  await page.emulateMedia({ reducedMotion: "no-preference" });
  let input = inputFor(), percent = 1, ready = false, unlocks = 0;
  await page.route("**/api/life-reports**", route => {
    if (route.request().method() === "POST") {
      if (route.request().url().endsWith("/unlock")) unlocks++;
      else {
        expect(new URL(route.request().url()).searchParams.get("wait")).toBe("false");
        input = route.request().postDataJSON();
      }
    }
    return route.fulfill({ json: ready ? reportFixture(input) : freeDraft(input, percent) });
  });
  await fillBirth(page);
  await page.getByRole("button", { name: lifeCopy.zh.generate, exact: true }).click({ force: true });
  const dialog = page.getByTestId("report-generation"), progress = page.getByRole("progressbar");
  await expect(dialog.getByRole("heading")).toHaveText(generationCopy.zh.previewTitle);
  await expect.poll(() => dialog.locator("video").evaluate((node: HTMLVideoElement) => !node.paused && node.currentTime > .2)).toBe(true);
  await expect(progress).toHaveAttribute("aria-valuenow", "1");
  await expect(page.getByTestId("generation-sections").locator("div")).toHaveCount(4);
  percent = 2;
  await expect(progress).toHaveAttribute("aria-valuenow", "2");
  percent = 7;
  await expect(progress).toHaveAttribute("aria-valuenow", "7");
  await expect(page.getByTestId("generation-sections")).toContainText("28%");
  await expect(page).not.toHaveURL(/report\.html/);
  await dialog.screenshot({ path: info.outputPath("free-report-content-progress.png") });
  ready = true;
  await expect(page).toHaveURL(/report\.html/, { timeout: 10_000 });
  await expect(page.getByTestId("life-free-traits").locator("article")).toHaveCount(3);
  await expect(page.getByTestId("life-background-status")).toHaveText(lifeCopy.zh.backgroundRetry);
  await expect(page.getByTestId("life-full-report")).toHaveCount(0);
  expect(unlocks).toBe(0);
});

test("cancelling free content generation keeps birth fields and prevents late navigation", async ({ page }) => {
  let input = inputFor(), started!: () => void, release!: () => void;
  const polling = new Promise<void>(resolve => { started = resolve; });
  const pending = new Promise<void>(resolve => { release = resolve; });
  await page.route("**/api/life-reports**", async route => {
    if (route.request().method() === "POST") input = route.request().postDataJSON();
    else { started(); await pending; }
    await route.fulfill({ json: route.request().method() === "POST" ? freeDraft(input, 3) : reportFixture(input) }).catch(() => {});
  });
  await fillBirth(page);
  await page.getByRole("button", { name: lifeCopy.zh.generate, exact: true }).click();
  await expect(page.getByRole("progressbar")).toHaveAttribute("aria-valuenow", "3");
  await polling;
  await page.keyboard.press("Escape"); release();
  await expect(page.getByTestId("report-generation")).not.toBeVisible();
  expect(await page.getByTestId("report-generation").locator("video").evaluate((video: HTMLVideoElement) => video.paused)).toBe(true);
  await expect(page.locator("#birth-date")).toHaveValue("1995-08-17");
  await expect(page).not.toHaveURL(/report\.html/);
});

test("a completed free report displays even while external font CSS is still loading", async ({ page }) => {
  let input = inputFor(), release!: () => void;
  const font = new Promise<void>(resolve => { release = resolve; });
  await page.route("**/fonts.googleapis.com/**", async route => {
    await font;
    await route.fulfill({ contentType: "text/css", body: "" }).catch(() => {});
  });
  await page.route("**/api/life-reports**", route => {
    if (route.request().method() === "POST") input = route.request().postDataJSON();
    return route.fulfill({ json: reportFixture(input) });
  });
  try {
    await showFreeReport(page);
    await expect(page.getByTestId("life-free-traits").locator("article")).toHaveCount(3);
  } finally { release(); }
});
