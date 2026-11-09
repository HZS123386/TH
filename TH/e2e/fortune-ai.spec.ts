import { expect, test } from '@playwright/test';
import { chooseChineseDate } from './pickers';
import zh from '../src/locales/zh-CN.json' with { type: 'json' };
import type { Fortune } from '../src/lib/fortune';

test('shows native facts while writing, then attaches the matching report and evidence', async ({
  page,
}, info) => {
  let current!: Fortune;
  let release!: () => void;
  const waiting = new Promise<void>((resolve) => {
    release = resolve;
  });
  await page.route('**/api/fortune', async (route) => {
    const response = await route.fetch();
    current = await response.json();
    await route.fulfill({
      response,
      json: { ...current, generation: { available: true, state: 'rules', cached: false } },
    });
  });
  await page.route('**/api/fortune/narrative', async (route) => {
    await waiting;
    expect(route.request().postDataJSON().for_date).toBe(current.calendar.date);
    await route.fulfill({
      json: {
        period: current.period,
        period_start: current.period_start,
        period_end: current.period_end,
        for_date: current.calendar.date,
        analysis_signature: current.analysis!.signature,
        narrative: {
          ...current.narrative,
          source: 'ai',
          paragraphs: [
            '今天适合让自己的表达更清楚，也给重要的关系留出温柔的回应空间。',
            '面对新的想法，可以先感受它与你当前生活是否合拍，再决定投入的节奏。',
          ],
          paragraph_evidence: current.analysis!.factors.slice(0, 2).map((factor) => [factor.id]),
        },
        generation: { available: true, state: 'ready', cached: false },
      },
    });
  });
  await page.goto('/');
  await page.getByRole('radio', { name: /简体中文/ }).check();
  await page.getByRole('button', { name: zh.confirmLanguage, exact: true }).click();
  await chooseChineseDate(page, '1999-02-20');
  await page.getByRole('button', { name: zh.f_cta, exact: true }).click();
  await expect(page.getByText(zh.o_generating, { exact: true })).toBeVisible();
  await expect(page.getByTestId('fortune-focus')).toContainText('1999-02-20');
  release();
  await expect(page.getByTestId('fortune-narrative')).toContainText('今天适合让自己的表达更清楚');
  await expect(page.getByTestId('fortune-paragraph-evidence')).toHaveCount(2);
  await expect(page.getByText(zh.o_generating, { exact: true })).toHaveCount(0);
  await expect(
    page.getByTestId('jy-fortune-page').getByText(zh.o_ai, { exact: true }),
  ).toBeVisible();
  await page.getByTestId('fortune-basis').locator('summary').first().click();
  await page.getByTestId('fortune-analysis').locator('summary').first().click();
  await expect(page.getByTestId('fortune-analysis')).toContainText('opastro@0.1.9');
  await expect(page.locator(`[data-factor-id="${current.analysis!.factors[0].id}"]`)).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({ path: `test-results/opastro-${info.project.name}.png`, fullPage: true });
});

test('keeps native results readable if personalized writing fails', async ({ page }) => {
  await page.route('**/api/fortune', async (route) => {
    const response = await route.fetch();
    const value: Fortune = await response.json();
    await route.fulfill({
      response,
      json: { ...value, generation: { available: true, state: 'rules', cached: false } },
    });
  });
  await page.route('**/api/fortune/narrative', (route) =>
    route.fulfill({ status: 503, json: { detail: 'unavailable' } }),
  );
  await page.goto('/');
  await page.getByRole('radio', { name: /简体中文/ }).check();
  await page.getByRole('button', { name: zh.confirmLanguage, exact: true }).click();
  await chooseChineseDate(page, '1999-02-20');
  await page.getByRole('button', { name: zh.f_cta, exact: true }).click();
  await expect(page.getByTestId('fortune-focus')).toContainText(zh.o_fallback);
  await expect(
    page.getByTestId('fortune-focus').getByRole('button', { name: zh.retry, exact: true }),
  ).toBeVisible();
  await expect(page.getByTestId('fortune-narrative')).not.toBeEmpty();
  await expect(page.getByTestId('fortune-topics').getByRole('article')).toHaveCount(4);
});
